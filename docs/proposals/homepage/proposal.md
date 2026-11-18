# ernest-lang.org: the homepage and the blocks' tools

What discussions on 2026-11-17 and 2026-11-18 chose for the site, stated as it is to be built. The reasons, and what was tried and set aside, are in [`reasons.md`](reasons.md).

The page was chosen on a mock made from the rehearsal of Ernest 0.10.0 at `https://ernest-lang.org:8443/`. Nothing here is built, and nothing here is authoritative.

## The homepage

The layout is the rehearsal's: the opening with the claims beside it, the example under both, then the three doors. The heading is the rehearsal's. What changes:

1. The opening is two paragraphs, with new text.
2. The example has no heading and no sentence of its own. It stands straight under the opening.
3. The example's two blocks take the columns above them: the counter the opening's, and the session the claims'.
4. Try it stands under the session, set to the right, its edge on the session's.
5. The counter's block shows Copy alone.
6. A sentence on the tour stands under the example, before the doors. It ends at the counter's right edge.
7. The first claim's sentence and the mailbox's are reworded.
8. Three spaces are tighter: above the heading, above the example, and around each claim.

### Its texts

The heading: "Start a process on another node, and its code goes with it".

The opening:

> The node is sent the code it lacks, and nothing of the program needs to be installed there first. Ernest is a functional language for concurrent programs, on the Erlang runtime. Why Ernest gives the whole argument.
>
> Below, a counter is typed into a shell and started on `foo`, a bare node beside it. Try it gives you that shell and a `foo` of your own, in your browser.

"Why Ernest" links to `/why/`.

The claims, under "What Ernest adds", are Why's first four, each its name and its first sentence:

- **Code travels.** Each function is known by a hash of its definition, not by the module it stands in, so it crosses to a node that lacks it, and a module keeps every version it has had.
- **The mailbox in the function's type.** A process's mailbox type is part of its function's type, so the compiler checks every send against the mailbox it reaches.
- The third and the fourth as Why has them.

Under the example: "The tour takes this counter further, and ends by updating its code while it runs, with its state intact." "Tour" links to `/tour/`.

### Its markup

The page's `main`, without the code's coloring and the doors' icons:

```html
<main id="main" class="wrap">
    <section class="home-intro" aria-labelledby="intro-title">
        <div class="opening">
            <h1 id="intro-title">Start a process on another node, and its code goes with it</h1>
            <p class="lead">The node is sent … <a href="/why/">Why Ernest</a> gives the whole argument.</p>
            <p class="lead">Below, a counter … in your browser.</p>
        </div>
        <div class="claims">
            <h2>What Ernest adds</h2>
            <ol>… four claims, each a link to its heading in Why …</ol>
        </div>
    </section>

    <section class="home-use" aria-label="A counter on another node">
        <div class="example">
            <pre class="code"><code>… the counter …</code></pre>
            <div class="session-column">
                <pre class="transcript" data-shell="paste"><code>… the session …</code></pre>
                <p class="run" data-shell="start"><a href="/shell/">Run it yourself in the shell</a></p>
            </div>
        </div>
        <p class="next">The <a href="/tour/">tour</a> takes this counter further, …</p>
    </section>

    <nav class="doors" aria-label="Where to begin">… as it is …</nav>
</main>
```

- The counter's `pre` has no `data-shell="paste"`.
- The session and the button share a `div class="session-column"`, the example's second column.
- The example's section has no heading and is labeled in its markup.
- The button stays in the counter's `section`.

### Its rules

Over the rehearsal's stylesheet. The mock gave the tour's sentence its width by a `calc` over the grid's fractions; the build states the two columns once, for the opening's row, the example's and that sentence.

```css
.home main { padding-top: 1rem; }
.home-intro { padding-bottom: 0; }
.home-intro .lead { margin-bottom: 0; }
.home-intro .lead + .lead { margin-top: .5rem; }
.claims a { padding: .4rem 0; }
.home-use { padding-top: 0; }
.home-use .example {
    margin-top: 1.5rem;
    grid-template-columns: minmax(0, 1fr) minmax(0, 1.15fr);
    gap: 3rem;
}
.home-use .next { margin: 1.25rem 0 0; }
.session-column .run { margin-top: .75rem; justify-content: flex-end; }
```

