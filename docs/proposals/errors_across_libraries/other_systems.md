# What other systems do with two error types in one block

Read 2026-11-07 for the proposal. Each entry says the mechanism and what it costs on the
principles, so that the proposal's choice is made against them and not alone. The systems
part in two: those whose error types are open, so that two merge without a word, and those
whose error types are closed, as Ernest's are (§7.1), which convert.

## Open error types

- **Zig.** An error is a member of an error set, and a function's error set is inferred as the
  union of what it can return; `try` returns any error upward, and two sets merge with `||`.
  No conversion is written, and a caller switches on the merged set. The merge is a feature
  of the type system, and an inferred set changes with the callee's body; a reader learns a
  function's errors from its callers' switches. Principle 5 against the feature, principle 1
  against the inference.
- **OCaml, polymorphic variants.** A result's error written as an open variant,
  `` [> `Timeout | `Malformed] ``, unifies with another open variant, so a chain of binds
  takes the union of the errors met and the match at the end names every case. Idiomatic in
  libraries over sockets. A type that grows at every use site, and an error type a reader
  reads off the inferred signature and not off a declaration. Principle 1.
- **Roc.** The same, as open tag unions: `Err [Timeout, Malformed]*` merges through `try`,
  and a closed union is written to stop the growth. As OCaml's variants.
- **Go.** Every error is the interface `error`, one type, and a cause is recovered by
  `errors.Is` and `errors.As` through the wrapping `%w` makes. No lift, since there is one
  type, and no case the type names: the cases a function can answer are its documentation's.
  Principle 1, and §7.4's rule that a cause the program acts on is in the type.
- **Java, checked exceptions.** A method's `throws` clause is the union of what it throws, and
  a caller's clause grows with its callees' until it names `Exception`. The union is free and
  the clauses grow to say nothing. Principle 1.
- **Erlang, the host.** `{error, Reason}` with `Reason` any term: `gen_tcp`'s posix atoms and
  a library's own reasons share one untyped slot, and a `case` names the ones it expects. No
  type, so no lift and no exhaustiveness. What Ernest's `Either` was made to replace.

## Closed error types

- **Rust.** `?` converts the error through `From`, so a function with its own error type
  declares one conversion per error it wraps, `impl From<io::Error> for ReadError`, often by
  `thiserror`'s `#[from]`, and every `?` in its body converts without a word at the site. The
  conversion is declared once and applied invisibly: the proposal's second way, principle 1
  against the invisible site and principle 2 against the second way to lift beside
  `map_err`.
- **Swift 6, typed throws.** `throws(E)` names a function's one error type, and a `try` of a
  function throwing another type is refused unless the block's type is `any Error`, the
  untyped fallback. A closed type with no conversion at the site, so the caller maps the error
  by hand or falls back to the open type. The proposal's form, with an escape Ernest lacks.
- **Haskell, `ExceptT`.** A block in `ExceptT e m` has one `e`, and an action with another
  error is lifted with `withExceptT f`, a conversion written at the site. The proposal's form
  exactly: one error type a block, `mapLeft` at the seam.
- **F# and Elm.** `Result` with `Result.mapError`, the same form as Haskell's, and F#'s
  `result` computation expression binds one error type a block. As Haskell.
- **Gleam.** `use` over `Result` binds one error type, and `result.map_error` converts at the
  site; libraries over sockets wrap `mug`'s socket error in their own, as `libs/http` wraps
  `Io.Error`, and programs lift at the seam. The proposal's form and the proposal's problem,
  with no answer in the language.

## What they say for the proposal

The systems that remove the lift do it by opening the error type, a feature of the type system
that Ernest's closed sum types and §5.5's one type a block refuse, or by converting at the site
as Rust does, the second way. Those with closed types and no conversion feature, Haskell's,
Swift's, Gleam's, write the lift as Ernest does. None of them puts a library's writes beside its
reads for the sake of the block's type; Gleam's socket libraries show the cost of not doing so.
The third way stands on the report alone.
