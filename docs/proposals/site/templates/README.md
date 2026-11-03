# The site's templates

The token files the generator fills, `site.ern` in item 2. Each is HTML written to be read, as [decisions.md](../decisions.md)'s *The templates* says, with tokens `{{name}}` where the generator puts its values. The mockup's pages under `../root/mockup/` show what each produces; serve the root to see them, `python3 -m http.server 8080 --directory ../root` or ernest-httpd, since a page opened as a file shows no icons.

## The templates

| File | What it is | Its tokens |
|---|---|---|
| `base.html` | every page's head, header and footer, the page's own part in `main` | `title`, `description`, `stylesheet`, `script`, `icons`, `navigation_html`, `main_html`, `source_html`, `version`, `tag` |
| `page.html` | a chapter of the tour, the guide or the report, a module's page, Why, the questions, the deployment guide, Install, Releases and the 404 page | `layout`, `contents_html`, `book_html`, `heading_html`, `body_html`, `page_nav_html` |
| `toc.html` | a contents page: the tour's, the guide's, the report's and the library's | `heading`, `opening_html`, `entries_html` |
| `home.html` | the homepage, its text the site's own | `claims_html`, `example_html`, `icons` |
| `shell.html` | the shell's page, its numbers the server's configuration's | `lifetime`, `warning`, `memory`, `at_once`, `starts` |

## The fragments

A list's item takes its look from a fragment under `fragments/`, one file an item.

| Fragment | An item of | Its tokens |
|---|---|---|
| `navigation.html`, `navigation-current.html` | the header's links, the page's own marked current | `href`, `name` |
| `source.html` | the footer's part that names the page's source; a contents page and the 404 page take none | `tag`, `path`, `date` |
| `claim.html` | the homepage's claims, from Why | `anchor`, `name`, `sentence_html` |
| `book.html` | the book's title above a chapter's heading, linking to its contents | `href`, `book` |
| `contents.html`, `contents-entry.html`, `contents-group.html` | a page's sidebar, its headings two levels deep | `summary`, `entries_html`; `anchor`, `label_html` |
| `page-nav.html`, `previous.html`, `next.html` | previous and next at a chapter's end | `label`, `previous_html`, `next_html`; `href`, `label_html`, `icons` |
| `chapter.html`, `section.html` | a contents page's chapter with its sections a line each | `href`, `label_html`, `sections_html` |
| `chapter-line.html` | a contents page's chapter with its own line, the tour's | `href`, `label_html`, `line_html` |
| `modules.html`, `module.html` | the library's groups and their modules | `id`, `group`, `rows_html`; `href`, `name`, `purpose_html` |

## How they are filled

- A file is cut at its tokens once and joined with the values; there is no templating language. A token that holds no value is written as nothing.
- A plain token is escaped. A `*_html` token takes only HTML the generator makes, as the decisions say; `layout` takes one of `doc-layout` and `doc-single`.
- A value of several lines is indented as its token's line is, so that the page reads as its template does; a fragment's last line feed is dropped. A `<pre>`'s body is written as it is, from the line's start.
- A link names a directory by its own form, `/guide/`. `stylesheet`, `script` and `icons` are the files' names with their digests, `/assets/js/site.3f9a2c1e.js`.
- No control the script works stands in a template: the panel, its buttons and a block's tools are the script's, and `data-shell` marks what the generator decided.
