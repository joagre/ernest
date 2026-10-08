# Style

The rules build on widely accepted guides and state only the repository's own rules and where they differ: for Erlang, Ericsson's *Programming Rules and Conventions* (Eriksson, Williams and Armstrong) and Inaka's *Erlang Coding Standards & Guidelines*; for Ernest, the *Elm Style Guide*, then the conventions of Gleam and OCaml. Where they and this file differ, this file holds. A guide serves the reader and is not a law: a rule a test checks holds always, and where another would make the code read worse, judgment goes first. `test/ern_style_tests.erl` checks what is marked *(tested)*.

## Every language

- A step of indentation is four spaces.
- No file holds a tab, but a Makefile *(tested)*.
- A line of code is at most 100 characters; prose in markdown may be longer *(tested)*.
- A name in a namespace shared with other code carries the repository's name: an Erlang module begins `ern` *(tested)*, an Emacs Lisp symbol `ernest-`.

### Names

Code is read more often than written, mostly by someone else, so a name is written for that reader. These rules cover a variable, a parameter, a function, an Erlang record and its fields, and an Ernest type, constructor and field. Longer names make longer code, and that is accepted.

- **A name says what its value is or what its function does**, in the words of the domain: `Tokens`, `Descriptor`, `Namespace`, `parse_module`; not what the value is made of, `List`, `Map`, where that is not what it is.
- **One concept, one name, in every module**: a type's descriptor is `Descriptor` in the emitter, the boundary and the runtime alike, and two concepts never share a name. A concept the report names takes the report's name; where the code names one otherwise, or the report's name seems wrong for the code, the question goes to the user before anything is renamed. A value changing through a function is numbered, `Env1`, `Env2`, and a numbered name is nothing else; past two steps the function is split.
- **No abbreviation a reader must guess.** A well-known acronym is fine, `TCP`, `URL`, `UTF-8`, `JSON`, and so is an abbreviation the host or the report writes: `Pid`, `Ref`, `Fd`, and `Acc` for what a fold carries.
- **One letter only where the whole scope is one line that shows what it is**, as a comprehension's element or a one-line fun's parameter: `[size(Module) || Module <- Modules]`, not `[size(M) || M <- Ms]`, wherever the line does not show it.
- **A function that does something is a verb**, `compile`; one that gives a value is that value, a noun or, for the value made so, a past participle, `descriptor`, `armed`, `held`; a yes-or-no reads as the question, `is_link`, `isEmpty`.
- **A record, a type or a constructor names what it holds**, a type as a noun: `#emit_context{}`, not `#cx{}`; `Key(Terminal.Event)`, not `K`.
- **A name the report states** changes only through the report.

### Structure

- **A function reads on one screen**; a longer one is split into steps whose names say what they do.
- **How deep code nests is the writer's judgment**, bounded by the line: a construct that no longer reads within 100 characters becomes a function.
- **A module has one job**, which its first comment states.
- **A comment says why and cites the report section the code implements**, `%% Report §8.4: ...`, `// Report §11.2: ...`; the names say what it does.

## Erlang

For the toolchain under `erl/`.

- **Every module is `ern_<thing>`**, `<thing>` unique across the repository and not repeating its application, which its directory names; a vendored file keeps its upstream name. A module compiled from Ernest is `ern@<namespace>`, the path with `@` for `/` (report §11.1): `stdlib/io.ern` is `ern@io`. The log's *One Token for the Project* says why.
- **One `-export` list at the top**, in the order the functions appear *(tested)*.
- **`-spec` on every exported function** *(tested)*; a type shared between modules is a `-type` of its owner.
- **A shared record lives in `include/*.hrl`**, any other in its module. The only macros are the few constants that need a name.
- **Tokens and AST nodes are plain data**, records and tuples, never closures or ETS state. A value of more than three parts is a record, and so is a tuple of more than two that crosses modules: a positional tuple makes its reader count. A map whose keys are fixed is such a value, counted by its keys.
- **A precondition is `Cond orelse fail(...)` on one line**; two or more conditions are a `case`.
- **No OTP behaviour for the toolchain's own processes, and no rebar3**; a callback module one of OTP's servers calls, a signal handler, is no such process. The log's *No OTP in the Toolchain* says why.
- **`make` compiles with `+debug_info -Werror`**: a warning is an error.
- **Tests are EUnit**, in `erl/<app>/test/`, or in `test/` when they span applications. A test module is `<module>_tests`, or names what it tests, `ern_grammar_tests`. A test function tests one behaviour, is named after it, and has above it a comment naming what it tests: `%% report §x.y`, or a document's path.

