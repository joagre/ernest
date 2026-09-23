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

## The standard library's shims, 2026-09-23

11. **Does the standard library follow a different rule from the rest of the Ernest we
    write, and should it?** Where it is written: E.0 rule 1 in the report is the normative
    one; CLAUDE.md states the rule for everything else and points at E.0 as the other side
    of the same line; the log has *Shims Where the Runtime Owns the Representation*
    (2026-09-20) and *Where `foreign` Stops* (2026-09-21).

    They are one principle, not two: a shim exists only where the **runtime owns the
    representation**. The counts bear that out. `list.ern` has one shim in thirty-two
    exports; `io.ern` one in six. The shim-heavy modules are `String` (20 of 28), `Float`
    (18 of 25), `Map` (16 of 20), `Set` (14 of 19), `Int` (12 of 22) and `Char` (10 of 11) —
    binaries, doubles, Erlang maps and sets, bignums and Unicode tables, none of which
    Ernest can build or fold case on.

    Two places where the rule is looser than it should be, and both should go the way of
    "write it in Ernest, measure later":

    - **Done 2026-09-23.** E.0 rule 1's second clause, "or the runtime's implementation is
      the one to trust", was the only opening in the library for an argument from
      performance, and it covered exactly one function: `List.sort`. `sort` is a merge sort
      in Ernest now, twenty lines, stable by taking the left element when two compare
      `Equal`; `ern_list.erl` is deleted, and rule 1 says one thing only, with "speed is not
      a reason for a shim" added. Measured after: twenty thousand elements in 17 ms.
    - **`path.ern` is seven shims of eight exports** over `filename:`, and a path is a
      `String`, whose content the language owns. `join`, `split`, `parent`, `name`,
      `extension`, `withExtension` and `isAbsolute` are string surgery that `String.split`,
      `String.indexOf` and `String.slice` can do. They are shims because `filename:` was
      there, which is the reason the rule exists to refuse.

    Performance is not a reason for a shim. If a measurement ever demands one, it comes back
    as a decision with numbers beside it, as `Tcp`'s socket processes did at 1.8 times raw
    Erlang and were kept.

12. **Should `Map` be in the prelude at all?** It is, with `Set` and `List`, in
    `ern_prelude:builtin_types/0`, and the answer is yes — but the rule that decides it has
    never been written down. `Map` has no syntax: no literal, no pattern, nothing in the
    grammar. What keeps it in the prelude is that **its module is named after it**. A
    standard library type whose module is not — `Random.Seed`, `Ets.Table` — is declared by
    its module and read from the compiled interface, and §3.10 already names `Ets.Table` by
    its section for the equality constraint, so the machinery is there. Moving `Map` out
    would make it `Map.Map(String, Int)` in every annotation, which is the wart the rule
    avoids.

    So: a type whose module is named after it is the language's, and a type a module merely
    provides is the module's. Worth a sentence in §9 or E.0, since it is the rule behind
    `Int`, `Float`, `Char`, `String`, `Bytes`, `Bool`, `List`, `Map` and `Set` being built
    in, and nothing states it.

    The worry underneath the question is the shims, and that is entry 11: the operations
    being the runtime's is the representation decision, not a prelude decision.
