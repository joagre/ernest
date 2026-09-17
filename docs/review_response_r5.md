# Response — module system and toolchain overhaul

This round is a set of related changes to how modules and namespaces work, and the toolchain around them. The typing rules, effect system, and reply-ownership discipline are unchanged.

## The change in one paragraph

Ernest now has an `export` keyword. Top-level declarations write local names; the compiler exports `export`-marked ones at the file's namespace (derived from the file's path relative to a source root). File paths are lowercase; case-fold collisions between namespace segments are compile-time errors. `main` is no longer a reserved specialness — any file's `export fn main` is a valid entry point, chosen at runtime by which module `ern` loads (or `--main Qualified.Name` override). `ernc` has a directory mode that walks the source tree, mirrors outputs under `build/`, creates missing directories, and removes stale `.erc` outputs whose source is gone.

## What used to be, and why it changed

Under the previous rule (R17 from earlier rounds), every qualified declaration repeated its file's path prefix — `fn Net.Http.parse(b) = ...` in `net/http.ern`. Two problems:

- The prefix was redundant with the path enforcement that already required it to match.
- Deep namespaces produced heavy repetition that scaled badly.
- `main.ern` was an unstated exception that contradicted the file-mirrors-namespace rule.
- Under case-preserved paths, `Http` and `HTTP` typenames could collide silently on macOS / Windows filesystems.

The overhaul removes the redundancy, folds `main` back into the general rule, and eliminates the case-portability trap.

## What the reader sees

**Declarations use local names, `export` marks visibility:**

```
// net/http.ern  (namespace Net.Http)
export type Request = Request(method : String, path : String)
export fn parse(s : String) -> Optional(Request) = ...
fn helper(x) = ...   // private to net/http.ern
```

External callers write `Net.Http.parse` and `Net.Http.Request`; the file-namespace prefix appears at *use* sites, never at declarations.

**`export` may prefix any top-level declaration** — `fn`, `type`, `abstract type`, `let`, `foreign fn`, `foreign type`. Constructors of an exported concrete type are exported with the type. Abstract-type constructor visibility is still controlled by the `with { ... }` signature, not by `export` on individual accessors.

**Abstract-type accessors** are the one remaining qualified-declaration form: `fn Stack.push(...)` in the module that declares `abstract type Stack`. The type-name prefix is a single typename that must name an abstract type in the same file; the file-namespace prefix is still implicit.

**`main` is a convention.** Any file's `export fn main() -> Void with m` is an entry-point candidate. `ern module.erc` looks up `main` in the loaded module; `--main Qualified.Name` overrides. A project with multiple entry points (a service main, a migration main) has each in its own module.

**Paths are lowercase.** Under a source root, every directory component and `.ern`/`.erc` filename stem must match the lowercase of a valid Ernest typename. `lib/Net/http.ern` is a compile-time error naming the failing component. Two typenames whose lowercase forms coincide (`Http` and `HTTP`) is also a compile-time error, regardless of filesystem.

**Toolchain (`ernc`, `ern`):**

- `ernc [-I src-root] [-o build-dir] file.ern` — single-file compile.
- `ernc [-I src-root] [-o build-dir] src-dir` — directory mode, walks the tree in dependency order, mirrors outputs into `build-dir`. Missing intermediate directories are created. After a successful build, any `.erc` file under `build-dir` whose mirror source `.ern` is gone (and any directory that becomes empty) is removed; only `.erc` files and empty directories are swept. `--no-clean` disables the sweep.
- `ern [--config-dir dir] [--load-path dir ...] [--main Qualified.Name] file.erc` — the runner. `--load-path` (renamed from the previous `-pa`; Ernest is not Erlang) extends the load path beyond the stdlib.

## Reserved-word count

16 → 17. The added word is `export`.

## What did not change

- Type system (HM + effect polymorphism, three inferred restrictions).
- Reply-ownership discipline.
- Bitstring alignment rules, `Float` finite-only, ABI table, code-shipping contracts.
- Prelude, standard library, paper programs' internal logic.

## Guide changes summary

- §1: hello-world uses `export fn main`. Command examples use `--load-path`.
- §2.2 gained a "**Constants**" subsection: top-level `let` as Ernest's constant form, lowercase naming, `export` for cross-module, pure-initializer + dependency-order rules.
- §6.1: rewritten around the file-is-namespace / `export` / local-declarations rule. Enumerates the six declaration kinds that accept `export`. States that constructors of an exported concrete type are exported with it, and that abstract-type constructor visibility is governed by the signature. Shows both single-file and directory-mode compilation.
- §6.2: Stack example uses `export abstract type` and `export fn Stack.push(...)` accessors, with explicit note that internal declarations use the type-name prefix but the file-namespace prefix `Main.` is implicit.
- FAQ "no import" answer references `export`.
- Every paper-program reference in "Reading further" checked.

## Cost

Reserved words +1. About 200 lines edited across the report and guide, plus a `sed` pass over paper programs to add `export` to their `main` functions. Grammar block simplified: `Name` and `QTypeName` productions removed from declaration sites; `DeclName` is the new declaration-side name form with an optional single-typename prefix for abstract-type accessors.

Full rationale, alternatives weighed, and per-edit details: `decisions.md`, entries dated 2026-09-15 and 2026-09-16.
