# What other systems do with a long name

Read 2026-11-02 for the proposal. Each entry says the mechanism and what it costs on the
principles, so that the proposal's choice is made against them and not alone.

- **C++.** An unqualified name is looked up in the enclosing namespaces outward, so `C::X`
  inside `A::B` finds `A::C::X`; `::X` names the global. `using` declarations and namespace
  aliases add second spellings. The lookup is the proposal's; the aliases and the global
  spelling are what the proposal leaves out.
- **C#.** The same outward lookup through enclosing namespaces, `global::` for the root, and
  `using` directives with aliases. As C++.
- **Go.** A package is imported by its full path and then named by its last segment,
  `http.Get`, the same short name from every file, with an alias in the import where two
  packages share a last segment; relative paths are refused. One declaration per file per
  package, and two spellings where an alias is used.
- **Rust.** Paths are relative to the current module by default, with `crate::`, `super::` and
  `self::` as anchors, and `use` brings a path into scope under its last segment or an alias.
  The relative path is the proposal's idea; the anchors and `use` are second spellings.
- **Haskell.** Modules are imported, qualified or not, with `as` for an alias; a name has as
  many spellings as imports give it.
- **OCaml.** A nested module is visible inside its parent by its own name, and `open` and
  `module M = ...` bring others in. The visibility of a child is the proposal's; the rest
  adds spellings.
- **Elixir.** `defmodule A.B` nests nothing by name: `C` inside it does not mean `A.B.C` unless
  an `alias` says so. Every short name is a declaration.
- **Erlang.** No namespaces: every module is one atom, and a long name is the module's own
  problem, `httpd_request_handler`.
- **Unison.** A name may be written by any unique suffix of its full path, and `use` shortens
  further; the suffix is resolved against the whole codebase, so a reader knows where a name
  points only by knowing the codebase. Set aside for principle 1.
