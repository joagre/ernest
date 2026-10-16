# Ernest visual identity

The **stoat** is Ernest's symbol. **Ernest** is the name. They are separate brand
elements and can appear independently; the combined horizontal logo is useful when
introducing the project, but it is not the only legitimate form.

## Which asset should I use?

| Asset | Purpose |
| --- | --- |
| `ernest-mark.svg` | **Primary symbol.** Use for documentation navigation, project badges, icons, and anywhere the project is already identified. Transparent background. |
| `ernest-combined-light.svg` | **Full logo on light backgrounds.** Use in a README introduction, landing-page hero, slides, and announcements. |
| `ernest-combined-dark.svg` | **Full logo on dark backgrounds.** Same use, adapted for dark themes. |
| `ernest-wordmark-light.svg` | **Name only on light backgrounds.** Use in text-led headers, footers, or layouts where the stoat is displayed elsewhere. |
| `ernest-wordmark-dark.svg` | **Name only on dark backgrounds.** Same use, adapted for dark themes. |
| `ernest-avatar-512.png` (also 256/64) | **Square transparent icon.** Use for GitHub organization avatar, profile images, and app launchers. |
| `ernest-icon-512.png` (also 256/64) | **Uncropped transparent stoat.** Use where a tall icon is appropriate. |
| `favicon.png` | **Small browser icon.** 512 × 512 transparent source; browsers may scale it down. |
| `ernest-social-light.png` | **Social preview on a light background.** 1280 × 640. |
| `ernest-social-dark.png` | **Social preview on a dark background.** 1280 × 640. |

## Default choices

- **GitHub README:** combined logo with automatic light/dark selection.
- **Website:** stoat in compact navigation; combined logo in the introductory section,
  or a standalone wordmark alongside the stoat if the layout calls for it.
- **Documentation:** stoat for the navigation mark; ordinary text for page headings.
- **GitHub organization avatar:** `ernest-avatar-512.png`.
- **GitHub social preview:** choose one of the two social PNGs in repository settings.
- **Favicon:** `favicon.png`, or export a dedicated small-size ICO from it if needed.

## GitHub README: automatic theme selection

```html
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/ernest-combined-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="assets/ernest-combined-light.svg">
  <img src="assets/ernest-combined-light.svg" alt="Ernest" width="520">
</picture>
```

Use the equivalent filenames for the standalone wordmarks if you want a text-only
treatment. The *light* suffix means **for a light background**, not a light-colored
logo.

## Usage rules

1. Keep the stoat's proportions, palette, and orientation intact.
2. Do not add gradients, shadows, outlines, slogans, or extra lettering.
3. Preserve clear space around the mark; avoid tight crops.
4. Use SVG wherever possible. Use PNG for platforms that require raster images.
5. Do not force the full horizontal logo into a square avatar or tiny favicon.
6. Check contrast on the actual background before publishing.

## Technical notes

- The stoat is real vector artwork in SVG, not a bitmap embedded in an SVG.
- The standalone and combined wordmarks use **live SVG text** in Arial/Helvetica
  fallback. They are not outlined; letter shapes can differ slightly across systems.
- PNGs are rendered exports of the supplied SVG artwork.
- The original stoat design is retained. This kit reorganizes the brand elements
  and adds formats and guidance; it is not a redesign of the animal.
