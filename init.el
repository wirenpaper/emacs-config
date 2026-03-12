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
 '(bmkp-last-as-first-bookmark-file "/home/saifr/.emacs.d/bookmarks")
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
;; 17. Project-Scoped Bookmark Tags
;; ==========================================
(require 'project)
(require 'cl-lib)

(defun my/bookmark-tag-current-file ()
  "Add a tag to the current file. Automatically bookmarks it if needed."
  (interactive)
  (let* ((bm-name (if buffer-file-name 
                      (file-name-nondirectory buffer-file-name) 
                    (buffer-name)))
         (new-tag (read-string (format "Tag for %s (e.g. login, register): " bm-name))))
    
    ;; 1. If it's not bookmarked yet, bookmark it instantly
    (unless (assoc bm-name bookmark-alist)
      (bookmark-set bm-name))
    
    ;; 2. Fetch existing tags for this bookmark, add the new one, and save
    (let ((existing-tags (bookmark-prop-get bm-name 'tags)))
      (unless (member new-tag existing-tags)
        (bookmark-prop-set bm-name 'tags (cons new-tag existing-tags)))
      (bookmark-save)
      (message "Successfully added tag '%s' to '%s'!" new-tag bm-name))))

(defun my/project-bookmark-jump-by-tag ()
  "Filter project bookmarks by a specific tag and jump to one."
  (interactive)
  (if-let ((pr (project-current)))
      (let* ((root (expand-file-name (project-root pr)))
             ;; 1. Get all bookmarks in the current project
             (project-bms (cl-remove-if-not
                           (lambda (bm)
                             (let ((file (bookmark-get-filename bm)))
                               (and file (string-prefix-p root (expand-file-name file)))))
                           bookmark-alist))
             ;; 2. Extract every unique tag used inside this project
             (project-tags (cl-remove-duplicates
                            (apply #'append (mapcar (lambda (bm) (bookmark-prop-get bm 'tags)) project-bms))
                            :test #'string=)))
        (if (not project-tags)
            (message "No tags found in this project! Use SPC b t to tag a file.")
          ;; 3. Ask you which tag you want to look at (e.g., "login")
          (let* ((selected-tag (completing-read "Select feature tag: " project-tags))
                 ;; 4. Filter the bookmarks to ONLY show files with that tag
                 (tagged-bms (cl-remove-if-not
                              (lambda (bm)
                                (member selected-tag (bookmark-prop-get bm 'tags)))
                              project-bms))
                 (names (mapcar #'car tagged-bms))
                 ;; 5. Ask which specific file from that tag you want to open
                 (choice (completing-read (format "Files tagged [%s]: " selected-tag) names)))
            (bookmark-jump choice))))
    (message "You are not currently inside a project!")))

;; -- Keybindings --
;; SPC b t: Tag the current file
(define-key evil-normal-state-map (kbd "SPC b t") 'my/bookmark-tag-current-file)

;; SPC b T (Shift+t): Jump to a file by its Tag
(define-key evil-normal-state-map (kbd "SPC b T") 'my/project-bookmark-jump-by-tag)

;; ==========================================
;; 18. Harpoon-Style Tag Speed-Dial
;; ==========================================

(defvar my/current-speed-dial-tag nil
  "The currently active tag locked in for speed-dialing.")

(defun my/set-speed-dial-tag ()
  "Lock in a specific tag to put its files on speed-dial keys (1-9)."
  (interactive)
  (if-let ((pr (project-current)))
      (let* ((root (expand-file-name (project-root pr)))
             ;; Get all project bookmarks
             (project-bms (cl-remove-if-not
                           (lambda (bm)
                             (let ((file (bookmark-get-filename bm)))
                               (and file (string-prefix-p root (expand-file-name file)))))
                           bookmark-alist))
             ;; Get all unique tags in the project
             (project-tags (cl-remove-duplicates
                            (apply #'append (mapcar (lambda (bm) (bookmark-prop-get bm 'tags)) project-bms))
                            :test #'string=)))
        (if (not project-tags)
            (message "No tags found! Use SPC b t to tag a file first.")
          
          ;; Ask user to pick a tag to lock in
          (setq my/current-speed-dial-tag (completing-read "Select tag for speed-dial: " project-tags))
          
          ;; Find the files for this tag and sort them alphabetically (so the numbers never shift randomly)
          (let* ((tagged-bms (cl-remove-if-not
                              (lambda (bm) (member my/current-speed-dial-tag (bookmark-prop-get bm 'tags)))
                              project-bms))
                 (sorted-bms (sort (mapcar #'car tagged-bms) #'string<))
                 ;; Format them so the user sees which number belongs to which file
                 (names-with-index (cl-loop for name in sorted-bms
                                            for i from 1
                                            collect (format "[%d] %s" i name))))
            ;; Show the speed-dial list at the bottom of the screen!
            (message "Locked '%s' -> %s" 
                     my/current-speed-dial-tag 
                     (mapconcat #'identity names-with-index " | ")))))
    (message "You are not currently inside a project!")))

(defun my/speed-dial-jump (num)
  "Jump to the NUM-th bookmark of the active speed-dial tag."
  (if (not my/current-speed-dial-tag)
      (message "No speed-dial tag set! Use SPC b d to lock one in.")
    (if-let ((pr (project-current)))
        (let* ((root (expand-file-name (project-root pr)))
               (project-bms (cl-remove-if-not
                             (lambda (bm)
                               (let ((file (bookmark-get-filename bm)))
                                 (and file (string-prefix-p root (expand-file-name file)))))
                             bookmark-alist))
               (tagged-bms (cl-remove-if-not
                            (lambda (bm) (member my/current-speed-dial-tag (bookmark-prop-get bm 'tags)))
                            project-bms))
               ;; Sort alphabetically again to ensure consistency
               (sorted-bms (sort (mapcar #'car tagged-bms) #'string<)))
          (if (or (< num 1) (> num (length sorted-bms)))
              (message "No file at position [%d] for tag '%s'." num my/current-speed-dial-tag)
            (let ((target (nth (1- num) sorted-bms)))
              (bookmark-jump target)
              (message "Speed-dial: %s" target))))
      (message "Not in a project!"))))

;; -- Keybindings --

;; SPC b d: Lock in (Dial) a tag for speed-dialing
(define-key evil-normal-state-map (kbd "SPC b d") 'my/set-speed-dial-tag)

;; -- Keybindings --
(define-key evil-normal-state-map (kbd "SPC b d") 'my/set-speed-dial-tag)

;; Hardcoded speed-dial keys
(define-key evil-normal-state-map (kbd "SPC b 1") (lambda () (interactive) (my/speed-dial-jump 1)))
(define-key evil-normal-state-map (kbd "SPC b 2") (lambda () (interactive) (my/speed-dial-jump 2)))
(define-key evil-normal-state-map (kbd "SPC b 3") (lambda () (interactive) (my/speed-dial-jump 3)))
(define-key evil-normal-state-map (kbd "SPC b 4") (lambda () (interactive) (my/speed-dial-jump 4)))
(define-key evil-normal-state-map (kbd "SPC b 5") (lambda () (interactive) (my/speed-dial-jump 5)))
(define-key evil-normal-state-map (kbd "SPC b 6") (lambda () (interactive) (my/speed-dial-jump 6)))
(define-key evil-normal-state-map (kbd "SPC b 7") (lambda () (interactive) (my/speed-dial-jump 7)))
(define-key evil-normal-state-map (kbd "SPC b 8") (lambda () (interactive) (my/speed-dial-jump 8)))
(define-key evil-normal-state-map (kbd "SPC b 9") (lambda () (interactive) (my/speed-dial-jump 9)))
