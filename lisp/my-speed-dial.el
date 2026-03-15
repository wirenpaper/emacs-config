;;; my-speed-dial.el --- Custom workspace speed dial -*- lexical-binding: t -*-

(require 'bookmark)
(require 'cl-lib)

;; ==========================================
;; 1. Workspace-Scoped Bookmarks (Global State)
;; ==========================================
(require 'cl-lib)

(defun my/project-bookmark-jump ()
  "Jump to a bookmark inside your manually locked workspace, from anywhere."
  (interactive)
  (bookmark-maybe-load-default-file)
  
  ;; 1. Check if you've locked a workspace via '<leader> a p'
  (if-let ((root my/current-workspace-root))
      (let* (
             ;; 2. Filter bookmarks. Since your Hydra tags them with "proj:<root>",
             ;; we can look for that tag! This is even better than checking file paths,
             ;; because it works for terminals and dired buffers too.
             (workspace-bms (cl-remove-if-not
                             (lambda (bm)
                               (let* ((bm-name (car bm))
                                      (tags (bookmark-prop-get bm-name 'tags))
                                      (proj-tag (concat "proj:" root)))
                                 (member proj-tag tags)))
                             bookmark-alist))
             
             ;; 3. Extract the names of the matched bookmarks
             (names (mapcar #'car workspace-bms)))
        
        ;; 4. Show the menu, or warn if empty
        (if names
            (let* ((project-name (file-name-nondirectory (directory-file-name root)))
                   (choice (completing-read (format "Workspace Bookmarks [%s]: " project-name) names)))
              (bookmark-jump choice))
          (message "No bookmarks found in locked workspace: %s" root)))
    
    ;; If my/current-workspace-root is nil, tell the user to lock one
    (message "No workspace locked! Press '<leader> a p' to select one first.")))

(use-package evil)
;; Bind it to <leader> b p
(evil-define-key 'normal 'global (kbd "<leader> b p") 'my/project-bookmark-jump)

;; ==========================================
;; 2. Manual Workspace State
;; ==========================================
(defvar my/current-workspace-root nil
  "The manually selected workspace directory.")

(defun my/set-workspace ()
  "Manually lock Emacs into a specific workspace directory."
  (interactive)
  (let* ((target-dir (read-directory-name "Select workspace directory: "))
	 (root (expand-file-name (file-name-as-directory target-dir))))
    (setq my/current-workspace-root root)
    (setq my/current-speed-dial-tag nil) ;; Clear right-hand tag on switch
    (message "Workspace locked to: %s" root)))

(defun my/get-workspace ()
  "Return the active workspace, or throw an error if none is set."
  (unless my/current-workspace-root
    (error "No workspace locked! Use <leader> a p to select your target file"))
  my/current-workspace-root)

(evil-define-key 'normal 'global (kbd "<leader> a p") 'my/set-workspace)

;; ==========================================
;; 3. Project-Scoped Tagging
;; ==========================================
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

(evil-define-key 'normal 'global (kbd "<leader> b t") 'my/bookmark-tag-current-file)

;; ==========================================
;; 4. Split-Keyboard Speed-Dial (HYDRA HUD + MANAGER)
;; ==========================================

;; Install Hydra
(use-package hydra)

(defvar my/current-speed-dial-tag nil "The currently active dynamic tag (Right Hand).")
(defvar my/speed-dial-mode 'normal "Can be 'normal, 'pick, 'drop, 'tag, or 'untag")
(defvar my/pending-move-bm nil "Bookmark currently being moved.")
(defvar my/pending-move-board nil "Board where the bookmark originated.")
(defvar my/pending-tag-target nil "A file selected in the background waiting to be assigned a slot.")

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
      (setq my/current-speed-dial-tag (completing-read "Select tag for RIGHT hand: " clean-tags)))))

(defun my/speed-dial-jump (tag num)
  "Jump to the NUM-th bookmark of TAG, handle Move, Tag, OR handle Untag."
  (bookmark-maybe-load-default-file)

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
               ;; 1. The path is physically missing from the hard drive -> Auto-clean
               ((and file-path (not (file-exists-p file-path)))
                (message "Path '%s' no longer exists! Auto-cleaning bookmark..." file-path)
                (bookmark-delete target)
                (bookmark-save)
                (hydra-speed-dial/body))

               ;; 2. It's a standard FILE -> Switch buffer or find-file to preserve cursor position
               ((and file-path (not (file-directory-p file-path)))
                (let ((buf (get-file-buffer file-path)))
                  (if buf
                      (switch-to-buffer buf)   ; Buffer is open, alt-tab to it
                    (find-file file-path))))   ; File is closed, open it

               ;; 3. It's a SPECIAL buffer (Dired, Eshell, Magit) -> Use native bookmark handler
               (t
                (bookmark-jump target))))
          (message "Empty slot")))

       ;; --- TAG MODE ---
       ((eq my/speed-dial-mode 'tag)
        (let* ((bm-name (or my/pending-tag-target 
                            (if buffer-file-name (expand-file-name buffer-file-name) (buffer-name))))
               (proj-tag (concat "proj:" root))
               (prop (intern (format "slot|%s|%s" root tag))))

          ;; If the bookmark doesn't exist yet, create it safely
          (unless (assoc bm-name bookmark-alist)
            (if my/pending-tag-target
                ;; If it's a background file, momentarily load it silently to generate the bookmark
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
          (setq my/pending-tag-target nil) ;; Reset for next time
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
          (setq my/speed-dial-mode 'normal)
          (setq my/pending-move-bm nil)
          (setq my/pending-move-board nil)

          (message "Moved '%s' to slot %d on [%s]!" (file-name-nondirectory bm-name) num new-tag))
        (hydra-speed-dial/body))

       ;; --- UNTAG MODE (With Global Garbage Collection) ---
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
                (message "Untagged '%s' from[%s]" (file-name-nondirectory target) tag)))))

        (setq my/speed-dial-mode 'normal)
        (hydra-speed-dial/body))))))

;; --- HYDRA HELPER & MANAGEMENT FUNCTIONS ---

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
      (setq-local mode-line-format nil 
                  header-line-format nil 
                  cursor-type nil 
                  truncate-lines t
                  ;; [FIX 1] Lock the window height so completions don't shrink it
                  window-size-fixed t))
    
    ;; [FIX 2] Use a 'side-window' at the TOP so it avoids bottom-anchored minibuffer growth
    (setq win (display-buffer buf 
                              '((display-buffer-in-side-window) 
                                (side . top) 
                                (window-height . fit-window-to-buffer))))
                                
    ;;[FIX 3] Dedicate the window so the *Completions* buffer is never allowed to overwrite it
    (set-window-dedicated-p win t)
    
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

