;; Local Variables:
;; byte-compile-warnings: (not undefined-functions)
;; End:

(require 'package)
(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")))

(package-initialize)

;; FIX: Force refresh if the archive is empty or stale
;; This prevents "Not found" errors when installing packages for the first time
(unless package-archive-contents
  (package-refresh-contents))

;; Bootstrap use-package
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
  
(require 'use-package)
(setq use-package-always-ensure t)

;; Set default font
(set-face-attribute 'default nil
  :family "Maple Mono NF"
  :height 180
  :weight 'regular)

(use-package ligature
  :config
  ;; Enable ligatures in all modes
  (ligature-set-ligatures t '(">>" ">>>" "<<" "<<" "{{" "}}" "{{--" "}}" "/*" "*/" "||" "|||" "&&" "&&&" "::" ":::" "??" "???" "++" "+++" "##" "###" "!!" "!!!" "//" "///" "==" "===" "!=" "!==" "<=" ">=" "=<<" "=>>" "->" "<-" "<->" "=>" "<=>" "<!--" "-->" "<#--" "<!---->" "~~" "~>" "<~" "<~>" "~~>" "<~~" "::=" "=:=" ":>" ":<" "<:" ">:" "<*" "<*>" "*>" "<|" "<|>" "|>" "<+" "<+>" "+>" "</" "</>" "/>" "###" "####" "...." "::" ":::" "++" "+++" "??" "???" "!!" "!!!" "||" "|||" "&&" "&&&" "--" "---" "==" "===" "!=" "!==" "<=" ">=" "=<<" "=>>" "->" "<-" "<->" "=>" "<=>" "<!--" "-->" "<#--" "<!---->" "~~" "~>" "<~" "<~>" "~~>" "<~~" "::=" "=:=" ":>" ":<" "<:" ">:" "<*" "<*>" "*>" "<|" "<|>" "|>" "<+" "<+>" "+>" "</" "</>" "/>"))
  (global-ligature-mode t))

;; Disable startup message
(setq inhibit-startup-message t)

;; Enable line numbers
(global-display-line-numbers-mode -1)

;; Highlight current line
(global-hl-line-mode -1)

;; Show column number
(setq column-number-mode t)

;; Disable toolbar and scrollbar
(tool-bar-mode -1)
(scroll-bar-mode -1)
(menu-bar-mode -1)

;; Disable cursor blinking
(setq blink-cursor-mode nil)

(use-package gruvbox-theme
  :init
  ;; avoid mixed faces if another theme was active
  (mapc #'disable-theme custom-enabled-themes)
  ;; load without confirmation
  (load-theme 'gruvbox-dark-hard t))

(use-package dashboard
  :config
  (setq dashboard-center-content t
        dashboard-vertically-center-content t)
  (dashboard-setup-startup-hook))

;; Enable Vertico.
(use-package vertico
  :init
  (vertico-mode))

;; Persist history over Emacs restarts. Vertico sorts by history position.
(use-package savehist
  :init
  (savehist-mode))

;; Emacs minibuffer configurations.
(use-package emacs
  :custom
  (context-menu-mode t)
  (enable-recursive-minibuffers t)
  (read-extended-command-predicate #'command-completion-default-include-p)
  (minibuffer-prompt-properties
   '(read-only t cursor-intangible t face minibuffer-prompt)))

(use-package vertico-posframe
  :config
  (vertico-posframe-mode 1))

(setq-default cursor-type 'bar)

(setq visible-bell t)

(add-hook 'text-mode-hook #'visual-line-mode)

;; Set default directory for org files
(setq org-directory "~/ORG/")
;; Using directory-files-recursively to find all org files in Roam folder
(setq org-agenda-files (directory-files-recursively "~/ORG/Roam/" "\\.org$"))

;; Enable org-babel languages
(org-babel-do-load-languages
 'org-babel-load-languages
 '((emacs-lisp . t)
   (python . t)))

;; Set keybinding for org-capture
(global-set-key (kbd "C-c l") 'org-store-link)
(global-set-key (kbd "C-c a") 'org-agenda)

(use-package org-modern)
(with-eval-after-load 'org (global-org-modern-mode))
(add-hook 'org-mode-hook #'org-indent-mode)
(setq
 org-auto-align-tags nil
 org-tags-column 0
 org-catch-invisible-edits 'show-and-error
 org-special-ctrl-a/e t
 org-insert-heading-respect-content t
 org-hide-emphasis-markers t

 org-startup-indented t
 org-indent-mode-turns-on-hiding-stars t
 org-modern-fold-stars '(("󰜵" . "󱥧"))
 org-modern-star 'fold
 org-ellipsis "…"
 )

;; Set variable font sizes for Org headings
(set-face-attribute 'org-level-1 nil :height 1.5)
(set-face-attribute 'org-level-2 nil :height 1.35)
(set-face-attribute 'org-level-3 nil :height 1.2)
(set-face-attribute 'org-level-4 nil :height 1.1)
(set-face-attribute 'org-level-5 nil :height 1.0)
(set-face-attribute 'org-level-6 nil :height 0.9)
(set-face-attribute 'org-level-7 nil :height 0.8)
(set-face-attribute 'org-level-8 nil :height 0.7)

(setq
 org-startup-with-inline-images t
 org-use-fast-todo-selection t
 org-todo-keywords
 '((sequence "TODO( t )" "CALL(l)" "MEETING(m)" "TEST(e)" "HOMEWORK(h)" "PROJECT(p)" "|" "DONE(d)" "CANCELLED(c)"))
 org-todo-keyword-faces
 '(("TODO" . (:background "#458588" :foreground "#fbf1c7" :weight bold))
   ("CALL" . (:background "#689d6a" :foreground "#fbf1c7" :weight bold))
   ("MEETING" . (:background "#d65d0e" :foreground "#fbf1c7" :weight bold))
   ("TEST" . (:background "#cc241d" :foreground "#fbf1c7" :weight bold))
   ("HOMEWORK" . (:background "#b16286" :foreground "#fbf1c7" :weight bold))
   ("PROJECT" . (:background "#d79921" :foreground "#fbf1c7" :weight bold))
   ("DONE" . (:background "#98971a" :foreground "#282828" :weight bold))
   ("CANCELLED" . (:background "#3c3836" :foreground "#928374" :weight bold :strike-through t))))

(use-package org-roam
  :init
  (setq org-roam-directory (file-truename "~/ORG/Roam/")
        org-roam-dailies-directory "journal/"
        org-roam-completion-everywhere t
        ;; IMPORTANT: Use built-in SQLite (Emacs 29+) to avoid C-compiler issues on NixOS
        org-roam-database-connector 'sqlite-builtin)
  
  :bind (("C-c n l" . org-roam-buffer-toggle)
         ("C-c n f" . org-roam-node-find)
         ("C-c n i" . org-roam-node-insert)
         ("C-c n d" . org-roam-dailies-map))
  
  :config
  (require 'org-roam-dailies)
  (setq org-roam-dailies-capture-templates
        '(("d" "default" entry
           "* %?\nTaken: %(format-time-string \"<%Y-%m-%d %H:%M>\")"
           :if-new (file+head "%<%Y-%m-%d>.org"
                              "#+title: %<%Y-%m-%d>\n"))))
  (org-roam-db-autosync-mode))

(use-package org-roam-ui
  :after org-roam
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

(use-package emacs
  :config
  ;; Tell Emacs where to look for the NixOS-installed grammars
  ;; (NixOS usually handles this via the wrapper, but this ensures safety)
  (setq treesit-font-lock-level 4)

  ;; Remap standard modes to their Tree-Sitter equivalents
  (setq major-mode-remap-alist
        '((bash-mode . bash-ts-mode)
          (css-mode . css-ts-mode)
          (python-mode . python-ts-mode)
          (javascript-mode . js-ts-mode)
          (json-mode . json-ts-mode)
          (yaml-mode . yaml-ts-mode)
          (c-mode . c-ts-mode)
          (c++-mode . c++-ts-mode))))

(defun my/reload-config ()
  "Tangle the current buffer and reload the user init file."
  (interactive)
  (if (derived-mode-p 'org-mode)
      (progn
        ;; Tangle the current buffer
        (let ((org-confirm-babel-evaluate nil))
          (org-babel-tangle))
        ;; Load the init file
        (load-file user-init-file)
        (message "Configuration reloaded successfully!"))
    (message "Not in an Org buffer!")))

;; Bind to C-c c r
(global-set-key (kbd "C-c c r") 'my/reload-config)

(defun my/tangle-on-save ()
  "Run org-babel-tangle if the current buffer is the config file."
  ;; Ensure this path matches your actual config file location!
  ;; You might need to change 'config.org' to whatever you named this file.
  (when (string-suffix-p ".org" (buffer-file-name)) 
    (let ((org-confirm-babel-evaluate nil))
      (org-babel-tangle))))

;; Uncomment to enable auto-tangle:
(add-hook 'after-save-hook #'my/tangle-on-save)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
