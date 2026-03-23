;;; my-speed-dial.el --- Custom workspace speed dial (SQLite Edition) -*- lexical-binding: t; byte-compile-warnings: (not docstrings redefine) -*-

(require 'bookmark)
(require 'cl-lib)
(require 'sqlite)

;; Let the compiler know about use-package
(eval-when-compile
  (require 'use-package))

;; Ensure required packages are loaded for macros
(use-package evil :ensure t)
(use-package hydra :ensure t)

;; Tell the byte-compiler about functions generated later
(declare-function hydra-speed-dial/body "my-speed-dial")
(declare-function my/refresh-speed-dial-hud "my-speed-dial")

;; ==========================================
;; 1. SQLITE DATABASE INITIALIZATION
;; ==========================================

(unless (fboundp 'sqlite-open)
  (error "Your Emacs was compiled without SQLite support! Emacs 29+ requires SQLite for this speed-dial."))

(defvar my/sd-db-file (expand-file-name "speed-dial.sqlite" user-emacs-directory)
  "Path to the SQLite database storing speed dial slots.")

(defvar my/sd-db nil
  "The active SQLite database connection.")

(defun my/sd-init-db ()
  "Initialize the SQLite database and create schemas if they don't exist."
  (unless my/sd-db
    (setq my/sd-db (sqlite-open my/sd-db-file))
    (sqlite-execute my/sd-db "
      CREATE TABLE IF NOT EXISTS speed_dial (
        workspace TEXT,
        tag TEXT,
        slot INTEGER,
        name TEXT,
        record TEXT,
        PRIMARY KEY (workspace, tag, slot)
      )")
    (sqlite-execute my/sd-db "
      CREATE TABLE IF NOT EXISTS state (
        key TEXT PRIMARY KEY,
        value TEXT
      )")))

;; Initialize immediately upon load
(my/sd-init-db)

;; ==========================================
;; 2. GLOBAL STATE & VARIABLES
;; ==========================================

(defvar my/current-workspace-root nil
  "The manually selected workspace directory.")

(defvar my/current-speed-dial-tag nil 
  "The currently active dynamic tag (Right Hand).")

(defvar my/speed-dial-mode 'normal 
  "Can be `normal', `pick', `drop', `tag', or `untag'.")

(defvar my/pending-move-src nil 
  "Cons cell (tag . slot) representing the slot being moved.")

(defvar my/pending-tag-target nil 
  "A file selected in the background waiting to be assigned a slot.")


;; ==========================================
;; 3. CORE HELPERS & UTILITIES
;; ==========================================

(defun my/get-workspace ()
  "Return the active workspace, or throw an error if none is set."
  (unless my/current-workspace-root
    (error "No workspace locked! Use <leader> a p to select your target workspace"))
  my/current-workspace-root)

(defun my/sd-name (side num)
  "Fetch the name of the bookmark for a given side and slot number."
  (let ((val "-"))
    (when my/current-workspace-root
      (let* ((root my/current-workspace-root)
             (tag (if (eq side 'left) "global" my/current-speed-dial-tag)))
        (when tag
          (let ((row (sqlite-select my/sd-db 
                                    "SELECT name FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                    (list root tag num))))
            (when row
              (let ((raw-name (caar row)))
                (setq val (if (file-name-absolute-p raw-name) 
                              (file-name-nondirectory raw-name) 
                            raw-name))))))))
    (truncate-string-to-width val 35 0 ?\s "…")))

;; --- STATE PERSISTENCE HELPERS ---

(defun my/get-saved-workspace-tag (root)
  "Retrieve the last used right-hand tag for the workspace ROOT."
  (let ((row (sqlite-select my/sd-db "SELECT value FROM state WHERE key=?" 
                            (list (concat "workspace_tag|" root)))))
    (when row (caar row))))

(defun my/save-workspace-tag (root tag)
  "Save TAG as the last active right-hand tag for workspace ROOT."
  (if tag
      (sqlite-execute my/sd-db "INSERT OR REPLACE INTO state (key, value) VALUES (?, ?)" 
                      (list (concat "workspace_tag|" root) tag))
    (sqlite-execute my/sd-db "DELETE FROM state WHERE key=?" 
                    (list (concat "workspace_tag|" root)))))

(defun my/save-global-workspace-state (root)
  "Save the globally active workspace so it restores on Emacs startup."
  (sqlite-execute my/sd-db "INSERT OR REPLACE INTO state (key, value) VALUES ('global_workspace', ?)" 
                  (list root)))

(defun my/load-global-workspace-state ()
  "Load the last active workspace on Emacs startup."
  (let ((row (sqlite-select my/sd-db "SELECT value FROM state WHERE key='global_workspace'")))
    (when row
      (let ((root (caar row)))
        (when (and root (file-exists-p root))
          (setq my/current-workspace-root root)
          (setq my/current-speed-dial-tag (my/get-saved-workspace-tag root)))))))

;; ==========================================
;; 4. WORKSPACE & TAGGING LOGIC
;; ==========================================

(defun my/set-workspace ()
  "Manually lock Emacs into a specific workspace directory."
  (interactive)
  (let* ((target-dir (read-directory-name "Select workspace directory: "))
         (root (expand-file-name (file-name-as-directory target-dir)))
         (saved-tag (my/get-saved-workspace-tag root)))
    (setq my/current-workspace-root root)
    (setq my/current-speed-dial-tag saved-tag)
    (my/save-global-workspace-state root)
    (if saved-tag
        (message "Workspace locked to: %s (Restored tag: [%s])" root saved-tag)
      (message "Workspace locked to: %s" root))
    (my/refresh-speed-dial-hud)))

(defun my/set-speed-dial-tag ()
  "Choose a tag for the RIGHT hand keys in the locked workspace."
  (interactive)
  (let* ((root (my/get-workspace))
         (rows (sqlite-select my/sd-db "SELECT DISTINCT tag FROM speed_dial WHERE workspace=? AND tag != 'global'" (list root)))
         (all-tags (mapcar #'car rows))
         (other-tags (remove my/current-speed-dial-tag all-tags)))
    (if (not other-tags)
        (if all-tags
            (message "You are already on the only tag [%s]! Press 'C' to create a new one." my/current-speed-dial-tag)
          (message "No custom tags found! Press 'C' to create one."))
      (setq my/current-speed-dial-tag (completing-read "Select tag for RIGHT hand: " other-tags))
      (my/save-workspace-tag root my/current-speed-dial-tag)
      (message "Locked right hand to tag:[%s]" my/current-speed-dial-tag)
      (my/refresh-speed-dial-hud))))

(defun my/project-bookmark-jump ()
  "Jump to any bookmark inside your manually locked workspace."
  (interactive)
  (if-let ((root my/current-workspace-root))
      (let* ((rows (sqlite-select my/sd-db "SELECT name, tag, slot, record FROM speed_dial WHERE workspace=?" (list root)))
             (choices (mapcar (lambda (row)
                                (let ((name (nth 0 row)) (tag (nth 1 row)) (slot (nth 2 row)))
                                  (cons (format "[%s-%d] %s" tag slot name) row)))
                              rows)))
        (if choices
            (let* ((choice (completing-read "Workspace Bookmarks: " choices))
                   (row-data (cdr (assoc choice choices)))
                   (bm-name (nth 0 row-data))
                   (raw-data (read (nth 3 row-data))))
              (bookmark-jump (cons bm-name raw-data)))
          (message "No bookmarks found in locked workspace: %s" root)))
    (message "No workspace locked! Press '<leader> a p' to select one first.")))

(defun my/bookmark-set-absolute ()
  "Standard global Emacs bookmarking (bypasses SQLite)."
  (interactive)
  (call-interactively 'bookmark-set))

(defun my/bookmark-tag-current-file ()
  "Quickly tag the current file into the first available slot of a chosen tag."
  (interactive)
  (let* ((root (my/get-workspace))
         (tag (read-string (format "Assign to tag (default %s): " (or my/current-speed-dial-tag "main")) 
                           nil nil (or my/current-speed-dial-tag "main")))
         (record (bookmark-make-record))
         (name (if buffer-file-name (file-name-nondirectory buffer-file-name) (car record)))
         (data-str (prin1-to-string (cdr record))))
    
    (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND name=?" (list root tag name))
    
    (let* ((used-slots (mapcar #'car (sqlite-select my/sd-db "SELECT slot FROM speed_dial WHERE workspace=? AND tag=?" (list root tag))))
           (free-slot (cl-find-if-not (lambda (s) (member s used-slots)) '(1 2 3 4 5 6 7 8))))
      (if (not free-slot)
          (message "Tag[%s] is full! All 8 slots are used." tag)
        (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                        (list root tag free-slot name data-str))
        (message "Pinned '%s' to Slot %d on[%s]" name free-slot tag)
        (my/refresh-speed-dial-hud)))))

;; ==========================================
;; 5. CORE SPEED DIAL LOGIC
;; ==========================================

(defun my/sd-generate-record-for (target)
  "Generate a fresh bookmark record for a file without opening its buffer permanently."
  (if target
      (with-current-buffer (find-file-noselect target)
        (bookmark-make-record))
    (bookmark-make-record)))

(defun my/speed-dial-jump (tag num)
  "Jump to the NUM-th slot of TAG, or handle Move, Tag, and Untag modes."
  (when (and (not tag) (or (eq my/speed-dial-mode 'tag) (eq my/speed-dial-mode 'drop)))
    (let ((root (my/get-workspace)))
      (setq tag "main")
      (setq my/current-speed-dial-tag "main")
      (my/save-workspace-tag root "main")
      (my/refresh-speed-dial-hud)
      (message "Auto-created default dynamic tag:[main]")))

  (if (not tag)
      (progn
        (message "No dynamic tag set for the right hand! Press 't' to lock one.")
        (when (not (eq my/speed-dial-mode 'normal))
          (hydra-speed-dial/body)))

    (let* ((root (my/get-workspace))
           (row (sqlite-select my/sd-db "SELECT name, record FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                               (list root tag num))))

      (cond
       ;; --- NORMAL MODE ---
       ((eq my/speed-dial-mode 'normal)
        (if row
            (let* ((name (nth 0 (car row)))
                   (data (read (nth 1 (car row))))
                   (file-path (alist-get 'filename data))
                   (exp-path (when file-path (expand-file-name file-path))))
              (cond
               ((and exp-path (not (file-exists-p exp-path)))
                (message "Path '%s' no longer exists! Auto-cleaning slot..." exp-path)
                (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" (list root tag num))
                (my/refresh-speed-dial-hud)
                (hydra-speed-dial/body))
               ((and exp-path (not (file-directory-p exp-path)))
                ;; Use find-file for actual files so save-place-mode handles cursor position!
                (let ((buf (find-buffer-visiting exp-path)))
                  (if buf (switch-to-buffer buf) (find-file exp-path)))
                (my/refresh-speed-dial-hud)) ;; EXPLICIT FORCE UPDATE FOR PDFs
               (t 
                ;; Let Emacs's bookmark engine handle Magit, Dired, etc.
                (bookmark-jump (cons name data))
                (my/refresh-speed-dial-hud)))) ;; EXPLICIT FORCE UPDATE FOR PDFs
          (message "Empty slot")))

       ;; --- TAG MODE (NON-DESTRUCTIVE CASCADE) ---
       ((eq my/speed-dial-mode 'tag)
        (let* ((record (my/sd-generate-record-for my/pending-tag-target))
               (moving-name (if my/pending-tag-target (file-name-nondirectory my/pending-tag-target) (car record)))
               (moving-data (prin1-to-string (cdr record))))
          
          (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND name=?" (list root tag moving-name))
          
          (let ((current-name moving-name)
                (current-data moving-data))
            (cl-loop for s from num to 8 do
                     (let ((occupant (sqlite-select my/sd-db "SELECT name, record FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                                    (list root tag s))))
                       (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                                       (list root tag s current-name current-data))
                       (if occupant
                           (setq current-name (nth 0 (car occupant))
                                 current-data (nth 1 (car occupant)))
                         (cl-return)))))

          (setq my/speed-dial-mode 'normal
                my/pending-tag-target nil)
          (my/refresh-speed-dial-hud)
          (message "Tagged '%s' to slot %d on [%s]!" moving-name num tag)
          (hydra-speed-dial/body)))

       ;; --- PICK MODE ---
       ((eq my/speed-dial-mode 'pick)
        (if (not row)
            (message "That slot is empty! Press a key with an active bookmark.")
          (setq my/pending-move-src (cons tag num))
          (setq my/speed-dial-mode 'drop))
        (hydra-speed-dial/body))

       ;; --- DROP MODE (SWAP vs SHIFT LOGIC) ---
       ((eq my/speed-dial-mode 'drop)
        (let* ((old-tag (car my/pending-move-src))
               (old-slot (cdr my/pending-move-src))
               (old-row (sqlite-select my/sd-db "SELECT name, record FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                       (list root old-tag old-slot))))
          (when old-row
            (let ((moving-name (nth 0 (car old-row)))
                  (moving-data (nth 1 (car old-row))))
              
              (if (string= old-tag tag)
                  ;; =========================================
                  ;; 1. SAME SIDE (SWAP)
                  ;; =========================================
                  (unless (= old-slot num)
                    (let ((target-occupant (sqlite-select my/sd-db "SELECT name, record FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                                          (list root tag num))))
                      ;; Overwrite the destination slot with the item we are carrying
                      (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                                      (list root tag num moving-name moving-data))
                      
                      ;; Put the displaced target occupant back into the source slot
                      (if target-occupant
                          (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                                          (list root old-tag old-slot (nth 0 (car target-occupant)) (nth 1 (car target-occupant))))
                        ;; If target was empty, just clear the old source slot
                        (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                        (list root old-tag old-slot)))
                      (message "Swapped '%s' to slot %d!" moving-name num)))

                ;; =========================================
                ;; 2. DIFFERENT SIDES (SHIFT / CASCADE)
                ;; =========================================
                (progn
                  ;; Delete item from old slot completely
                  (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                  (list root old-tag old-slot))
                  ;; Prevent duplicates on the new side
                  (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND name=?" 
                                  (list root tag moving-name))
                  
                  ;; Perform the Cascade Shift down the list
                  (let ((current-name moving-name)
                        (current-data moving-data))
                    (cl-loop for s from num to 8 do
                             (let ((occupant (sqlite-select my/sd-db "SELECT name, record FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                                            (list root tag s))))
                               (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                                               (list root tag s current-name current-data))
                               (if occupant
                                   (setq current-name (nth 0 (car occupant))
                                         current-data (nth 1 (car occupant)))
                                 (cl-return)))))
                  (message "Moved '%s' across sides to slot %d (shifted others down)!" moving-name num)))))
          
          ;; Cleanup and reset mode
          (setq my/speed-dial-mode 'normal
                my/pending-move-src nil)
          (my/refresh-speed-dial-hud)
          (hydra-speed-dial/body)))

       ;; --- UNTAG MODE ---
       ((eq my/speed-dial-mode 'untag)
        (if (not row)
            (message "That slot is already empty!")
          (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" (list root tag num))
          (message "Untagged slot %d from [%s]" num tag))
        (setq my/speed-dial-mode 'normal)
        (my/refresh-speed-dial-hud)
        (hydra-speed-dial/body))))))

;; ==========================================
;; 6. HYDRA HELPER FUNCTIONS
;; ==========================================

(defun my/hydra-consolidate-slots ()
  "Remove all gaps by shifting filled slots to be contiguous starting from slot 1.
Applies to both the left hand (global) and right hand (dynamic tag)."
  (interactive)
  (let* ((root (my/get-workspace))
         (tags (list "global" my/current-speed-dial-tag))
         (total-moved 0))
    
    (dolist (tag tags)
      (when tag
        ;; 1. Fetch all existing bookmarks for the tag, naturally ordered by their current slot
        (let ((rows (sqlite-select my/sd-db "SELECT slot, name, record FROM speed_dial WHERE workspace=? AND tag=? ORDER BY slot ASC" (list root tag))))
          
          ;; 2. Nuke the slots for this tag entirely
          (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=?" (list root tag))
          
          ;; 3. Re-insert them starting at 1
          (let ((new-slot 1))
            (dolist (row rows)
              (let ((name (nth 1 row))
                    (record (nth 2 row)))
                (sqlite-execute my/sd-db "INSERT INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                                (list root tag new-slot name record))
                (cl-incf new-slot)
                (cl-incf total-moved)))))))
    
    (my/refresh-speed-dial-hud)
    (message "Workspace organized! Shifted %d bookmarks to close all gaps." total-moved))
  (hydra-speed-dial/body))

(defun my/hydra-find-and-tag ()
  "Find a file to pin without visiting it immediately."
  (interactive)
  (setq my/speed-dial-mode 'tag)
  (setq my/pending-tag-target nil)
  (let* ((original-dir default-directory) 
         (hud-text
          (format "
  WORKSPACE: %s
  TAG (R)  : %s

  >>>[TAG MODE] SEARCHING FOR FILE... PRESS A SLOT KEY AFTERWARDS <<<

  GLOBAL (Left Hand)                DYNAMIC (Right Hand)
  [a]: %-22s  [j]: %-22s
  [s]: %-22s  [k]: %-22s[d]: %-22s  [l]: %-22s[f]: %-22s  [;]: %-22s
  [z]: %-22s[m]: %-22s
  [x]: %-22s  [,]: %-22s                      
  [c]: %-22s  [.]: %-22s
  [v]: %-22s  [/]: %-22s
"
                  (or my/current-workspace-root "[None Locked]")
                  (or my/current-speed-dial-tag "[No Tag Selected]")
                  (my/sd-name 'left 1) (my/sd-name 'right 1)
                  (my/sd-name 'left 2) (my/sd-name 'right 2)
                  (my/sd-name 'left 3) (my/sd-name 'right 3)
                  (my/sd-name 'left 4) (my/sd-name 'right 4)
                  (my/sd-name 'left 5) (my/sd-name 'right 5)
                  (my/sd-name 'left 6) (my/sd-name 'right 6)
                  (my/sd-name 'left 7) (my/sd-name 'right 7)
                  (my/sd-name 'left 8) (my/sd-name 'right 8)))
         (buf (get-buffer-create " *Speed-Dial HUD*"))
         (win nil)
         (selected-file nil))
    (with-current-buffer buf
      (erase-buffer) (insert (propertize hud-text 'face 'bold))
      (goto-char (point-min))
      (setq-local mode-line-format nil header-line-format nil cursor-type nil window-size-fixed t))
    (setq win (display-buffer buf '((display-buffer-in-side-window) (side . top) (window-height . fit-window-to-buffer))))
    (set-window-dedicated-p win t)
    
    (condition-case nil
        (unwind-protect
            (let ((default-directory original-dir))
              (setq selected-file (read-file-name "Select file to pin: ")))
          (when (window-live-p win) (delete-window win))
          (kill-buffer buf))
      (quit (setq my/speed-dial-mode 'normal) (message "Cancelled Find & Tag")))
      
    (when selected-file
      (setq my/pending-tag-target (expand-file-name selected-file)))
    (hydra-speed-dial/body)))

(defun my/hydra-start-tag ()   (interactive) (setq my/pending-tag-target nil my/speed-dial-mode (if (eq my/speed-dial-mode 'normal) 'tag 'normal)) (hydra-speed-dial/body))
(defun my/hydra-start-move ()  (interactive) (setq my/speed-dial-mode (if (eq my/speed-dial-mode 'normal) 'pick 'normal)) (hydra-speed-dial/body))
(defun my/hydra-start-untag () (interactive) (setq my/speed-dial-mode (if (eq my/speed-dial-mode 'normal) 'untag 'normal)) (hydra-speed-dial/body))

(defun my/hydra-quit () 
  (interactive) 
  (setq my/speed-dial-mode 'normal 
        my/pending-move-src nil 
        my/pending-tag-target nil))

(defun my/hydra-create-tag ()
  (interactive)
  (let ((new-tag (read-string "Create new tag: ")))
    (if (string= "" new-tag)
        (message "Cancelled: Tag name cannot be empty.")
      (setq my/current-speed-dial-tag new-tag)
      (my/save-workspace-tag (my/get-workspace) new-tag)
      (my/refresh-speed-dial-hud)
      (message "Created and locked new tag: [%s]" new-tag)))
  (hydra-speed-dial/body))

(defun my/hydra-wipe-tag ()
  "Remove a specific tag entirely from the database."
  (interactive)
  (let* ((root (my/get-workspace))
         (rows (sqlite-select my/sd-db "SELECT DISTINCT tag FROM speed_dial WHERE workspace=? AND tag != 'global'" (list root)))
         (clean-tags (mapcar #'car rows)))
    (if (not clean-tags)
        (message "No custom tags exist in this workspace!")
      (let ((tag-to-nuke (completing-read "Wipe tag completely: " clean-tags nil t)))
        (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=?" (list root tag-to-nuke))
        (when (string= my/current-speed-dial-tag tag-to-nuke) 
          (setq my/current-speed-dial-tag nil)
          (my/save-workspace-tag root nil))
        (my/refresh-speed-dial-hud)
        (message "Wiped tag '%s'." tag-to-nuke))))
  (hydra-speed-dial/body))

(defun my/hydra-wipe-workspace ()
  "Remove all bookmarks from the workspace but KEEP the workspace locked."
  (interactive)
  (let* ((root (my/get-workspace))
         (count (caar (sqlite-select my/sd-db "SELECT COUNT(*) FROM speed_dial WHERE workspace=?" (list root)))))
    (if (= count 0)
        (message "Workspace is already empty! No bookmarks to remove.")
      (when (y-or-n-p (format "DANGER: Wipe all contents of workspace '%s' (%d slots)? " 
                              (file-name-nondirectory (directory-file-name root)) count))
        (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=?" (list root))
        (my/save-workspace-tag root nil)
        (setq my/current-speed-dial-tag nil)
        (my/refresh-speed-dial-hud)
        (message "Workspace contents wiped successfully!"))))
  (hydra-speed-dial/body))

(defun my/set-workspace-and-resume () (interactive) (call-interactively 'my/set-workspace) (hydra-speed-dial/body))
(defun my/set-tag-and-resume ()       (interactive) (call-interactively 'my/set-speed-dial-tag) (hydra-speed-dial/body))

(defun my/hydra-rename-tag ()
  "Rename an existing tag and move all its files to the new name."
  (interactive)
  (let* ((root (my/get-workspace))
         (rows (sqlite-select my/sd-db "SELECT DISTINCT tag FROM speed_dial WHERE workspace=? AND tag != 'global'" (list root)))
         (clean-tags (mapcar #'car rows)))
    (if (not clean-tags)
        (message "No tags exist to rename!")
      (let* ((old-tag (completing-read "Rename tag: " clean-tags nil t))
             (new-tag (read-string (format "Rename[%s] to: " old-tag))))
        (if (or (string= "" new-tag) (member new-tag clean-tags))
            (message "Cancelled: Tag name cannot be empty or already exist.")
          (sqlite-execute my/sd-db "UPDATE OR REPLACE speed_dial SET tag=? WHERE workspace=? AND tag=?" 
                          (list new-tag root old-tag))
          (when (string= my/current-speed-dial-tag old-tag)
            (setq my/current-speed-dial-tag new-tag)
            (my/save-workspace-tag root new-tag))
          (my/refresh-speed-dial-hud)
          (message "Renamed tag [%s] to[%s]!" old-tag new-tag)))))
  (hydra-speed-dial/body))

(defun my/hydra-copy-tag ()
  "Copy an existing tag and its slot layout into a new tag name."
  (interactive)
  (let* ((root (my/get-workspace))
         (rows (sqlite-select my/sd-db "SELECT DISTINCT tag FROM speed_dial WHERE workspace=? AND tag != 'global'" (list root)))
         (clean-tags (mapcar #'car rows)))
    (if (not clean-tags)
        (message "No tags exist to copy!")
      (let* ((old-tag (completing-read "Copy tag: " clean-tags nil t))
             (new-tag (read-string (format "Copy [%s] to new tag: " old-tag))))
        (if (or (string= "" new-tag) (member new-tag clean-tags))
            (message "Cancelled: Tag name cannot be empty or already exist.")
          (let ((slots (sqlite-select my/sd-db "SELECT slot, name, record FROM speed_dial WHERE workspace=? AND tag=?" 
                                      (list root old-tag))))
            (dolist (slot-row slots)
              (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                              (list root new-tag (nth 0 slot-row) (nth 1 slot-row) (nth 2 slot-row))))
            (my/refresh-speed-dial-hud)
            (message "Copied layout of [%s] into[%s]!" old-tag new-tag))))))
  (hydra-speed-dial/body))

(defun my/hydra-clone-workspace ()
  "Clone another workspace's layout INTO the currently locked workspace."
  (interactive)
  (unless my/current-workspace-root
    (error "No workspace locked! Press 'p' to lock into your blank target workspace first."))
    
  (let* ((target-root (expand-file-name (file-name-as-directory my/current-workspace-root)))
         (all-rows (sqlite-select my/sd-db "SELECT DISTINCT workspace FROM speed_dial"))
         (all-workspaces (mapcar #'car all-rows))
         (source-workspaces (remove target-root all-workspaces)))
         
    (unless source-workspaces
      (error "No other workspaces found to clone from!"))
      
    (let* ((source-root (completing-read "Source workspace to clone from: " source-workspaces nil t))
           (source-root-exp (expand-file-name (file-name-as-directory source-root)))
           (target-count (caar (sqlite-select my/sd-db "SELECT COUNT(*) FROM speed_dial WHERE workspace=?" (list target-root)))))

      (when (> target-count 0)
        (error "Current workspace already contains bookmarks! Please nuke it first (X) before cloning."))

      (let ((rows (sqlite-select my/sd-db "SELECT tag, slot, name, record FROM speed_dial WHERE workspace=?" (list source-root-exp))))
        
        ;; PRE-FLIGHT CHECK
        (let ((missing-files nil))
          (dolist (row rows)
            (let* ((data (read (nth 3 row)))
                   (raw-path (alist-get 'filename data))
                   (old-path (when raw-path (expand-file-name raw-path))))
              (when (and old-path (string-prefix-p source-root-exp old-path))
                (let ((new-path (concat target-root (substring old-path (length source-root-exp)))))
                  (unless (file-exists-p new-path)
                    (push new-path missing-files))))))
          (when missing-files
            (error "Abort: Target directory is missing %d required files (e.g., '%s'). Did you copy the project files?"
                   (length missing-files) (file-name-nondirectory (car missing-files)))))

        ;; CLONE EXECUTION
        (dolist (row rows)
          (let* ((tag (nth 0 row))
                 (slot (nth 1 row))
                 (name (nth 2 row))
                 (data (read (nth 3 row)))
                 (raw-path (alist-get 'filename data))
                 (old-path (when raw-path (expand-file-name raw-path))))
            
            ;; Adjust internal paths (Only triggers if the file was inside the original project folder)
            (when (and old-path (string-prefix-p source-root-exp old-path))
              (setf (alist-get 'filename data) 
                    (abbreviate-file-name (concat target-root (substring old-path (length source-root-exp))))))
            
            ;; Adjust floating names if they are pure paths
            (let ((new-name name))
              (when (and name (file-name-absolute-p name))
                (let ((exp-name (expand-file-name name)))
                  (when (string-prefix-p source-root-exp exp-name)
                    (setq new-name (abbreviate-file-name (concat target-root (substring exp-name (length source-root-exp))))))))
              
              (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                              (list target-root tag slot new-name (prin1-to-string data))))))
        
        ;; CLONE THE META-STATE
        (let ((source-tag (my/get-saved-workspace-tag source-root-exp)))
          (when source-tag
            (my/save-workspace-tag target-root source-tag)
            (setq my/current-speed-dial-tag source-tag)))

        (my/refresh-speed-dial-hud)
        (message "Successfully pulled %d slots from '%s' into current workspace!" 
                 (length rows) (file-name-nondirectory (directory-file-name source-root-exp))))))
  (hydra-speed-dial/body))

;; ==========================================
;; 7. HYDRA HUD MANAGER
;; ==========================================

(defhydra hydra-speed-dial (:color blue :hint nil)
  "
^WORKSPACE^: %s(or my/current-workspace-root \"[None Locked - Press 'p']\")
^TAG    ^  : %s(or my/current-speed-dial-tag \"[No Tag Selected - Press 't']\")%s(cond
  ((eq my/speed-dial-mode 'pick)
   \"\n\n  >>>[MOVE MODE] PRESS BOOKMARK KEY TO PICK UP <<<\")
  ((eq my/speed-dial-mode 'drop)
   (let* ((tag (car my/pending-move-src))
          (slot (cdr my/pending-move-src))
          (row (sqlite-select my/sd-db \"SELECT name FROM speed_dial WHERE workspace=? AND tag=? AND slot=?\" (list (my/get-workspace) tag slot))))
     (format \"\n\n  >>>[MOVE MODE] CARRYING:[%s] ... PRESS TARGET KEY TO DROP! <<<\"
             (if row (file-name-nondirectory (caar row)) \"Unknown\"))))
  ((eq my/speed-dial-mode 'untag)
   \"\n\n  >>>[UNTAG MODE] PRESS SLOT KEY TO UNTAG <<<\")
  ((eq my/speed-dial-mode 'tag)
   (if my/pending-tag-target
       (format \"\n\n  >>>[TAG MODE] READY TO PIN: [%s] ... PRESS A SLOT KEY <<<\"
               (file-name-nondirectory my/pending-tag-target))
     \"\n\n  >>>[TAG MODE] PRESS SLOT KEY TO TAG CURRENT FILE <<<\"))
  (t \"\"))
-----------------------------------------------------------------------------------------------------
_a_: %s(my/sd-name 'left 1)  _j_: %s(my/sd-name 'right 1)  _T_: Tag File     _C_: Create Tag
_s_: %s(my/sd-name 'left 2)  _k_: %s(my/sd-name 'right 2)  _F_: Find & Tag   _R_: Rename Tag
_d_: %s(my/sd-name 'left 3)  _l_: %s(my/sd-name 'right 3)  _U_: Untag Slot   _Y_: Copy Tag
_f_: %s(my/sd-name 'left 4)  _;_: %s(my/sd-name 'right 4)  _M_: Toggle Move  _W_: Wipe Tag
_z_: %s(my/sd-name 'left 5)  _m_: %s(my/sd-name 'right 5)  _O_: Organize HUD _X_: Nuke Workspace
_x_: %s(my/sd-name 'left 6)  _,_: %s(my/sd-name 'right 6)  
_c_: %s(my/sd-name 'left 7)  _._: %s(my/sd-name 'right 7)  _p_: Lock Workspc | _P_: Clone Workspc
_v_: %s(my/sd-name 'left 8)  _/_: %s(my/sd-name 'right 8)  _t_: Lock Tag     | _q_: Quit HUD
  "
  ("a" (my/speed-dial-jump "global" 1)) ("s" (my/speed-dial-jump "global" 2))
  ("d" (my/speed-dial-jump "global" 3)) ("f" (my/speed-dial-jump "global" 4))
  ("z" (my/speed-dial-jump "global" 5)) ("x" (my/speed-dial-jump "global" 6))
  ("c" (my/speed-dial-jump "global" 7)) ("v" (my/speed-dial-jump "global" 8))

  ("j" (my/speed-dial-jump my/current-speed-dial-tag 1))
  ("k" (my/speed-dial-jump my/current-speed-dial-tag 2))
  ("l" (my/speed-dial-jump my/current-speed-dial-tag 3))
  (";" (my/speed-dial-jump my/current-speed-dial-tag 4))
  ("m" (my/speed-dial-jump my/current-speed-dial-tag 5))
  ("," (my/speed-dial-jump my/current-speed-dial-tag 6))
  ("." (my/speed-dial-jump my/current-speed-dial-tag 7))
  ("/" (my/speed-dial-jump my/current-speed-dial-tag 8))

  ("T" my/hydra-start-tag) ("F" my/hydra-find-and-tag) ("U" my/hydra-start-untag)
  ("M" my/hydra-start-move) ("O" my/hydra-consolidate-slots) 
  ("C" my/hydra-create-tag) ("W" my/hydra-wipe-tag) ("R" my/hydra-rename-tag) 
  ("Y" my/hydra-copy-tag) ("X" my/hydra-wipe-workspace) 
  ("p" my/set-workspace-and-resume) ("P" my/hydra-clone-workspace) 
  ("t" my/set-tag-and-resume) 
  ("q" my/hydra-quit) ("<escape>" my/hydra-quit) ("C-g" my/hydra-quit))

;; ==========================================
;; 8. Auto-load Last Workspace
;; ==========================================
(my/load-global-workspace-state)

;; Ensure subr-x is loaded for string trimming
(require 'subr-x)

;; ==========================================
;; 8.5 PERSISTENT TMUX-STYLE HUD (TOP & BOTTOM)
;; ==========================================

(defvar my/speed-dial-hud-buffer-name " *Speed-Dial-HUD*")
(defvar my/speed-dial-global-hud-buffer-name " *Speed-Dial-Global-HUD*")

(defun my/sd-generate-hud-string (keys side active-buf active-file)
  "Generates the flexbox string for a HUD bar, given the keys and the side (left/right)."
  (let* ((items (cl-loop for i from 1 to 8
                         for k in keys
                         for raw-name = (my/sd-name side i)
                         ;; Strip all invisible text properties and accidental spaces
                         for clean-name = (string-trim (substring-no-properties raw-name))
                         unless (string= clean-name "-")
                         collect 
                         ;; --- DYNAMIC MATCHING LOGIC (BULLETPROOF) ---
                         (let* ((b-name (and active-buf (substring-no-properties active-buf)))
                                (f-name (and active-file (file-name-nondirectory (substring-no-properties active-file))))
                                
                                ;; Detect if my/sd-name truncated this string with the "…" symbol
                                (is-truncated (string-suffix-p "…" clean-name))
                                (base-name (if is-truncated (substring clean-name 0 -1) clean-name))
                                
                                ;; Check if buffer name OR file name matches (handles PDF tools and text properties)
                                (is-active (or (and b-name (if is-truncated (string-prefix-p base-name b-name) (string= base-name b-name)))
                                               (and f-name (if is-truncated (string-prefix-p base-name f-name) (string= base-name f-name)))))
                                
                                ;; Swap ) for -> if active
                                (sep (if is-active "→" ")"))
                                
                                ;; --- STYLING CHANGES HERE ---
                                ;; keys have squiggly lines
                                (key-face '(:weight bold :underline (:style wave)))

                                ;; Use a neutral "inverted" highlight for the active text instead of a blue background
                                (text-face (if is-active '(:weight bold :inverse-video t) nil)))
                           
                           (format "%s%s %s"
                                   (propertize k 'face key-face)
                                   (propertize sep 'face key-face)
                                   (if text-face (propertize clean-name 'face text-face) clean-name)))))
         ;; Subtract 4 to be absolutely immune to scrollbar/fringe edge-cases
         (max-width (- (frame-width) 0))
         (current-len 0)
         (body ""))

    (unless items
      (setq items (list (propertize "[No files tagged]" 'face 'shadow))))

    ;; Flexbox loop
    (dolist (item items)
      (let ((padded-item (concat item " ")))
        (if (> (+ current-len (length padded-item)) max-width)
            (setq body (concat body "\n" padded-item)
                  current-len (length padded-item))
          (setq body (concat body padded-item)
                current-len (+ current-len (length padded-item))))))

    (string-trim-right body)))

(defun my/speed-dial-hud-content (&optional active-buf active-file)
  "Generates content for the TOP (Dynamic / Right Hand) HUD."
  (my/sd-generate-hud-string '("j" "k" "l" ";" "m" "," "." "/") 'right active-buf active-file))

(defun my/speed-dial-global-hud-content (&optional active-buf active-file)
  "Generates content for the BOTTOM (Global / Left Hand) HUD."
  (my/sd-generate-hud-string '("a" "s" "d" "f" "z" "x" "c" "v") 'left active-buf active-file))

(defun my/setup-hud-window (buf-name content-string window-side)
  "Helper that creates the buffer, strips UI, and snaps the window to the top or bottom."
  (with-current-buffer (get-buffer-create buf-name)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert content-string)
      (goto-char (point-min)))

    ;; Strip ALL editor UI features
    (read-only-mode 1)
    (setq cursor-type nil mode-line-format nil header-line-format nil)
    
    ;; KILLER FIXES FOR THE VERTICAL GAP:
    (setq-local truncate-lines t word-wrap nil
                mode-require-final-newline nil require-final-newline nil)
    
    ;; Turn off fringes, margins, and the "small dashes"
    (setq left-fringe-width 0 right-fringe-width 0
          left-margin-width 0 right-margin-width 0
          indicate-empty-lines nil indicate-buffer-boundaries nil)
    
    (when (bound-and-true-p display-line-numbers-mode)
      (display-line-numbers-mode -1))
    (setq display-line-numbers nil)

    ;; --- BULLETPROOF PROTECTION (BUFFER LEVEL) ---
    ;; Completely nullify all mouse clicks, drags, and drag-and-drop events inside this buffer
    (let ((map (make-sparse-keymap)))
      (define-key map [mouse-1] 'ignore)
      (define-key map [down-mouse-1] 'ignore)
      (define-key map [drag-mouse-1] 'ignore)
      (define-key map [mouse-2] 'ignore)
      (define-key map [down-mouse-2] 'ignore)
      (define-key map [mouse-3] 'ignore)
      (define-key map [down-mouse-3] 'ignore)
      (define-key map[double-mouse-1] 'ignore)
      (define-key map [triple-mouse-1] 'ignore)
      (define-key map [drag-n-drop] 'ignore)
      (use-local-map map)))
    
  ;; Dynamically bind pixel-perfect resizing
  (let ((window-resize-pixelwise t) 
        (window-size-fixed nil))
    (let ((win (display-buffer buf-name
                               `((display-buffer-in-side-window)
                                 (side . ,window-side)
                                 (window-height . fit-window-to-buffer) 
                                 (window-parameters . ((no-other-window . t)
                                                       (no-delete-other-windows . t)
                                                       (mode-line-format . none)
                                                       (header-line-format . none)))))))
      (when win
        ;; --- BULLETPROOF PROTECTION (WINDOW LEVEL) ---
        ;; Hard-lock the buffer into the window to prevent file-drops from overriding it
        (set-window-dedicated-p win t)
        (let ((window-min-height 1))
          (fit-window-to-buffer win nil 1))))))

(defun my/hide-speed-dial-huds ()
  "Force closes BOTH the top and bottom Tmux-style HUDs."
  (let ((win-top (get-buffer-window my/speed-dial-hud-buffer-name))
        (win-bot (get-buffer-window my/speed-dial-global-hud-buffer-name)))
    (when win-top (delete-window win-top))
    (when win-bot (delete-window win-bot))))

(defun my/show-speed-dial-huds ()
  "Force opens BOTH the top and bottom Tmux-style HUDs."
  (my/hide-speed-dial-huds) ;; Prevent duplicates
  (let ((active-buf (buffer-name))
        (active-file (buffer-file-name)))
    (my/setup-hud-window my/speed-dial-hud-buffer-name 
                         (my/speed-dial-hud-content active-buf active-file) 
                         'top)
    (my/setup-hud-window my/speed-dial-global-hud-buffer-name 
                         (my/speed-dial-global-hud-content active-buf active-file) 
                         'bottom)))

(defun my/refresh-speed-dial-hud ()
  "Refreshes BOTH HUD contents dynamically."
  (let ((win-top (get-buffer-window my/speed-dial-hud-buffer-name))
        (win-bot (get-buffer-window my/speed-dial-global-hud-buffer-name))
        (active-buf (buffer-name))
        (active-file (buffer-file-name)))
    
    ;; Update Top
    (when win-top
      (with-current-buffer my/speed-dial-hud-buffer-name
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (my/speed-dial-hud-content active-buf active-file))
          (goto-char (point-min))))
      (let ((window-resize-pixelwise t) (window-size-fixed nil) (window-min-height 1))
        (fit-window-to-buffer win-top nil 1)))
        
    ;; Update Bottom
    (when win-bot
      (with-current-buffer my/speed-dial-global-hud-buffer-name
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (my/speed-dial-global-hud-content active-buf active-file))
          (goto-char (point-min))))
      (let ((window-resize-pixelwise t) (window-size-fixed nil) (window-min-height 1))
        (fit-window-to-buffer win-bot nil 1)))))


;; ==========================================
;; 8.6 HUD AUTO-UPDATE HOOKS & PROTECTIONS
;; ==========================================

(defun my/speed-dial-auto-refresh (&rest _)
  "Refresh the HUDs automatically if they are visible and we change buffers."
  (let ((bname (buffer-name)))
    ;; Only refresh if at least one HUD is visible, AND our cursor isn't currently INSIDE a HUD buffer
    (when (and (or (get-buffer-window my/speed-dial-hud-buffer-name)
                   (get-buffer-window my/speed-dial-global-hud-buffer-name))
               (not (string= bname my/speed-dial-hud-buffer-name))
               (not (string= bname my/speed-dial-global-hud-buffer-name)))
      (my/refresh-speed-dial-hud))))

(defun my/speed-dial-prevent-focus (&rest _)
  "Prevent the HUD windows from ever gaining focus. Bounces the cursor back instantly."
  (let ((win (selected-window)))
    (when (and (window-live-p win)
               (member (buffer-name (window-buffer win))
                       (list my/speed-dial-hud-buffer-name
                             my/speed-dial-global-hud-buffer-name)))
      (let ((best-win nil)
            (best-time -1))
        ;; Find the most recently used window that is NOT a HUD
        (walk-windows (lambda (w)
                        (unless (member (buffer-name (window-buffer w))
                                        (list my/speed-dial-hud-buffer-name
                                              my/speed-dial-global-hud-buffer-name))
                          (let ((time (window-use-time w)))
                            (when (> time best-time)
                              (setq best-time time
                                    best-win w)))))
                      'nomini)
        (if best-win
            (select-window best-win)
          (other-window 1))))))

;; Tie the HUD refresh and Focus Protection to Emacs' native window systems
(add-hook 'window-selection-change-functions #'my/speed-dial-auto-refresh)
(add-hook 'window-buffer-change-functions #'my/speed-dial-auto-refresh)
(add-hook 'window-selection-change-functions #'my/speed-dial-prevent-focus)


;; ==========================================
;; 8.7 MODE TOGGLES & HYDRA OVERRIDES
;; ==========================================

(defvar my/speed-dial-display-mode 'operational
  "Visual mode for the speed dial. Can be 'tactical (Tmux bars) or 'operational (Hydra HUD).")

(defun my/speed-dial-tactical-mode ()
  "Switch to tactical mode: Persistent Tmux bars ON, huge Hydra HUD OFF."
  (interactive)
  (setq my/speed-dial-display-mode 'tactical)
  (my/show-speed-dial-huds)
  (message "Speed Dial: TACTICAL mode active."))

(defun my/speed-dial-operational-mode ()
  "Switch to operational mode: Persistent Tmux bars OFF, huge Hydra HUD ON."
  (interactive)
  (setq my/speed-dial-display-mode 'operational)
  (my/hide-speed-dial-huds)
  (message "Speed Dial: OPERATIONAL mode active."))

(defun my/toggle-speed-dial-hud ()
  "Quick-toggle between Tactical and Operational visual modes."
  (interactive)
  (if (eq my/speed-dial-display-mode 'operational)
      (my/speed-dial-tactical-mode)
    (my/speed-dial-operational-mode)))

(defun my/speed-dial-hydra-display-override (orig-fun &rest args)
  "Intercepts the Hydra call. If we are in 'tactical' mode, completely silences the visual HUD."
  ;; hydra-is-helpful is a built-in hydra variable. Binding it to nil prevents the popup!
  (let ((hydra-is-helpful (eq my/speed-dial-display-mode 'operational)))
    (apply orig-fun args)))

;; Attach the override directly to the hydra engine
(advice-add 'hydra-speed-dial/body :around #'my/speed-dial-hydra-display-override)


;; ==========================================
;; 9. KEYBINDINGS
;; ==========================================

;; 1. The main entry point to open the speed-dial HUD
(evil-define-key 'normal 'global (kbd "<leader> a") 'hydra-speed-dial/body)

;; 2. Bookmark management
(evil-define-key 'normal 'global (kbd "<leader> b p") 'my/project-bookmark-jump)
(evil-define-key 'normal 'global (kbd "<leader> b m") 'my/bookmark-set-absolute)
(evil-define-key 'normal 'global (kbd "<leader> b t") 'my/bookmark-tag-current-file)

;; 3. EVIL EX COMMANDS (Type :tactical or :operational in normal mode!)
(evil-ex-define-cmd "tactical" 'my/speed-dial-tactical-mode)
(evil-ex-define-cmd "operational" 'my/speed-dial-operational-mode)

;; ==========================================
;; my-speed-dial.el ends here
;; ==========================================
(provide 'my-speed-dial)
