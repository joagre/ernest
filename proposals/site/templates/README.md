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
| changes.html | changes | index.html |
| shell.html | the shell | shell.html |
| 404.html | any unmatched path (HTTP 404) | error.html |

The tour's, the guide's and the report's contents pages still need a layout. The shared wrapper is base.html, with header.html and footer.html fragments. Templates are renderer-neutral token files, not an executable templating language. Files under ../docroot/assets/ are self-hosted.

## Rendering contract

1. Resolve path, document and layout; render Markdown with libs/markdown.
2. Render the body template, header and footer; insert them into base.html.
3. HTML-escape every plain-text token and attribute value. Restrict layout_class to known layout classes. URLs must be validated for their context. Do not use a global textual replace over already-rendered user content; bind template tokens from the original template.
4. Only *_html fields receive trusted server-generated HTML. These include Markdown from reviewed site sources and navigation. Escape code examples before placing them in pre/code. If user Markdown is ever accepted, sanitise it separately.
5. Set asset_base to /assets in production. Set aria-current="page" on the active navigation link. Omit absent previous/next links; preserve stable chapter and declaration anchors. The preview sidebar contains same-page links; production may also include chapter links.
6. Supply a real version in the footer and documentation metadata. Status text must distinguish shipped features from proposals. Do not publish the preview labels or illustrative API pages as authoritative documentation.
7. Wrap wide Markdown tables in .table-scroll. Preserve heading levels, list structure and descriptive links.

## Visual decisions

- One dependency-free shared CSS stylesheet, with system fonts, compact navigation and a restrained teal link color.
- Automatic light/dark mode; keyboard focus and skip link; responsive layouts and print rules.
- 1120 px outer maximum width, narrower prose, wider code and terminal. The logo appears on the homepage at 230 px wide; other pages have a compact text home link.
- Supplied ernest-light.svg is unchanged. ernest-dark.svg is a provisional derived variant: dark outlines/text become pale. Replace it with the approved dark logo when available.
- Native details elements provide contents and supplementary controls without JavaScript. Contents remain open by default; mobile users can collapse them.
- Lucide SVG icons are inlined in the rendered preview and supplied separately for reuse. Use icons with text, and keep decorative SVGs aria-hidden. No icon library runtime is needed. No external fonts or decorative imagery are used.

## Live shell integration

The template reserves #terminal and three disabled control buttons. It deliberately implements no fake shell. Host xterm.js, its CSS, a fit addon and a small session client locally when implementing the real service.

Start creates an isolated server session and attaches a WebSocket to its pseudo-terminal. Fit the terminal on viewport/container resize and send rows/columns to the pseudo-terminal. Preserve the existing Terminal-based shell. Show connecting, running, disconnected, expired and unavailable states separately. Announce connection status in #session-state, not every terminal output byte. Never execute examples merely because they were selected.

Display configured server limits and remaining time. Stop destroys the session; Restart requires a deliberate action and destroys the old one. Disconnection and expiry must not be conflated. Container isolation, quotas, authentication/origin checks, session cleanup and WebSocket handling belong to your server implementation. No runtime or session is created by this bundle.

## Licensing

Lucide source: https://github.com/lucide-icons/lucide
Icon license: ../docroot/assets/img/icons/LICENSE (ISC, with MIT notice for Feather-derived icons).
The supplied logo remains the user's asset. No new license is imposed on the template HTML/CSS.
