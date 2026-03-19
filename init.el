;; -*- lexical-binding: t; -*-
(when (boundp 'native-comp-async-report-warnings-errors)
  (setq native-comp-async-report-warnings-errors nil))
;; Maximize memory for insanely fast startup
(setq gc-cons-threshold (* 100 1024 1024)) ;; 100 MB

;; ==========================================
;; 0. Emacs Core & Custom UI Settings
;; ==========================================

;; Always prefer newer source files over stale byte-compiled files
(setq load-prefer-newer t)

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;; ==========================================
;; 1. Setup Package Archives & Use-Package
;; ==========================================
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)

;; Initialize package.el
(package-initialize)

;; Bootstrap use-package
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; CRITICAL: Tell the byte-compiler about use-package so it expands macros correctly
(eval-when-compile
  (require 'use-package))

;; ==========================================
;; Silence Byte-Compiler Warnings
;; ==========================================
;; Tell the compiler these functions will exist at runtime
(declare-function eshell-send-input "esh-mode")
(declare-function evil-org-set-key-theme "evil-org")
(declare-function evil-org-agenda-set-keys "evil-org-agenda")
;; Fix for PDF Tools compiler warnings:
(declare-function pdf-info-outline "pdf-info")
(declare-function image-mode-window-get "image-mode")
;; Fix for Eglot/JSONRPC warnings:
(declare-function jsonrpc--log-event "jsonrpc")

;; ==========================================
;; 2. Install and enable Evil & Evil-Collection
;; (MUST be loaded before my-speed-dial, as my-speed-dial requires Evil!)
;; ==========================================

(use-package evil
  :init
  (setq evil-want-integration t
	evil-want-keybinding nil
	evil-want-C-u-scroll t)
  :config
  (evil-mode 1)
  (evil-set-leader 'normal (kbd "SPC"))
  ;; Moved this global keybinding inside the Evil config
  (evil-define-key 'normal 'global (kbd "<leader> f f") 'find-file))

(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))

;; ==========================================
;; 3. Load Custom Lisp Path & My-Speed-Dial
;; ==========================================
;; We load this EARLY because later functions (like Eshell) rely on variables
;; defined inside my-speed-dial.el!
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(require 'my-speed-dial)

;; ==========================================
;; 4. General UI & System Settings
;; ==========================================

(menu-bar-mode -1)      ;; Hide the top menu bar
(tool-bar-mode -1)      ;; Hide the icon tool bar
(scroll-bar-mode -1)    ;; Hide the side scroll bars
;; (setq inhibit-startup-screen t) ;; Skip the splash screen

;; get rid of annoying bell sound
(setq ring-bell-function 'ignore)
(setq visible-bell t)

;; scrolling find section
(with-eval-after-load 'minibuffer
  
  (defun my/scroll-completions-down ()
    "Scroll the *Completions* window down without changing selection."
    (interactive)
    (let ((win (get-buffer-window "*Completions*")))
      (when win
        (with-selected-window win
          ;; In Emacs, 'scroll-up' moves the text up, meaning your view goes DOWN.
          (scroll-up 3)))))

  (defun my/scroll-completions-up ()
    "Scroll the *Completions* window up without changing selection."
    (interactive)
    (let ((win (get-buffer-window "*Completions*")))
      (when win
        (with-selected-window win
          ;; 'scroll-down' moves the text down, meaning your view goes UP.
          (scroll-down 3)))))

  ;; Enable built-in OSC 52 clipboard integration for modern terminals
  (setq xterm-extra-capabilities '(getSelection setSelection modifyOtherKeys))

  ;; Bind to M-j and M-k in the minibuffer
  (define-key minibuffer-local-map (kbd "M-j") 'my/scroll-completions-down)
  (define-key minibuffer-local-map (kbd "M-k") 'my/scroll-completions-up)
  
  (define-key minibuffer-local-completion-map (kbd "M-j") 'my/scroll-completions-down)
  (define-key minibuffer-local-completion-map (kbd "M-k") 'my/scroll-completions-up)
  
  (define-key minibuffer-local-filename-completion-map (kbd "M-j") 'my/scroll-completions-down)
  (define-key minibuffer-local-filename-completion-map (kbd "M-k") 'my/scroll-completions-up))

;; remember file position
(save-place-mode 1)

;; ==========================================
;; Typography / Font Settings
;; ==========================================

(let ((my-english-font "CMU Typewriter Text")
      (my-arabic-font  "Scheherazade New"))

  (when (member my-english-font (font-family-list))
    (set-face-attribute 'default nil :font my-english-font :height 200))

  (when (member my-arabic-font (font-family-list))
    (add-to-list 'face-font-rescale-alist (cons my-arabic-font 1.35))
    (set-fontset-font t 'arabic (font-spec :family my-arabic-font))))

;; ==========================================
;; Fix RTL/Arabic Cursor Movement in Evil Mode
;; ==========================================

(setq visual-order-cursor-movement t)
(with-eval-after-load 'evil
  (define-key evil-motion-state-map (kbd "<left>") 'left-char)
  (define-key evil-motion-state-map (kbd "<right>") 'right-char)
  (define-key evil-motion-state-map (kbd "h") 'left-char)
  (define-key evil-motion-state-map (kbd "l") 'right-char))

;; ==========================================
;; Make ESC quit prompts and cancel chords
;; ==========================================

(global-set-key (kbd "<escape>") 'keyboard-escape-quit)

(defun my/minibuffer-keyboard-quit ()
  "Abort recursive edit. In Delete Selection mode, this is undefined."
  (interactive)
  (abort-recursive-edit))

(define-key minibuffer-local-map            (kbd "<escape>") 'my/minibuffer-keyboard-quit)
(define-key minibuffer-local-ns-map         (kbd "<escape>") 'my/minibuffer-keyboard-quit)
(define-key minibuffer-local-completion-map (kbd "<escape>") 'my/minibuffer-keyboard-quit)
(define-key minibuffer-local-must-match-map (kbd "<escape>") 'my/minibuffer-keyboard-quit)
(define-key minibuffer-local-isearch-map    (kbd "<escape>") 'my/minibuffer-keyboard-quit)

(define-key ctl-x-map         (kbd "<escape>") 'keyboard-quit)
(define-key mode-specific-map (kbd "<escape>") 'keyboard-quit)
(define-key help-map          (kbd "<escape>") 'keyboard-quit)

;; ==========================================
;; Relative Line Numbers
;; ==========================================

(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)

(dolist (mode '(eshell-mode-hook
                eat-mode-hook
                term-mode-hook
                shell-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode 0))))

;; ==========================================
;; Reload Config Function
;; ==========================================
(defun my/reload-config ()
  "Reload your Emacs init.el file instantly."
  (interactive)
  (load-file user-init-file)
  (message "Config successfully reloaded!"))

(with-eval-after-load 'evil
  (evil-define-key 'normal 'global (kbd "<leader> h r r") 'my/reload-config))

(defun my/compile-config ()
  "Compile my-speed-dial.el first, then init.el to Machine Code (if supported)."
  (interactive)
  (let ((speed-dial (expand-file-name "lisp/my-speed-dial.el" user-emacs-directory))
        (init       (expand-file-name "init.el" user-emacs-directory))
        (use-native (and (fboundp 'native-comp-available-p) 
                         (native-comp-available-p))))
    
    (if use-native
        (message "🚀 Native Compilation is ON. Compiling to machine code...")
      (message "⚙️ Native Compilation not found. Falling back to byte-compilation..."))

    ;; 1. Compile my-speed-dial.el
    (when (file-exists-p speed-dial)
      (if use-native
          (native-compile speed-dial)
        (byte-compile-file speed-dial)))
      
    ;; 2. Compile init.el
    (when (file-exists-p init)
      (if use-native
          (native-compile init)
        (byte-compile-file init)))
      
    (message "✨ Config successfully compiled! Restart Emacs to experience the speed.")))

(with-eval-after-load 'evil
  (evil-define-key 'normal 'global (kbd "<leader> h c c") 'my/compile-config))

;; ==========================================
;; 5. Setup Org-Mode Ecosystem
;; ==========================================

(require 'org)

(use-package evil-org
  :hook (org-mode . evil-org-mode)
  :config
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys)
  (evil-org-set-key-theme '(navigation insert textobjects additional calendar)))

;; Set base directory first so other packages can use it
(defvar org-roam-directory (expand-file-name "~/org-roam"))

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

(use-package org-roam-ui
  :custom
  (org-roam-ui-sync-theme t)
  (org-roam-ui-follow t)
  (org-roam-ui-update-on-save t)
  (org-roam-ui-open-on-start t)
  :config
  (evil-define-key 'normal 'global
    (kbd "<leader> n g") 'org-roam-ui-mode))

;; Minibuffer SPC fix
(define-key minibuffer-local-completion-map (kbd "SPC") 'self-insert-command)

(use-package org-transclusion
  :config
  (evil-define-key 'normal 'global
    (kbd "<leader> n t") 'org-transclusion-mode
    (kbd "<leader> n a") 'org-transclusion-add))

(use-package org-download
  :hook ((dired-mode . org-download-enable)
         (org-mode . org-download-enable))
  :custom
  (org-download-image-dir (concat org-roam-directory "/images")))

(use-package org-capture
  :ensure nil
  :custom
  (org-default-notes-file (concat org-roam-directory "/inbox.org"))
  (org-capture-templates
   '(("i" "Inbox / Fleeting Note" entry (file org-default-notes-file)
      "* %?\n%U\n%i" :empty-lines 1)))
  :config
  (evil-define-key 'normal 'global
    (kbd "<leader> n c") 'org-capture))

(use-package org-appear
  :hook (org-mode . org-appear-mode)
  :custom
  (org-hide-emphasis-markers t)
  (org-appear-autoemphasis t)
  (org-appear-autolinks t)
  (org-appear-autosubmarkers t))

;; ==========================================
;; 6. Setup Eshell & Eat 
;; ==========================================

(defun my/eshell-in-dir (target-dir)
  "Helper function to open Eshell in TARGET-DIR, or cd into it if already running."
  (let ((default-directory target-dir))
    (eshell))
  (when (and (eq major-mode 'eshell-mode)
             (not (string= (file-name-as-directory (expand-file-name default-directory))
                           (file-name-as-directory (expand-file-name target-dir)))))
    (goto-char (point-max))
    (insert (format "cd '%s'" target-dir))
    (eshell-send-input)))

(defun my/eshell-workspace ()
  "Open Eshell. If a workspace is locked via my-speed-dial, open it there."
  (interactive)
  (let ((target-dir (if (and (boundp 'my/current-workspace-root)
                             my/current-workspace-root)
                        my/current-workspace-root
                      default-directory)))
    (my/eshell-in-dir target-dir)))

(defun my/eshell-current-file-dir ()
  "Open Eshell in the directory of the currently visited file/buffer."
  (interactive)
  (my/eshell-in-dir default-directory))

(use-package eat
  :hook ((eshell-load . eat-eshell-visual-command-mode)
         (eshell-load . eat-eshell-mode))
  :init
  (with-eval-after-load 'evil
    (evil-define-key 'normal 'global
      (kbd "<leader> e w") 'my/eshell-workspace
      (kbd "<leader> e f") 'my/eshell-current-file-dir))
  :config
  (evil-set-initial-state 'eat-mode 'emacs))

(defun my/eshell-clear-buffer ()
  "Instantly clear the Eshell buffer, like `clear' in bash."
  (interactive)
  (let ((inhibit-read-only t))
    (erase-buffer)
    (eshell-send-input)))

(add-hook 'eshell-mode-hook
          (lambda ()
            (local-set-key (kbd "C-l") 'my/eshell-clear-buffer)))

;; ==========================================
;; 7. Setup Standard Bookmarks
;; ==========================================

(require 'bookmark)

(setq bookmark-save-flag nil)
(add-hook 'kill-emacs-hook #'bookmark-save)

(with-eval-after-load 'evil
  (evil-define-key 'normal 'global (kbd "<leader> b l") 'bookmark-bmenu-list)
  (evil-define-key 'normal 'global (kbd "<leader> b s") 'bookmark-set)
  (evil-define-key 'normal 'global (kbd "<leader> b j") 'bookmark-jump))

(with-eval-after-load 'evil
  (evil-set-initial-state 'bookmark-bmenu-mode 'emacs))

(add-hook 'bookmark-bmenu-mode-hook
          (lambda ()
            (define-key bookmark-bmenu-mode-map (kbd "j") 'next-line)
            (define-key bookmark-bmenu-mode-map (kbd "k") 'previous-line)
            (define-key bookmark-bmenu-mode-map (kbd "<escape>") 'quit-window)))

;; ==========================================
;; 8. Install and Setup ef-themes
;; ==========================================

(use-package ef-themes
  :config
  (load-theme 'ef-summer t)
  (evil-define-key 'normal 'global
    (kbd "<leader> t s") 'ef-themes-select
    (kbd "<leader> t t") 'ef-themes-toggle))

;; Reset memory back to normal after startup so Emacs doesn't freeze during normal use
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 100 1024 1024)))) ;; 100 MB

;; ==========================================
;; 9. Elfeed & Elfeed-Org
;; ==========================================

(use-package elfeed
  :custom
  (elfeed-use-curl t)
  (elfeed-search-filter "@6-months-ago ")
  
  :config
  ;; ----------------------------------------------------
  ;; 🎬 THE "PLAY YOUTUBE IN MPV" FUNCTION
  ;; (Kept this here so you can still press 'v' to watch videos!)
  ;; ----------------------------------------------------
  (defun my/elfeed-play-with-mpv ()
    "Play the current Elfeed entry's video link in mpv."
    (interactive)
    (let ((link (if (derived-mode-p 'elfeed-search-mode)
                    (elfeed-entry-link (elfeed-search-selected :ignore-region))
                  (elfeed-entry-link elfeed-show-entry))))
      (if link
          (progn
            (message "🚀 Launching mpv for: %s" link)
            (start-process "elfeed-mpv" nil "mpv" link))
        (message "❌ No link found!"))))

  (with-eval-after-load 'evil
    (evil-define-key 'normal elfeed-search-mode-map (kbd "v") 'my/elfeed-play-with-mpv)
    (evil-define-key 'normal elfeed-show-mode-map (kbd "v") 'my/elfeed-play-with-mpv)))

;; Install and setup elfeed-org
(use-package elfeed-org
  :after elfeed
  :config
  ;; Initialize elfeed-org
  (elfeed-org)
  ;; Tell it where to find your "folders" file (we will create this in Step 2)
  (setq rmh-elfeed-org-files (list (expand-file-name "elfeed.org" user-emacs-directory))))

;; ==========================================
;; 10. PDF Tools (The ultimate PDF viewer)
;; ==========================================

;; Tell Emacs not to warn us about large files unless they are over 50MB
(setq large-file-warning-threshold (* 50 1024 1024))

(use-package pdf-tools
  ;; This line is the magic key: it forces Emacs to load this package for ALL .pdf files
  :mode ("\\.pdf\\'" . pdf-view-mode) 
  :hook (pdf-view-mode . pdf-view-midnight-minor-mode) ;; Optional: Dark mode for PDFs!
  :config
  ;; Install and initialize the package
  (pdf-tools-install)
  
  ;; FIX 1: Automatically turn off line numbers when reading a PDF to stop the warnings
  (add-hook 'pdf-view-mode-hook (lambda () (display-line-numbers-mode -1)))
  
  ;; FIX 2 (Part 1): Turn on Emacs' built-in memory for where your cursor was
  (save-place-mode 1))

;; FIX 2 (Part 2): The add-on that tells the memory mode how to handle PDFs
(use-package saveplace-pdf-view
  :after pdf-tools)

;;How to fix it if it ever breaks
;;If a system update ever breaks your PDF viewer, do not panic! You do not need to rewrite your config.
;;All you have to do is tell Emacs to rebuild the engine against your new system libraries:
;;Open Emacs.
;;Press Alt + x (or SPC :).
;;Type pdf-tools-install and hit Enter.

;; ==========================================
;; Show Current PDF Chapter Hierarchy (Breadcrumbs)
;; ==========================================

;; Local memory to store the chapter so we don't slow Emacs down
(defvar-local my-pdf-chapter-cache (cons 0 ""))

(defun my-pdf-update-header-line ()
  "Find current chapter hierarchy and show it in the top header line."
  (ignore-errors
    (when (eq major-mode 'pdf-view-mode)
      (let ((current-page (pdf-view-current-page)))
        ;; Only recalculate if we actually turned a page
        (unless (eq current-page (car my-pdf-chapter-cache))
          (let ((best-title "")
                ;; Ask pdf-tools server for the metadata
                (outline (pdf-info-outline))
                ;; Create a temporary array to hold the path (up to 20 levels deep)
                (path (make-vector 20 nil))
                (best-path-list nil)) 
            
            (when outline
              (dolist (node outline)
                (let* ((node-page (alist-get 'page node))
                       (node-depth (alist-get 'depth node))
                       (raw-title (alist-get 'title node))
                       ;; Clean up title (removes accidental newlines/tabs from PDF metadata)
                       (node-title (if (stringp raw-title)
                                       (replace-regexp-in-string "[ \t\n\r]+" " " raw-title)
                                     "")))
                  
                  ;; If we have passed (or are on) the page of this section
                  (when (and (numberp node-page) 
                             (<= node-page current-page)
                             (numberp node-depth)
                             (> node-depth 0))
                    
                    ;; Expand memory if the PDF has insanely deep nesting (> 20 levels)
                    (when (>= node-depth (length path))
                      (setq path (vconcat path (make-vector node-depth nil))))
                    
                    ;; Insert the title at its exact depth level
                    (aset path (1- node-depth) node-title)
                    
                    ;; Crucial: Clear out any deeper subsections left over from previous chapters
                    (let ((i node-depth))
                      (while (< i (length path))
                        (aset path i nil)
                        (setq i (1+ i))))
                    
                    ;; Take a snapshot of the valid path so far
                    (setq best-path-list (append path nil)))))
              
              ;; Clean up empty levels and combine them with " -> "
              (when best-path-list
                (setq best-title 
                      (mapconcat #'identity 
                                 (delq nil (mapcar (lambda (x) (and (stringp x) (not (string-empty-p x)) x)) 
                                                   best-path-list)) 
                                 " ➔ ")))) ;; Change " ➔ " to " -> " if your font doesn't support the arrow!
            
            ;; Save to memory cache
            (setq my-pdf-chapter-cache (cons current-page best-title))))
        
        ;; Update the top bar (header-line)
        (setq header-line-format
              (if (string-empty-p (cdr my-pdf-chapter-cache))
                  nil ;; Hide the bar if no metadata exists for this page
                (format "  📖 %s " (cdr my-pdf-chapter-cache))))))))

;; Attach this function to run automatically every time you flip a page
(add-hook 'pdf-view-mode-hook
          (lambda ()
            (add-hook 'pdf-view-after-change-page-hook #'my-pdf-update-header-line nil t)
            (my-pdf-update-header-line)))

;; Bind "O" in Evil normal mode to open the PDF outline
(with-eval-after-load 'pdf-tools
  (with-eval-after-load 'evil
    (evil-define-key 'normal pdf-view-mode-map (kbd "O") #'pdf-outline)))

;; ==========================================
;; 11. C/C++ LSP & Autocompletion (Clangd)
;; ==========================================

;; Tell Emacs that .cppm files are C++ files so they get colors and LSP
(add-to-list 'auto-mode-alist '("\\.cppm\\'" . c++-mode))

;; 1. Setup Corfu for modern, lightweight auto-completion popups
(use-package corfu
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.1)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-quit-no-match t)
  :init
  (global-corfu-mode)
  :config
  (with-eval-after-load 'evil
    (define-key corfu-map (kbd "C-j") 'corfu-next)
    (define-key corfu-map (kbd "C-k") 'corfu-previous)))

;; 2. Setup Eglot (The built-in LSP client)
(use-package eglot
  :ensure nil
  :hook ((c-mode . eglot-ensure)
         (c++-mode . eglot-ensure))
  :config
  (setq eglot-events-buffer-config '(:size 0 :format short)) 
  
  (with-eval-after-load 'jsonrpc
    (fset #'jsonrpc--log-event #'ignore))

  ;; CRITICAL: Tell Clangd to enable C++ modules!
  (add-to-list 'eglot-server-programs
               '((c++-mode c-mode)
                 "clangd"
                 "--experimental-modules-support"))
  
  (with-eval-after-load 'evil
    (evil-define-key 'normal eglot-mode-map
      (kbd "<leader> c r") 'eglot-rename
      (kbd "<leader> c a") 'eglot-code-actions
      (kbd "<leader> c f") 'eglot-format-buffer
      (kbd "g d") 'xref-find-definitions
      (kbd "g D") 'xref-find-references
      (kbd "K")   'eldoc)))

;; indentation
;; Use spaces for indentation
(setq-default indent-tabs-mode nil)

;; Set the width of tabs for display purposes (optional, as we use spaces)
(setq-default tab-width 4)

;; Tell the byte-compiler this variable exists to silence the warning
(defvar c-basic-offset)

;; Define a function to set C/C++ specific indentation
(defun my/c-c++-hook ()
  "Custom settings for C and C++ modes."
  (setq c-basic-offset 4)
  ;; Ensure spaces are used for indentation within this mode
  (setq indent-tabs-mode nil))

;; Add this function to the hooks for C and C++ modes
(add-hook 'c-mode-hook 'my/c-c++-hook)
(add-hook 'c++-mode-hook 'my/c-c++-hook)
