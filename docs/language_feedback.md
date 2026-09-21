# Language feedback

Let us discuss all this.

Field selection is the biggest issue, and the shell has now given it three witnesses (the screen's record, then `Shell.Editor.State` twice — `fn text(editing) = match editing { State(text = text) -> text }` exists only to read one field). The others, roughly strongest first:

## Language proper

1. **A local constructor name hides the prelude's, with no way to reach past it.** Four
   witnesses now: `Outcome.Failed` against `TestResult.Failed`, and, on 2026-09-21, a
   `Last = Other | Tabbed | Documented` in the shell that hid `IoError.Other` in a function
   twenty lines away, which the compiler caught as "Other takes no fields". The rename was
   again an improvement, and again the rule offered no way out but a rename. §4.2 says a module may declare a constructor with a prelude name and the name then means the local one *throughout the module*. Types have namespaces, but prelude constructors have none, so there is no `TestResult.Failed` to fall back on. That is what made the region's tests impossible inside `shell.ern` until `Outcome.Failed` became `Faulted`. The rename was an improvement, so nothing was lost this time — but the rule has no escape hatch, and the next collision may not have a better name waiting.

2. **Constructor names unique across a module's types.** Felt three times: the `Output2` dodge, the editor's `Typing`/`Clear`/`Cancel` wanting names the screen had, and the `Failed` case above. Each time the right answer was to split a module, which is a good outcome — but it means the namespace rule, not the design, is doing the pushing.

3. **No constant patterns.** `let ctrlW = '\u{17}'` cannot appear in a `match` arm; an identifier there binds. So Readline's key table is bare literals with trailing comments (`'\u{17}' -> … // C-w`). A guard (`c == ctrlW`) is the alternative and reads worse. I would still not add them — it is a real cost honestly paid for one-way pattern semantics.

4. **Qualified constructors are heavy at use sites**, and there is no import or alias (§4.2 is explicit: no export list, no `import`). The reader loop matches five `Shell.Editor.*` constructors in one `match`. Explicit and correct; also the main argument anyone will make for aliases later.

5. **`after` is reserved**, so a natural helper name for "the rest of a string from here" had to become `from`. Trivial, but the kind of thing that accumulates.

## Standard library, not language

6. **`String.indexOf` was missing** (found writing the incremental search; now in E.5 with `lastIndexOf`).

7. **`String.lines` is not the split a text editor wants** — it drops the empty last line, so the region had to use `String.split(typed, "\n")` to show the empty row you are typing on. Both are documented and correct; the obvious-looking one is the wrong one.

8. **What a "character" is** — the report said code points, the code counts extended grapheme clusters, and `toList` gives code points. Settled in favour of the code. Display width is still open: a wide glyph is one grapheme and two columns, and nothing in the runtime knows it.

## Neither — worth separating out

The `Shell.Editor.fresh` resolution failure and the three runtime races were implementation defects, not language warts; they only showed that the report was silent on a consequence (§4.2 gained one sentence).

What I would actually put to you as candidate language changes: field selection (already queued for MVP 2.6) and, much more tentatively, some way to name a prelude constructor a module has shadowed. The rest I would record and leave alone.
```

## Found while writing completion, 2026-09-21

9. **A fault in a foreign function's *return* is silent to the caller's caller.** `fields_of`
   answered Erlang strings where the ABI wants binaries, so §8.4's boundary faulted the
   reader — correctly — and the shell became a zombie that painted but never read a key. The
   fault was right; nothing said it. The shell now monitors its reader and says so, but the
   general shape is worth a thought: a process that dies of a boundary fault takes its
   silence with it unless someone monitors it.

10. **Typing ahead while an input runs looks wrong** (found by a test that sent a second
    input before the first had finished; the second never produced a result within thirty
    seconds). Not yet diagnosed, and the shell's own, not the language's — recorded here so
    it is not lost, and it belongs to the hands-on session that closes MVP 2.6.