(defun my/hydra-start-tag () 
  (interactive) 
  (setq my/pending-tag-target nil)
  (setq my/speed-dial-mode (if (eq my/speed-dial-mode 'normal) 'tag 'normal)) 
  (hydra-speed-dial/body))

(defun my/hydra-start-move () (interactive) (setq my/speed-dial-mode (if (eq my/speed-dial-mode 'normal) 'pick 'normal)) (hydra-speed-dial/body))
(defun my/hydra-start-untag () (interactive) (setq my/speed-dial-mode (if (eq my/speed-dial-mode 'normal) 'untag 'normal)) (hydra-speed-dial/body))

(defun my/hydra-quit () 
  (interactive) 
  (setq my/speed-dial-mode 'normal 
        my/pending-move-bm nil 
        my/pending-move-board nil
        my/pending-tag-target nil))

(defun my/bookmark-set-absolute ()
  "Bookmark current buffer. Uses absolute path, or appends directory for special buffers."
  (interactive)
  (let* ((default-name (if buffer-file-name 
                           (expand-file-name buffer-file-name) 
                         (concat (buffer-name) "[" (abbreviate-file-name default-directory) "]")))
         (bm-name (read-string (format "Set bookmark (%s): " default-name) nil nil default-name)))
    (bookmark-set bm-name)))

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

(defun my/hydra-create-tag ()
  (interactive)
  (let ((new-tag (read-string "Create new tag: ")))
    (if (string= "" new-tag)
        (message "Cancelled: Tag name cannot be empty.")
      (setq my/current-speed-dial-tag new-tag)
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
          (setq my/current-speed-dial-tag nil))
        (message "Wiped tag '%s' (Deleted %d orphaned globally)." tag-to-nuke deleted-count))))
  (hydra-speed-dial/body))

(defun my/hydra-wipe-workspace ()
  "Remove the workspace. If bookmarks are shared, untag them. If strictly local, delete them."
  (interactive)
  (bookmark-maybe-load-default-file)
  (let* ((root (my/get-workspace))
         (project-bms (cl-remove-if-not 
                       (lambda (bm) (my/bookmark-belongs-to-workspace-p bm root)) 
                       bookmark-alist)))
    (if (not project-bms)
        (message "Workspace is already empty! No bookmarks to remove.")
      (when (y-or-n-p (format "DANGER: Remove workspace '%s' (%d files)? " 
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
        (setq my/current-workspace-root nil)
        (setq my/current-speed-dial-tag nil)
        (message "Workspace clean successfully!"))))
  (hydra-speed-dial/body))

(defun my/set-workspace-and-resume () (interactive) (call-interactively 'my/set-workspace) (hydra-speed-dial/body))
(defun my/set-tag-and-resume () (interactive) (call-interactively 'my/set-speed-dial-tag) (hydra-speed-dial/body))

;; THE HYDRA HUD
(defhydra hydra-speed-dial (:color blue :hint nil)
  "
^WORKSPACE^: %s(or my/current-workspace-root \"[None Locked - Press 'p']\")
^TAG    ^  : %s(or my/current-speed-dial-tag \"[No Tag Selected - Press 't']\")%s(cond ((eq my/speed-dial-mode 'pick) \"\n\n  >>> [MOVE MODE] PRESS THE KEY OF THE BOOKMARK YOU WANT TO PICK UP <<<\") ((eq my/speed-dial-mode 'drop) (format \"\n\n  >>> [MOVE MODE] CARRYING:[%s] ... PRESS TARGET KEY TO DROP! <<<\" (if (and my/pending-move-bm (file-name-absolute-p my/pending-move-bm)) (file-name-nondirectory my/pending-move-bm) my/pending-move-bm))) ((eq my/speed-dial-mode 'untag) \"\n\n  >>> [UNTAG MODE] PRESS THE KEY OF THE SLOT YOU WANT TO UNTAG <<<\") ((eq my/speed-dial-mode 'tag) (if my/pending-tag-target (format \"\n\n  >>> [TAG MODE] READY TO PIN: [%s] ... PRESS A SLOT KEY <<<\" (file-name-nondirectory my/pending-tag-target)) \"\n\n  >>> [TAG MODE] PRESS A SLOT KEY TO TAG AND ASSIGN THE CURRENT FILE <<<\")) (t \"\"))
--------------------------------------------------------------------------------------------------------------
_a_: %s(my/sd-name 'left 1) 	_j_: %s(my/sd-name 'right 1)  	_T_: Tag Current File (Active)
_s_: %s(my/sd-name 'left 2) 	_k_: %s(my/sd-name 'right 2)  	_F_: Find & Tag Background File
_d_: %s(my/sd-name 'left 3) 	_l_: %s(my/sd-name 'right 3)  	_U_: Untag a Slot
_f_: %s(my/sd-name 'left 4) 	_;_: %s(my/sd-name 'right 4)  	_M_: Toggle Move Mode       
_z_: %s(my/sd-name 'left 5) 	_m_: %s(my/sd-name 'right 5)  	_C_: Create New Tag
_x_: %s(my/sd-name 'left 6) 	_,_: %s(my/sd-name 'right 6)  	_W_: Wipe Tag Completely
_c_: %s(my/sd-name 'left 7) 	_._: %s(my/sd-name 'right 7)  	_X_: Nuke Workspace 
_v_: %s(my/sd-name 'left 8) 	_/_: %s(my/sd-name 'right 8)  	_p_: Lock Workspace  _t_: Lock Tag  _q_: Quit
  "
  ("a" (my/speed-dial-jump "global" 1)) ("s" (my/speed-dial-jump "global" 2))
  ("d" (my/speed-dial-jump "global" 3)) ("f" (my/speed-dial-jump "global" 4))
  ("z" (my/speed-dial-jump "global" 5)) ("x" (my/speed-dial-jump "global" 6))
  ("c" (my/speed-dial-jump "global" 7)) ("v" (my/speed-dial-jump "global" 8))

  ("j" (my/speed-dial-jump my/current-speed-dial-tag 1)) ("k" (my/speed-dial-jump my/current-speed-dial-tag 2))
  ("l" (my/speed-dial-jump my/current-speed-dial-tag 3)) (";" (my/speed-dial-jump my/current-speed-dial-tag 4))
  ("m" (my/speed-dial-jump my/current-speed-dial-tag 5)) ("," (my/speed-dial-jump my/current-speed-dial-tag 6))
  ("." (my/speed-dial-jump my/current-speed-dial-tag 7)) ("/" (my/speed-dial-jump my/current-speed-dial-tag 8))

  ("T" my/hydra-start-tag) ("F" my/hydra-find-and-tag) ("U" my/hydra-start-untag) ("M" my/hydra-start-move)
  ("C" my/hydra-create-tag) ("W" my/hydra-wipe-tag) ("X" my/hydra-wipe-workspace)    
  ("p" my/set-workspace-and-resume) ("t" my/set-tag-and-resume)
  ("q" my/hydra-quit) ("<escape>" my/hydra-quit) ("C-g" my/hydra-quit))

;; Bind standard '<leader> b m' to our new absolute path command
(evil-define-key 'normal 'global (kbd "<leader> b m") 'my/bookmark-set-absolute)

;; Bind the Hydra
(evil-define-key 'normal 'global (kbd "<leader> a") 'hydra-speed-dial/body)

(provide 'my-speed-dial)
;;; my-speed-dial.el ends here
