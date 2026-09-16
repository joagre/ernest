# Response — sixth-round findings (NR01–NR06)

This round addresses the six findings from the sixth review, plus small consistency edits caught while walking the report. No changes to type system, effects, or reply ownership.

## Summary in one paragraph

The main clarification is that type-member namespaces (`Main.Stack.push`, `Distance.+`) are *owned* by the file that declares the enclosing type: they are compiled into the same `.erc` as the type itself, and the compiled interface records that ownership so the loader routes qualified references correctly. Concrete types can now declare type-member operations too — the type-name-prefix declaration form is no longer restricted to abstract-type accessors. Namespace segments are the *canonical typename form* (first-letter-cap) of the corresponding lowercase path segment, one-to-one. The output-path formula for `ernc` and the cleanup scope both use `relpath(source, source-root)` explicitly. Path-shape validation applies only to files the compiler is considering as modules — unrelated content under the tree is left alone. Appendix D's Ets shim no longer claims Ernest `match` can decode `{ok, V}` from a raw Erlang return; a foreign adapter is required.

## NR01 — Type-member namespace ownership

**The problem.** With the new module system, `abstract type Stack` in `main.ern` produces the qualified name `Main.Stack.push`, but §11.2's lowercase-path-mirror rule would look for it at `main/stack.erc`. `Main.Stack.push` is compiled into `main.erc`, not a separate file.

**The fix.** §4.2 now includes a *module ownership* paragraph:

> A type-member namespace belongs to the file that declares the type. `abstract type Stack` in `main.ern` (namespace `Main`) means the type `Main.Stack` and every member `Main.Stack.*` is defined by `main.erc`; the compiled interface records that ownership so `Main.Stack.push` loads from `main.erc`, not from a hypothetical `main/stack.erc`.

§11.2's loader rule mirrors this: for a type-member reference `A.B.C.T.member`, the loader consults the compiled interface of `a/b/c.erc` (which owns `T`), not `a/b/c/t.erc`. Collision case (`main.ern` and `main/stack.ern` both declaring `Main.Stack.*`) is a compile-time error at load.

## NR02 — Concrete-type operators

**The problem.** The previous wording restricted the type-name-prefix declaration form to abstract-type accessors, but §4.8 promised per-type arithmetic operators on any type. Concrete types couldn't declare operators under any legal grammar form.

**The fix.** §4.2 now states the rule generally:

> A locally declared type `T` — whether concrete (§4.3) or abstract (§4.4) — creates a nested namespace `T` inside its module. Members of `T` are declared with `T.` as a single-typename prefix (`fn Distance.+`, `let Stack.empty`, `fn Stack.push`).

§4.4 restructures so that the abstract-type-specific restriction (constructors accessed only via signature-listed accessors) is layered *on top* of the general rule, rather than being the whole rule. §4.8 shows the concrete example:

```
export type Distance = Distance(Float)
export fn Distance.+(Distance(a), Distance(b)) -> Distance = Distance(a + b)
```

## NR03 — Canonical namespace capitalization

**The problem.** The previous "case-preserving typename form" was under-specified.

**The fix.** §4.2 gives an explicit *canonical typename form* rule: each namespace segment is the corresponding lowercase path segment with its first ASCII letter uppercased and the rest preserved. Examples: `http.ern` → `Http`, `http_server.ern` → `Http_server`, `httpv2.ern` → `Httpv2`. The mapping is one-to-one with lowercase paths; the case-collision rule applies to path segments (trivially satisfied under canonical form). Type-member namespace segments are the programmer's choice and may differ in case at the author's discretion.

## NR04 — Output path formula and cleanup scope

**The problem.** `ernc -I src -o build src/net` should write `build/net/http.erc` (mirroring the source root), not `build/http.erc` (mirroring the argument). And cleanup should not treat `build/main.erc` as orphaned when `src/main.ern` still exists but wasn't part of the current subtree build.

**The fix.** §11.1 now states:

> For a source file *s* under source root *R*, the output path is `build-dir / relpath(s, R)` with the extension changed from `.ern` to `.erc`. When `-o` is omitted, `build-dir` defaults to *R* itself.

Cleanup is confined to the *subtree mirroring the compiled source subtree*: `ernc -I src -o build src/net` sweeps only `build/net/`, so `build/main.erc` (mirror of `src/main.ern`) is untouched. `--no-clean` disables.

## NR05 — Path validation scope

**The problem.** Read literally, the previous wording would reject `.ernest/` under a `--load-path .` root as an invalid namespace segment. But `.ernest/` is configuration, not a module.

**The fix.** §11.1: path-shape validation runs only on `.ern` files the compiler considers as modules and the intermediate directories between them and the source root. It does not scan the tree looking for offenders. §11.2 parallel for the loader. Unrelated content (`.ernest/`, `README.md`, editor artifacts, embedded resources) is silently ignored by the shape rule.

## NR06 — Appendix D decoding claim

**The problem.** Appendix D said an ETS shim could decode `{ok, V}` from a raw Erlang return either via an Ernest `match` or via an Erlang helper. But `Foreign` is opaque; ordinary Ernest `match` cannot destructure raw atom-tagged tuples.

**The fix.** Rewrote the paragraph:

> An API returning that shape needs a foreign adapter that returns the declared Ernest representation — either an Erlang helper module that rewrites `{ok, V}` to `{'Right', V}` before it crosses the boundary, or explicitly declared foreign decoding functions on the Ernest side. An ordinary Ernest `match` cannot destructure the raw `{ok, _}` term directly.

## Small consistency edits

- §4.2: the "declarations use local names" paragraph now says "the compiler exports it as `Net.Http.parse` *when the declaration is marked `export`*".
- §4.4: signature-listed constructor access is separated from `export` visibility. A signature entry can be private (no `export`) when used only inside the module.
- Appendix E section headings unified: `### Appendix E.1. \`io.ern\` (namespace \`Io\`)` and equivalents. Filenames lowercase per §11.1; namespaces stay first-letter-cap.
- Appendix F glossary: `Reply(a)` entry expanded to name the six consumption forms and note the reply-carrying-types extension. `top-level binding` entry distinguishes user-declared bindings (module-private by default, external when `export`) from runtime-provided bindings (`Sys.*`, prelude, in scope everywhere).

## Cost

Six paragraph-level edits, an Appendix E heading sweep, two glossary rewrites. No new grammar production: the type-member-prefix rule was already in `DeclName` (the single-typename prefix), and the change is that concrete types are allowed to use it. Reserved-word count unchanged at 17.

## What did not change

- Grammar. `DeclName` and the `[ "export" ]` prefix on declarations are the same tokens as R5.
- Reserved words. Still 17.
- Type system, effect discipline, three inferred restrictions.
- Reply ownership, `Address.call` semantics, distributed failure model.
- BEAM ABI, code-shipping contract, foreign-boundary promises.
- Standard-library surface. Only heading spelling changed in Appendix E.

## Where to look

- Report: `ernest.md` §4.2 (canonical typenames + ownership), §4.4 (concrete/abstract split), §4.8 (operators), §11.1 and §11.2 (paths), Appendix D, Appendix E headings, Appendix F.
- Decisions log entry: `ernest-decisions.md`, entry dated 2026-09-16, *Sixth-Round Review Response*.
- Consolidated changelog: `ernest-changelog.md`, refreshed under "Modules, namespaces, and `main`" and "Toolchain".
