;; -*- lexical-binding: t; -*-
;; local-theme.el
;; This file is tracked by git but local changes are ignored via --skip-worktree!

(load-theme 'ef-light t)
;; -*- lexical-binding: t; -*-
;; local-theme.el
;; This file is tracked by git but local changes are ignored via --skip-worktree!

(if (display-graphic-p)
    (load-theme 'ef-light t)   ;; GUI gets the light theme
  (load-theme 'ef-cherie t))     ;; Terminal (-nw) gets the dark theme
