# Installing the Emacs mode

`ernest-mode` edits `.ern` files, and needs Emacs 29 or later. [`docs/design/emacs_mode.md`](../../docs/design/emacs_mode.md) says what it does.

`make install` puts `ernest-mode.el` in `share/emacs/site-lisp` under its prefix, which an Emacs built for that prefix has on its `load-path`. Another Emacs is given that directory, `PREFIX/share/emacs/site-lisp`, here for the default prefix, `/usr/local`:

```elisp
(add-to-list 'load-path "/usr/local/share/emacs/site-lisp")
```

An Emacs that loads the mode from a checkout is given the checkout's `editors/emacs`:

```elisp
(add-to-list 'load-path "~/src/ernest/editors/emacs")
```

These two lines in your init file load the mode when a `.ern` file is opened:

```elisp
(autoload 'ernest-mode "ernest-mode" "Major mode for Ernest." t)
(add-to-list 'auto-mode-alist '("\\.ern\\'" . ernest-mode))
```

This line lays out each Ernest buffer as it is saved, with `ern format`:

```elisp
(add-hook 'ernest-mode-hook #'ernest-format-on-save-mode)
```

`ern` is looked for on `exec-path`, where an Emacs started from a desktop menu may not have a checkout's `bin/`, nor an installation's where the prefix's `bin` is not on it. This line names it:

```elisp
(setq ernest-format-command (expand-file-name "~/src/ernest/bin/ern"))
```

The mode turns nothing on, so a tab pasted in, or a line past 100 characters, is shown only by what you enable. These lines show both:

```elisp
(add-hook 'ernest-mode-hook #'display-fill-column-indicator-mode)
(add-hook 'ernest-mode-hook
          (lambda ()
            (setq-local whitespace-style '(face tabs lines-tail)
                        whitespace-line-column nil)
            (whitespace-mode)))
```

The indicator stands at the mode's `fill-column`, 100, and `whitespace-line-column` nil makes `whitespace-mode` mark a line past it rather than past 80.