`.home main` stands for the homepage's `main` alone. No other page's space above its heading changes.

## Every page

Three changes are the stylesheet's and the script's, and reach every page.

**A block's tools are always shown, as small buttons.** Each is the page's own color with a line around it, its icon in the accent's color, drawn a little heavier. Pointed at or focused, the icon and the line take the text's color.

**An input's Paste is the same small button**, in the line it follows.

**The tools stand over a block's upper right corner where its first line leaves them room, and on a row of their own above it where it does not.** The script measures the first line when it makes a block's tools, and again when the block's width changes. The rule is the same under a mouse and on a touch screen, and no width is named. Without script a block has no tools.

**With the shell's panel beside the page, the header runs from the window's left edge to its right.** With the panel closed or below the page the header is as it is today.

```css
/* a block's tools */
.block-tools {
    position: absolute;
    top: .35rem;
    right: .35rem;
    gap: .3rem;
    margin: 0;
    background: none;
    opacity: 1;
}
.block.tools-above .block-tools { position: static; margin: 0 0 .25rem; }
.block-tools .icon-button { color: var(--accent); background: var(--paper); border-color: var(--line); }
.block-tools .icon-button .icon { stroke-width: 2.5; }
.block-tools .icon-button:hover,
.block-tools .icon-button:focus-visible { color: var(--ink); border-color: var(--ink); }

/* an input's Paste */
.line-paste {
    padding: .05rem .28rem;
    border: 1px solid var(--line);
    border-radius: 3px;
    background: var(--paper);
    color: var(--accent);
    line-height: 1;
    vertical-align: middle;
}
.line-paste .icon { stroke-width: 2.5; vertical-align: -.1em; }
.line-paste:hover,
.line-paste:focus-visible { color: var(--ink); border-color: var(--ink); }

/* the header beside the panel */
body.panel-beside .header-inner { width: auto; margin-inline: 1.5rem; }
```

The rules for a fine pointer that hide the tools and show them under a hover go. `tools-above` is the mock's name for the class the script sets.

## What it measures

From 1200 pixels wide and up the page is the same page, 1120 pixels wide and centered. It was measured at 1200, 1280, 1366, 1536, 1920 and 2560. Each figure is a lower edge, in pixels from the top:

| | The rehearsal | The page chosen |
|---|---|---|
| The heading | | 146 |
| The claims | 449 | 420 |
| The session | 836 | 662 |
| Try it | 966 | 716 |
| The counter | 905 | 732 |
| The tour's sentence | | 801 |
| The doors | | 985 |

**The first screen, at three sizes of the page.** A size here is the page's own, after the browser's and the system's bars.

| The page | The first screen holds |
|---|---|
| 1366×650 | the heading, the opening and the four claims |
| 1536×730 | the example and Try it as well |
| 1920×950 | the tour's sentence as well |

**Narrower than 1200.** The two columns hold down to 800 pixels, and the page grows taller as the heading and the claims wrap. At 1024 the counter's longest line runs 56 pixels past its block and the session's 45, and each block scrolls sideways. From 1200 up neither does.

**Not measured again.** The phone's figures and the panel's were made on the page before the tighter spaces, the shared columns and the tools' one rule. At 390×844 the counter began 1.3 screens down where it began 1.5, the session 1.7 where it was 1.9, and Try it ended 2.0 screens down where it ended 2.3. With the panel beside the page in a window of 1440 pixels, a block of the example was 362 pixels wide, and the header's name stood at 24 pixels where it stood at 160.

Every render was made in a headless Chromium, which reports no mouse. The mouse's rules were forced for the figures above.

## What changes, by owner

**`docs/design/site.md`, *The homepage*.** These sentences change:

- "In order: an opening under its heading, Why's list beside it, and a small example with its output." The example has no heading and no sentence, it takes the columns above it, and a sentence on the tour follows it.
- "Then they say what kind of language it is and what it is for." The sentence on what Ernest is for leaves the homepage.
- "Under the example stands its button, 'Try it', alone". It stands under the session.
- "Why is the link ending the introduction's paragraph, 'the whole argument'." It ends the first paragraph, as "Why Ernest".
- "The opening and the list are visible on a desktop without scrolling." The sentence names the three sizes of the page above, and what the first screen holds at each.

