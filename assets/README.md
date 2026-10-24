# The logos

This directory holds Ernest's logos, and this file says where each is used.

| File | What it is | Where it is used |
|---|---|---|
| `ernest-mark.svg` | the stoat alone | none yet; planned for the site's header beside the word "Ernest" (the plan's MVP 4.2) |
| `ernest-combined-light.svg` | the full logo, for a light background | the README, the release's README, `guide/language.md` and `guide/deployment.md`; planned for the site's homepage |
| `ernest-combined-dark.svg` | the full logo, for a dark background | the same places, in dark mode |
| `ernest-avatar-512.png` | the stoat, square, 512 × 512 | GitHub's organization avatar |
| `ernest-avatar-64.png` | the stoat, square, 64 × 64 | none yet; planned for the site's favicon |
| `ernest-social-light.png` | the full logo on a light background, 1280 × 640 | GitHub's social preview |

A Markdown page shows the full logo with this block, and the browser picks the file for its mode:

```html
<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="assets/ernest-combined-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="assets/ernest-combined-light.svg">
  <img src="assets/ernest-combined-light.svg" alt="Ernest" width="520">
</picture>
```

The suffix names the background: `-light` is for a light background, `-dark` for a dark one.

## Rules

1. Keep the stoat's proportions and palette intact.
2. Add nothing: no shadow, outline, gradient or text.
3. Use SVG wherever possible, and PNG only where a platform wants a raster image.
