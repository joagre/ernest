# What other systems do with a dependency

Each system's own documents, read on 2026-11-09, with the sentence that decides each point. What [`proposal.md`](proposal.md) takes from each, and what it leaves, is said under it.

## Go

From the Go Modules Reference, https://go.dev/ref/mod.

- **A requirement is a minimum.** "A `require` directive declares a minimum required version of a given module dependency." The build takes, for each module, the highest version any requirement names.
- **No lockfile.** "Unlike other dependency management systems, the build list is not saved in a 'lock' file." The file `go.sum` "contains cryptographic hashes of the module's direct and indirect dependencies", and chooses nothing.
- **No upper bound.** An `exclude` directive names single versions, and "`exclude` directives only apply in the main module's `go.mod` file and are ignored in other modules". A dependency cannot bound its own dependencies from above.
- **A break takes a new path.** "If an old package and a new package have the same import path, the new package must be backwards compatible with the old package." From version 2, "module paths must have a major version suffix like `/v2`".
- **A version before 1 promises nothing.** "A version is considered unstable if its major version is 0 or it has a pre-release suffix. Unstable versions are not subject to compatibility requirements."
- **The whole build is listed.** "At go 1.17 or higher: The go.mod file includes an explicit `require` directive for each module that provides any package transitively imported by a package or test in the main module." The tool writes those lines.

The proposal takes the minimum, the absence of a lockfile and of an upper bound, and the new name at a break. It differs in one thing: Go's tool walks the graph and takes the highest minimum, and Ernest's root writes each version itself and is refused where one is too early.

## Elm

From the compiler's documents, https://github.com/elm/compiler/tree/master/docs/elm.json.

- **An application names exact versions.** "We use exact versions, so your `elm.json` file doubles as a 'lock file' that ensures reliable builds."
- **One version of a package.** "In each application, there can only be one version of each package."
- **A version is held to the interface.** "All packages start at '1.0.0' and from there, Elm automatically enforces semantic versioning by comparing API changes." `elm bump` sets the version from the difference, and `elm publish` refuses one the difference does not give.

The proposal's root manifest is Elm's application file: exact, and its own lock. It does not hold a version to the interface. The checker refuses a broken interface where the root builds it, and a tool that numbered versions would be a second judge of the same thing.

## Cargo, Hex and npm

From the Cargo Book's *Dependency Resolution*, Hex's *Usage*, and npm's pages on `package.json`, `package-lock.json` and `folders`.

- **A range, a resolver and a lockfile.** Cargo: "The result of the resolution is stored in the `Cargo.lock` file which 'locks' the dependencies to specific versions." Hex: "The resolution process will always try to use the latest version of all packages." npm: "Dependencies are specified in a simple object that maps a package name to a version range."
- **Several versions at once.** npm nests them: "It is still possible to have `a/node_modules/b/node_modules/a` if the two 'a' packages are different versions." Cargo builds two versions that are not compatible side by side, and says that their types "are considered different by the Rust compiler, even if they have the same name".

The proposal takes none of the three. What they build depends on the day and on an index, a lockfile says again what a manifest could say, and a namespace of Ernest's has one module (§4.2).

## A package's code at install

- **Cargo** (the Cargo Book, *Build Scripts*): "Placing a file named `build.rs` in the root of a package will cause Cargo to compile that script and execute it just before building the package."
- **npm** ran a dependency's install scripts by default through version 11. From version 12 (`npm approve-scripts`): "Dependency install scripts are blocked by default."

The proposal runs no code of a package while it is unpacked or built, which is where npm has arrived.

## Nix

From the Nixpkgs manual, *Fetchers*.

- **A source is a URL and a hash.** "Because Nixpkgs fetchers are fixed-output derivations, an output hash has to be specified, usually indirectly through a `hash` attribute." A fetch that gives another hash fails the build, `hash mismatch in fixed-output derivation`.

The proposal's line is that pair, the archive's URL and its SHA-256.

## Erlang/OTP

From the system documentation, *Compatibility*, https://www.erlang.org/doc/system/misc.html.

- **Compiled code and the release.** "Compiled code can be loaded on at least two subsequent releases." "Loading on previous releases is not supported."

So a package's `.beam` files are compiled on the earliest release of OTP the package is meant for.
