;;; my-speed-dial.el --- Custom workspace speed dial -*- lexical-binding: t; byte-compile-warnings: (not docstrings redefine) -*-

(require 'bookmark)
(require 'cl-lib)

;; Let the compiler know about use-package
(eval-when-compile
  (require 'use-package))

;; Ensure required packages are loaded for macros
(use-package evil :ensure t)
(use-package hydra :ensure t)

;; Tell the byte-compiler that this function will be generated later by `defhydra`
;; This prevents "undefined function" warnings and allows compiler optimizations.
(declare-function hydra-speed-dial/body "my-speed-dial")

;; ==========================================
;; 1. GLOBAL STATE & VARIABLES
;; ==========================================

(defvar my/current-workspace-root nil
  "The manually selected workspace directory.")

(defvar my/current-speed-dial-tag nil 
  "The currently active dynamic tag (Right Hand).")

(defvar my/speed-dial-mode 'normal 
  "Can be `normal', `pick', `drop', `tag', or `untag'.")

(defvar my/pending-move-bm nil 
  "Bookmark currently being moved.")

(defvar my/pending-move-board nil 
  "Board where the bookmark originated.")

(defvar my/pending-tag-target nil 
  "A file selected in the background waiting to be assigned a slot.")


;; ==========================================
;; 2. CORE HELPERS & UTILITIES
;; ==========================================

(defun my/get-workspace ()
  "Return the active workspace, or throw an error if none is set."
  (unless my/current-workspace-root
    (error "No workspace locked! Use <leader> a p to select your target file"))
  my/current-workspace-root)

(defun my/bookmark-belongs-to-workspace-p (bm root)
  "Check if bookmark BM belongs strictly to the active ROOT workspace."
  (let ((proj-tag (concat "proj:" root)))
    (member proj-tag (bookmark-prop-get bm 'tags))))

(defun my/get-workspace-bookmarks ()
  "Return a list of bookmark names in the active workspace."
  (bookmark-maybe-load-default-file)
  (let ((root (my/get-workspace)))
    (mapcar #'car
            (cl-remove-if-not
             (lambda (bm) (my/bookmark-belongs-to-workspace-p bm root))
             bookmark-alist))))

(defun my/get-bookmarks-in-slots (bm-names tag root)
  (let* ((prop (intern (format "slot|%s|%s" root tag)))
         (slots (make-vector 8 nil))
         (unassigned nil))
    (dolist (bm bm-names)
      (let ((slot-num (bookmark-prop-get bm prop)))
        (if (and (integerp slot-num) (>= slot-num 1) (<= slot-num 8))
            (aset slots (1- slot-num) bm)
          (push bm unassigned))))
    (setq unassigned (sort unassigned #'string<))
    (dotimes (i 8)
      (when (and (null (aref slots i)) unassigned)
        (aset slots i (pop unassigned))))
    (append slots nil)))

(defun my/sd-name (side num)
  (bookmark-maybe-load-default-file)
  (let ((val "-"))
    (when my/current-workspace-root
      (let* ((root my/current-workspace-root)
             (project-bms (cl-remove-if-not (lambda (bm) (my/bookmark-belongs-to-workspace-p bm root)) bookmark-alist))
             (active-tag (if (eq side 'left) "global" my/current-speed-dial-tag))
             (bms (when active-tag
                    (let ((wt-tag (format "wt|%s|%s" root active-tag)))
                      (cl-remove-if-not (lambda (bm) (member wt-tag (bookmark-prop-get bm 'tags))) project-bms))))
             (slotted-bms (when active-tag (my/get-bookmarks-in-slots (mapcar #'car bms) active-tag root)))
             (target (when slotted-bms (nth (1- num) slotted-bms))))
        (when target
          (setq val (if (file-name-absolute-p target) (file-name-nondirectory target) target)))))
    (truncate-string-to-width val 35 0 ?\s "…")))

;; --- STATE PERSISTENCE HELPERS ---

(defun my/get-saved-workspace-tag (root)
  "Retrieve the last used right-hand tag for the workspace ROOT."
  (let ((bm-name (format "sd-workspace-state|%s" root)))
    (when (assoc bm-name bookmark-alist)
      (bookmark-prop-get bm-name 'active-tag))))

(defun my/save-workspace-tag (root tag)
  "Save TAG as the last active right-hand tag for workspace ROOT."
  (let* ((bm-name (format "sd-workspace-state|%s" root))
         (existing (assoc bm-name bookmark-alist))
         (alist (if existing (cdr existing) nil)))
    (setf (alist-get 'active-tag alist) tag)
    (bookmark-store bm-name alist nil)
    (bookmark-save)))

;; NEW: Save globally active workspace
(defun my/save-global-workspace-state (root)
  "Save the globally active workspace so it restores on Emacs startup."
  (let* ((bm-name "sd-global-state")
         (existing (assoc bm-name bookmark-alist))
         (alist (if existing (cdr existing) nil)))
    (setf (alist-get 'last-workspace alist) root)
    (bookmark-store bm-name alist nil)
    (bookmark-save)))

;; NEW: Load globally active workspace
(defun my/load-global-workspace-state ()
  "Load the last active workspace on Emacs startup."
  (bookmark-maybe-load-default-file)
  (let* ((bm-name "sd-global-state")
         (existing (assoc bm-name bookmark-alist)))
    (when existing
      (let ((root (bookmark-prop-get bm-name 'last-workspace)))
        ;; Only load it if the directory hasn't been deleted from the hard drive
        (when (and root (file-exists-p root))
          (setq my/current-workspace-root root)
          (setq my/current-speed-dial-tag (my/get-saved-workspace-tag root)))))))

;; ==========================================
;; 3. WORKSPACE & TAGGING LOGIC
;; ==========================================

(defun my/set-workspace ()
  "Manually lock Emacs into a specific workspace directory."
  (interactive)
  (bookmark-maybe-load-default-file)
  (let* ((target-dir (read-directory-name "Select workspace directory: "))
         (root (expand-file-name (file-name-as-directory target-dir)))
         (saved-tag (my/get-saved-workspace-tag root)))
    (setq my/current-workspace-root root)
    (setq my/current-speed-dial-tag saved-tag) ;; Auto-restore tag for this workspace
    (my/save-global-workspace-state root)      ;; <--- NEW: Save for next startup
    (if saved-tag
        (message "Workspace locked to: %s (Restored tag: [%s])" root saved-tag)
      (message "Workspace locked to: %s" root))))

(defun my/set-speed-dial-tag ()
  "Choose a tag for the RIGHT hand keys in the locked workspace."
  (interactive)
  (bookmark-maybe-load-default-file)
  (let* ((root (my/get-workspace))
         (project-bms (cl-remove-if-not (lambda (bm) (my/bookmark-belongs-to-workspace-p bm root)) bookmark-alist))
         (all-tags (cl-remove-duplicates (apply #'append (mapcar (lambda (bm) (bookmark-prop-get bm 'tags)) project-bms)) :test #'string=))
         (prefix (format "wt|%s|" root))
         (clean-tags (delq nil (mapcar (lambda (t-name)
                                         (when (string-prefix-p prefix t-name)
                                           (substring t-name (length prefix))))
                                       all-tags))))
    (if (not clean-tags)
        (message "No tags found! Press 'N' to tag a file first.")
      (setq my/current-speed-dial-tag (completing-read "Select tag for RIGHT hand: " clean-tags))
      (my/save-workspace-tag root my/current-speed-dial-tag) ;; Persist to Emacs bookmarks
      (message "Locked right hand to tag: [%s]" my/current-speed-dial-tag))))

(defun my/project-bookmark-jump ()
  "Jump to a bookmark inside your manually locked workspace, from anywhere."
  (interactive)
  (bookmark-maybe-load-default-file)
  (if-let ((root my/current-workspace-root))
      (let* ((workspace-bms (cl-remove-if-not
                             (lambda (bm)
                               (let* ((bm-name (car bm))
                                      (tags (bookmark-prop-get bm-name 'tags))
                                      (proj-tag (concat "proj:" root)))
                                 (member proj-tag tags)))
                             bookmark-alist))
             (names (mapcar #'car workspace-bms)))
        (if names
            (let* ((project-name (file-name-nondirectory (directory-file-name root)))
                   (choice (completing-read (format "Workspace Bookmarks [%s]: " project-name) names)))
              (bookmark-jump choice))
          (message "No bookmarks found in locked workspace: %s" root)))
    (message "No workspace locked! Press '<leader> a p' to select one first.")))

(defun my/bookmark-tag-current-file ()
  "Tag the current file and link it to the locked workspace."
  (interactive)
  (let* ((root (my/get-workspace))
         (proj-tag (concat "proj:" root))
         (bm-name (if buffer-file-name (file-name-nondirectory buffer-file-name) (buffer-name)))
         (project-name (file-name-nondirectory (directory-file-name root)))
         (new-tag (read-string (format "Tag %s for workspace '%s': " bm-name project-name))))
    (unless (assoc bm-name bookmark-alist)
      (bookmark-set bm-name))
    (let ((existing-tags (bookmark-prop-get bm-name 'tags)))
      (unless (member new-tag existing-tags) (push new-tag existing-tags))
      (unless (member proj-tag existing-tags) (push proj-tag existing-tags))
      (bookmark-prop-set bm-name 'tags existing-tags)
      (bookmark-save)
      (message "Successfully tagged '%s' as [%s] in '%s'" bm-name new-tag project-name))))

(defun my/bookmark-set-absolute ()
  "Bookmark current buffer. Uses absolute path, or appends directory for special buffers."
  (interactive)
  (let* ((default-name (if buffer-file-name 
                           (expand-file-name buffer-file-name) 
                         (concat (buffer-name) "[" (abbreviate-file-name default-directory) "]")))
         (bm-name (read-string (format "Set bookmark (%s): " default-name) nil nil default-name)))
    (bookmark-set bm-name)))

;; ==========================================
;; 4. CORE SPEED DIAL LOGIC
;; ==========================================

(defun my/speed-dial-jump (tag num)
  "Jump to the NUM-th bookmark of TAG, handle Move, Tag, OR handle Untag."
  (bookmark-maybe-load-default-file)

  ;; --- NEW: Auto-create "main" tag if dropping/tagging into an empty right-hand ---
  (when (and (not tag)
             (or (eq my/speed-dial-mode 'tag)
                 (eq my/speed-dial-mode 'drop)))
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
           (project-bms (cl-remove-if-not (lambda (bm) (my/bookmark-belongs-to-workspace-p bm root)) bookmark-alist))
           (wt-tag (format "wt|%s|%s" root tag))
           (tagged-bms (cl-remove-if-not (lambda (bm) (member wt-tag (bookmark-prop-get bm 'tags))) project-bms))
           (slotted-bms (my/get-bookmarks-in-slots (mapcar #'car tagged-bms) tag root))
           (target (nth (1- num) slotted-bms)))

      (cond
       ;; --- NORMAL MODE ---
       ((eq my/speed-dial-mode 'normal)
        (if target
            (let ((file-path (bookmark-get-filename target)))
              (cond
               ((and file-path (not (file-exists-p file-path)))
                (message "Path '%s' no longer exists! Auto-cleaning bookmark..." file-path)
                (bookmark-delete target)
                (bookmark-save)
                (hydra-speed-dial/body))
               ((and file-path (not (file-directory-p file-path)))
                (let ((buf (get-file-buffer file-path)))
                  (if buf (switch-to-buffer buf) (find-file file-path))))
               (t (bookmark-jump target))))
          (message "Empty slot")))

       ;; --- TAG MODE ---
       ((eq my/speed-dial-mode 'tag)
        (let* ((bm-name (or my/pending-tag-target 
                            (if buffer-file-name (expand-file-name buffer-file-name) (buffer-name))))
               (proj-tag (concat "proj:" root))
               (prop (intern (format "slot|%s|%s" root tag))))
          (unless (assoc bm-name bookmark-alist)
            (if my/pending-tag-target
                (with-current-buffer (find-file-noselect my/pending-tag-target)
                  (bookmark-set bm-name))
              (bookmark-set bm-name)))
          (dolist (other-bm (mapcar #'car project-bms))
            (when (and (not (string= other-bm bm-name)) (eq (bookmark-prop-get other-bm prop) num))
              (bookmark-prop-set other-bm prop nil)))
          (let ((existing-tags (bookmark-prop-get bm-name 'tags)))
            (unless (member wt-tag existing-tags) (push wt-tag existing-tags))
            (unless (member proj-tag existing-tags) (push proj-tag existing-tags))
            (bookmark-prop-set bm-name 'tags existing-tags))
          (bookmark-prop-set bm-name prop num)
          (bookmark-save)
          (setq my/speed-dial-mode 'normal)
          (setq my/pending-tag-target nil)
          (message "Tagged '%s' to slot %d on [%s]!" (file-name-nondirectory bm-name) num tag)
          (hydra-speed-dial/body)))

       ;; --- PICK MODE ---
       ((eq my/speed-dial-mode 'pick)
        (if (not target)
            (message "That slot is empty! Press a key with a bookmark.")
          (setq my/pending-move-bm target)
          (setq my/pending-move-board tag)
          (setq my/speed-dial-mode 'drop))
        (hydra-speed-dial/body))

       ;; --- DROP MODE ---
       ((eq my/speed-dial-mode 'drop)
        (let* ((bm-name my/pending-move-bm)
               (old-tag my/pending-move-board)
               (new-tag tag)
               (new-prop (intern (format "slot|%s|%s" root new-tag)))
               (old-prop (intern (format "slot|%s|%s" root old-tag)))
               (wt-new-tag (format "wt|%s|%s" root new-tag))
               (wt-old-tag (format "wt|%s|%s" root old-tag)))
          (dolist (other-bm (mapcar #'car project-bms))
            (when (and (not (string= other-bm bm-name)) (eq (bookmark-prop-get other-bm new-prop) num))
              (bookmark-prop-set other-bm new-prop nil)))
          (bookmark-prop-set bm-name old-prop nil)
          (when (not (string= old-tag new-tag))
            (let ((tags (bookmark-prop-get bm-name 'tags)))
              (setq tags (remove wt-old-tag tags))
              (unless (member wt-new-tag tags) (push wt-new-tag tags))
              (bookmark-prop-set bm-name 'tags tags)))
          (bookmark-prop-set bm-name new-prop num)
          (bookmark-save)
          (setq my/speed-dial-mode 'normal
                my/pending-move-bm nil
                my/pending-move-board nil)
          (message "Moved '%s' to slot %d on [%s]!" (file-name-nondirectory bm-name) num new-tag))
        (hydra-speed-dial/body))

       ;; --- UNTAG MODE ---
       ((eq my/speed-dial-mode 'untag)
        (if (not target)
            (message "That slot is already empty!")
          (let* ((tags (bookmark-prop-get target 'tags))
                 (prop (intern (format "slot|%s|%s" root tag)))
                 (prefix (format "wt|%s|" root)))
            (setq tags (remove wt-tag tags))
            (bookmark-prop-set target prop nil)
            (let ((remaining-wt-for-root (cl-remove-if-not (lambda (t-name) (string-prefix-p prefix t-name)) tags)))
              (unless remaining-wt-for-root
                (setq tags (remove (concat "proj:" root) tags))))
            (bookmark-prop-set target 'tags tags)
            (let ((remaining-proj (cl-remove-if-not (lambda (t-name) (string-prefix-p "proj:" t-name)) tags)))
              (if (not remaining-proj)
                  (progn
                    (bookmark-delete target)
                    (message "Untagged '%s' and DELETED bookmark (not in any workspace)." (file-name-nondirectory target)))
                (bookmark-save)
                (message "Untagged '%s' from [%s]" (file-name-nondirectory target) tag)))))
        (setq my/speed-dial-mode 'normal)
        (hydra-speed-dial/body))))))

;; ==========================================
;; 5. HYDRA HELPER FUNCTIONS
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
  [a]: %-22s  [j]: %-22s
  [s]: %-22s  [k]: %-22s
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
      (erase-buffer)
      (insert (propertize hud-text 'face 'bold))
      (goto-char (point-min))
      (setq-local mode-line-format nil 
                  header-line-format nil 
                  cursor-type nil 
                  truncate-lines t
                  window-size-fixed t))
    
    (setq win (display-buffer buf 
                              '((display-buffer-in-side-window) 
                                (side . top) 
                                (window-height . fit-window-to-buffer))))
    (set-window-dedicated-p win t)
    (set-window-start win (point-min))
    
    (condition-case nil
        (unwind-protect
            (let ((default-directory original-dir))
              (setq selected-file (read-file-name "Select file to pin: ")))
          (when (window-live-p win) (delete-window win))
          (kill-buffer buf))
      (quit 
       (setq my/speed-dial-mode 'normal)
       (message "Cancelled Find & Tag")))
      
    (when selected-file
      (setq my/pending-tag-target (expand-file-name selected-file)))
      
    (hydra-speed-dial/body)))

(defun my/hydra-start-tag () 
  (interactive) 
  (setq my/pending-tag-target nil)
  (setq my/speed-dial-mode (if (eq my/speed-dial-mode 'normal) 'tag 'normal)) 
  (hydra-speed-dial/body))

(defun my/hydra-start-move () 
  (interactive) 
  (setq my/speed-dial-mode (if (eq my/speed-dial-mode 'normal) 'pick 'normal)) 
  (hydra-speed-dial/body))

(defun my/hydra-start-untag () 
  (interactive) 
  (setq my/speed-dial-mode (if (eq my/speed-dial-mode 'normal) 'untag 'normal)) 
  (hydra-speed-dial/body))

(defun my/hydra-quit () 
  (interactive) 
  (setq my/speed-dial-mode 'normal 
        my/pending-move-bm nil 
        my/pending-move-board nil
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
  "Remove a specific tag from ALL bookmarks in the current workspace, checking for orphans."
  (interactive)
  (let* ((root (my/get-workspace))
         (project-bms (cl-remove-if-not (lambda (bm) (my/bookmark-belongs-to-workspace-p bm root)) bookmark-alist))
         (prefix (format "wt|%s|" root))
         (all-tags (cl-remove-duplicates (apply #'append (mapcar (lambda (bm) (bookmark-prop-get bm 'tags)) project-bms)) :test #'string=))
         (clean-tags (delq nil (mapcar (lambda (t-name)
                                         (when (string-prefix-p prefix t-name)
                                           (substring t-name (length prefix))))
                                       all-tags))))
    (if (not clean-tags)
        (message "No tags exist in this workspace!")
      (let ((tag-to-nuke (completing-read "Wipe tag completely: " clean-tags nil t))
            (deleted-count 0)
            (modified nil))
        (let ((wt-tag (format "wt|%s|%s" root tag-to-nuke))
              (prop (intern (format "slot|%s|%s" root tag-to-nuke))))
          (dolist (bm project-bms)
            (let* ((bm-name (car bm)) 
                   (tags (bookmark-prop-get bm-name 'tags)))
              (when (member wt-tag tags)
                (setq modified t)
                (let ((new-tags (remove wt-tag tags)))
                  (bookmark-prop-set bm-name prop nil)
                  (let ((remaining-wt-for-root (cl-remove-if-not (lambda (t-name) (string-prefix-p prefix t-name)) new-tags)))
                    (unless remaining-wt-for-root
                      (setq new-tags (remove (concat "proj:" root) new-tags))))
                  (bookmark-prop-set bm-name 'tags new-tags)
                  (let ((remaining-proj (cl-remove-if-not (lambda (t-name) (string-prefix-p "proj:" t-name)) new-tags)))
                    (when (not remaining-proj)
                      (bookmark-delete bm-name)
                      (setq deleted-count (1+ deleted-count)))))))))
        (when modified (bookmark-save))
        (when (string= my/current-speed-dial-tag tag-to-nuke) 
          (setq my/current-speed-dial-tag nil)
          (my/save-workspace-tag root nil)) ;; Clear saved state
        (message "Wiped tag '%s' (Deleted %d orphaned globally)." tag-to-nuke deleted-count))))
  (hydra-speed-dial/body))

(defun my/hydra-wipe-workspace ()
  "Remove all bookmarks from the workspace but KEEP the workspace locked."
  (interactive)
  (bookmark-maybe-load-default-file)
  (let* ((root (my/get-workspace))
         (project-bms (cl-remove-if-not 
                       (lambda (bm) (my/bookmark-belongs-to-workspace-p bm root)) 
                       bookmark-alist)))
    (if (not project-bms)
        (message "Workspace is already empty! No bookmarks to remove.")
      (when (y-or-n-p (format "DANGER: Wipe all contents of workspace '%s' (%d files)? " 
                              (file-name-nondirectory (directory-file-name root))
                              (length project-bms)))
        (dolist (bm project-bms)
          (let* ((bm-name (car bm))
                 (tags (bookmark-prop-get bm-name 'tags))
                 (prefix (format "wt|%s|" root))
                 (new-tags (cl-remove-if (lambda (t-name) (string-prefix-p prefix t-name)) tags)))
            (setq new-tags (remove (concat "proj:" root) new-tags))
            (bookmark-prop-set bm-name 'tags new-tags)
            (let ((remaining-proj (cl-remove-if-not (lambda (t-name) (string-prefix-p "proj:" t-name)) new-tags)))
              (when (not remaining-proj)
                (bookmark-delete bm-name)))))
        (bookmark-save)
        
        ;; Nuke the hidden state bookmark for this workspace
        (let ((state-bm (format "sd-workspace-state|%s" root)))
          (when (assoc state-bm bookmark-alist)
            (bookmark-delete state-bm)
            (bookmark-save)))
        
        ;; CRITICAL FIX: We NO LONGER set my/current-workspace-root to nil.
        ;; We only clear the tag because all tags were just wiped.
        (setq my/current-speed-dial-tag nil)
        
        (message "Workspace contents wiped successfully!"))))
  (hydra-speed-dial/body))

(defun my/set-workspace-and-resume () 
  (interactive) 
  (call-interactively 'my/set-workspace) 
  (hydra-speed-dial/body))

(defun my/set-tag-and-resume () 
  (interactive) 
  (call-interactively 'my/set-speed-dial-tag) 
  (hydra-speed-dial/body))

(defun my/hydra-rename-tag ()
  "Rename an existing tag and move all its files to the new name."
  (interactive)
  (bookmark-maybe-load-default-file)
  (let* ((root (my/get-workspace))
         (project-bms (cl-remove-if-not (lambda (bm) (my/bookmark-belongs-to-workspace-p bm root)) bookmark-alist))
         (prefix (format "wt|%s|" root))
         (all-tags (cl-remove-duplicates (apply #'append (mapcar (lambda (bm) (bookmark-prop-get bm 'tags)) project-bms)) :test #'string=))
         (clean-tags (delq nil (mapcar (lambda (t-name)
                                         (when (string-prefix-p prefix t-name)
                                           (substring t-name (length prefix))))
                                       all-tags))))
    (if (not clean-tags)
        (message "No tags exist to rename!")
      (let* ((old-tag (completing-read "Rename tag: " clean-tags nil t))
             (new-tag (read-string (format "Rename [%s] to: " old-tag))))
        (if (or (string= "" new-tag) (member new-tag clean-tags))
            (message "Cancelled: Tag name cannot be empty or already exist.")
          (let ((wt-old (format "wt|%s|%s" root old-tag))
                (wt-new (format "wt|%s|%s" root new-tag))
                (prop-old (intern (format "slot|%s|%s" root old-tag)))
                (prop-new (intern (format "slot|%s|%s" root new-tag)))
                (modified nil))
            (dolist (bm project-bms)
              (let* ((bm-name (car bm))
                     (tags (bookmark-prop-get bm-name 'tags)))
                (when (member wt-old tags)
                  (setq modified t)
                  ;; Swap out the tags
                  (setq tags (remove wt-old tags))
                  (push wt-new tags)
                  (bookmark-prop-set bm-name 'tags tags)
                  ;; Swap out the slots
                  (let ((slot-val (bookmark-prop-get bm-name prop-old)))
                    (when slot-val
                      (bookmark-prop-set bm-name prop-new slot-val)
                      (bookmark-prop-set bm-name prop-old nil))))))
            (when modified
              (bookmark-save)
              ;; If they renamed their currently active tag, seamlessly switch to the new name
              (when (string= my/current-speed-dial-tag old-tag)
                (setq my/current-speed-dial-tag new-tag)
                (my/save-workspace-tag root new-tag))
              (message "Renamed tag [%s] to[%s]!" old-tag new-tag)))))))
  (hydra-speed-dial/body))

(defun my/hydra-copy-tag ()
  "Copy an existing tag and its slot layout into a new tag name."
  (interactive)
  (bookmark-maybe-load-default-file)
  (let* ((root (my/get-workspace))
         (project-bms (cl-remove-if-not (lambda (bm) (my/bookmark-belongs-to-workspace-p bm root)) bookmark-alist))
         (prefix (format "wt|%s|" root))
         (all-tags (cl-remove-duplicates (apply #'append (mapcar (lambda (bm) (bookmark-prop-get bm 'tags)) project-bms)) :test #'string=))
         (clean-tags (delq nil (mapcar (lambda (t-name)
                                         (when (string-prefix-p prefix t-name)
                                           (substring t-name (length prefix))))
                                       all-tags))))
    (if (not clean-tags)
        (message "No tags exist to copy!")
      (let* ((old-tag (completing-read "Copy tag: " clean-tags nil t))
             (new-tag (read-string (format "Copy [%s] to new tag: " old-tag))))
        (if (or (string= "" new-tag) (member new-tag clean-tags))
            (message "Cancelled: Tag name cannot be empty or already exist.")
          (let ((wt-old (format "wt|%s|%s" root old-tag))
                (wt-new (format "wt|%s|%s" root new-tag))
                (prop-old (intern (format "slot|%s|%s" root old-tag)))
                (prop-new (intern (format "slot|%s|%s" root new-tag)))
                (modified nil))
            (dolist (bm project-bms)
              (let* ((bm-name (car bm))
                     (tags (bookmark-prop-get bm-name 'tags)))
                (when (member wt-old tags)
                  (setq modified t)
                  ;; Add the new tag (keep the old one)
                  (unless (member wt-new tags)
                    (push wt-new tags)
                    (bookmark-prop-set bm-name 'tags tags))
                  ;; Copy the slot over to the new tag layout
                  (let ((slot-val (bookmark-prop-get bm-name prop-old)))
                    (when slot-val
                      (bookmark-prop-set bm-name prop-new slot-val))))))
            (when modified
              (bookmark-save)
              (message "Copied layout of [%s] into [%s]!" old-tag new-tag)))))))
  (hydra-speed-dial/body))

(defun my/get-all-workspaces ()
  "Return a list of all known workspace roots."
  (let ((roots nil))
    (dolist (bm bookmark-alist)
      (let ((tags (bookmark-prop-get (car bm) 'tags)))
        (dolist (tag tags)
          (when (string-prefix-p "proj:" tag)
            (cl-pushnew (substring tag 5) roots :test #'string=)))))
    roots))

(defun my/hydra-clone-workspace ()
  "Clone another workspace's layout INTO the currently locked workspace."
  (interactive)
  (bookmark-maybe-load-default-file)
  
  ;; 1. Ensure we have a target workspace (the currently locked one)
  (unless my/current-workspace-root
    (error "No workspace locked! Press 'p' to lock into your blank target workspace first."))
    
  (let* ((target-root (expand-file-name (file-name-as-directory my/current-workspace-root)))
         (all-workspaces (my/get-all-workspaces))
         ;; 2. Remove the current workspace from the choices so you can't clone into itself
         (source-workspaces (remove target-root all-workspaces)))
         
    (unless source-workspaces
      (error "No other workspaces found to clone from!"))
      
    ;; 3. Prompt ONLY for the source workspace
    (let* ((source-root (completing-read "Source workspace to clone from: " source-workspaces nil t))
           (source-root-exp (expand-file-name (file-name-as-directory source-root))))

      ;; 4. Enforce current workspace is entirely empty of bookmarks
      (let ((target-bms (cl-remove-if-not (lambda (bm) (my/bookmark-belongs-to-workspace-p bm target-root)) bookmark-alist)))
        (when target-bms
          (error "Current workspace already contains bookmarks! Please nuke it first (X) before cloning.")))

      (let ((project-bms (cl-remove-if-not (lambda (bm) (my/bookmark-belongs-to-workspace-p bm source-root-exp)) bookmark-alist))
            (cloned-count 0))
            
        ;; --- PRE-FLIGHT CHECK ---
        (let ((missing-files nil))
          (dolist (bm project-bms)
            (let* ((raw-path (bookmark-prop-get (car bm) 'filename))
                   (old-path (when raw-path (expand-file-name raw-path)))
                   (is-local (and old-path (string-prefix-p source-root-exp old-path))))
              (when is-local
                (let ((new-path (concat target-root (substring old-path (length source-root-exp)))))
                  (unless (file-exists-p new-path)
                    (push new-path missing-files))))))
          (when missing-files
            (error "Abort: Target directory is missing %d required files (e.g., '%s'). Did you copy the project files over first?"
                   (length missing-files)
                   (file-name-nondirectory (car missing-files)))))

        ;; --- CLONE EXECUTION ---
        (dolist (bm project-bms)
          (let* ((old-bm-name (car bm))
                 (raw-path (bookmark-prop-get old-bm-name 'filename))
                 (old-path (when raw-path (expand-file-name raw-path)))
                 (is-local (and old-path (string-prefix-p source-root-exp old-path)))
                 
                 (new-path (if is-local
                               (concat target-root (substring old-path (length source-root-exp)))
                             raw-path)) 
                             
                 (new-bm-name (if is-local new-path old-bm-name))
                 (old-tags (bookmark-prop-get old-bm-name 'tags))
                 
                 (existing-alist (if (assoc new-bm-name bookmark-alist)
                                     (copy-alist (cdr (assoc new-bm-name bookmark-alist)))
                                   `((filename . ,new-path))))
                                   
                 (base-tags (if is-local
                                (cl-remove-if (lambda (t-name) 
                                                (or (string-prefix-p "proj:" t-name)
                                                    (string-prefix-p "wt|" t-name)))
                                              old-tags)
                              (alist-get 'tags existing-alist)))
                 (new-tags base-tags))

            (unless (member (concat "proj:" target-root) new-tags)
              (push (concat "proj:" target-root) new-tags))

            (dolist (tag old-tags)
              (when (string-prefix-p (format "wt|%s|" source-root-exp) tag)
                (let ((new-wt (concat "wt|" target-root "|" (substring tag (length (format "wt|%s|" source-root-exp))))))
                  (unless (member new-wt new-tags)
                    (push new-wt new-tags)))))

            (setf (alist-get 'tags existing-alist) new-tags)

            (when is-local
              (let ((clean-alist nil))
                (dolist (pair existing-alist)
                  (unless (and (symbolp (car pair)) (string-prefix-p "slot|" (symbol-name (car pair))))
                    (push pair clean-alist)))
                (setq existing-alist (nreverse clean-alist))))

            (dolist (prop-cons (cdr bm))
              (let ((prop-name (symbol-name (car prop-cons))))
                (when (string-prefix-p (format "slot|%s|" source-root-exp) prop-name)
                  (let* ((tag-name (substring prop-name (length (format "slot|%s|" source-root-exp))))
                         (new-prop-sym (intern (format "slot|%s|%s" target-root tag-name)))
                         (slot-val (cdr prop-cons)))
                    (setf (alist-get new-prop-sym existing-alist) slot-val)))))

            (bookmark-store new-bm-name existing-alist nil)
            (cl-incf cloned-count)))
        
        ;; --- CLONE THE META-STATE ---
        (let ((source-tag (my/get-saved-workspace-tag source-root-exp)))
          (when source-tag
            (my/save-workspace-tag target-root source-tag)
            ;; Instantly update the current HUD's right hand view
            (setq my/current-speed-dial-tag source-tag)))

        (bookmark-save)
        (message "Successfully pulled %d slots from '%s' into current workspace!" 
                 cloned-count 
                 (file-name-nondirectory (directory-file-name source-root-exp))))))
  (hydra-speed-dial/body))

;; ==========================================
;; 6. HYDRA HUD MANAGER
;; ==========================================

(defhydra hydra-speed-dial (:color blue :hint nil)
  "
^WORKSPACE^: %s(or my/current-workspace-root \"[None Locked - Press 'p']\")
^TAG    ^  : %s(or my/current-speed-dial-tag \"[No Tag Selected - Press 't']\")%s(cond
  ((eq my/speed-dial-mode 'pick)
   \"\n\n  >>>[MOVE MODE] PRESS BOOKMARK KEY TO PICK UP <<<\")
  ((eq my/speed-dial-mode 'drop)
   (format \"\n\n  >>>[MOVE MODE] CARRYING:[%s] ... PRESS TARGET KEY TO DROP! <<<\"
           (if (and my/pending-move-bm (file-name-absolute-p my/pending-move-bm))
               (file-name-nondirectory my/pending-move-bm)
             my/pending-move-bm)))
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
;; 7. Auto-load Last Workspace
;; ==========================================
(my/load-global-workspace-state)

;; ==========================================
;; 8. KEYBINDINGS
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
