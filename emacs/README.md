# Installing the Emacs mode

`ernest-mode` edits `.ern` files, and needs Emacs 29 or later. What it does and what it leaves to you is [`docs/emacs_mode.md`](../docs/emacs_mode.md).

`make install` puts [`ernest-mode.el`](ernest-mode.el) in `share/emacs/site-lisp` under its prefix, which an Emacs built for that prefix has on its `load-path`. Another Emacs, and one that loads the mode from a checkout, is given the directory that holds it:

```elisp
(add-to-list 'load-path "~/src/ernest/emacs")
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

`ern` is looked for on `exec-path`, where an Emacs started from a desktop menu may not have the repository's `bin/`. This line names it:

```elisp
(setq ernest-format-command (expand-file-name "~/src/ernest/bin/ern"))
```
