;; 1. Setup package archives (MELPA)
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; 2. Refresh contents if you haven't yet
(unless package-archive-contents
  (package-refresh-contents))

;; 3. Install and enable Evil
(unless (package-installed-p 'evil)
  (package-install 'evil))
(require 'evil)
(evil-mode 1)

;; 4. Install Bookmarks+ from GitHub
(unless (package-installed-p 'quelpa)
  (package-install 'quelpa))
(unless (package-installed-p 'bookmark+)
  (quelpa '(bookmark+ :fetcher github :repo "emacsmirror/bookmark-plus")))
(require 'bookmark+)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(bmkp-last-as-first-bookmark-file "/home/saifr/rnd/blog/jmp")
 '(package-selected-packages nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

(set-face-attribute 'default nil 
                    :font "CMU Typewriter Text" 
                    :height 200)

;; Set Space as leader key
(evil-set-leader 'normal (kbd "SPC"))

;; Bookmark keybindings under SPC b
(evil-define-key 'normal 'global
  (kbd "<leader>bb") 'bookmark-set          		; set a bookmark
  ;;(kbd "<leader>bj") 'bookmark-jump         		; jump to bookmark
  (kbd "<leader>bj") 'bmkp-jump-in-navlist         	; jump to bookmark
  (kbd "<leader>bl") 'bookmark-bmenu-list       	; open bookmark list
  (kbd "<leader>bd") 'bookmark-delete       		; delete a bookmark
  (kbd "<leader>bs") 'bookmark-save        		; save bookmarks to file
  (kbd "<leader>bf") 'bmkp-switch-bookmark-file-create  ; project files
  (kbd "<leader>bt") 'bmkp-add-tags			; bookmark tags
  (kbd "<leader>bT") 'bmkp-list-all-tags)		

(kbd "<leader>bt") 'bmkp-tag-a-file           ; tag a file
  (kbd "<leader>bT") 'bmkp-find-files-tagged-all ; find files by tag


(setq bookmark-save-flag 1)
(defun my/bookmark-set-filename ()
  (interactive)
  (bookmark-set (buffer-name)))

(evil-define-key 'normal 'global
  (kbd "<leader>bm") 'my/bookmark-set-filename)
