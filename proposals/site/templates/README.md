# Ernest HTML templates

A small, framework-free design proposal for ernest-lang.org. Open ../docroot/mockup/index.html or serve the docroot:

    python3 -m http.server 8080 --directory ../docroot

Then visit http://localhost:8080/mockup/. The flat demo filenames keep the bundle browsable; the production addresses are [decisions.md](../decisions.md)'s. There is no build step, CDN, font download, icon JavaScript or application framework. Documentation examples are illustrative, not a replacement for current project documentation. The browser shell is an explicitly disconnected layout preview.

## Files and templates

| Preview, in ../docroot/mockup/ | Page | Body template |
|---|---|---|
| index.html | the homepage | home.html |
| tour.html | a tour lesson | chapter.html |
| guide.html | a guide chapter | chapter.html |
| report.html | a report page | chapter.html |
| library.html | the library's contents | index.html |
| module.html | a module's page, man/'s Markdown | chapter.html |
| install.html | install | chapter.html |
| changes.html | the releases | index.html |
| shell.html | the shell | shell.html |
| 404.html | any unmatched path (HTTP 404) | error.html |

The tour's, the guide's and the report's contents pages still need a layout. The shared wrapper is base.html, with header.html and footer.html fragments. Templates are renderer-neutral token files, not an executable templating language. Files under ../docroot/assets/ are self-hosted.

## Rendering contract

1. Resolve path, document and layout; render Markdown with libs/markdown.
2. Render the body template, header and footer; insert them into base.html.
3. HTML-escape every plain-text token and attribute value. Restrict layout_class to known layout classes. URLs must be validated for their context. Do not use a global textual replace over already-rendered user content; bind template tokens from the original template.
4. Which fields take HTML is [decisions.md](../decisions.md)'s rule for `*_html` tokens. Escape code examples before placing them in pre/code.
5. Set asset_base to /assets in production. Set aria-current="page" on the active navigation link. Omit absent previous/next links; preserve stable chapter and declaration anchors. The preview sidebar contains same-page links; production may also include chapter links.
6. Supply a real version in the footer and documentation metadata. Status text must distinguish shipped features from proposals. Do not publish the preview labels or illustrative API pages as authoritative documentation.
7. Wrap wide Markdown tables in .table-scroll. Preserve heading levels, list structure and descriptive links.

## Visual decisions

The look is [decisions.md](../decisions.md)'s. The templates' own choices:

- A teal accent, compact navigation, and a 1120 px outer maximum width.
- A skip link and print rules.
- Native details elements for the contents and the supplementary controls, without JavaScript: open by default, collapsible on a phone.
- Lucide SVG icons, inlined in the rendered pages and supplied separately for reuse; used with text, a decorative one aria-hidden.

## Live shell integration

The shell's behavior is [decisions.md](../decisions.md)'s. The template reserves #terminal, three disabled control buttons and #session-state, where the connection's state is announced, and implements no fake shell. No runtime or session is created by this bundle.

## Licensing

Lucide source: https://github.com/lucide-icons/lucide
Icon license: ../docroot/assets/img/icons/LICENSE (ISC, with MIT notice for Feather-derived icons).
The supplied logo remains the user's asset. No new license is imposed on the template HTML/CSS.
