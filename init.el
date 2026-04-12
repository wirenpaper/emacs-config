;; -*- lexical-binding: t; -*-
(when (boundp 'native-comp-async-report-warnings-errors)
  (setq native-comp-async-report-warnings-errors nil))
;; Maximize memory for insanely fast startup
(setq gc-cons-threshold (* 100 1024 1024)) ;; 100 MB

;; ==========================================
;; 0. Emacs Core & Custom UI Settings
;; ==========================================
(server-start)

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
(declare-function pdf-info-running-p "pdf-info")
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
	evil-want-C-u-scroll t
    	evil-undo-system 'undo-redo)
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

;; Start Emacs in true full-screen mode (covers the bottom taskbar)
(add-to-list 'default-frame-alist '(fullscreen . fullboth))

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

(defvar my/font-typewriter-name "CMU Typewriter Text")
(defvar my/font-retro-name "AcPlus IBM VGA 8x16:pixelsize=32:antialias=true:autohint=false")

(defvar my/font-arabic-name "Scheherazade New")
(defvar my/font-symbol-name (seq-find (lambda (f) (string-match-p "JetBrains\\|Hack" f)) 
                                      (font-family-list)))

(defun my/setup-font-fallbacks ()
  "Ensure Arabic and Symbols are locked in,
   completely unaffected by the English font."
  
  ;; 1. PURGE EMACS MEMORY: Destroy all relative scaling logic.
  (setq face-font-rescale-alist nil)

  ;; 2. Arabic: The Absolute Pixel Lock (not quite)
  (when (member my/font-arabic-name (font-family-list))
    (set-fontset-font t 'arabic 
                      (font-spec :family my/font-arabic-name 
                                 :size 36         ;; Integer = EXACT pixels (ignores DPI)
                                 :weight 'bold))) ;; Lock thickness

  ;; 3. Symbols
  (when my/font-symbol-name
    (let ((sym-spec (font-spec :family my/font-symbol-name 
                               :weight 'normal)))
      (set-fontset-font t '(#x2500 . #x25FF) sym-spec nil 'prepend)
      (set-fontset-font t '(#x2600 . #x26FF) sym-spec nil 'prepend)
      (set-fontset-font t '(#xE000 . #xF8FF) sym-spec nil 'prepend)

      (make-face 'my-jj-symbol-face)
      (set-face-attribute 'my-jj-symbol-face nil :font sym-spec)

      (unless standard-display-table
        (setq standard-display-table (make-display-table)))

      (dolist (char '(?○ ?● ?◆ ?◇))
        (aset standard-display-table char 
              (vector (make-glyph-code char 'my-jj-symbol-face)))))))

(defun my/font-typewriter ()
  "Switch to CMU Typewriter (Semi-Bold)."
  (interactive)
  (set-face-attribute 'default nil 
                      :font my/font-typewriter-name 
                      :weight 'semi-bold 
                      :height 200)
  (my/setup-font-fallbacks)
  (clear-face-cache t)
  (message "Font: CMU Typewriter Text (Semi-Bold)"))

(defun my/font-retro ()
  "Switch to IBM VGA (Normal weight, Xft spec)."
  (interactive)
  (set-face-attribute 'default nil 
                      :font my/font-retro-name 
                      :weight 'normal)
  (my/setup-font-fallbacks)
  (clear-face-cache t)
  (message "Font: AcPlus IBM VGA 8x16 (Retro)"))

;; 1. Apply Typewriter as the default on startup
(my/font-typewriter)

;; 2. Bind the Evil Ex commands (:typewriter and :retro)
(with-eval-after-load 'evil
  (evil-ex-define-cmd "vintage" 'my/font-typewriter)
  (evil-ex-define-cmd "oldschool" 'my/font-retro))

;; ==========================================
;; Fix RTL/Arabic Cursor Movement in Evil Mode
;; ==========================================

(setq visual-order-cursor-movement t)

(with-eval-after-load 'evil
  ;; 1. Define L as an official Evil motion so the visual highlight box draws correctly
  (evil-define-motion my/evil-right-char (count)
    "Visual-order right movement that strictly respects Vim line boundaries."
    :type exclusive
    (let ((count (or count 1)))
      (dotimes (_ count)
        (let ((prev (point))
              (prev-bol (line-beginning-position)))
          (right-char 1)
          ;; If the line-beginning changed, we stepped to a new line. Snap back!
          (when (/= (line-beginning-position) prev-bol)
            (goto-char prev)
            (user-error "End of line"))))))

  ;; 2. Define H as an official Evil motion
  (evil-define-motion my/evil-left-char (count)
    "Visual-order left movement that strictly respects Vim line boundaries."
    :type exclusive
    (let ((count (or count 1)))
      (dotimes (_ count)
        (let ((prev (point))
              (prev-bol (line-beginning-position)))
          (left-char 1)
          (when (/= (line-beginning-position) prev-bol)
            (goto-char prev)
            (user-error "Beginning of line"))))))

  ;; 3. Bind them to the Evil motion map
  (define-key evil-motion-state-map (kbd "<left>") 'my/evil-left-char)
  (define-key evil-motion-state-map (kbd "<right>") 'my/evil-right-char)
  (define-key evil-motion-state-map (kbd "h") 'my/evil-left-char)
  (define-key evil-motion-state-map (kbd "l") 'my/evil-right-char))

;; ==========================================
;; Fix Visual Region Spilling (Vim Rendering)
;; ==========================================

(declare-function face-remap-remove-relative "face-remap")

(defvar-local my/evil-visual-extend-state 'unknown)
(defvar-local my/evil-region-remap-cookie nil)

(defun my/fix-visual-region-extension ()
  "Stop extending region face to the edge of the screen in any visual mode."
  (when (fboundp 'evil-visual-state-p)
    ;; If we are in ANY visual state (v, V, or C-v), turn off screen extension
    (let ((desired-state (if (evil-visual-state-p) 'no-extend 'extend)))
      (unless (eq desired-state my/evil-visual-extend-state)
        (setq my/evil-visual-extend-state desired-state)
        
        ;; Remove old face modification
        (when my/evil-region-remap-cookie
          (face-remap-remove-relative my/evil-region-remap-cookie)
          (setq my/evil-region-remap-cookie nil))
        
        ;; Apply new face modification (disable extension)
        (when (eq desired-state 'no-extend)
          (setq my/evil-region-remap-cookie
                (face-remap-add-relative 'region :extend nil)))))))

(add-hook 'post-command-hook #'my/fix-visual-region-extension)

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

;;(setq display-line-numbers-type 'relative)
;;(global-display-line-numbers-mode 1)
;;
;;(dolist (mode '(eshell-mode-hook
;;                eat-mode-hook
;;                term-mode-hook
;;                shell-mode-hook))
;;  (add-hook mode (lambda () (display-line-numbers-mode 0))))

;; ==========================================
;; Remove bar (Terminal Only)
;; ==========================================
(unless (display-graphic-p)
  (setq-default mode-line-format nil))

;; ==========================================
;; Calculate Location (Terminal Only)
;; ==========================================
(defvar my-last-ruler-message nil
  "Store the last position message to prevent overwriting active messages.")

(defun my-show-position-echo ()
  "Show position in the bottom right, yielding to other messages for performance."
  (unless (active-minibuffer-window)
    (let ((msg (current-message)))
      
      ;; FAST PATH: Only do the heavy math if the echo area is empty 
      ;; OR if it's currently displaying our own ruler.
      (when (or (not msg) 
                (equal msg my-last-ruler-message))
        
        (let* ((raw-line (line-number-at-pos))
               (raw-total (line-number-at-pos (point-max)))
               (total-lines (if (and (> raw-total 1) 
                                     (eq ?\n (char-before (point-max))))
                                (- raw-total 1)
                              raw-total))
               (line (min raw-line total-lines))
               (pct (if (> total-lines 0) (floor (* 100.0 line) total-lines) 0))
               
               (info-str (format "Line %d of %d --%d%%--" line total-lines pct))
               (width (window-width (minibuffer-window)))
               (padding (- width (string-width info-str) 1)))
          
          (when (>= padding 0)
            (let ((message-log-max nil)) 
              (setq my-last-ruler-message (concat (make-string padding ?\s) info-str))
              (message "%s" my-last-ruler-message))))))))

;; ONLY attach it to the post-command hook if we are in the terminal (-nw)
(unless (display-graphic-p)
  (add-hook 'post-command-hook #'my-show-position-echo))

;; ==========================================
;; Reload / Compile Config Functions
;; ==========================================
(defun my/reload-config ()
  "Reload your Emacs init.el file instantly."
  (interactive)
  (load-file user-init-file)
  (message "Config successfully reloaded!"))

(with-eval-after-load 'evil
  (evil-define-key 'normal 'global (kbd "<leader> h r r") 'my/reload-config))

(defun my/compile-config ()
  "Compile all config files to Machine Code (if supported)."
  (interactive)
  (let ((speed-dial (expand-file-name "lisp/my-speed-dial.el" user-emacs-directory))
        (theme      (expand-file-name "local-theme.el" user-emacs-directory))
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

    ;; 2. Compile local-theme.el
    (when (file-exists-p theme)
      (if use-native
          (native-compile theme)
        (byte-compile-file theme)))
      
    ;; 3. Compile init.el
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

(defun eshell/vi (&rest files)
  "Alias the vi command to `find-file' in Eshell. Opens files directly in Emacs."
  (if files
      (mapc #'find-file files)
    (message "Usage: vi <filename>")))

(defun my/eshell-clear-buffer ()
  "Instantly clear the Eshell buffer, like `clear' in bash."
  (interactive)
  (let ((inhibit-read-only t))
    (erase-buffer)
    (eshell-send-input)))

(add-hook 'eshell-mode-hook
          (lambda ()
            (local-set-key (kbd "C-l") 'my/eshell-clear-buffer)))

;; Bind Alt-j and Alt-k to navigate history in Eshell's insert mode
(with-eval-after-load 'esh-mode
  (with-eval-after-load 'evil
    (evil-define-key 'insert eshell-mode-map
      (kbd "M-k") 'eshell-previous-matching-input-from-input
      (kbd "M-j") 'eshell-next-matching-input-from-input)))

;; ==========================================
;; The Ultimate Zsh-like Completion Fix for Eshell + Corfu
;; ==========================================
(with-eval-after-load 'pcomplete
  (defun my/pcomplete-capf-fix-dir-space (orig-fn &rest args)
    "Ensure that `pcomplete' does not append a space after a directory."
    (let ((res (apply orig-fn args)))
      ;; Check if pcomplete returned a valid completion list
      (when (and res (listp res))
        (let ((exit-fn (plist-get (nthcdr 3 res) :exit-function)))
          (when exit-fn
            ;; Override the exit function
            (plist-put (nthcdr 3 res) :exit-function
                       (lambda (str status)
                         ;; If the string ends in a slash, it's a directory! Bind the 
                         ;; termination string to "" (no space). Otherwise, let it be a space.
                         (let ((pcomplete-termination-string
                                (if (and (stringp str) (string-suffix-p "/" str))
                                    ""
                                  (if (boundp 'pcomplete-termination-string)
                                      pcomplete-termination-string
                                    " "))))
                           (funcall exit-fn str status)))))))
      res))
  
  ;; Apply the wrapper to Eshell's completion engine
  (advice-add 'pcomplete-completions-at-point :around #'my/pcomplete-capf-fix-dir-space))

;; ---------------------------------------------------
;; Make Corfu popups work in Terminal (emacs -nw)
;; ---------------------------------------------------
(use-package corfu-terminal
  ;; Only load this if we are running in a terminal
  :unless (display-graphic-p)
  :config
  (corfu-terminal-mode +1))

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
  ;; Load our local theme file
  (let ((theme-file (expand-file-name "local-theme.el" user-emacs-directory)))
    (if (file-exists-p theme-file)
        (load theme-file)
      ;; Ultimate fallback just in case the file gets deleted somehow
      (load-theme 'ef-orange t)))

  ;; 1. Define custom completion specifically for ef-themes
  (evil-ex-define-argument-type ef-theme-name
    "Completion for ef-themes."
    :collection (lambda (string predicate action)
                  (let ((themes (mapcan (lambda (sym)
                                          (let ((name (symbol-name sym)))
                                            (if (string-prefix-p "ef-" name)
                                                (list name))))
                                        (custom-available-themes))))
                    (complete-with-action action themes string predicate))))

  ;; 2. Properly define the Evil command
  (evil-define-command evil-ef-theme-select (theme)
    "Select an ef-theme with Evil Ex command."
    (interactive "<a>")
    (let ((clean-theme (when theme (string-trim theme))))
      (if (and clean-theme (not (string-empty-p clean-theme)))
          (progn
            ;; Disable current themes to prevent color bleeding
            (mapc #'disable-theme custom-enabled-themes)
            ;; Load the requested theme cleanly
            (load-theme (intern clean-theme) t))
        ;; Fallback: if you just type `:colo` and hit Enter
        (call-interactively 'ef-themes-select))))

  ;; 3. Tell Evil Ex to use our custom completion list for this command
  (evil-set-command-property 'evil-ef-theme-select :ex-arg 'ef-theme-name)

  ;; 4. Bind the command to Vim's standard :colo and :colorscheme
  (evil-ex-define-cmd "colo" 'evil-ef-theme-select)
  (evil-ex-define-cmd "colorscheme" 'evil-ef-theme-select)

  ;; 5. Toggle keybind
  (evil-define-key 'normal 'global
    (kbd "<leader> t t") 'ef-themes-toggle))

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
(setq large-file-warning-threshold (* 80 1024 1024))

(use-package pdf-tools
  :mode ("\\.pdf\\'" . pdf-view-mode) 
  :hook ((pdf-view-mode . pdf-view-midnight-minor-mode)
         ;; FIX 1: Move this here! Now it registers before pdf-tools even loads.
         ;; Emacs will safely disable line numbers before the display engine crashes.
         (pdf-view-mode . (lambda () (display-line-numbers-mode -1))))
  :config
  
  ;; FIX 2: Add 't' (no-query). This prevents Emacs from deadlocking if it
  ;; needs to compile or start the epdfinfo server in the background.
  (pdf-tools-install t)
  
  ;; Turn on Emacs' built-in memory for where your cursor was
  (save-place-mode 1)
  
  ;; ==========================================
  ;; FIX: Dynamic PDF Colors on Theme Change
  ;; ==========================================
  (defun my/pdf-update-colors-on-theme-change (&rest _)
    "Update PDF midnight colors and refresh all open PDFs when theme changes."
    ;; We use a tiny timer because Emacs needs a split-second to actually 
    ;; apply the new theme's faces to the frame before we can read them.
    (run-with-timer 0.1 nil
      (lambda ()
        ;; 1. Update midnight colors to the newly loaded theme's default faces
        (setq pdf-view-midnight-colors (cons (face-foreground 'default)
                                             (face-background 'default)))
        ;; 2. Look through all open buffers for PDFs
        (dolist (buffer (buffer-list))
          (with-current-buffer buffer
            (when (eq major-mode 'pdf-view-mode)
              ;; Clear out the old cached images
              (when (fboundp 'pdf-info-invalidate-image-caches)
                (pdf-info-invalidate-image-caches))
              ;; Toggle midnight mode off and on to force a re-render
              (when pdf-view-midnight-minor-mode
                (pdf-view-midnight-minor-mode -1)
                (pdf-view-midnight-minor-mode 1))))))))

  ;; Attach our function to Emacs' load-theme command
  (advice-add 'load-theme :after #'my/pdf-update-colors-on-theme-change))

  ;; ==========================================
  ;; Show Full PDF Chapter Hierarchy (On-Demand)
  ;; ==========================================

(defun my/pdf-show-full-path ()
  "Show the full chapter hierarchy for the current PDF page.
Displays the calculated breadcrumb path in the echo area."
  (interactive)
    (if (not (and (eq major-mode 'pdf-view-mode)
                  (pdf-info-running-p)))
        (message "PDF server is not ready or not in a PDF buffer.")
      (let ((current-page (pdf-view-current-page))
            (outline (pdf-info-outline))
            (path (make-vector 20 nil))
            (best-path-list nil))
        (if (not outline)
            (message "No outline (table of contents) found for this PDF.")
          (dolist (node outline)
            (let* ((node-page (alist-get 'page node))
                   (node-depth (alist-get 'depth node))
                   (raw-title (alist-get 'title node))
                   (node-title (if (stringp raw-title)
                                   (replace-regexp-in-string "[ \t\n\r]+" " " raw-title)
                                 "")))
              (when (and (numberp node-page) 
                         (<= node-page current-page)
                         (numberp node-depth)
                         (> node-depth 0))
                (when (>= node-depth (length path))
                  (setq path (vconcat path (make-vector node-depth nil))))
                (aset path (1- node-depth) node-title)
                (let ((i node-depth))
                  (while (< i (length path))
                    (aset path i nil)
                    (setq i (1+ i))))
                (setq best-path-list (append path nil)))))
          
          (let ((best-title (when best-path-list
                              (mapconcat #'identity 
                                         (delq nil (mapcar (lambda (x) (and (stringp x) (not (string-empty-p x)) x)) 
                                                           best-path-list)) 
                                         " ➔ "))))
            (if (or (null best-title) (string-empty-p best-title))
                (message "Page %d is not inside any chapter." current-page)
              ;; Display in echo area (will expand multi-line automatically if long)
              (message best-title)))))))

;; Bind "O" to Outline and "P" to show the Full Path
(with-eval-after-load 'pdf-tools
  (with-eval-after-load 'evil
    (evil-define-key 'normal pdf-view-mode-map (kbd "O") #'pdf-outline)
    (evil-define-key 'normal pdf-view-mode-map (kbd "P") #'my/pdf-show-full-path)))

(use-package saveplace-pdf-view
  :after pdf-tools)

;; ==========================================
;; Allow Evil Leader (Spacebar) to work in PDFs
;; ==========================================
(with-eval-after-load 'pdf-tools
  ;; 1. Unbind Emacs' default scroll-down behavior for Spacebar
  (define-key pdf-view-mode-map (kbd "SPC") nil)
  
  (with-eval-after-load 'evil
    ;; 2. Explicitly tell Evil to let the global leader pass through in PDF mode
    (evil-define-key 'normal pdf-view-mode-map (kbd "SPC") nil)))

;; ==========================================
;; 11. C/C++ LSP & Autocompletion (Clangd)
;; ==========================================

;; Add this before your Corfu and Eglot configs
(use-package yasnippet
  :config
  (yas-global-mode 1))

;; Tell Emacs that .cppm files are C++ files so they get colors and LSP
(add-to-list 'auto-mode-alist '("\\.cppm\\'" . c++-mode))

;; 1. Setup Corfu for modern, lightweight auto-completion popups
(use-package corfu
  :custom
  (corfu-auto nil)              ;; NO automatic popup while typing
  (corfu-cycle t)               ;; Allow cycling from bottom back to top
  (corfu-quit-no-match t)
  (corfu-preselect 'first)      ;; Always highlight the first option automatically
  (corfu-preview-current nil)   ;; DO NOT inject or change text while cycling
  :init
  (global-corfu-mode)
  :config
  ;; ========================================================
  ;; THE "ENTER CYCLES DOWN" FIX
  ;; ========================================================
  ;; Emacs forcefully translates C-j to Enter. So we just make Enter cycle down!
  ;; Note: Because C-m IS physically Enter in a terminal, it will also cycle down.
  (define-key corfu-map (kbd "RET") #'corfu-next)
  (define-key corfu-map (kbd "<return>") #'corfu-next)
  (define-key corfu-map (kbd "C-j") #'corfu-next)
  (define-key corfu-map (kbd "C-m") #'corfu-next)

  ;; Cycle UP with C-k
  (define-key corfu-map (kbd "C-k") #'corfu-previous)
  (define-key corfu-map (kbd "<C-k>") #'corfu-previous)

  ;; ========================================================
  ;; THE NEW ACCEPT KEYS
  ;; ========================================================
  ;; Since Enter/C-m now cycles, we use TAB or C-l to accept the completion!
  (define-key corfu-map (kbd "TAB") #'corfu-insert)
  (define-key corfu-map (kbd "<tab>") #'corfu-insert)
  (define-key corfu-map (kbd "C-l") #'corfu-insert)

  ;; Cancel popup with C-[ or Escape without changing anything
  (define-key corfu-map (kbd "C-[") #'corfu-quit)
  (define-key corfu-map (kbd "<escape>") #'corfu-quit)

  ;; Trigger manual completion with C-n in Evil Insert Mode
  (with-eval-after-load 'evil
    (define-key evil-insert-state-map (kbd "C-n") #'completion-at-point)))

;; 2. Setup Eglot (The built-in LSP client)
(use-package eglot
  :ensure nil
  :hook
  ((c-mode . eglot-ensure)
   (c++-mode . eglot-ensure)
   (python-mode . eglot-ensure) ;; <-- ADDED: Start LSP automatically for Python
   ;; FIX: Prevent Eldoc from stacking hover documentation with function signatures
   (eglot-managed-mode . (lambda () (setq-local eldoc-documentation-strategy #'eldoc-documentation-default))))
  :custom
  ;; Ignore BOTH auto-formatting on type and inlay hints
  (eglot-ignored-server-capabilities '(:documentOnTypeFormattingProvider :inlayHintProvider))
  :config
  ;; Tell Eglot to completely ignore Flymake (turns off annoying linting)
  (add-to-list 'eglot-stay-out-of 'flymake)

  (setq eglot-events-buffer-config '(:size 0 :format short))
  (with-eval-after-load 'jsonrpc
    (fset #'jsonrpc--log-event #'ignore))

  ;; CRITICAL: Tell Clangd to enable C++ modules AND inject our Linux formatting rules directly!
  (add-to-list 'eglot-server-programs
               '((c++-mode c-mode)
                 . ("clangd"
                    "--experimental-modules-support"
                    "--fallback-style=BasedOnStyle: LLVM, IndentWidth: 8, TabWidth: 8, UseTab: Always, BreakBeforeBraces: Linux, IndentCaseLabels: false, BinPackArguments: false, BinPackParameters: false")))

  ;; PYTHON: Tell Eglot to use basedpyright
  (add-to-list 'eglot-server-programs
               '(python-mode . ("basedpyright-langserver" "--stdio")))

  (with-eval-after-load 'evil
    (evil-define-key 'normal eglot-mode-map
      (kbd "<leader> c r") 'eglot-rename
      (kbd "<leader> c a") 'eglot-code-actions
      (kbd "<leader> c f") 'eglot-format-buffer
      (kbd "g d") 'xref-find-definitions
      (kbd "g D") 'xref-find-references
      (kbd "K") 'eldoc)))

;; ==========================================
;; C/C++ Indentation & Formatting (Linux Style)
;; ==========================================

;; Tell the byte-compiler this variable exists to silence the warning
(defvar c-basic-offset)

;; Define a function to set C/C++ specific indentation
(defun my/c-c++-hook ()
  "Custom settings for C and C++ modes (Linus Torvalds style)."
  ;; Apply the built-in Linux kernel formatting style for Emacs typing
  (c-set-style "linux")
  
  ;; Linus mandates 8-column wide indents
  (setq c-basic-offset 8)
  (setq tab-width 8)
  
  ;; Linus strictly uses real tabs, not spaces
  (setq indent-tabs-mode t) 
  
  ;; Stop Emacs from fighting your manual line breaks
  (electric-indent-local-mode -1))

;; Add this function to the hooks for C and C++ modes
(add-hook 'c-mode-hook #'my/c-c++-hook)
(add-hook 'c++-mode-hook #'my/c-c++-hook)

;; ==========================================
;; Python Indentation & Formatting
;; ==========================================

;; Tell the byte-compiler this variable exists to silence the warning
(defvar python-indent-offset)

;; Define a function to set Python specific indentation (Spaces, no Tabs!)
(defun my/python-hook ()
  "Custom settings for Python mode."
  ;; Python strictly requires 4 spaces
  (setq python-indent-offset 4)
  (setq tab-width 4)
  
  ;; Force Emacs to use SPACES instead of tabs for Python!
  (setq indent-tabs-mode nil) 
  
  ;; Stop Emacs from fighting your manual line breaks
  (electric-indent-local-mode -1))

;; Add this function to the hook for Python mode
(add-hook 'python-mode-hook #'my/python-hook)

;; ==========================================
;; 12. Vim-like Scrolling and End-of-Buffer
;; ==========================================

;; 1. Stop Emacs from jumping half-a-page when hitting the bottom of the screen.
;; Setting this above 100 forces Emacs to only scroll 1 line at a time.
(setq scroll-conservatively 101)
(setq scroll-preserve-screen-position t)

;; 2. Show Vim-like markers in the left fringe for the "void" past the end of the file.
;; (In Vim this is the ~ character, in Emacs it's a graphical line).
(setq-default indicate-empty-lines t)

;; 3. Redefine 'G' to ignore the empty POSIX newline at the end of the file
(with-eval-after-load 'evil
  (evil-define-motion my/evil-goto-line-vim-behavior (count)
    "Go to the last non-empty line, Vim style."
    :type line
    :jump t
    (let ((col (current-column))
          (tgc temporary-goal-column))
      (if count
          (evil-goto-line count)
        (evil-goto-line))
      ;; If we landed in the empty void at the end, step back one line
      (when (and (eobp) (bolp) (not (bobp)))
        (forward-line -1)
        ;; Instead of snapping to the first letter, perfectly preserve the visual column!
        (move-to-column col)
        (setq temporary-goal-column tgc))))

  ;; Bind our new 'G' in Evil's motion state (so dG, yG, etc., all still work perfectly)
  (evil-define-key 'motion 'global (kbd "G") 'my/evil-goto-line-vim-behavior))
;; ==========================================
;; Stop 'j' from stepping into the EOF void
;; ==========================================

;; 1. Never add new lines automatically when holding 'j' at the bottom
(setq next-line-add-newlines nil)

;; 2. Tell Evil to bounce back if it steps onto the empty POSIX newline
(defun my/evil-avoid-eof-newline (orig-fun &rest args)
  "Prevent `j' from stepping into the empty POSIX newline at buffer end."
  (let ((tgc temporary-goal-column)
        (col (current-column)))
    (apply orig-fun args)
    (when (and (eobp) (bolp) (not (bobp)))
      ;; We stepped into the void! Undo it with raw Lisp so Evil doesn't corrupt the column
      (forward-line -1)
      ;; Warp back to the exact column you were on
      (move-to-column col)
      ;; Secretly restore the goal column so pressing 'k' remembers your original long line
      (setq temporary-goal-column tgc)
      (message "End of file"))))

;; Apply this rule to both standard 'j' and visual-line 'j'
(advice-add 'evil-next-line :around #'my/evil-avoid-eof-newline)
(advice-add 'evil-next-visual-line :around #'my/evil-avoid-eof-newline)
;; ==========================================
;; Rescue the cursor from the EOF void globally
;; ==========================================

(defun my/evil-rescue-from-eof-void ()
  "Rescue cursor if dropped into EOF void by commands like `dd' or `p'."
  (when (and (evil-normal-state-p)
             (eobp)
             (bolp)
             (not (bobp)))
    ;; Step back up to the actual text
    (forward-line -1)
    ;; Vim's default behavior when deleting the last line is to snap the 
    ;; cursor to the first non-blank character. This perfectly replicates it!
    (back-to-indentation)))

(add-hook 'post-command-hook #'my/evil-rescue-from-eof-void)

;; ==========================================
;; Rescue Visual State from the EOF void
;; ==========================================

(defun my/evil-visual-rescue-from-eof-void ()
  "Prevent visual selection from dragging into the empty EOF newline."
  (when (and (evil-visual-state-p)
             (eobp)            ;; We are at the absolute end of the buffer
             (bolp)            ;; We are at the beginning of a line
             (not (bobp)))     ;; We aren't in an entirely empty file
    
    ;; We stepped into the void newline during a visual selection.
    ;; 1. Step backward one character to get back onto the last real line
    (backward-char 1)
    
    ;; 2. Tell Evil to update the visual selection region to end here,
    ;; preventing the highlight from spilling into the void.
    (evil-visual-refresh)))

;; Attach it to the global command hook so it checks after every movement
(add-hook 'post-command-hook #'my/evil-visual-rescue-from-eof-void)

;; ==========================================
;; Close PDF Outline windows with ESC / C-[
;; ==========================================

(with-eval-after-load 'pdf-outline
  ;; When in the PDF Outline buffer, make Escape and Ctrl-[ close the window
  (evil-define-key 'normal pdf-outline-buffer-mode-map
    (kbd "<escape>") 'quit-window
    (kbd "C-[") 'quit-window))

;; ==========================================
;; Disable Vim jumping motions inside PDFs (Bulletproof)
;; ==========================================

(with-eval-after-load 'pdf-tools
  ;; 1. Disable gg and G on the mode map level
  (evil-define-key '(normal motion) pdf-view-mode-map
    (kbd "G")   'ignore
    (kbd "gg")  'ignore)
  
  ;; 2. C-o is stubborn and often hijacked by Evil's global jump list 
  ;; or evil-collection. We must forcefully disable it at the absolute 
  ;; local buffer level the moment the PDF opens.
  (add-hook 'pdf-view-mode-hook
            (lambda ()
              (evil-local-set-key 'normal (kbd "C-o") 'ignore)
              (evil-local-set-key 'motion (kbd "C-o") 'ignore))))

;; ==========================================
;; Make Emacs Auto-Saves act EXACTLY like Vim Swap Files
;; ==========================================

(require 'cl-lib)

;; ==========================================
;; 1. NUKE THE 1-SECOND PAUSE
;; ==========================================
(defun my/fast-after-find-file (orig-fn &rest args)
  "Bypass the hardcoded 1-second pause when opening files."
  (cl-letf (((symbol-function 'sit-for) #'ignore))
    (apply orig-fn args)))

(advice-add 'after-find-file :around #'my/fast-after-find-file)

;; ==========================================
;; 2. THE VIM-BALANCED AUTO-SAVE ENGINE & CURSOR TRACKER
;; ==========================================

;; 1. Match Vim's Exact Aggressiveness (Using Emacs' optimized C engine)
;; We throw away the custom timers. Emacs does this natively and much faster.
(setq auto-save-timeout 4)    ;; Vim's `updatetime` (4 seconds of idle time)
(setq auto-save-interval 200) ;; Vim's `updatecount` (200 keystrokes)

;; 2. Instant Vim Swap Creation on the First Keystroke
(defun my/instant-vim-swap-on-first-keystroke ()
  (when (and buffer-file-name (not buffer-read-only))
    (let ((inhibit-message t))
      (do-auto-save t t))))

(add-hook 'first-change-hook #'my/instant-vim-swap-on-first-keystroke)

;; 3. FIX: The Bulletproof Cursor Tracker (The Sidecar)
(defun my/save-point-during-auto-save (&rest _)
  "Save cursor position to a side-car file whenever Emacs auto-saves."
  (when (and buffer-file-name buffer-auto-save-file-name)
    (ignore-errors
      (write-region (number-to-string (point)) nil 
                    (concat buffer-auto-save-file-name ".point") nil 'silent))))

(add-hook 'auto-save-hook #'my/save-point-during-auto-save)
(advice-add 'do-auto-save :after #'my/save-point-during-auto-save)

;; 4. Ensure manual autosaves (like our first-change-hook) also track the cursor
(advice-add 'do-auto-save :after #'my/save-point-during-auto-save)

;; ==========================================
;; 3. QUIET VIM-STYLE RECOVERY (RESTORING TEXT & CRASH CURSOR)
;; ==========================================
(defun my/vim-style-quiet-recovery-prompt ()
  "Prompt for recovery in the minibuffer only, and restore exact crash cursor."
  (when (and buffer-file-name
             buffer-auto-save-file-name
             (file-exists-p buffer-auto-save-file-name)
             (file-newer-than-file-p buffer-auto-save-file-name buffer-file-name))
    (run-with-idle-timer 0.1 nil
                         (lambda (buf)
                           (when (buffer-live-p buf)
                             (with-current-buffer buf
                               (if (y-or-n-p "Recover from auto-save file? ")
                                   (let ((fallback-point (point))
                                         (point-file (concat buffer-auto-save-file-name ".point"))
                                         (crash-point nil))
                                     
                                     ;; 1. Try to read the exact cursor position from the side-car file
                                     (when (file-exists-p point-file)
                                       (with-temp-buffer
                                         (insert-file-contents point-file)
                                         (setq crash-point (string-to-number (buffer-string)))))
                                     
                                     ;; 2. Recover the text seamlessly
                                     (insert-file-contents buffer-auto-save-file-name nil nil nil t)
                                     
                                     ;; 3. Put the cursor EXACTLY where it was during the crash
                                     (if (and crash-point (> crash-point 0) (<= crash-point (point-max)))
                                         (goto-char crash-point)
                                       (goto-char fallback-point))
                                     
                                     (set-buffer-modified-p t)
                                     (message "Recovered successfully."))
                                 
                                 ;; If 'n' is pressed, trash the auto-save AND the side-car cursor file
                                 (when (y-or-n-p "Delete the orphaned auto-save file? ")
                                   (delete-file buffer-auto-save-file-name)
                                   (when (file-exists-p (concat buffer-auto-save-file-name ".point"))
                                     (delete-file (concat buffer-auto-save-file-name ".point")))
                                   (message "Auto-save file deleted."))))))
                         (current-buffer))))

(add-hook 'find-file-hook #'my/vim-style-quiet-recovery-prompt)

;; ==========================================
;; 4. UNBYPASSABLE CLEANUP & VIM :q / :q! GUARDRAILS
;; ==========================================
(defun my/assassinate-autosave ()
  "Deletes the auto-save file, the point file, and unlinks them."
  (when buffer-auto-save-file-name
    (when (file-exists-p buffer-auto-save-file-name)
      (ignore-errors (delete-file buffer-auto-save-file-name)))
    (when (file-exists-p (concat buffer-auto-save-file-name ".point"))
      (ignore-errors (delete-file (concat buffer-auto-save-file-name ".point"))))
    ;; CRUCIAL: Give Emacs amnesia
    (setq buffer-auto-save-file-name nil)))

;; Intercept Evil's :q and :q! directly
(defun my/evil-quit-cleanup (orig-fn &optional force)
  "Mimic Vim's :q and :q! by refusing to exit or prompt if files are unsaved."
  (let* ((windows-left (length (window-list)))
         (is-last-window (<= windows-left 1))
         ;; Find any modified files that are NOT the current buffer
         (other-modified-buffers
          (cl-remove-if-not
           (lambda (buf)
             (and (buffer-modified-p buf)
                  (buffer-file-name buf)
                  (not (eq buf (current-buffer)))))
           (buffer-list))))
    
    (if force
        ;; =====================
        ;; HANDLE :q! (FORCE QUIT)
        ;; =====================
        (progn
          ;; 1. VIM GUARDRAIL: Refuse to exit entirely if OTHER files have unsaved changes
          (when (and is-last-window other-modified-buffers)
            (let ((first-other (buffer-name (car other-modified-buffers))))
              (user-error "E162: No write since last change for buffer \"%s\". Use :qa! to discard all." first-other)))
          
          ;; 2. Safe to proceed: nuke the CURRENT buffer's autosave
          (my/assassinate-autosave)
          ;; 3. Trick Emacs into thinking this buffer is saved so it discards changes
          (set-buffer-modified-p nil)
          
          ;; 4. Execute the quit command silently (ignore background processes)
          (let ((confirm-kill-processes nil))
            (funcall orig-fn force)))
      
      ;; =====================
      ;; HANDLE :q (NORMAL QUIT)
      ;; =====================
      (progn
        ;; 1. If the CURRENT buffer is modified, instantly block :q (NO PROMPTS!)
        (when (and (buffer-modified-p) (buffer-file-name))
          (user-error "E37: No write since last change (add ! to override)"))
        
        ;; 2. If it's the last window and OTHER buffers are modified, block :q
        (when (and is-last-window other-modified-buffers)
          (let ((first-other (buffer-name (car other-modified-buffers))))
            (user-error "E162: No write since last change for buffer \"%s\"" first-other)))
        
        ;; 3. Safe to proceed! Execute quit with NO interactive conversations.
        ;; Everything is guaranteed saved at this point. We also squelch process warnings.
        (let ((confirm-kill-processes nil))
          (funcall orig-fn force))))))

(advice-add 'evil-quit :around #'my/evil-quit-cleanup)

;; General hooks for standard buffer kills
(defun my/unbypassable-buffer-cleanup (&optional buffer-or-name &rest _)
  (let ((buf (get-buffer (or buffer-or-name (current-buffer)))))
    (when (and buf (buffer-live-p buf))
      (with-current-buffer buf (my/assassinate-autosave)))))

(advice-add 'kill-buffer :before #'my/unbypassable-buffer-cleanup)

;; Catch-all for :qa! or normal exits
(advice-add 'kill-emacs :before (lambda (&rest _) 
                                  (dolist (buf (buffer-list))
                                    (with-current-buffer buf (my/assassinate-autosave)))))

;; ==========================================
;; 5. CENTRALIZED HOUSEKEEPING (NEOVIM STYLE)
;; ==========================================

;; Define the centralized directory (similar to ~/.local/state/nvim/swap/)
(defvar my/emacs-recovery-dir (expand-file-name "~/.local/state/emacs/recovery/"))

;; Create the directory if it doesn't exist
(unless (file-exists-p my/emacs-recovery-dir)
  (make-directory my/emacs-recovery-dir t))

;; 1. ROUTE BACKUP FILES (~) TO THE CENTRAL DIRECTORY
;; We keep backups enabled for safety, but out of sight!
(setq make-backup-files t
      vc-make-backup-files t) ; Even make backups for files in Git
(setq backup-directory-alist `(("." . ,my/emacs-recovery-dir)))

;; 2. ROUTE AUTO-SAVE FILES (#) TO THE CENTRAL DIRECTORY
;; The 't' at the end tells Emacs to flatten the path (turn / into !) 
;; so files with the same name from different projects don't overwrite each other.
(setq auto-save-file-name-transforms `((".*" ,my/emacs-recovery-dir t)))

;; 3. ROUTE LOCKFILES (.#) TO THE CENTRAL DIRECTORY (Emacs 28+)
;; Lockfiles prevent two Emacs instances from editing the same file simultaneously.
(setq create-lockfiles t)
(when (boundp 'lock-file-name-transforms)
  (setq lock-file-name-transforms `((".*" ,my/emacs-recovery-dir t))))

;; 4. CLEAN UP SIDECARS ON NORMAL SAVE (:w)
;; Because buffer-auto-save-file-name now points to ~/.local/state/emacs/recovery/...,
;; your .point files are ALREADY being created in the central directory automatically!
;; We still want to sweep them up so the recovery folder doesn't get massive over time.
(defun my/cleanup-sidecar-on-normal-save ()
  "Delete the .point side-car file when the buffer is properly saved."
  (when buffer-auto-save-file-name
    (let ((point-file (concat buffer-auto-save-file-name ".point")))
      (when (file-exists-p point-file)
        (ignore-errors (delete-file point-file))))))

(add-hook 'after-save-hook #'my/cleanup-sidecar-on-normal-save)

;; 5. CLEAN UP ON KILL-BUFFER (Just in case)
(defun my/cleanup-sidecar-on-kill ()
  (unless (buffer-modified-p)
    (my/cleanup-sidecar-on-normal-save)))

(add-hook 'kill-buffer-hook #'my/cleanup-sidecar-on-kill)

;; Force TRAMP to use the local centralized auto-save directory
(setq tramp-auto-save-directory my/emacs-recovery-dir)

;; ==========================================
;; 6. VSCode-Style Function/Symbol Outline
;; ==========================================

(use-package imenu-list
  :custom
  ;; Put the side-pane on the right (like VSCode) instead of the left
  (imenu-list-position 'right)
  ;; How wide the side pane should be
  (imenu-list-size 40)
  ;; Automatically focus the side-pane when you open it
  (imenu-list-focus-after-activation t)
  :config
  ;; Bind it to Leader + c + o (Code Outline)
  (with-eval-after-load 'evil
    (evil-define-key 'normal 'global (kbd "<leader> c o") 'imenu-list-smart-toggle)
    
    ;; Make Vim keys work smoothly inside the outline pane
    (evil-define-key 'normal imenu-list-major-mode-map
      (kbd "RET") 'imenu-list-ret-dwim
      (kbd "SPC") 'imenu-list-display-dwim
      (kbd "<escape>") 'imenu-list-quit-window
      (kbd "q") 'imenu-list-quit-window)))


;; ==========================================
;; 7. Disable Eglot coloring
;; ==========================================

;; 1. Disable Eglot's semantic highlighting from the language server
;;(with-eval-after-load 'eglot
;;  (add-to-list 'eglot-ignored-server-capabilities :semanticTokensProvider))
;;
;;;; 2. Strip colors from all syntax faces EXCEPT comments
;;(defun mystrip-syntax-colors (&rest _)
;;  "Make all code look like plain text, leaving only comments colored."
;;  (dolist (face '(font-lock-builtin-face
;;                  font-lock-constant-face
;;                  font-lock-doc-face
;;                  font-lock-function-name-face
;;                  font-lock-keyword-face
;;                  font-lock-string-face
;;                  font-lock-type-face
;;                  font-lock-variable-name-face
;;                  font-lock-preprocessor-face))
;;    (set-face-attribute face nil 
;;                        :foreground 'unspecified 
;;                        :background 'unspecified 
;;                        :weight 'unspecified 
;;                        :slant 'unspecified 
;;                        :inherit 'default)))
;;
;;;; Run it once during startup
;;(mystrip-syntax-colors)
;;
;;;; 3. Bulletproof: Re-apply the stripping immediately after any theme is loaded or toggled
;;(advice-add 'load-theme :after #'mystrip-syntax-colors)

;; =========================================
;; Avy: Jump to any place on the screen
;; =========================================
(use-package avy
  :ensure t
  :custom
  ;; How long it waits after your last keystroke before showing jump labels
  ;; 0.3 is usually the sweet spot for fast typists.
  (avy-timeout-seconds 0.1)
  
  ;; The keys used for the jump overlays (home row for speed)
  (avy-keys '(?a ?s ?d ?f ?j ?k ?l ?\;))
  
  :config
  (with-eval-after-load 'evil
    ;; Bind 'g s' in normal/motion states to trigger the jump
    (define-key evil-motion-state-map (kbd "g k") #'evil-avy-goto-char-timer)
    
    ;; Alternatively, since you use Space as your leader key, 
    ;; uncomment this if you prefer a leader binding like "SPC j":
    ;; (evil-define-key '(normal motion) 'global (kbd "<leader> j") #'evil-avy-goto-char-timer)
    ))

;; =========================================
;; make copy pasting xclip compliant
;; =========================================
(use-package xclip
  :ensure t
  :config
  (xclip-mode 1))

;;;; ==========================================
;;;; The "L" Programmatic Camouflage (Theme-Aware)
;;;; ==========================================
;;
;;;; 1. Variables to hold the overlay and the micro-timer locally per buffer
;;(defvar-local my-camouflage-overlay nil)
;;(defvar-local my-camouflage-timer nil)
;;
;;;; 2. The core logic that finds and paints the chopped line
;;(defun apply-camouflage-logic ()
;;  "Silently applies the camouflage logic to the chopped line at the bottom.
;;This targets the exact rendering artifact and masks it."
;;  (when (and (not (minibufferp)) (window-live-p (selected-window)))
;;    
;;    ;; Make sure the overlay exists
;;    (unless (overlayp my-camouflage-overlay)
;;      (setq my-camouflage-overlay (make-overlay 1 1))
;;      (overlay-put my-camouflage-overlay 'priority 9999))
;;
;;    ;; DYNAMIC THEME UPDATE: Always pull the current background color
;;    (let ((bg-color (or (face-background 'default) "black")))
;;      ;; Paint BOTH the text and the background with the theme's background color
;;      ;; This makes the chopped line gray, surviving theme changes
;;      (overlay-put my-camouflage-overlay 'face `(:foreground "gray" :background ,bg-color)))
;;
;;    ;; THE EXACT LOGIC FROM YOUR SUCCESSFUL MANUAL TEST
;;    (save-excursion
;;      (move-to-window-line -1)
;;      
;;      ;; Check if vertical-motion actually moved down
;;      (if (= (vertical-motion 1) 1)
;;          (let ((start-pos (point)))
;;            (end-of-visual-line)
;;            (unless (eobp) 
;;              (forward-char 1))
;;            
;;            ;; Apply the camouflage
;;            (move-overlay my-camouflage-overlay start-pos (point)))
;;        
;;        ;; Hide the overlay out of the way if at the end of the file
;;        (move-overlay my-camouflage-overlay 1 1)))))
;;
;;;; 3. The deferred trigger that waits for Emacs to finish drawing the screen
;;(defun trigger-camouflage-deferred (&rest _args)
;;  "Triggers the camouflage logic after a microscopic delay.
;;This gives the screen time to settle before painting the line."
;;  (when my-camouflage-timer
;;    (cancel-timer my-camouflage-timer))
;;  (setq my-camouflage-timer 
;;        (run-with-idle-timer 0.01 nil #'apply-camouflage-logic)))
;;
;;;; 4. Attach the deferred trigger to the two main Emacs lifecycle events
;;(add-hook 'post-command-hook #'trigger-camouflage-deferred)
;;(add-hook 'window-scroll-functions #'trigger-camouflage-deferred)
;;
;;;; ==========================================
;;;; Avy <-> Camouflage Compatibility Patch
;;;; ==========================================
;;
;;(require 'cl-lib)
;;
;;(defun my/avy-filter-camouflage-candidates (orig-fn candidates &rest args)
;;  "Intercepts Avy to remove jump targets
;;   that land inside the camouflaged chopped line."
;;  (let ((filtered-cands
;;         (cl-remove-if
;;          (lambda (cand)
;;            ;; Avy candidates look like (POS . WINDOW) or ((START . END) . WINDOW)
;;            (let* ((pos (if (consp (car cand)) (caar cand) (car cand)))
;;                   (win (cdr cand))
;;                   (buf (window-buffer win)))
;;              (with-current-buffer buf
;;                ;; If the candidate's position is inside the camouflage overlay, filter it out!
;;                (and (bound-and-true-p my-camouflage-overlay)
;;                     (overlayp my-camouflage-overlay)
;;                     (> (overlay-start my-camouflage-overlay) 1)
;;                     (>= pos (overlay-start my-camouflage-overlay))))))
;;          candidates)))
;;    ;; Pass the cleaned-up list back to Avy
;;    (apply orig-fn filtered-cands args)))
;;
;;;; Apply the patch to Avy's core rendering engine
;;(with-eval-after-load 'avy
;;  (advice-add 'avy-process :around #'my/avy-filter-camouflage-candidates))
