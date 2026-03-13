;; 1. Setup package archives (MELPA)
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; 2. Refresh contents if you haven't yet
(unless package-archive-contents
  (package-refresh-contents))

;; ==========================================
;; 3. Install and enable Evil & Evil-Collection
;; ==========================================

;; MUST BE SET BEFORE EVIL LOADS!
;; This fixes the evil-collection warning by preventing Evil from
;; loading its default (and conflicting) keybindings.
(setq evil-want-integration t)
(setq evil-want-keybinding nil)
(setq evil-want-C-u-scroll t)   ; <--- ADD THIS LINE HERE

;; Install and load Evil
(unless (package-installed-p 'evil)
  (package-install 'evil))
(require 'evil)
(evil-mode 1)
;; Set Space as leader key
(evil-set-leader 'normal (kbd "SPC"))

;; Install and load Evil-Collection
(unless (package-installed-p 'evil-collection)
  (package-install 'evil-collection))
(require 'evil-collection)
(evil-collection-init)

;; ==========================================
;; 4. getting plugins from github
;; ==========================================
(unless (package-installed-p 'quelpa)
  (package-install 'quelpa))

(require 'quelpa)
;; Stop Quelpa from checking for MELPA recipe updates on every startup
(setq quelpa-update-melpa-p nil)


;; 5. general settings
(define-key evil-normal-state-map (kbd "SPC f f") 'find-file)

;; setting english font
(set-face-attribute 'default nil 
                    :font "CMU Typewriter Text" 
                    :height 200)

;; reload emacs
(defun my/reload-config ()
  "Reload your Emacs init.el file instantly."
  (interactive)
  (load-file user-init-file)
  (message "Config successfully reloaded!"))
(define-key evil-normal-state-map (kbd "SPC h r r") 'my/reload-config)

;; ==========================================
;; Make ESC quit prompts and cancel chords (The Vim Way)
;; ==========================================

;; I. Global: Make ESC quit prompts, close extraneous windows, etc.
(global-set-key (kbd "<escape>") 'keyboard-escape-quit)

;; II. Minibuffer: Make ESC abort M-x, Evil command line (:), searches, etc.
(defun my/minibuffer-keyboard-quit ()
  "Abort recursive edit. In Delete Selection mode, this is undefined."
  (interactive)
  (abort-recursive-edit))

(define-key minibuffer-local-map            (kbd "<escape>") 'my/minibuffer-keyboard-quit)
(define-key minibuffer-local-ns-map         (kbd "<escape>") 'my/minibuffer-keyboard-quit)
(define-key minibuffer-local-completion-map (kbd "<escape>") 'my/minibuffer-keyboard-quit)
(define-key minibuffer-local-must-match-map (kbd "<escape>") 'my/minibuffer-keyboard-quit)
(define-key minibuffer-local-isearch-map    (kbd "<escape>") 'my/minibuffer-keyboard-quit)

;; III. Prefix Keys: Make ESC safely abort C-x, C-c, and C-h without getting stuck
(define-key ctl-x-map         (kbd "<escape>") 'keyboard-quit)  ; Cancels C-x
(define-key mode-specific-map (kbd "<escape>") 'keyboard-quit)  ; Cancels C-c
(define-key help-map          (kbd "<escape>") 'keyboard-quit)  ; Cancels C-h

;; get rid of annoying bell sound
(setq ring-bell-function 'ignore)
(setq visible-bell t)

;; remember file position
(save-place-mode 1)

;; ==========================================
;; Relative Line Numbers (The Vim Way)
;; ==========================================

;; Set line numbers to relative
(setq display-line-numbers-type 'relative)

;; Enable line numbers globally
(global-display-line-numbers-mode 1)

;; PRO-TIP: Disable line numbers in certain modes (like terminals)
;; Having line numbers inside Eshell or Eat (like when running htop) breaks the UI!
(dolist (mode '(eshell-mode-hook
                eat-mode-hook
                term-mode-hook
                shell-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode 0))))

;; ==========================================
;; 6. Setup Org-Mode & Evil-Org
;; ==========================================

;; Load built-in org-mode
(require 'org)

;; Install evil-org from MELPA
(unless (package-installed-p 'evil-org)
  (package-install 'evil-org))
(require 'evil-org)

;; Automatically enable evil-org-mode whenever you open an .org file
(add-hook 'org-mode-hook 'evil-org-mode)

;; Load the standard Evil-org key themes
;; This gives you the proper Vim-like behavior for navigating headings,
;; folding with Tab, and interacting with lists.
(evil-org-set-key-theme '(navigation insert textobjects additional calendar))

;; (Optional but Highly Recommended) 
;; Enable Evil bindings in the Org Agenda
(require 'evil-org-agenda)
(evil-org-agenda-set-keys)

;; ==========================================
;; 7. Setup Org-Roam
;; ==========================================

;; Install org-roam from MELPA
(unless (package-installed-p 'org-roam)
  (package-install 'org-roam))
(require 'org-roam)

;; Set the directory where your Roam notes will be saved
;; `file-truename` is important for org-roam to work correctly
(setq org-roam-directory (file-truename "~/org-roam"))

;; Create the directory automatically if it doesn't exist yet
(unless (file-exists-p org-roam-directory)
  (make-directory org-roam-directory))

;; Start the background database sync (essential for Org-Roam v2)
(org-roam-db-autosync-mode)

;; -- Evil Keybindings for Org-Roam --
;; We will use "SPC n" (Space -> Notes) as the prefix for Roam commands.

;; SPC n l: Toggles the Roam side-panel (shows backlinks/unlinked references)
(define-key evil-normal-state-map (kbd "SPC n l") 'org-roam-buffer-toggle)

;; SPC n f: Find or create a node (your main entry point)
(define-key evil-normal-state-map (kbd "SPC n f") 'org-roam-node-find)

;; SPC n i: Insert a link to another node at your current cursor position
(define-key evil-normal-state-map (kbd "SPC n i") 'org-roam-node-insert)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(bmkp-last-as-first-bookmark-file "~/.emacs.d/bookmarks")
 '(package-selected-packages nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
;; ==========================================
;; 8. Org-Roam-UI (The Obsidian-style Graph)
;; ==========================================

;; Install org-roam-ui
(unless (package-installed-p 'org-roam-ui)
  (package-install 'org-roam-ui))

(require 'org-roam-ui)

;; Configure ORUI to use xwidgets so it opens INSIDE Emacs
(setq org-roam-ui-sync-theme t
      org-roam-ui-follow t
      org-roam-ui-update-on-save t
      org-roam-ui-open-on-start t)

;; Bind SPC n g to open the Graph View
(define-key evil-normal-state-map (kbd "SPC n g") 'org-roam-ui-mode)
;; Make the Space key type a normal space in search menus
;; instead of trying to autocomplete
(define-key minibuffer-local-completion-map (kbd "SPC") 'self-insert-command)
;;(org-roam-db-autosync-mode 1)
;; SPC n s: Manually sync the Org-Roam database (fixes missing backlinks)
(define-key evil-normal-state-map (kbd "SPC n s") 'org-roam-db-sync)

;; ==========================================
;; 9. Setup Org-Transclusion
;; ==========================================

;; Install org-transclusion from MELPA
(unless (package-installed-p 'org-transclusion)
  (package-install 'org-transclusion))
(require 'org-transclusion)

;; -- Evil Keybindings for Org-Transclusion --

;; SPC n t: Toggle transclusions in the current buffer (turns links into actual text)
(define-key evil-normal-state-map (kbd "SPC n t") 'org-transclusion-mode)

;; SPC n a: Helper to quickly add a transclusion link at your cursor
(define-key evil-normal-state-map (kbd "SPC n a") 'org-transclusion-add)

;; ==========================================
;; 10. Setup Org-Download
;; ==========================================

;; Install org-download
(unless (package-installed-p 'org-download)
  (package-install 'org-download))
(require 'org-download)

;; Drag-and-drop to Dired and Org buffers
(add-hook 'dired-mode-hook 'org-download-enable)
(add-hook 'org-mode-hook 'org-download-enable)

;; Save images in a sub-folder called "images" inside your org-roam directory
(setq-default org-download-image-dir (concat org-roam-directory "/images"))


;; ==========================================
;; 11. Setup Org-Capture
;; ==========================================

;; Set a file for your messy, temporary thoughts
(setq org-default-notes-file (concat org-roam-directory "/inbox.org"))

;; Setup the capture template
(setq org-capture-templates
      '(("i" "Inbox / Fleeting Note" entry (file org-default-notes-file)
         "* %?\n%U\n%i" :empty-lines 1)))

;; Bind it to SPC n c (Capture)
(define-key evil-normal-state-map (kbd "SPC n c") 'org-capture)

;; ==========================================
;; 12. Setup Org-Appear
;; ==========================================

(unless (package-installed-p 'org-appear)
  (package-install 'org-appear))
(require 'org-appear)

;; Make emphasis markers (*bold*, /italic/) hidden by default in org-mode
(setq org-hide-emphasis-markers t)

;; Enable org-appear in org-mode so they reveal when the cursor is on them
(add-hook 'org-mode-hook 'org-appear-mode)

;; Tell org-appear to also reveal links when the cursor is over them
(setq org-appear-autoemphasis t
      org-appear-autolinks t
      org-appear-autosubmarkers t)

;; ==========================================
;; 13. Setup Eshell & Eat (TUI support in Emacs)
;; ==========================================

;; Install Eat
;; (Eat is available on NonGNU ELPA, which is enabled by default in Emacs 28+)
(unless (package-installed-p 'eat)
  (package-install 'eat))
(require 'eat)

;; Hook Eat into Eshell
;; 1. Enable Eat's visual command mode for Eshell
;;    (This tells Eshell to use Eat to draw TUIs like htop, vim, lazygit)
(add-hook 'eshell-load-hook #'eat-eshell-visual-command-mode)

;; 2. Enable general Eat integration in Eshell
(add-hook 'eshell-load-hook #'eat-eshell-mode)

;; Bind "SPC e" to quickly open/jump to Eshell
(define-key evil-normal-state-map (kbd "SPC e") 'eshell)

;; IMPORTANT FOR EVIL USERS:
;; Tell Evil to start in 'emacs' state when an Eat terminal buffer opens.
;; This ensures that when you run 'htop' or 'lazygit', your keystrokes 
;; go directly to the app instead of triggering Vim commands.
(evil-set-initial-state 'eat-mode 'emacs)

;; ==========================================
;; ESHELL / EAT TERMINAL FIXES
;; ==========================================

(defun my/eshell-clear-buffer ()
  "Instantly clear the Eshell buffer, like 'clear' in bash."
  (interactive)
  (let ((inhibit-read-only t))
    (erase-buffer)
    (eshell-send-input)))

;; Hook this to Eshell so C-l always clears with one press
(add-hook 'eshell-mode-hook
          (lambda ()
            (local-set-key (kbd "C-l") 'my/eshell-clear-buffer)))

;; ==========================================
;; 14. Setup Bookmark+
;; ==========================================


;; Install Bookmark+ using the Emacsmirror GitHub repository.
;; This is safer than the EmacsWiki fetcher.
;; ONLY install if it isn't already installed!
(unless (package-installed-p 'bookmark+)
  (quelpa '(bookmark+ :fetcher github :repo "emacsmirror/bookmark-plus")))

(require 'bookmark+)

;; Automatically save bookmarks to your bookmark file whenever one is made/changed
(setq bookmark-save-flag 1)

;; -- Evil Keybindings for Bookmarks --
;; We will use "SPC b" as the prefix for all Bookmark commands.

;; SPC b m: Open the enhanced Bookmark+ Menu (bmenu)
(define-key evil-normal-state-map (kbd "SPC b m") 'bookmark-bmenu-list)

;; SPC b s: Set/Create a bookmark at your current cursor position
(define-key evil-normal-state-map (kbd "SPC b s") 'bookmark-set)

;; SPC b j: Jump to a bookmark instantly via the minibuffer
(define-key evil-normal-state-map (kbd "SPC b j") 'bookmark-jump)

;; SPC b a: Annotate the bookmark at point
(define-key evil-normal-state-map (kbd "SPC b a") 'bookmark-annotate)

;; ==========================================
;; BOOKMARK+ BMENU EVIL INTEGRATION
;; ==========================================

;; Start the bookmark menu in Emacs state. 
;; This prevents Evil's normal mode from overriding Bookmark+'s incredibly 
;; useful keys (like 't' for tags, 's' for sorting, and 'm' for marking).
(evil-set-initial-state 'bookmark-bmenu-mode 'emacs)

;; But we still want Vim-style navigation! 
;; We will map 'j' and 'k' to move up and down, and 'ESC' to close the menu.
(add-hook 'bookmark-bmenu-mode-hook
          (lambda ()
            (define-key bookmark-bmenu-mode-map (kbd "j") 'next-line)
            (define-key bookmark-bmenu-mode-map (kbd "k") 'previous-line)
            (define-key bookmark-bmenu-mode-map (kbd "<escape>") 'quit-window)))

;; ==========================================
;; 15. Project-Specific Bookmarks
;; ==========================================
(require 'project)
(require 'cl-lib)

(defun my/project-bookmark-jump ()
  "Filter your master bookmarks and jump only to those inside the current project."
  (interactive)
  (bookmark-maybe-load-default-file) ;; <--- THE FIX
  ;; 1. Check if we are currently inside a project (e.g., a git repo)
  (if-let ((pr (project-current)))
      (let* ((root (expand-file-name (project-root pr)))
             ;; 2. Scan global bookmarks and keep only ones matching the project path
             (project-bms (cl-remove-if-not
                           (lambda (bm)
                             (let ((file (bookmark-get-filename bm)))
                               (and file (string-prefix-p root (expand-file-name file)))))
                           bookmark-alist))
             ;; 3. Extract just the names of those bookmarks
             (names (mapcar #'car project-bms)))
        ;; 4. Show the narrowed list in the minibuffer, or warn if empty
        (if names
            (let* ((project-name (file-name-nondirectory (directory-file-name root)))
                   (choice (completing-read (format "Project Bookmarks [%s]: " project-name) names)))
              (bookmark-jump choice))
          (message "No bookmarks found for this project! (Press SPC b s to make one)")))
    (message "You are not currently in a project (no .git folder detected).")))

;; =============================================
;; 16. Bind it to SPC b p (Bookmarks -> Project)
;; =============================================

(define-key evil-normal-state-map (kbd "SPC b p") 'my/project-bookmark-jump)
(defun my/bookmark-current-file-auto ()
  "Automatically set a bookmark using the current file or buffer's name."
  (interactive)
  (let ((bm-name (if buffer-file-name
                     ;; If it's a file, use just the filename (e.g. "index.html")
                     (file-name-nondirectory buffer-file-name)
                   ;; If it's a directory or special buffer (like Eshell), use the buffer name
                   (buffer-name))))
    (bookmark-set bm-name)
    (message "Successfully bookmarked as: %s" bm-name)))

;; Bind your new auto-bookmark function to SPC b m (Make)
(define-key evil-normal-state-map (kbd "SPC b m") 'my/bookmark-current-file-auto)

;; Move the Bookmark+ Menu (bmenu) to SPC b l (List) so you can still access it!
(define-key evil-normal-state-map (kbd "SPC b l") 'bookmark-bmenu-list)
;; ==========================================
;; 17 Manual Workspace State
;; ==========================================
(defvar my/current-workspace-root nil
  "The manually selected workspace directory.")

(defun my/set-workspace ()
  "Manually lock Emacs into a specific workspace using a target file."
  (interactive)
  (let* ((target-file (read-file-name "Select workspace target file: "))
         (root (expand-file-name (file-name-directory target-file))))
    (setq my/current-workspace-root root)
    (setq my/current-speed-dial-tag nil) ;; Clear right-hand tag on switch
    (message "Workspace locked to: %s" root)))

(defun my/get-workspace ()
  "Return the active workspace, or throw an error if none is set."
  (unless my/current-workspace-root
    (error "No workspace locked! Use SPC a p to select your target file"))
  my/current-workspace-root)

(define-key evil-normal-state-map (kbd "SPC a p") 'my/set-workspace)

;; ==========================================
;; 18. Project-Scoped Tagging
;; ==========================================
(require 'bookmark)

(defun my/bookmark-tag-current-file ()
  "Tag the current file and link it to the locked workspace."
  (interactive)
  (let* ((root (my/get-workspace))  ;; <--- DECOUPLED!
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

(define-key evil-normal-state-map (kbd "SPC b t") 'my/bookmark-tag-current-file)

;; ==========================================
;; 19. Split-Keyboard Speed-Dial (HYDRA HUD + MANAGER)
;; ==========================================

;; 1. Install Hydra
(unless (package-installed-p 'hydra)
  (package-install 'hydra))
(require 'hydra)

(defvar my/current-speed-dial-tag nil
  "The currently active dynamic tag (Right Hand).")

(defun my/bookmark-belongs-to-workspace-p (bm root)
  "Check if bookmark BM belongs to the active ROOT."
  (let ((file (bookmark-get-filename bm))
        (proj-tag (concat "proj:" root)))
    (or (member proj-tag (bookmark-prop-get bm 'tags))
        (and file (string-prefix-p root (expand-file-name file))))))

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
         (project-tags (cl-remove-duplicates (apply #'append (mapcar (lambda (bm) (bookmark-prop-get bm 'tags)) project-bms)) :test #'string=))
         (clean-tags (cl-remove-if (lambda (t-name) (string-prefix-p "proj:" t-name)) project-tags)))
    (if (not clean-tags)
        (message "No tags found! Press 'N' to tag a file first.")
      (setq my/current-speed-dial-tag (completing-read "Select tag for RIGHT hand: " clean-tags)))))

(defun my/speed-dial-jump (tag num)
  "Jump to the NUM-th bookmark of TAG, handle Move, OR handle Untag."
  (bookmark-maybe-load-default-file)
  
  ;; Block actions on the right side if no tag is locked
  (if (not tag)
      (progn
        (message "No dynamic tag set for the right hand! Press 't' to lock one.")
        (when (not (eq my/speed-dial-mode 'normal))
          (hydra-speed-dial/body)))
    
    (let* ((root (my/get-workspace))
           (project-bms (cl-remove-if-not (lambda (bm) (my/bookmark-belongs-to-workspace-p bm root)) bookmark-alist))
           (tagged-bms (cl-remove-if-not (lambda (bm) (member tag (bookmark-prop-get bm 'tags))) project-bms))
           (slotted-bms (my/get-bookmarks-in-slots (mapcar #'car tagged-bms) tag))
           (target (nth (1- num) slotted-bms)))
      
      (cond
       ;; --- NORMAL MODE: Just jump to the file ---
       ((eq my/speed-dial-mode 'normal)
        (if target
            (bookmark-jump target)
          (message "Empty slot")))

       ;; --- PICK MODE: User pressed a key to pick up a file ---
       ((eq my/speed-dial-mode 'pick)
        (if (not target)
            (message "That slot is empty! Press a key with a bookmark.")
          (setq my/pending-move-bm target)
          (setq my/pending-move-board tag)
          (setq my/speed-dial-mode 'drop))
        (hydra-speed-dial/body)) ;; Keep Hydra open!

       ;; --- DROP MODE: User pressed a key to drop the file ---
       ((eq my/speed-dial-mode 'drop)
        (let* ((bm-name my/pending-move-bm)
               (old-tag my/pending-move-board)
               (new-tag tag)
               (new-prop (intern (concat "slot-" new-tag)))
               (old-prop (intern (concat "slot-" old-tag))))

          ;; 1. Kick out whatever is currently occupying the target slot
          (dolist (other-bm (mapcar #'car bookmark-alist))
            (when (and (not (string= other-bm bm-name))
                       (eq (bookmark-prop-get other-bm new-prop) num))
              (bookmark-prop-set other-bm new-prop nil)))

          ;; 2. Clear its old slot location
          (bookmark-prop-set bm-name old-prop nil)

          ;; 3. If moving between Left (Global) and Right (Dynamic), swap the tags!
          (when (not (string= old-tag new-tag))
            (let ((tags (bookmark-prop-get bm-name 'tags)))
              (setq tags (remove old-tag tags))            ;; Remove old board
              (unless (member new-tag tags)
                (push new-tag tags))                       ;; Add new board
              (bookmark-prop-set bm-name 'tags tags)))

          ;; 4. Save new location
          (bookmark-prop-set bm-name new-prop num)
          (bookmark-save)

          ;; 5. Reset everything back to normal
          (setq my/speed-dial-mode 'normal)
          (setq my/pending-move-bm nil)
          (setq my/pending-move-board nil)

          (message "Moved '%s' to slot %d on [%s]!" bm-name num new-tag))
        
        ;; Keep Hydra open to see the new layout!
        (hydra-speed-dial/body))
       
       ;; --- UNTAG MODE: User pressed a key to untag the file ---
       ((eq my/speed-dial-mode 'untag)
        (if (not target)
            (message "That slot is already empty!")
          (let* ((tags (bookmark-prop-get target 'tags))
                 (prop (intern (concat "slot-" tag))))
            ;; Remove the specific tag (left=global, right=dynamic)
            (setq tags (remove tag tags))
            (bookmark-prop-set target 'tags tags)
            ;; Also clear its specific slot position for this tag
            (bookmark-prop-set target prop nil)
            (bookmark-save)
            (message "Untagged '%s' from [%s]" target tag)))
        
        ;; Reset mode back to normal and keep Hydra open
        (setq my/speed-dial-mode 'normal)
        (hydra-speed-dial/body))))))

(defvar my/speed-dial-mode 'normal "Can be 'normal, 'pick, 'drop, or 'untag")
(defvar my/pending-move-bm nil "Bookmark currently being moved.")
(defvar my/pending-move-board nil "Board where the bookmark originated.")

;; --- HYDRA HELPER & MANAGEMENT FUNCTIONS ---

(defun my/get-bookmarks-in-slots (bm-names tag)
  "Distribute BM-NAMES into an 8-slot list based on their 'slot-TAG' property.
Unassigned bookmarks automatically fill any remaining empty gaps."
  (let* ((prop (intern (concat "slot-" tag)))
         (slots (make-vector 8 nil))
         (unassigned nil))
    
    ;; Pass 1: Place manually pinned bookmarks into their exact slots
    (dolist (bm bm-names)
      (let ((slot-num (bookmark-prop-get bm prop)))
        (if (and (integerp slot-num) (>= slot-num 1) (<= slot-num 8))
            (aset slots (1- slot-num) bm)
          (push bm unassigned))))
    
    ;; Pass 2: Sort the remaining unassigned bookmarks alphabetically
    (setq unassigned (sort unassigned #'string<))
    
    ;; Pass 3: Fill any remaining gaps on the board with the unassigned ones
    (dotimes (i 8)
      (when (and (null (aref slots i)) unassigned)
        (aset slots i (pop unassigned))))
    
    ;; Convert vector back to a standard list for the Hydra
    (append slots nil)))

(defun my/hydra-start-move ()
  "Toggle the Speed Dial into Move (Pick & Drop) mode."
  (interactive)
  (if (eq my/speed-dial-mode 'normal)
      (setq my/speed-dial-mode 'pick)
    (progn ;; Cancel if pressed again
      (setq my/speed-dial-mode 'normal)
      (setq my/pending-move-bm nil)
      (setq my/pending-move-board nil)))
  (hydra-speed-dial/body))

(defun my/hydra-start-untag ()
  "Toggle the Speed Dial into Untag mode."
  (interactive)
  (if (eq my/speed-dial-mode 'normal)
      (setq my/speed-dial-mode 'untag)
    (progn ;; Cancel if pressed again
      (setq my/speed-dial-mode 'normal)
      (setq my/pending-move-bm nil)
      (setq my/pending-move-board nil)))
  (hydra-speed-dial/body))

(defun my/hydra-quit ()
  "Safely quit the Hydra and cancel any pending moves."
  (interactive)
  (setq my/speed-dial-mode 'normal)
  (setq my/pending-move-bm nil)
  (setq my/pending-move-board nil))

(defun my/hydra-quick-tag-current ()
  "Prompt to tag the currently opened file to either 'global' or the active dynamic tag."
  (interactive)
  (bookmark-maybe-load-default-file)
  (let* ((root (my/get-workspace))
         (proj-tag (concat "proj:" root))
         (bm-name (if buffer-file-name (file-name-nondirectory buffer-file-name) (buffer-name)))
         
         ;; Create the choices for the prompt. 
         ;; 'global' is always an option. If a right-hand tag is locked, add it too.
         (choices (if my/current-speed-dial-tag
                      (list "global" my/current-speed-dial-tag)
                    (list "global")))
         
         ;; Ask the user which side/tag they want to assign
         (selected-tag (completing-read "Tag current file to: " choices nil t)))
    
    ;; Automatically bookmark the file if it isn't bookmarked yet
    (unless (assoc bm-name bookmark-alist)
      (bookmark-set bm-name))
    
    ;; Grab existing tags and apply the chosen tag + workspace tag
    (let ((existing-tags (bookmark-prop-get bm-name 'tags)))
      (unless (member selected-tag existing-tags)
        (push selected-tag existing-tags))
      (unless (member proj-tag existing-tags)
        (push proj-tag existing-tags))
      
      (bookmark-prop-set bm-name 'tags existing-tags)
      (bookmark-save)
      (message "Quick-tagged '%s' as [%s]" bm-name selected-tag)))
  
  ;; Resume the Hydra HUD so you can see your update instantly
  (hydra-speed-dial/body))

(defun my/sd-name (side num)
  "Helper for Hydra: fetch, pad, and truncate the bookmark name for the HUD."
  (bookmark-maybe-load-default-file)
  (let ((val "-"))
    (when my/current-workspace-root
      (let* ((root my/current-workspace-root)
             (project-bms (cl-remove-if-not (lambda (bm) (my/bookmark-belongs-to-workspace-p bm root)) bookmark-alist))
             (bms (if (eq side 'left)
                      (cl-remove-if-not (lambda (bm) (member "global" (bookmark-prop-get bm 'tags))) project-bms)
                    (if my/current-speed-dial-tag
                        (cl-remove-if-not (lambda (bm) (member my/current-speed-dial-tag (bookmark-prop-get bm 'tags))) project-bms)
                      nil)))
             ;; NEW: Use absolute slots
             (active-tag (if (eq side 'left) "global" my/current-speed-dial-tag))
             (slotted-bms (my/get-bookmarks-in-slots (mapcar #'car bms) active-tag))
             (target (nth (1- num) slotted-bms)))
        (when target
          (setq val target))))
    (truncate-string-to-width val 20 0 ?\s "…")))

(defun my/hydra-create-tag ()
  "Prompt for a new tag name and lock it to the right hand.
You can then populate it by tagging the current file ('T') or moving items ('M')."
  (interactive)
  (let ((new-tag (read-string "Create new tag: ")))
    (if (string= "" new-tag)
        (message "Cancelled: Tag name cannot be empty.")
      (setq my/current-speed-dial-tag new-tag)
      (message "Created and locked new tag: [%s]" new-tag)))
  (hydra-speed-dial/body))

(defun my/hydra-wipe-tag ()
  "Remove a specific tag from ALL bookmarks in the current workspace."
  (interactive)
  (let* ((root (my/get-workspace))
         (project-bms (cl-remove-if-not (lambda (bm) (my/bookmark-belongs-to-workspace-p bm root)) bookmark-alist))
         (project-tags (cl-remove-duplicates (apply #'append (mapcar (lambda (bm) (bookmark-prop-get bm 'tags)) project-bms)) :test #'string=))
         (clean-tags (cl-remove-if (lambda (t-name) (string-prefix-p "proj:" t-name)) project-tags)))
    (if (not clean-tags)
        (message "No tags exist in this workspace!")
      (let ((tag-to-nuke (completing-read "Wipe tag completely: " clean-tags nil t)))
        ;; Loop through all project bookmarks and remove the tag
        (dolist (bm project-bms)
          (let* ((bm-name (car bm))
                 (tags (bookmark-prop-get bm-name 'tags)))
            (when (member tag-to-nuke tags)
              (bookmark-prop-set bm-name 'tags (remove tag-to-nuke tags)))))
        (bookmark-save)
        
        ;; If the tag we just wiped was currently locked to the Right Hand, unlock it
        (when (string= my/current-speed-dial-tag tag-to-nuke)
          (setq my/current-speed-dial-tag nil))
        
        (message "Wiped tag '%s' from all bookmarks." tag-to-nuke))))
  (hydra-speed-dial/body))

;; Wrappers for native hydra controls
(defun my/set-workspace-and-resume () (interactive) (call-interactively 'my/set-workspace) (hydra-speed-dial/body))
(defun my/set-tag-and-resume () (interactive) (call-interactively 'my/set-speed-dial-tag) (hydra-speed-dial/body))

;; THE HYDRA HUD
(defhydra hydra-speed-dial (:color blue :hint nil)
  "
  ^WORKSPACE^: %s(or my/current-workspace-root \"[None Locked - Press 'p']\")
  ^TAG (R)^  : %s(or my/current-speed-dial-tag \"[No Tag Selected - Press 't']\")%s(cond ((eq my/speed-dial-mode 'pick) \"\n\n  >>> [MOVE MODE] PRESS THE KEY OF THE BOOKMARK YOU WANT TO PICK UP <<<\") ((eq my/speed-dial-mode 'drop) (format \"\n\n  >>> [MOVE MODE] CARRYING:[%s] ... PRESS TARGET KEY TO DROP! <<<\" my/pending-move-bm)) ((eq my/speed-dial-mode 'untag) \"\n\n  >>> [UNTAG MODE] PRESS THE KEY OF THE SLOT YOU WANT TO UNTAG <<<\") (t \"\"))

  ^GLOBAL^ (Left Hand)      ^DYNAMIC^ (Right Hand)    ^MANAGEMENT^
  ^^^^^^^^^^^^^^^^^^^^      ^^^^^^^^^^^^^^^^^^^^^^    ^^^^^^^^^^^^
  _a_: %s(my/sd-name 'left 1) _j_: %s(my/sd-name 'right 1)  _T_: Tag Current File (Active)
  _s_: %s(my/sd-name 'left 2) _k_: %s(my/sd-name 'right 2)  _U_: Untag a Slot
  _d_: %s(my/sd-name 'left 3) _l_: %s(my/sd-name 'right 3)  _M_: Toggle Move Mode       
  _f_: %s(my/sd-name 'left 4) _;_: %s(my/sd-name 'right 4)  _C_: Create New Tag
  _z_: %s(my/sd-name 'left 5) _m_: %s(my/sd-name 'right 5)  _W_: Wipe Tag Completely
  _x_: %s(my/sd-name 'left 6) _,_: %s(my/sd-name 'right 6)  
  _c_: %s(my/sd-name 'left 7) _._: %s(my/sd-name 'right 7)  ^CONTROLS^
  _v_: %s(my/sd-name 'left 8) _/_: %s(my/sd-name 'right 8)  ^^^^^^^^^^
                                                      _p_: Lock Workspace  _t_: Lock Tag  _q_: Quit
  "
  ;; Left Hand
  ("a" (my/speed-dial-jump "global" 1)) ("s" (my/speed-dial-jump "global" 2))
  ("d" (my/speed-dial-jump "global" 3)) ("f" (my/speed-dial-jump "global" 4))
  ("z" (my/speed-dial-jump "global" 5)) ("x" (my/speed-dial-jump "global" 6))
  ("c" (my/speed-dial-jump "global" 7)) ("v" (my/speed-dial-jump "global" 8))
  
  ;; Right Hand
  ("j" (my/speed-dial-jump my/current-speed-dial-tag 1)) ("k" (my/speed-dial-jump my/current-speed-dial-tag 2))
  ("l" (my/speed-dial-jump my/current-speed-dial-tag 3)) (";" (my/speed-dial-jump my/current-speed-dial-tag 4))
  ("m" (my/speed-dial-jump my/current-speed-dial-tag 5)) ("," (my/speed-dial-jump my/current-speed-dial-tag 6))
  ("." (my/speed-dial-jump my/current-speed-dial-tag 7)) ("/" (my/speed-dial-jump my/current-speed-dial-tag 8))

  ;; Management (Shift / Capital letters)
  ("T" my/hydra-quick-tag-current)
  ("U" my/hydra-start-untag)
  ("M" my/hydra-start-move)
  ("C" my/hydra-create-tag)
  ("W" my/hydra-wipe-tag)    

  ;; Controls
  ("p" my/set-workspace-and-resume)
  ("t" my/set-tag-and-resume)
  ("q" my/hydra-quit)
  ("<escape>" my/hydra-quit))

;; Bind ONLY the Hydra to SPC a
(define-key evil-normal-state-map (kbd "SPC a") 'hydra-speed-dial/body)
