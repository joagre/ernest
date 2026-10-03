# Ernest logo assets

The Ernest README logo is supplied in separate light- and dark-theme variants.
You do **not** need to know which background a visitor uses: the browser can
select the appropriate asset with `prefers-color-scheme`.

```html
<picture>
  <source media="(prefers-color-scheme: dark)"
          srcset="assets/ernest-dark.svg">
  <source media="(prefers-color-scheme: light)"
          srcset="assets/ernest-light.svg">
  <img src="assets/ernest-light.svg" alt="Ernest" width="50%">
</picture>
```

## Files

- `assets/ernest-light.svg` — full logo for light backgrounds; dark wordmark.
- `assets/ernest-dark.svg` — full logo for dark backgrounds; cream wordmark and
  lifted charcoal details so the stoat's tail tip, feet and face remain visible.
- `assets/ernest-mark.svg` — standalone stoat mark with a middle charcoal chosen
  to remain usable on both light and dark backgrounds.
- `assets/ernest-mark-512.png` — 512 px raster mark for services that require PNG.
- `assets/ernest-social-preview.png` — 1280 × 640 GitHub social preview, no slogan.

The two full SVG logos use the same stoat geometry and layout. Only colors needed
for contrast change between themes.
