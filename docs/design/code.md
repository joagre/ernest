# Ernest's Code Across Nodes: Design

Status: the code note, which changes when the canonical form, the code table, the exchange, an arrival's making or a load's placement do. It is not a proposal, and not authoritative: the report states what a program is promised of code known by its hash, in §3.11, §6.10, §8.7, §11.1, §11.2, §12.7 and Appendices E.28 and H, and this note states the shape the runtime keeps those promises by, as it stands.

A line here is a shape a reader must know to change the component without breaking a promise, never what one function does, which is the code's; the module map and the tables are [`architecture.md`](../architecture.md)'s, the nodes' connections, frames and losses are [`nodes.md`](nodes.md)'s, and the reasons are the log's, named at each line. How the design was weighed is the log's, *The Nodes' Reasons, Kept* and *What Other Systems Taught the Nodes* among its entries; the proposals it came from stood under `docs/proposals/nodes_and_code/` until 2026-10-24. Where the code and this note differ, the code is what is built and this note is corrected.

## The rule

A definition is known by the hash of its canonical form, on every node and in every build, and a node holds every definition it has ever loaded for its life; code crosses between nodes as forms with a spawn or a compute and nowhere else, verified by hash where it arrives and loaded whole before any of it runs (§8.7, *Definitions and their hashes*, *The exchange*; Appendix H; the log's *The Nodes' Reasons, Kept*, *The Canonical Form, Built*). Nothing is evaluated because code arrived: a binding's value is its node's own, and a received definition reads it where the node holds it or is refused before it runs (the log's *The Module Peer*, *What the Outline Asked*).

A lookup is by hash and never by a name: two nodes that hold one hash hold one definition, whatever each build calls it, and two builds that differ in a definition hold two.

## Hashes and identities

A definition's canonical form is a term of the host's, Appendix H's, with everything that does not change what the code does left out: spans, comments, doc blocks, the names of locals and of annotation variables, the namespace a name was written with, and the order a pattern writes a constructor's fields; a type a program declares is referenced by its hash, the standard library's and the prelude's declarations by their qualified names, and a foreign function by its name with its scheme, so that the floor, not the hash, is what makes two nodes agree on them (§8.7, *Connections*; Appendix H).

The hash is the SHA-256 of the form in the host's external term format, deterministic, versioned by the form's version, which the cookie carries, so that nodes whose forms differ never connect. A mutually recursive group is hashed as one, each member's identity the group's hash with its position; a lambda or a local function that a spawn may start is its enclosing definition's hash with its position; a binding's identity is its qualified name with its definition's hash, since a binding is found where it was evaluated and not by its form alone (§8.7; the log's *The Canonical Form, Built*, *Positional Names Wait for Code That Arrives*).

A definition's reach is the definition with everything it references, transitively, which the `.erc` records with each function's bindings and foreign declarations, so that a node knows what a spawned function needs without reading its code (§11.1).

A form is kept beside the code it compiled to, sourced, with the lines of its source and its names, and with what prints a type in a cause as its module writes it, in the unit's recorded chunk (`#recorded{}`); the exchange sends it, `Code.hashes` reads it, and a shell session's declarations have one under the session's namespace, `$Session`, so that a function typed at the prompt crosses as a build's does (§11.1, §11.2, Appendix E.28; `ern_canonical:read/1`).

## The code table

A unit is a compiled module of the host's that holds definitions, one per source module in a build, one for the definitions one exchange brought, one per load; a unit names its functions by their position, so that it adds one name to the host's, its own (§10, §11.1).

A node's code table, kept by a holder of its own for the host's life (`ern_code`), is read from each unit's `'$code'/0` as the unit loads. It maps each function's hash to its unit, function, arity and reach; each lambda or local function a spawn may start to its entry, the function of its unit that runs it over its captures; each type to its hash; and each binding by its identity to the key its value is kept under and the unit that holds its form by its hash, which the exchange ships for a lambda written in it.

A constant (§4.6) is held by its form's hash, since one form is one value, with the value itself and the getter of the unit that lists it, under `{constant, Hash}`, which a read of the binding is compiled to and no node need evaluate. Each foreign declaration maps to the host's module and function it names, and the unit's own row holds the units its code calls, by which the reach's bindings and foreign declarations are read in the units that hold them (§8.5, §8.7, §11.1; the log's *The Code Table, Built*).

A build unit's forms are read from its `.erc` at the first request for them, checked against the loaded code's digest and kept for the node's life, so a build written under a running node leaves a unit no peer had asked for with no forms to ship, which is why a new build goes in a directory of its own (the deployment guide's §5.1). A unit loaded again with other code replaces its rows, and a definition another unit's code may reach by its hash, a type or a function its unit exports, is *linkable*; a definition held in no unit that exports its function is one a peer must be sent, as if the node lacked it (`ern_code:linkable/1`).

## Units, placement and versions

A module a node comes to hold after its start, by `Code.load` or a shell's load, is placed as a unit the node already holds of the same code, as its compiled file loaded as it is, or as a unit made from its forms, in that order, each candidate tried where it was compiled by this build of `ern`, against the interfaces the node holds, and calls no module the node holds at a unit other than its own (§11.2, *Loading and reloading*; `ern_code:placement/4`).

A shell's reload makes a version, a unit of its own, `ern@counter$2`, and the types it changed are the previous version's, printed under its namespace, `Counter$1.Msg`; a process keeps the version it was started on, and a peer that names a definition the session holds in two versions finds it in the latest whose bindings have their values (§6.10, §11.2; the log's *The Shell's Reload by Hash, Built*). A version's sites carry its number, `Counter$2.service:5`, so that a fault names the code that faulted. Nothing a node has loaded is unloaded while it runs, a refused load's unit among them, since a process may still run it and a peer may still name it by hash (§11.2, *What a node holds*).