**`docs/design/site.md`, the tools and the header.** These sentences change:

- "A block's tools show on hover or focus where there is a fine pointer, on the block's own color." They are always shown, and stand by the rule above.
- "An input's Paste is a small icon drawn bold, in the accent's color when pointed at or focused, and visible without a hover."
- "The header spans the window." It does, and beside the panel its content runs from edge to edge.

**`guide/why.md`.** Two first sentences change, since the homepage shows them word for word:

- The first claim's, today "A process started on another node brings its code along, and a module keeps every version it has had: each function is known by a hash of its definition, not by the module it stands in."
- The mailbox's, today "Every process receives messages of one type, which a function that receives names in its own type and a process's address carries."

**`README.md`.** Nothing. It lists the claims by name, and no name changes.

**`site/templates/home.html`** takes the markup above.

**`tools/site.ern`.** `homeWritten` gives both blocks of `site/example.md` a Paste and fills them into one binding, `example_html`. The chosen page needs the counter with Copy alone, and the session in a column with the button, so the two blocks reach the template apart. `homeDescription` stays: it is the heading's sentence.

**`site/root/assets/js/site.js`** places a block's tools: it measures the block's first line against the room the tools leave, and sets the block's class. It gives a Paste only to a `pre` with `data-shell="paste"` and the class `code`, and a Copy to every block, as today. It finds the code Try it pastes by the button's `section`.

**The stylesheet** takes the rules above.

**The tests.** `ern_site_tests` holds the heading in `home.html`. `claims_test` in `ern_docs_tests` holds the claims' names between Why and the README. `ern_tour_tests` runs the homepage's example on two nodes. `make test-site`, `make test-site-shell` and `make test-browser` hold the generator, the blocks offered to the shell and the client. None was run against the chosen page. `make test-browser` gains two things: the first screen at the three sizes, and a block's tools above a first line that reaches them.

## Decided beside the page

- The tools are always shown on every page.
- No page of its own for a phone, yet.
- The shell's editing is changed before the homepage is built. It is a change to report §11.2, and the plan's item for it holds it: in an input of several lines the up and down arrows move between its lines.

## Open

1. **The homepage's last clause.** The page says that `foo` is bare and does not show it. Once the shell's editing is made, the opening's second paragraph gains: change the counter, and `foo` runs your change.
2. **Two sentences of Why's *Code travels***, below.
3. **A live shell.** Try it was not pressed on the chosen markup with a shell that runs.

## Looked at

- **The dark scheme**, in Chromium with the scheme forced, on the page before the tighter spaces. The page holds, and a small button stands on the page's dark color with its icon in the accent's.
- **A second browser**, Firefox 153, headless, on the same page. It draws the page as Chromium does.
- **The guide's pages 9 to 13.** They hold no block, so the count of 225 blocks over Why, the tour, the guide and the deployment guide is whole.

## Two sentences of *Code travels*

`guide/why.md` is the site's `/why/` page. Two sentences of its first section are to be split at their turns:

- The sentence that begins "It stands on the same floor", which carries five facts on one chain of commas.
- The sentence on `Code.running`, which holds `f`, its name, the hash of its message type and "which a fix leaves as it is" at once.

The rest of the section was not read for this.

## The stylesheet's units

An item of its own, after the homepage. The stylesheet is written in `rem`, 158 lengths, with `em`, `ch` and 62 in pixels, 25 of them a line of one pixel. Three uses of the pixel bind the page to one font size, and go together or not at all:

- `:root` sets `font-size: 16px`, so a `rem` is 16 pixels whatever size the reader set in the browser. `100%` follows the reader.
- The widths at which the layout changes, 760 and 999 pixels, would be `47.5em` and `62.5em`.
- The page's width, 1120 pixels, and the columns of 205 and 120 would be `70rem`, `12.8rem` and `7.5rem`.

A line, an outline, a corner's radius and the dot on a button stay in pixels. It would be looked at with the browser's font size at 20 and at 24 pixels. The first screen's three sizes were measured at 16.

## The mock

The mock is the rehearsal's own page, stylesheet and script, with small stylesheets over them. Its shell does not run. It is not in the repository: the markup and the rules above hold what is needed to make the chosen page again.