## C

The runtime's helper, `erl/runtime/c_src/ern_exec.c`, is C99 and compiles with `-pedantic -Wall -Wextra -Werror`.

## Ernest

For every Ernest source and every Ernest block of the report and the guide. The layout `ern format` writes, and what else it keeps and changes, is report §11.6's: `make test` holds every source to it, `make format` restores it, and the Emacs mode indents as it does ([`emacs_mode.md`](../proposals/emacs/emacs_mode.md)). The writer decides the rest:

- **Top-down**: types, then the module's service bindings, then `main` or the exported functions, each followed directly by its helpers; a helper several share goes with its first user or in a utilities section at the bottom.
- **A block holds more than one statement**; one expression is written bare *(tested)*.
- **A blank line groups**, where the writer chooses. A declaration's comment or doc block stands directly above it.
- **Name a part of a long expression** where the formatter's split reads worse than a name.
- **A section's banner** is a line `//`, lines `// text`, and a line `//`, with a blank line before and after. A module with a doc block has no banner for the file; its `///` block is its header (report §2.2).
- **An exported function's parameters are named for their role**, since the shell and `ern doc` show the signature: `List.filter(list, keep)`; `xs` and `f` only where nothing more can be said.
- **A message type's constructors**: a request in the imperative, `Subscribe`; an event in the past tense, `Resized`.
- **A module of two words or more is a file of those words joined by `_`** (report §4.2): `kv_parser.ern` for `KvParser`, not `kvparser.ern`, which is the one word `Kvparser`.

Code in that layout:

    fn start(keys : Optional(Keys)) : Unit = {
        let reader = spawn(fn() = match keys {
            Some(k) -> readLoop(k)
          | None -> plainLoop()
        });
        loop(reader)
    }

    fn respond(request : Request,
               session : SessionId,
               cookies : List(Cookie),
               body : String) : Bytes with Msg =
        Response(status = statusOk, headers = [], body = body)
            |> withCookie("sid", sessionIdText(session))
            |> render

## Glossary

