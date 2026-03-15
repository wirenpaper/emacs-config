;; ==========================================
;; 0. Keep Emacs custom UI settings out of init.el
;; ==========================================
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;; 1. Setup package archives (MELPA)
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)

;; 2. Setup use-package (Built into Emacs 29+)
(require 'use-package)
(setq use-package-always-ensure t)

;; ==========================================
;; 3. Install and enable Evil & Evil-Collection
;; ==========================================

(use-package evil
  :init
  (setq evil-want-integration t
        evil-want-keybinding nil
        evil-want-C-u-scroll t)
  :config
  (evil-mode 1)
  (evil-set-leader 'normal (kbd "SPC")))

(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))

;; 4. general settings
(evil-define-key 'normal 'global (kbd "<leader> f f") 'find-file)

;; setting english font
(when (member "CMU Typewriter Text" (font-family-list))
  (set-face-attribute 'default nil :font "CMU Typewriter Text" :height 200))

;; reload emacs
(defun my/reload-config ()
  "Reload your Emacs init.el file instantly."
  (interactive)
  (load-file user-init-file)
  (message "Config successfully reloaded!"))
(evil-define-key 'normal 'global (kbd "<leader> h r r") 'my/reload-config)

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
;; 5. Setup Org-Mode & Evil-Org
;; ==========================================

;; Load built-in org-mode
(require 'org)

(use-package evil-org
  :hook (org-mode . evil-org-mode)
  :config
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys)
  (evil-org-set-key-theme '(navigation insert textobjects additional calendar)))

;; ==========================================
;; 6. Setup Org-Roam
;; ==========================================

(setq org-roam-directory (expand-file-name "~/org-roam"))

(use-package org-roam
  :config
  (unless (file-exists-p org-roam-directory)
    (make-directory org-roam-directory))
  (org-roam-db-autosync-mode)
  :config
  (evil-define-key 'normal 'global
    (kbd "<leader> n l") 'org-roam-buffer-toggle
    (kbd "<leader> n f") 'org-roam-node-find
    (kbd "<leader> n i") 'org-roam-node-insert
    (kbd "<leader> n s") 'org-roam-db-sync))

;; ==========================================
;; 7. Org-Roam-UI (The Obsidian-style Graph)
;; ==========================================

;; Install org-roam-ui
(use-package org-roam-ui
  :custom
  (org-roam-ui-sync-theme t)
  (org-roam-ui-follow t)
  (org-roam-ui-update-on-save t)
  (org-roam-ui-open-on-start t)
  :config
  (evil-define-key 'normal 'global
    (kbd "<leader> n g") 'org-roam-ui-mode))

;; Make the Space key type a normal space in search menus
;; instead of trying to autocomplete
(define-key minibuffer-local-completion-map (kbd "SPC") 'self-insert-command)

;; ==========================================
;; 8. Setup Org-Transclusion
;; ==========================================

(use-package org-transclusion
  :config
  (evil-define-key 'normal 'global
    (kbd "<leader> n t") 'org-transclusion-mode
    (kbd "<leader> n a") 'org-transclusion-add))

;; ==========================================
;; 9. Setup Org-Download
;; ==========================================

(use-package org-download
  :hook ((dired-mode . org-download-enable)
         (org-mode . org-download-enable))
  :custom
  (org-download-image-dir (concat org-roam-directory "/images")))

;; ==========================================
;; 10. Setup Org-Capture
;; ==========================================

(use-package org-capture
  :ensure nil ; It's built into Emacs!
  :custom
  (org-default-notes-file (concat org-roam-directory "/inbox.org"))
  (org-capture-templates
   '(("i" "Inbox / Fleeting Note" entry (file org-default-notes-file)
      "* %?\n%U\n%i" :empty-lines 1)))
  :config
  (evil-define-key 'normal 'global
    (kbd "<leader> n c") 'org-capture))

;; ==========================================
;; 11. Setup Org-Appear
;; ==========================================

(use-package org-appear
  :hook (org-mode . org-appear-mode)
  :custom
  (org-hide-emphasis-markers t)
  (org-appear-autoemphasis t)
  (org-appear-autolinks t)
  (org-appear-autosubmarkers t))

;; ==========================================
;; 12. Setup Eshell & Eat (TUI support in Emacs)
;; ==========================================

(use-package eat
  :hook ((eshell-load . eat-eshell-visual-command-mode)
         (eshell-load . eat-eshell-mode))
  :config
  (evil-set-initial-state 'eat-mode 'emacs)
  (evil-define-key 'normal 'global
    (kbd "<leader> e") 'eshell))

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
;; 13. Setup Standard Bookmarks
;; ==========================================

(require 'bookmark)

;; Automatically save bookmarks to your bookmark file whenever one is made/changed
(setq bookmark-save-flag nil)

;; -- Evil Keybindings for Bookmarks --
;; We will use "<leader> b" as the prefix for all Bookmark commands.

;; <leader> b l: Open the standard Bookmark Menu (bmenu)
(evil-define-key 'normal 'global (kbd "<leader> b l") 'bookmark-bmenu-list)

;; <leader> b s: Set/Create a standard bookmark at your current cursor position
(evil-define-key 'normal 'global (kbd "<leader> b s") 'bookmark-set)

;; <leader> b j: Jump to a bookmark instantly via the minibuffer
(evil-define-key 'normal 'global (kbd "<leader> b j") 'bookmark-jump)

;; ==========================================
;; BOOKMARK BMENU EVIL INTEGRATION
;; ==========================================

;; Start the standard bookmark menu in Emacs state. 
;; This prevents Evil's normal mode from overriding the menu keys.
(evil-set-initial-state 'bookmark-bmenu-mode 'emacs)

;; But we still want Vim-style navigation! 
;; We will map 'j' and 'k' to move up and down, and 'ESC' to close the menu.
(add-hook 'bookmark-bmenu-mode-hook
	  (lambda ()
	    (define-key bookmark-bmenu-mode-map (kbd "j") 'next-line)
	    (define-key bookmark-bmenu-mode-map (kbd "k") 'previous-line)
	    (define-key bookmark-bmenu-mode-map (kbd "<escape>") 'quit-window)))

;; ==========================================
;; 14. Add lisp directory to Emacs' load path
;; ==========================================
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;; ==========================================
;; 15. load your custom speed dial system
;; ==========================================
(require 'my-speed-dial)