## The exchange

A spawn's frame, or a compute's, names its function by its identity, and a peer that holds the identity starts the process at once; one that lacks it asks the spawner's node, through one registered process of the exchange's on each node, which plays both parts for every peer (§12.7, *The exchange*). As the spawner's node it answers a request for a reach from the code table and the forms kept beside the code: the identities the function references, transitively, code, types and the constants its reach names, which cross as definitions do, the other bindings its reach names and the foreign declarations, each with the host's module and function its declaration calls, its type, its printing and the line it is declared at.

The peer answers with the identities it lacks, among them a definition it holds in no unit that exports its function, or with `NotLoaded` where a binding of the reach has no value there or a foreign declaration's module or function is missing; and the node sends each lacking definition as a code frame, dependencies first, the sourced form with its name, its lines and its printing and each foreign declaration its form calls with its line, and never compiled code (Appendix H). A mutually recursive group crosses whole in one frame, and a lambda crosses as the definition that encloses it, a top-level binding among them, whose value stays its node's (the log's *The Full Review Before 0.5.0*).

The exchange runs within the spawn's time, two spawns that wait on one identity share one exchange, and a frame of an exchange that has ended is dropped; a peer that waited longer than the latest `ms` of the frames waiting on it drops the exchange, says the spawn was not loaded, and answers nothing, since the spawner's own wait has ended (§12.7).

## Arrivals

The definitions one exchange brings become one unit on the node they arrive at, an *arrival*, named from the node's pool, `ern$1`, `ern$2`, the first the host holds no unit of; it is made by the build's own back end from the same forms as a build's, so that a received definition is compiled as its build was, its frames and its foreign declarations' at the sender's lines, and compiled by the host and loaded whole before any process runs it (§12.7; the log's *The Report for Code with a Spawn*).

A binding that crosses, for a lambda written in it or as a member of its group, is the arrival's for its lambdas' entries alone: its initializer is compiled for them and never evaluated, its value being the node's. A constant that crosses is the arrival's whole, its value read from its form. Each form is verified against its hash as it arrives, a mismatch a faulty frame that ends the connection, and the forms are held apart until the reach is complete.

A node has no checker's environment of the sender's, so what the forms reference outside the unit is linked through the code table: a definition of another unit by its hash, to a unit that exports its function; a type to the forms the unit that holds it keeps; a binding by its identity, to the unit that holds it with its value, through its getter; a constant to the value a unit lists, the arrival's own among them; and what the standard library and the prelude declare by its name, as the build links them, from the prelude's environment, built at the first arrival and kept for the node's life, about 370 KB (the log's *The Report for Code with a Spawn*).

Units are off the host's code path, loaded whole by the runtime at an arrival or a load and never by the host's autoload, so no name is ever resolved by the host at a call. What the definitions name beyond the spawned function's reach that the node lacks, a binding without a value or a foreign function without its module, is linked to one of the unit's lacked functions, `'$lacked_K'`, which faults naming it and which no process reaches, since a spawn whose reach names it is refused before it starts (§12.7). A foreign function spawned by its name crosses as its declaration alone, and a received definition calls the host's function the sender's declaration names, the module's code being the node's own (§8.7, *Connections*).

## Loading at run time

`Code.load(path)` loads a compiled module and its reach, found under the module's root and then on the load path, as `ern run` loads a program: each definition verified against its hash and placed as a unit as above, then the bindings of the module and of its reach that have no value on the node evaluated in the calling process, in §8.5's order, each as a body at `Never`, the process and what it starts carrying a mark for their root while the evaluation runs; a binding that faults undoes the load, every process the evaluation started killed as a shell's load kills them, the unit the load brought held by the node out of scope (§11.2, Appendix E.28; `ern_rt:rooting/0`).

`Code.running(f)` is a form the compiler reads: it answers the addresses of the processes on this node whose stack holds a frame of `f` itself at the moment of the call, read from the host's stacks through the code table, which knows `f`'s unit and function from its hash; the host keeps the innermost sixty-four frames, which the runtime sets at its start, so a process whose frame of `f` lies beneath them is not listed (§3.11, §10, Appendix E.28). A program moves the processes it lists by its own `send` to each, as §6.10 moves them: the runtime moves nothing.

## The host's counts

The host limits what one runtime loads in its life and gives none of it back: 65,536 module names, 524,288 export entries, 524,288 function entries and 1,048,576 atoms, as OTP 29 sets them (§11.2).

The code table keeps the sums the host counts (`ern_code_sums`) and reads them each time units load, a program's at its start, an arrival's, a shell's at an input, a load's and a reload's, saying once on standard error, for each limit in the host's life, where one has reached four fifths of it; a definition spawned onto a node costs about one module name, five exports, a function entry per lambda and an atom, which the deployment guide's §4.2 turns into days (§11.2; the log's *What MVP 3.1 Costs, Measured*). A unit's functions are named by position so that a unit costs one atom for its name and none for its functions beyond the host's own (§10).

## What it does not do

It sends no compiled code, only forms, so that a node compiles what it runs and a mismatch of hash is caught before anything is loaded. It unloads nothing while a node runs, so a version a process still runs is never taken from under it (§6.10, §11.2); the cost, a node that grows with its versions, is said and counted. It initializes nothing because a peer asked. It looks nothing up by name across nodes, and keeps no table of which node holds which definition: a node knows what it holds, asks for what it lacks, and the spawner's node answers from what it holds, so there is no store to keep consistent and no name to translate between builds (the log's *The Report Rewritten for MVP 3.1*).
