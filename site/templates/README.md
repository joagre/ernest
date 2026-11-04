# The site's templates

The token files the generator, [`tools/site.ern`](../../tools/site.ern), fills. Each is HTML written to be read, as the site's [decisions](../../docs/proposals/site/decisions.md) say in *The templates*, with tokens `{{name}}` where the generator puts its values. The pages it writes stand under `build/site/`, which `make site` writes from a release's tag; serve that directory to see them, `python3 -m http.server 8080 --directory build/site` or ernest-httpd, since a page opened as a file finds neither its stylesheet nor its icons. The mockup's pages, under `docs/proposals/site/root/mockup/`, are the look as it was settled by hand.

## The templates

| File | What it is | Its tokens |
|---|---|---|
| `base.html` | every page's head, header and footer, the page's own part in `main` | `title`, `description`, `stylesheet`, `script`, `icons`, `shell_path`, `lifetime`, `navigation_html`, `main_html`, `source_html`, `version`, `tag` |
| `page.html` | a chapter of the tour, the guide or the report, a module's page, Why, the questions, the deployment guide, Install, Releases, Projects and the 404 page | `layout`, `contents_html`, `book_html`, `heading_html`, `body_html`, `page_nav_html` |
| `toc.html` | a contents page: the tour's, the guide's, the report's and the library's | `heading_html`, `opening_html`, `entries_html` |
| `home.html` | the homepage, its text the site's own | `claims_html`, `example_html`, `icons` |
| `shell.html` | the shell's page, its numbers the server's configuration's | `lifetime`, `warning`, `memory`, `at_once`, `starts`, `within` |

## The fragments

A list's item takes its look from a fragment under `fragments/`, one file an item, and a list's own element where the page's template does not hold it.

| Fragment | What it is | Its tokens |
|---|---|---|
| `navigation.html`, `navigation-current.html` | a header's link, and the link to the room the page is in, marked current | `href`, `name` |
| `source.html` | the footer's part that names the page's source; a contents page and the 404 page take none | `tag`, `path`, `date` |
| `claim.html` | a homepage's claim, from Why | `anchor`, `name`, `sentence_html` |
| `book.html` | the book's title above a chapter's heading, linking to its contents | `href`, `book` |
| `contents.html` | a page's sidebar, its headings two levels deep | `summary`, `entries_html` |
| `declarations.html` | a module's page's sidebar, its declarations by their short names under the module's | `summary`, `entries_html` |
| `contents-entry.html` | a sidebar's heading | `anchor`, `label_html` |
| `contents-group.html` | a sidebar's heading with the headings under it | `anchor`, `label_html`, `entries_html` |
| `page-nav.html` | previous and next at a chapter's end | `label`, `previous_html`, `next_html` |
| `previous.html`, `next.html` | the chapter before, and the chapter after | `href`, `label_html`, `icons` |
| `chapters.html` | a contents page's list of chapters | `entries_html` |
| `chapter.html` | a contents page's chapter with its sections | `href`, `label_html`, `sections_html` |
| `sections.html` | a chapter's sections, which a chapter without any leaves out | `entries_html` |
| `section.html` | a section a line | `href`, `label_html` |
| `chapter-line.html` | a contents page's chapter with its own line, the tour's | `href`, `label_html`, `line_html` |
| `modules.html` | the library's group of modules under its name | `id`, `group_html`, `list_html` |
| `module-list.html` | a list of modules, a group's or a library's | `rows_html` |
| `module.html` | a module of a list, with the purpose its page opens with | `href`, `name`, `purpose_html` |
| `toolchain.html` | the library's line naming the toolchain's section | `line_html` |
| `revision.html` | a report file's revision, above its text | `revision_html` |
| `margin-line.html` | the guide's sections that cite a report section, under its heading | `links_html` |
| `project-list.html` | Projects' list of projects | `rows_html` |
| `project.html` | a project of the list: its icon, its name, in the text's face since it names a repository and no module, linked to its repository, and its purpose | `icon`, `href`, `name`, `purpose_html` |

A test, `test/ern_site_tests.erl`, holds each file here to the tokens its row lists, and the generator refuses to fill a template given a token it does not hold or not given one it does.

## How they are filled

- A file is cut at its tokens once and joined with the values; there is no templating language. A token that holds no value is written as nothing, and a line that holds only such a token is left out.
- A plain token is escaped. A `*_html` token takes only HTML the generator makes, as the decisions say; `layout` takes one of `doc-layout`, `doc-single`, where the page has no heading for a sidebar, and `error-page`, the 404 page's.
- `heading_html` is the page's `h1` whole, its anchor its number where it has one.
- A value of several lines stands alone on its token's line, and is indented as that line is, so that the page reads as its template does; a fragment's last line feed is dropped. A `<pre>`'s body is written as it is, from the line's start.
- A link names a directory by its own form, `/guide/`. `stylesheet`, `script` and `icons` are the files' names with their digests, `/assets/js/site.3f9a2c1e.js`, and the script finds the icons' name on its own element, `data-icons`, beside the server's `shell.path`, `data-shell-path`, where it opens the session's socket, and the session's lifetime as the shell's page says it, `data-lifetime`, which its notice at an expired session names.
- An icon is a `<use>` of its symbol in the icons' file, `{{icons}}#copy`. The generator gathers the file from `site/root/assets/img/icons/`, a symbol for each icon by its file's name, with the icon's `viewBox` and `fill` and its children as they are; the stylesheet's `.icon` gives its line and its size.
- A project's icon is its image under `site/root/assets/img/projects/`, named by the project, `ernest-epx.png`, which the root copies as it stands; `project.html` shows it at 40 × 40.
- Every internal link of a page, a template's among them, leads to a page, an anchor, an asset or an icon the site holds, or the generator refuses the site, naming the link and its page.
- No control the script works stands in a template: the panel, its buttons and a block's tools are the script's, and `data-shell` marks what the generator decided. A block that `site/unrunnable.md` lists, by its page's address and its first line, a bare shell cannot run, and has none.