The names that recur across modules, one for each concept, in every module. A word is spelled as each language spells a name: `Descriptor` an Erlang variable, `descriptor` an Erlang function or field, an Ernest binding or parameter. The report is the authority: a concept it names takes its name. Drafted on 2026-10-01 from a survey of every module (MVP 2.99b's item 2), where the code departed from the report the report's word taken with the user; the renamings, items 7 and 15, corrected it as they read the code name by name. It grows as the code does, as CLAUDE.md says. A name not here is the writer's, under the rules above.

**The compiler**

- **Span**: the source a node or a diagnostic's label covers (§11.5); a token's start is its `Position`. Not `Pos` for a span.
- **Diagnostic**: an error the toolchain reports, `#diagnostic{}` (§11.5); its text is its `Message`. Not `#diag{}`, `D`, `Error`, `Msg`.
- **Env**: the names in scope as the checker reads them, the word every Hindley-Milner text uses. Not `En`, `E`. The shell's session is a `Session`, the host's variables an `Environment`.
- **TypeState**: the checker's type variables and substitution, `#type_state{}`. Not `St`, `S`.
- **Substitution**: not `S`, `Sub`, `subst`; applying one is `substitute`, not `zonk`.
- **Context**: the emitter's, `#emit_context{}`, and nothing else. Not `Cx`, `C`. The formatter's state, the descriptor builder's, a message's prefix and a source line are each named for what they hold.
- **QualifiedName**: §4.2's qualified name. Not `Q`, `QName`, `TQ`, `CQ`.
- **Namespace**: §4.2's namespace, a qualified name's prefix among it, which the AST's `namespace` field holds; beside the module's own, which the checker's env holds, a name's is the `Namespace` and the module's the `OwnNamespace`. Not `Ns`, `Prefix`, `Path`, nor `Module` for a namespace.
- **Path**: §5.6's path in a record update, `#field_set{path}`, the segments after the field's name; a file's path is a `Path`, `SourcePath`, in the build and the runner alone. The indexes through a type's arguments to a variable, which a derived `compare` follows, are a `Route`.
- **Module**: an Ernest module (§4.1); the Erlang module it compiles to is its `ErlangModule`, `ern@io`, and a build's record of one a `#build_module{}`. Not `Mod`.
- **Interface**: a compiled module's interface (§11.1), `#interface{}`. Not `Iface`, `I`.
- **Scheme**: a type scheme (§3.9), as the code has it, and beside it a declaration's requirement (§4.9), which no instance has.
- **Annotation**: a type the source writes. Not `Ann`; an AST record's `type` field holds one of the four things it holds today, each named.
- **Effect**: the `with` part of a function type, a mailbox type or an effect variable (§3.9, §6.1). Not `E`, `Eff`, `EffT`, `MailboxT`.
- **Constructor**: a constructor (§3.5, §5.6); many are `constructors`. Not `Cs`, `CI`, `cons`; `cons` is `::` alone.
- **MemberOf**: the type a member belongs to, `Stack` of `fn Stack.push` (§4.8), a declaration's `member_of`; of `a.compare` (§4.9), the type variable `a`. Not `Owner`, which is a resource's process.
- **Member**: a type's member (§4.5), `compare`, `negate` or an operator; one a requirement names is a `#member{}`, and one a body writes an `#e_member{}`. Not `Method`, `Op`.
- **Requirement**: §4.9's requirement, a `fn` declaration's `needs`, its `#member{}`s; the enclosing declarations' in force are the checker's `requirement`. Not `Needs`, `Bounds`, `Constraint`, which is §3.10's equality constraint.
- **Supply**: what a requirement's member is supplied with at a use (§4.9), a `#known_member{}`, a `#required_member{}`, a `#shown_type{}` or a key's `#type_text{}`, a `#pending_member{}` until the definition ends; many are `supplies`. Not `Witness`, `Dictionary`, `Instance`.
- **Derives**: §3.5's `derives compare`, a type declaration's `derives`.
- **Restriction**: §3.9's inferred restriction; the three are `equality`, `process_only` and `not_reply_carrying`. Not `flags`, `add_flag`, `eq`, `no_reply`.
- **Obligation**: §6.6's obligation. Not `Linear`.
- **Bound**: §3.11's type bound to its node, and what binds it, which `ern_bound:binds` answers: a function, a foreign type, a resource, or an address or a reply of a bound type. Not `Local`, `Pinned`, `Sendable`.
- **Capture**: a local a lambda's body names from around it (§6.6, §3.11), in the reply check and the bound check alike; many are `captures`. Not `Free`, `Closed`, `Env`.
- **ResultType**: §4.5's result type, and "result type" in every message. Not `ret`, `Ret`, `RetT`, `R`, "return type".
- **TypeVariable**: §3.9's type variable. A record's `vars` field is named for what it holds: a scheme's `quantified`, the type state's `variables`, the checker's `locals`.
- **Descriptor**: a type's description at run time, in the emitter, the boundary and the runtime alike. Not `D`, `Desc`, `desc`; its tag for `Address(m)` is `address`, not `pid`.
- **Token**: a token, many `Tokens`, what follows one `Rest`. Not `T`, `Ts`, `Toks`, `R`; `T` and `Ts` are a type and types in a one-line scope alone.
- **Declaration, Statement, Element, Segment, Alternative**: whole words. Not `Decl`, `Stmt`, `Elem`, `Seg`, `Alt`.
- **Doc**: §2.2's doc block, and nothing else; the pretty printer's document is named for what it lays out.

**The runtime and the command line**

- **Address**: §6.5's address. Not `Addr`, `To`, `A`; an IP address is an `IpAddress`, and `Target` is `via`'s target (§6.5) and a link's (E.17) alone.
- **Pid**: the host's process; the Ernest value is a `Process` (E.21).
- **Reply**: §6.6's reply. Not `Alias`, `Written`, `R`.
- **Cause**: a fault's cause (§7.3). Not `Msg`, `Text`; the host's stack beside it is a `Trace`.
- **Reason**: §9.3's `Reason`, and nothing else. The host's exit reason is an `ExitReason`, a host's error an `Error`. Not `Raw`, `How`.
- **Site**: §6.9's spawn site. Not `At`, `Where`.
- **Ms, Deadline**: milliseconds as given (E.0 shape rule 8) and the moment they end, as the code has them; a timer's message is `deadline` in every module.
- **Monitor**: §6.9's monitor, in the reaper as elsewhere. Not `await`, `watch`, `Waiters`. The host's reference to one is a `MonitorRef`, not `Watch`, `Mon`, `MRef`, `OwnerMonitor`.
- **Runner**: §11.2's runner, the process that starts the system processes and the entry point; the launcher is `bin/ern` alone. Not `Launcher`.
- **SystemProcess**: a system process (§8.2, §8.4). Not `Service`, `sys`; the report's service is §6.5's.
- **Run**: one execution of a restarting function's `f` (§6.9), a noun, and nothing else; a launch, a running program and a test are named as such. A test case's `run` (E.24) is the verb, the function the case runs.
- **Owner**: the process that opened a resource or was given it (§6.9, E.18), and nothing else; the type a member belongs to is its MemberOf.
- **Port**: E.18's port of a socket. A host port is named for what it runs: `Helper`, `Stty`.
- **EntryPoint, EntryProcess**: the entry point and its process (§8.1, §8.6). Not `Main`.
- **LoadPath, SourceRoot, BuildRoot**: the load path, a source root and a build root (§11.1, §11.2). Not `Roots`, `Dirs`, `OutDir`, `Root` alone.
- **Message**: a message. Not `Msg`.

**Ernest**

- A function's **subject** is named for its type, `list`, `text`, `map`, `set`, `bytes`, `path`, `table`, `process`. Not `xs`, `s`, `m`, `b`, `r`, `t`, `p`.
- A **callback** is named for its role: `keep` for a predicate that keeps, `test` for one asked of each element, as `any`, `all`, `find`, `span` and `partition` ask it, `step` for a fold's or a try's (E.0 rule 2), `wrap` for what delivers a message (E.0 shape rule 8); `f` only where nothing more can be said. Not `p`, `g`.
- **acc**: what a fold or a recursion carries. Not `done`.
- **reply**: a `Reply`. Not `r`.
- **index**: a position in a sequence (E.2, E.5); a place in a file is an `offset` (E.17). Not `at`, `i`, `from`, `start`.
- **count**: how many. Not `n`, `length`.
- **ms**: milliseconds (E.23); a moment is a `time`. Not `wait`, `t`.
- **old, new**: what `replace` takes, in every module. Not `from`, `to`.
- **cause**: as above. Not `why`, `c`, `text`.
- **error**: an error a function answers, an `Io.Error` among them. Not `e`, `why`.
- **user**: the host's number for a user, the one a file belongs to, an `Fs.Entry`'s `user`, and the one the program runs as, `Os.user` (E.17, E.23). Not `owner`, which is a resource's process, nor `uid`.
- **char**: a `Char`. Not `c`, `ch`.
- **cursor**: the place in the line being typed, in the shell's editor, region and completion. Not `at`.
- **serial**: the number the shell gives an input, which its outcome carries, `Serial` in the Erlang. Not `run`, `n`.
- A **request** constructor is the function it serves, `Read` for `read`, and where that is a prelude name, what it asks for, `ListEntries` for `list`; an **event** is in the past tense, `Resized`. Not `Recv`, `Measure`, `FarEnd`, `Resize`.
- A prelude name, `Down`, `answer`, `kill`, is not bound to another concept.
