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

;; Tell the byte-compiler that this function will be generated later by `defhydra`
(declare-function hydra-speed-dial/body "my-speed-dial")

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
      (message "Workspace locked to: %s" root))))

(defun my/set-speed-dial-tag ()
  "Choose a tag for the RIGHT hand keys in the locked workspace."
  (interactive)
  (let* ((root (my/get-workspace))
         (rows (sqlite-select my/sd-db "SELECT DISTINCT tag FROM speed_dial WHERE workspace=? AND tag != 'global'" (list root)))
         (clean-tags (mapcar #'car rows)))
    (if (not clean-tags)
        (message "No custom tags found! Press 'N' to tag a file first.")
      (setq my/current-speed-dial-tag (completing-read "Select tag for RIGHT hand: " clean-tags))
      (my/save-workspace-tag root my/current-speed-dial-tag)
      (message "Locked right hand to tag:[%s]" my/current-speed-dial-tag))))

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
    
    ;; Prevent duplicates in the same tag! Remove old entry if this file was already in this tag.
    (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND name=?" (list root tag name))
    
    (let* ((used-slots (mapcar #'car (sqlite-select my/sd-db "SELECT slot FROM speed_dial WHERE workspace=? AND tag=?" (list root tag))))
           (free-slot (cl-find-if-not (lambda (s) (member s used-slots)) '(1 2 3 4 5 6 7 8))))
      (if (not free-slot)
          (message "Tag[%s] is full! All 8 slots are used." tag)
        (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                        (list root tag free-slot name data-str))
        (message "Pinned '%s' to Slot %d on [%s]" name free-slot tag)))))

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
      (message "Auto-created default dynamic tag: [main]")))

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
                (hydra-speed-dial/body))
               ((and exp-path (not (file-directory-p exp-path)))
                ;; Use find-file for actual files so save-place-mode handles cursor position!
                (let ((buf (find-buffer-visiting exp-path)))
                  (if buf (switch-to-buffer buf) (find-file exp-path))))
               (t 
                ;; Let Emacs's bookmark engine handle Magit, Dired, etc.
                (bookmark-jump (cons name data)))))
          (message "Empty slot")))

       ;; --- TAG MODE ---
       ((eq my/speed-dial-mode 'tag)
        (let* ((record (my/sd-generate-record-for my/pending-tag-target))
               (name (if my/pending-tag-target (file-name-nondirectory my/pending-tag-target) (car record)))
               (data-str (prin1-to-string (cdr record))))
          
          ;; Delete it from its OLD slot in this same tag (if it exists) to prevent duplication!
          (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND name=?" (list root tag name))
          
          ;; Insert into the requested slot
          (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                          (list root tag num name data-str))
          (setq my/speed-dial-mode 'normal
                my/pending-tag-target nil)
          (message "Tagged '%s' to slot %d on[%s]!" name num tag)
          (hydra-speed-dial/body)))

       ;; --- PICK MODE ---
       ((eq my/speed-dial-mode 'pick)
        (if (not row)
            (message "That slot is empty! Press a key with an active bookmark.")
          (setq my/pending-move-src (cons tag num))
          (setq my/speed-dial-mode 'drop))
        (hydra-speed-dial/body))

       ;; --- DROP MODE ---
       ((eq my/speed-dial-mode 'drop)
        (let* ((old-tag (car my/pending-move-src))
               (old-slot (cdr my/pending-move-src))
               (old-row (sqlite-select my/sd-db "SELECT name, record FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                       (list root old-tag old-slot))))
          (when old-row
            (let ((name (nth 0 (car old-row)))
                  (data-str (nth 1 (car old-row))))
              ;; If it somehow existed elsewhere in the DESTINATION tag, wipe it first to avoid duplicates
              (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND name=?" (list root tag name))
              
              (sqlite-execute my/sd-db "INSERT OR REPLACE INTO speed_dial (workspace, tag, slot, name, record) VALUES (?, ?, ?, ?, ?)"
                              (list root tag num name data-str))
              (unless (and (string= old-tag tag) (= old-slot num))
                (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" 
                                (list root old-tag old-slot)))
              (message "Moved '%s' to slot %d on [%s]!" name num tag)))
          (setq my/speed-dial-mode 'normal
                my/pending-move-src nil)
          (hydra-speed-dial/body)))

       ;; --- UNTAG MODE ---
       ((eq my/speed-dial-mode 'untag)
        (if (not row)
            (message "That slot is already empty!")
          (sqlite-execute my/sd-db "DELETE FROM speed_dial WHERE workspace=? AND tag=? AND slot=?" (list root tag num))
          (message "Untagged slot %d from [%s]" num tag))
        (setq my/speed-dial-mode 'normal)
        (hydra-speed-dial/body))))))

;; ==========================================
;; 6. HYDRA HELPER FUNCTIONS
;; ==========================================

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
  [a]: %-22s  [j]: %-22s[s]: %-22s  [k]: %-22s
  [d]: %-22s  [l]: %-22s
  [f]: %-22s  [;]: %-22s
  [z]: %-22s  [m]: %-22s
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
          (message "Renamed tag [%s] to [%s]!" old-tag new-tag)))))
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
_z_: %s(my/sd-name 'left 5)  _m_: %s(my/sd-name 'right 5)  _X_: Nuke Workspace
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
  ("M" my/hydra-start-move) ("C" my/hydra-create-tag) ("W" my/hydra-wipe-tag)
  ("R" my/hydra-rename-tag) ("Y" my/hydra-copy-tag)
  ("X" my/hydra-wipe-workspace) ("p" my/set-workspace-and-resume)
  ("P" my/hydra-clone-workspace) ("t" my/set-tag-and-resume) 
  ("q" my/hydra-quit) ("<escape>" my/hydra-quit) ("C-g" my/hydra-quit))

;; ==========================================
;; 8. Auto-load Last Workspace
;; ==========================================
(my/load-global-workspace-state)

;; ==========================================
;; 9. KEYBINDINGS
;; ==========================================

;; 1. The main entry point to open the speed-dial HUD
(evil-define-key 'normal 'global (kbd "<leader> a") 'hydra-speed-dial/body)

;; 2. Bookmark management
(evil-define-key 'normal 'global (kbd "<leader> b p") 'my/project-bookmark-jump)
(evil-define-key 'normal 'global (kbd "<leader> b m") 'my/bookmark-set-absolute)
(evil-define-key 'normal 'global (kbd "<leader> b t") 'my/bookmark-tag-current-file)

;; ==========================================
;; my-speed-dial.el ends here
;; ==========================================
(provide 'my-speed-dial)
