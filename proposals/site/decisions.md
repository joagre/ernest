# Decisions

What is decided, tersely. `site.md` and `documents.md` argue; this file
records. A decision changes here, with its date.

## The docroot, 2026-10-13

The site's files as served.

    /                               the homepage
    /404.html                       any unmatched path, served with HTTP 404
    /favicon.ico
    /robots.txt
    /sitemap.xml
    /why/                           but_why.md
    /features/                      features.md
    /tour/                          contents
    /tour/<n>.html                  lesson n, with previous and next
    /guide/                         contents
    /guide/<n>.html                 chapter n
    /deployment/                    guide/deployment.md
    /report/                        contents of the three files
    /report/language.html           §0 to §10, Appendices A, B and F
    /report/toolchain.html          §11, Appendices C and H
    /report/library.html            Appendices D, E and G
    /man/                           contents
    /man/stdlib/                    contents
    /man/stdlib/<module>.html
    /man/libs/                      contents
    /man/libs/<name>/               contents, a line per module
    /man/libs/<name>/<module>.html
    /shell/                         the full-page shell
    /install/
    /changes/
    /map/                           documents.md's table
    /diagnostics/                   test/diagnostics.md
    /assets/css/                    site.css, xterm's stylesheet
    /assets/js/                     xterm.js, its fit addon, the session client
    /assets/img/                    ernest-light.svg, ernest-dark.svg, icons/

- A report page is one of the report's files, whole. A citation's first
  number or letter names its page.
- A chapter or a lesson is addressed by its number, as a citation names it.
- Every contents page is generated, from the headings or from `libs/*/`.
  No symlink, and no page at two addresses.
- The `/man/` pages are rendered from `man/`'s Markdown, which `make man`
  writes. The site calls them Library.
- The docroot holds the pages served: the static pages written by hand,
  beside the ones generated from Markdown. The templates and their README are
  the generator's input and stand outside it, in `templates/`.
- A link names a directory by its own form, `/guide/`, never
  `/guide/index.html`.
- The server serves a directory's `index.html` without a redirect. It
  redirects only a directory named without its slash, `/report` to `/report/`.
- No path holds a version: the site shows one version.

## Anchors, 2026-10-13

- An anchor is the citation's own text without its `§`: `#6.5`, `#E.17`, and
  `#4.2` in the guide. A chapter's is its number or letter: `#6`, `#E`.
- A declaration's anchor is its qualified name as `man/`'s heading writes it:
  `#List.removeAt`, `#Address.call`, `#spawn`. An operator stays as written.
- Only numbered headings and declarations have anchors. No anchor is made from
  a heading's words.
- A citation becomes a link to its anchor, its page found as the documents test
  finds it: "§6.5" is `/report/language.html#6.5`, "Appendix E.17"
  `/report/library.html#E.17`, "guide §4.2" `/guide/4.html#4.2`, `List.sort`
  `/man/stdlib/list.html#List.sort`.

## The homepage, 2026-10-13

- Its rows are four doors, in this order, each with its question: Try, "let me
  see it run", the shell's entry with Start; Tour, "show me the language";
  Guide, "help me write programs"; Report, "tell me the rules".
- Why is the link ending the introduction's paragraph, "the whole argument".
- Library and Install are in the header. Deployment is reached from Install,
  from the guide's running chapter and from Why's code by content.
