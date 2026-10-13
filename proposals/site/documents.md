# The documents

A discussion note, begun 2026-10-13, beside [`site.md`](site.md), the site's
design. Which documents the project will have, which reader each serves, and
what two of them, `but_why.md` and `features.md`, are to hold. Nothing here
is decided; it flows into no plan item until it is. The same set would exist
with no site; how the site shows them is `site.md`'s.

## One document per question

A reader arrives with a question. One document answers each, and CLAUDE.md's
rule holds: each fact has one owner, and the others point at it.

| Question | Document | Where it lives | What it does |
|---|---|---|---|
| Should I care? | `but_why.md` | to write | the argument: four pieces with their precedents, the principles, how the language is made, its status; persuades, cites, restates nothing |
| What do I get? | `features.md` | to write | the inventory, one line a feature with a pointer; argues nothing |
| Show me, in order | the tour | `tour/`, MVP 3.3 | a program growing chapter by chapter, each lesson with previous and next, which the guide cannot be since the guide is organized by rule |
| How do I write it? | the guide | `guide/language.md` | exists; teaches by rule, restating the report where it teaches, each chapter stable and linkable |
| What exactly is the rule? | the report | `report/language.md`, `toolchain.md`, `library.md` | exists; the one normative document, §0 to §11 and the appendices; the grammar wins over the prose |
| What does this function do? | the library's pages | `ern doc`, a page per module from its doc block, with its examples run by the tests | exists; reference, never teaching |
| How do I run it? | the deployment guide | `guide/deployment.md` | exists; the operator's day, one node to many, the catalog of what a node says |
| What does this command do? | the manual pages | `make man`: `ern(1)` rendered from §11 by `tools/manual.ern` and a page per module by `ern doc --man`, installed; the module pages as Markdown in `man/`, from `main` | exists; what `man ern` answers at the terminal, the report's §11 in roff and nothing more |
| What is it like at size? | a walk through one real program | to write | `examples/` and the operations programs are half of it; a page that walks one is what a hesitant reader opens last |
| Let me try it | the shell, hands-on | the site's shell, MVP 4.2: xterm.js into a live `ern shell` in a container per visitor; no document | a link, not a page to read: the prompt itself, with the tour's examples linking into it; what the shell does is guide §1.2 and guide §9.3, and report §11.2 |
| How does the shell's code read? | `shell/README.md` | exists | for a reader of the code, not of the language |
| What changed? | release notes | on the site, each release's | what the release is, by its milestone, no history |

Two that are easy to forget:

- **A comparison page**, short and honest: Erlang, Elixir, Gleam, one paragraph
  each on what was taken and what differs, written so that each community would
  nod. The FAQ's seed. One page we control beats a thread we do not.
- **A contributing page**, for the day a patch arrives; CLAUDE.md is not the
  document to hand a contributor.

## `but_why.md`

Answers "why another language on BEAM" with one argument, the synthesis: every
piece has a parent elsewhere, and no runtime has had them together. The
pieces, from the log's own sentence on what Ernest adds, the mailbox in the
function's type, checked replies, purity in the type, and distribution by
content on the Erlang runtime, and from the guide's two ideas:

1. **The mailbox in the function's type.** Hindley-Milner typing with the
   mailbox in the signature, purity as the absence of a mailbox, what a value
   may be used for, requirements, operators as members, one `compare` per type.
   Precedent: ML for the types, Erlang for the mailbox; nobody for the two in
   one signature.
2. **Checked replies.** A reply answered exactly once on every path, or the
   program does not compile; a callee's death ends the call with its cause.
   Precedent: linear types, which Rust made ordinary; nobody applied them to a
   request's reply on a mailbox.
3. **Code by content on the runtime.** A definition has an identity by hash and
   a node holds what it has received. Three consequences, each a subsection:
   any number of revisions at once, code traveling with a spawn to peers that
   lack it, bare nodes included, and work placed where there is room. The
   paragraph that makes it safe: code moves only between peers that list each
   other, by key, over TLS, never a mesh. Precedent: Unison, which has no
   runtime of Erlang's kind.
4. **Failure as messages, in the type.** A monitor's `Down` arrives as a
   message of the mailbox's type; a call ends with the callee's cause; §7.4's
   four kinds of failure; the runtime chooses no time of its own and retries
   nothing. Precedent: Erlang for faults as messages; nobody for them in the
   type.

Around the four: an opener stating the synthesis and naming the parents; a
chapter on the five principles and what they refuse, since it answers every
"why not X" at once; a chapter on how the language is made, the report, the
grammar that wins, a test per section, the soundness argument, the memory
loads, the log; a status chapter, plainly; and a FAQ: why not Erlang with
Dialyzer, why not Elixir, why not Gleam, why no type classes, why one mailbox
per process, why is the compiler so strict. The toolchain and the operator's
day stay as evidence, one paragraph each, not a tour.

The form of a section, settled on 2026-10-13 while the typing section was
drafted: state the rule, name its price before its gain, then a program and
the compiler's line about it, compiled before it is quoted, and a pointer to
the guide and the report. No sentence describes another language; no
superiority claim; no sentence answers an objection the text did not raise.
Everything a reader would look up rather than be persuaded by, the library,
the border to Erlang, the cost numbers, the formatter, the shell's commands,
goes to `features.md` with one link from here.

The test for adding a piece later: it has a precedent and a thing it adds, and
the synthesis weakens without it.

## `features.md`

The inventory. One line a feature, grouped by the language, the library, the
toolchain, the runtime and the operator, each with its pointer into the guide
or the report, and nothing argued. The README's list today is its seed. It is
an afternoon's work and is written first, so that `but_why.md` has something
to point at.

## Order of writing

`features.md`; then `but_why.md` one chapter at a time, each with its examples
compiled as the typing section's were; the comparison page last, once the
chapters say what was taken from whom.

## Doors and rooms

Eight entrances were counted on 2026-10-13: the shell, the guide, the
deployment guide, the tour, the report, `features.md`, `but_why.md` and the
manual pages. Only a few are doors. A door answers a question a newcomer
brings; a room answers a question a reader already inside has.

- **Doors**, on the homepage: Try, "let me see it run";
  Tour, "show me the language"; Guide, "help me write programs"; Report, "tell
  me the rules"; and Why, the smallest, whose first line is the homepage's own
  "why would I use it" paragraph, with "the whole argument" as the link.
- **Rooms**: Features is the homepage's characteristics at full depth, reached
  from them. Deployment is the operator's room, reached from Install and from
  the guide's running chapter, never from the homepage, since a newcomer has no
  node. The manual pages are the site's Library, a room; at the terminal their
  door is `man ern` after Install.

Three readers, three paths, which the homepage shows as three rows: the
curious, Why, Try, Tour; the programmer, Guide, Report, Library; the operator,
Install, Deployment, the manual pages at the terminal. The footer carries
every room, and the site map page all of them with the reader's question beside
each; whether the header carries the doors alone is `site.md`'s question 5.

## To decide

- Whether the typing section drafted on 2026-10-13 stands as the template for
  every piece, with its length brought level with its neighbors.
- Whether the walk through one real program is a page of its own or the tour's
  last chapter.
- Where `but_why.md` and `features.md` live in the repository, and who tests
  them: their code blocks are run as the guide tests run the guide's, so they
  need a directory the docs tests read, which `proposals/site/` is not today, and a row
  each in CLAUDE.md's owners table.
