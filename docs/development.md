# Working on Ernest

For those who work on the language and its toolchain: where things are, how to build and test them, and what the toolchain does not do yet. A reader who wants to learn Ernest starts with the [guide](../guide/language.md) instead.

The report, in three files under [`report/`](../report/), is the one normative document. How work proceeds, and which document owns which fact, is in [`CLAUDE.md`](../CLAUDE.md).

## The documents

What each document is, those under `docs/` and the READMEs that stand beside the code, is listed in [`README.md`](README.md), the index of this directory.

The prelude is the report's §9 and the standard library its Appendix E, which admits a module or a function by Appendix E.0's rules. The libraries under `src/libs/` are Appendix G's; each one's build ends every job's load path, so a program uses one without naming it (report §11.1, §11.2), and which are first-party is the plan's MVP 4.1.

## The layout of the repository

`src/` holds what a release ships, each directory named by its role, in Ernest or in Erlang; a part's host half stands beside its Ernest. `tools/` holds what works on the repository and is not shipped, and `build/` what `make` builds of both; `editors/` holds the editor modes; everything else serves the repository. `report/` and `guide/` stand at the top, since they are the language, where `docs/` holds every other document, the manual pages and the proposals among them.

```
VERSION            the release the checkout works toward, read at build time, which
                   make version sets
README.md          what Ernest is and where to begin
CLAUDE.md          the working rules
Makefile           the build and the tests' targets
LICENSE, THIRD_PARTY_LICENSES  the license, and the third-party code's
ACKNOWLEDGMENTS.md the people Ernest stands on
report/            the report (normative), in three files: language.md, §0 to §9 and
                   Appendices A, B and F; toolchain.md, §10 to §12 and Appendices C and H;
                   library.md, Appendices D, E and G
guide/             the guides: language.md, the language guide; deployment.md,
                   Running Ernest, the operator's; style.md, the rules a program
                   is written by; why.md, the argument for the design, its list
                   held equal to the README's; and faq.md
tour/              the tour, README.md, one program grown through eight chapters, and
                   1/ to 8/, the program as it stands at each chapter's end, which a
                   test holds equal to the document's blocks
site/              the website's own files, which tools/site.ern reads: templates/,
                   each page's template and its fragments, with README.md, the tokens
                   each binds; root/, the assets laid out as served, but the icons'
                   file, which the generator gathers from the icons; example.md,
                   the homepage's example, which ern_tour_tests runs on two nodes;
                   projects.md, the Projects page's list, a project a line, each
                   with its icon under root/assets/img/projects/, which a test holds
                   to its form; and unrunnable.md, the blocks a bare shell cannot
                   run, which a test holds equal to what it finds
assets/            the logos, which assets/README.md lists with where each is used
docs/              every other document, which docs/README.md lists, this one and the
                   catalog of diagnostics among them
docs/proposals/    what is designed, a directory for each proposal: the proposal, the
                   reasons for it, what other systems do, and its experiments or
                   programs; tentative until decided, and kept as a record once built
docs/man/          the pages as CommonMark, which make man writes from main and a
                   release commits: the prelude's and the standard library's under
                   stdlib/, each library's under libs/, an index in each and one over
                   them, each its directory's README.md
examples/          Ernest programs written for a reader of the language, which
                   examples/README.md lists by topic
test/              what spans the roots of src/: the integration, nodes, deployment guide,
                   tour, installation, manual pages', document, style, guide, site,
                   grammar, generated-program, shell and terminal tests; the harness of the
                   loads; bench/, the benchmark's harnesses and its memory of its runs,
                   ern_last_run; the tests of the measuring machine and of that
                   memory, ern_measure_tests and ern_last_run_tests; the service
                   manager's checks; the pseudo-terminal's harness, ern_pty, which
                   runs the Ernest program of fixtures/pty/ that make builds, and the
                   watcher of a directory's changes, ern_changes.py; ern_grammar.erl, which
                   reads Appendix A; ern_repository.erl, which the document and style
                   tests read the repository through; and ern_machine, ern_machine_node
                   and ern_machines, which run nodes on the machines of test/machines/,
                   with their tests, ern_machine_tests
test/fixtures/     what the tests read: target/, the hand-written target modules;
                   programs/, the programs the tests keep: the first test programs, a
                   two-module tree, the module of docs/module_doc_template.md and the
                   echo measurement; refused/, the README's refused program; outputs/ and emitted/, what programs/, hello,
                   services print, interpreter's session among
                   them, and the Erlang they compile to; site/, under tree/ the
                   documents the site's generator renders and the log it links to, each
                   at the path of the one it plays, config.json, the server's
                   configuration it is given, and under expected/ the pages it writes;
                   and bench/, input/, layout/,
                   load/, peers/, pty/, service/,
                   session/, stdin/ and terminal/, the programs and inputs tests run
test/machines/     machines.example.txt, the form of machines.txt, which is each user's
                   own and untracked: the machines that make bench-machines, make
                   bench-pick and nodes.sh start nodes on, a line each: its name, the
                   host ssh takes and its peers dial, and its clone of the repository
                   and the directory its nodes go in, outside the clone, or local for
                   this machine; and nodes.sh: check, each machine's commit, version and
                   floor against this checkout's; pull, each clone pulled and built by
                   make, the only writes to a clone; start, a bare node on each machine
                   on port 8654, listing every other, and a shell's directory here that
                   lists them; stop; and status
bin/               ern, the launcher, a POSIX sh script
src/toolchain/     the compiler and the command line, a directory for each: lexer,
                   parser, formatter, checker, emitter and cli, which holds the vendored
                   getopt; each its modules beside include/ and test/
src/shared/        the four modules beneath every stage and the runtime
src/nodes/         a node's configuration, carrier, gateway, exchange and arrivals, and
                   Code.load, its modules beside include/ and test/
src/runtime/       the runtime, its modules beside include/ and test/, and c_src/, the
                   helper ern_exec's C source
src/stdlib/        the standard library as Ernest source
src/libs/          the first-party libraries, each a source root whose build ends
                   every job's load path, so that a program names none: ansi, base64,
                   crypto, ets, http, which needs time and uri, json, markdown, which
                   needs ansi, proxy, time, uri and utilization; json, http and uri
                   each hold their shim beside their Ernest, ern_json.erl, ern_http.erl
                   and ern_uri.erl, http with its tests under test/
src/shell/         the shell as Ernest source under ernest/, its host half
                   ern_shell.erl, whose tests stand under test/, and README.md, which
                   guides a reader through the code
editors/emacs/     ernest-mode.el, the Emacs major mode, and its tests under test/
release/           the release archive's own files, Makefile and README.md, which
                   tools/install.sh fills with the version
.github/           ISSUE_TEMPLATE/, the form a defect is reported by, and the chooser
                   that sends a security hole to private reporting, as SECURITY.md does
tools/             the programs of the build: manual.ern writes ern(1) from the
                   report's §11, for make; site.ern, with site/ beside it, which holds
                   its helper ern_site.erl over the toolchain's lexer, writes every page of
                   the website from the repository into a directory of its own, the
                   shell page's numbers from the server's configuration, and checks
                   every link of it, for make site;
                   unicode_width.escript writes Terminal.width's
                   table, for make unicode; install.sh, with strip.escript, stages,
                   installs and archives, for make install, uninstall and release;
                   paragraphs.sh lists the long paragraphs, for make paragraphs and make
                   test-docs, and comments.sh the long comment blocks, for make comments;
                   and version.sh sets VERSION and the lines the tests hold to it, for
                   make version
build/             build products, not in git, an installation holding what it ships:
                   toolchain/<app>/ebin/, shared/ebin/, nodes/ebin/, runtime/ebin/ and
                   shell/ebin/, the toolchain's Erlang, on the host's code path;
                   runtime/priv/, the helper; stdlib/, libs/, shell/, tools/ and man/
                   from make, with the manual pages, each library's shim beside its .erc;
                   the standard library's pages in stdlib/ from make doc, and each
                   library's in libs/ too from make man; each root's test/ from the
                   tests that compile it, on no job's code path; release/ from make
                   release; dialyzer/ and dialyzer.plt from make dialyzer; sanitize/ from
                   make sanitize. The tests under test/ build beside themselves, in
                   test/ebin/ and test/build/, as an application's do
```

A module's path follows report §11.1. A file that is not a module is named with underscores, but for the Emacs mode's, which follow Emacs's convention, and the logos', which `assets/README.md` lists.

## Lists in two places

A list that lives in two places is held equal by a test where one is cheap, whose comment names both places. These are kept equal by hand, and a change to one place changes the other in its commit:

- the logo's `<picture>` block, in `assets/README.md`, the README, the release's README and the two guides that show the logo;
- the Emacs mode's tests, in `docs/design/emacs_mode.md`'s table, `editors/emacs/test/` and the Makefile's `EMACS_TESTS`;
- the stages' modules, the runtime's shims, the processes and the code table's keys in `docs/architecture.md`, against the code;
- the rows of the runtime's tables in `docs/architecture.md` and `docs/design/runtime.md`, but the names of `ern_rt`'s tables and the map's row of `ern_launch`, which a test holds;
- the frames' count in `docs/design/nodes.md`, and the frames the glossary of `docs/code_style.md` names;
- the shell's foreign functions, in `docs/design/shell.md`'s *The foreign interface* and the shell's `foreign fn`s;
- the memory's regression tests, in `docs/memory_checks.md`;
- the first-party libraries, in this document's layout, the plan's MVP 4.1, Appendix G and the libraries' directory;
- the documents, in `docs/README.md` and this document's layout;
- this document's layout of `test/` and of `tools/`, against their files;
- the launcher's flags, in `docs/design/install.md` and `bin/ern`;
- the release review's machines, in `docs/reviews/release.md` and the Makefile's targets.

## Building

Beyond what the README's *Installing* needs, the tests need python3: `make test` for the runtime's test of `Os.resize`, whose program under a terminal says its size when told it changed, and `make test-full` besides to signal `ern` in the tests of how it ends and to watch, through Linux's inotify, the files a program writes in the tests that wait for them, which therefore need Linux. `make sanitize` needs clang, and `make test-browser` Chrome or Chromium, which it says it lacks, with the status 2, where none is found. Emacs, man, and groff or mandoc are optional: where one is missing, the tests that need it say so and are skipped, and so are the Emacs mode's under an Emacs older than 29, which the mode needs.

```
make              build the helper, compile the toolchain's Erlang into build/, then
                  src/stdlib/, src/libs/, src/shell/ and tools/, and write each manual page
                  that is missing or older than what it is made from
make test         build, then the unit tests of every root, the library's doc
                  examples, the document and style tests, and the site's generator over
                  its fixture and over an export of HEAD, side by side: the light run,
                  about a minute
make test-full    build, then two phases: first the guide's tests, the Emacs mode's, the unit
                  tests, the library's, the documents', the site's, the grammar's, the typed
                  programs' and the dialyzer's, which builds its PLT once, side by side;
                  then the shell's, the site's blocks in a bare shell and the six program
                  parts, one after another,
                  each running its own tests as many at once as the host has schedulers: the
                  whole suite
make test-erl     the unit tests of every root under src/, side by side, each run from
                  the repository's root; APP=checker for one, a shim's by its library's
                  name
make test-library  the doc examples of the standard library and the libraries, with the
                  libraries' own tests, run by ern test over build/stdlib and build/libs,
                  each example a program of its own, one line where all pass, and the
                  shims' tests beside them
make test-programs  the six parts below, one after another
make test-integration  the programs compiled and run as a user runs them, the
                  signals, the streams, Os and the libraries' builds, that the
                  measuring machine reaches every function of the library, and the
                  bench's comparison of a run with the last and the release's
make test-nodes   nodes on one machine
make test-deployment  the deployment guide's commands and its deployment end to end
                  run on nodes, and the lines it quotes held to a node's
make test-tour    the tour's programs, tour/1/ to tour/8/, and its sessions run on nodes
make test-manual  the manual pages against §11, each rendered
make test-install  the installation and the release archive, installed and run
                  where they are put; after test-manual, which it runs first,
                  since both write the manual pages
make test-docs    the document tests and the style tests
make paragraphs   list every prose paragraph past about a hundred words, a list item among
                  them, for its writer to read again for a turn it may hide; test-docs lists
                  them too, and fails on none
make comments     list every comment block of the Erlang and the Ernest past about a hundred
                  words the same way; the style tests hold both at 150 words
make test-guide   the guide's examples, the report's, the README's, and the catalog of
                  diagnostics
make test-site    the site's generator, tools/site.ern, run over its fixture, the pages it
                  writes held to test/fixtures/site/expected/, every template held to the
                  tokens site/templates/README.md lists, its check of the site's links
                  refusing one that leads nowhere, each line of site/projects.md held to
                  its form, and the generator run over an export of HEAD, the
                  repository's own documents with the site's files as they stand
make test-site-shell  every block the site's pages offer the shell, and every one
                  site/unrunnable.md lists, pasted into a bare ern shell under the
                  pseudo-terminal, and the file held to those that do not run; part of
                  make test-full, about 45 seconds
make test-browser  the site's client in a headless Chrome over its DevTools protocol, the
                  fixture's pages served by OTP's httpd and a stub speaking
                  ernest-httpd's protocol at the shell's path; not part of make
                  test-full, a step of docs/reviews/release.md
make test-grammar  Appendix A read as data, and a thousand programs generated from it,
                  parsed, laid out and given as near misses; ERN_SEED=n runs a failing
                  seed again
make test-typed   well-typed programs generated, checked, compiled and run in one host,
                  each printing what an interpreter of it computes;
                  ERN_SEED=n runs a failing seed again
make test-shell   the shell's sessions and the terminal
make test-emacs   the Emacs mode's tests (docs/design/emacs_mode.md)
make load         the loads of docs/memory_checks.md; not part of make test-full, whose
                  test-integration builds their programs and the benchmark's
make service      a program run by the host's service manager, a user's systemd or
                  launchd: started, stopped, started again after Os.exit(1); not
                  part of make test-full
make bench        what each of a few operations costs in Ernest beside the same operation
                  in Erlang, in nanoseconds, a raise at each backtrace depth among them, in
                  test/build/bench/bench.txt; then every function of the library beside the
                  host's, at 10, 100 and 10,000, its time and what it allocates, with what
                  costs more than three times the host's and whether the machine was idle,
                  the whole table in library.txt; then, between two nodes on this machine,
                  the host's ping over TLS and over TCP, a call to the other node's
                  process, and a round trip to it straight and through an adapted address
                  made there, in nodes.txt; then, on nodes it starts, what a spawn and a
                  compute cost whose code crosses, each step of the exchange, a fix's
                  callers, what an arrival, a Code.load and a day's spawns add to the
                  host's counts, a utilization, a compute on a peer picked and on one
                  named, the pick alone, what connected nodes exchange idle with their
                  tellings, and the sizes of an .erc and a code frame, in code.txt; then
                  Ernest's spawn, spawnMonitored and monitor beside the host's, on every
                  scheduler and on one, and the spawn alone with no end between, in
                  spawn.txt, spawn_monitored.txt and monitor.txt; then entering restarting
                  beside the host's try, with a hundred messages waiting too, in
                  restarting.txt; then four bursts at 1,000, 5,000 and 25,000, a process's
                  monitors of processes that end, callers of one process that end,
                  deliveries in flight to one process, started and delivered, and a
                  process's alarms firing at once, each element's time beside the smallest
                  burst's, in burst.txt; then what each piece of a foreign call adds to the
                  host's call, by the type of its result, a model of a foreign fn a piece
                  at a time, each operation alone, and the host's call, the foreign fn and
                  the look's key by one process, by eight at once and by one on each of the
                  host's schedulers, in foreign.txt; then what each piece of Address.call
                  adds to the host's call of the same shape, with one caller and one callee,
                  eight pairs, eight callers of one callee, and those two again at the
                  host's schedulers, and each of the call's writes alone by one process, by
                  eight and by the host's schedulers, in call.txt; then a top-level let's
                  read, a receive with an after,
                  a message to a system process, a bare launch with its pieces and an
                  input at the shell's prompt in line mode, at a session's start and after a
                  thousand declarations, each beside the host's, in rules.txt; then each
                  construct the compiler writes code for, a match and one whose guards call
                  functions, a record update, a Float operation and an expression of five,
                  an Int operation, a derived compare, a requirement's member, a string's
                  concatenation and slice, a map's read and write, List.map, a send and a
                  receive, Io.show, a function value's call and a lambda made, each beside
                  the plain Erlang a programmer writes, the two measured together, in
                  language.txt; then three programs
                  written twice, the ray tracer's pure half, examples/interpreter.ern's lexer,
                  parser and evaluator over a fixed input, and the guide's counter with its
                  callers, each Ernest program's time over its Erlang twin's, the twins
                  under test/fixtures/bench/, in programs.txt; and last, every row that
                  moved by more than a fifth against the last run, whose tables
                  test/build/bench/last/ keeps, and against the release's, whose tables
                  test/build/bench/release/ keeps, each under its reference, printed and
                  written to moved.txt with the rows on either side that match none of the
                  other's, a table with a ratio by its ratios and any other by its numbers,
                  the library's table left out; the memory is kept a table at a time, each
                  table moved to last/ as a run that writes it begins, so that a part's run
                  below keeps and compares its own; about ten and a half minutes; not part of make
                  test-full. A row is for a number a later change could move, a promise of
                  CLAUDE.md's cost rules or a construct the emitter writes code for; a
                  number measured once to settle a design is the log's
make bench-<part>  one part of make bench alone, its tables alone kept and compared:
                  bench-core, bench-library, bench-nodes, bench-code, bench-spawn,
                  bench-restarting, bench-burst, bench-foreign, bench-call, bench-rules,
                  bench-language and bench-programs, bench-library comparing nothing
make bench-release  keep the tables the last runs of make bench and its parts wrote, a
                  table at a time, in test/build/bench/release/ as the release's run,
                  which every later run is compared with too, and name them; the release
                  review runs it, and so does the first run on a new machine, which is a
                  new reference and not a move; make clean removes it with the rest of
                  test/build/
make bench-machines  make bench's two node parts across the machines of
                  test/machines/machines.txt, each checked against this checkout
                  first: the store on the first machine after this one and the desk
                  here, with the host's ping over TCP between the two; then the
                  code's nodes over the machines after this one in turn, the
                  measuring node here; each part's table in test/build/bench/, in
                  nodes-machines.txt and code-machines.txt; run by hand, on the user's
                  machines alone, and not part of make test-full
make bench-pick   the push's experiment, the log's *The Numbers Across Machines*
                  across the machines of test/machines/machines.txt: from a measuring
                  node, a burst of a hundred computes of a hundred milliseconds' work and
                  a stream of one every 50 ms for a minute, counted on each peer under
                  Peer.compute's pick and under the least busy over Peer.utilizations(),
                  with their round trips, the packets each connection carried a second,
                  each node's schedulers busy and each machine's processors idle, over
                  the stream and at rest; by default the measuring node here and bare
                  nodes, one on each other machine, then as many as its processors, the
                  stream again at utilization-interval 1000 and 500; MEASURING=name puts
                  the measuring node on that machine, PEERS=desk:2,lab:4 names the
                  peers, INTERVALS=1000,500 the intervals the last arrangement's
                  stream runs again at, RUNS=7,3 the bursts and streams,
                  UTILIZATION=schedulers how every node measures its utilization,
                  run-queue or schedulers as Appendix C spells them, the
                  configuration's default, run-queue, where it is left out; its table in
                  test/build/bench/pick-machines.txt, each run's lines in
                  test/build/bench/pick-machines-raw/; about 32 minutes by default; run
                  by hand, on the user's machines alone, and not part of make test-full
make doc          write the standard library's and the prelude's pages to build/stdlib/,
                  with index.md
make man          write every page: the manual pages make writes, and docs/man/, main's pages
                  as CommonMark, the standard library's, the prelude's and each
                  library's, with their indexes (docs/reviews/release.md)
make manual       the manual pages alone, which make also writes: each module's beside
                  its .erc, as build/stdlib/Ernest.List.3ern, and ern(1) as
                  build/man/ern.1, which man -l shows
make install      install under PREFIX, /usr/local by default, within DESTDIR if one
                  is given (docs/design/install.md)
make uninstall    remove the installation under the same PREFIX and DESTDIR
make release      write the release archive, build/release/ern-VERSION.tar.gz, which says its
                  commit after the version where the checkout is not at the release's tag
make site TAG=v0.x.y CONFIG=path/to/config.json
                  write the website into build/site/ from the release TAG names, given the
                  server's configuration: the tag exported into build/site-source/, the
                  toolchain built there and make man run there, then the tag's generator
                  run over it, every link of the site checked; it refuses a tag that holds
                  no site/; TAG=HEAD, or any commit, builds a site whose links to GitHub name
                  the commit; about 35 seconds, nearly all of them the export's build
make version V=x.y.z
                  set VERSION, the release the checkout works toward, and every line the
                  tests hold to it, the documents' start lines and the session fixtures',
                  by tools/version.sh, then write every page as make man does
                  (docs/reviews/release.md, step 5)
make dialyzer     Dialyzer over the toolchain and the Erlang the compiler writes for
                  src/stdlib/, src/shell/ and src/libs/; its first run builds
                  build/dialyzer.plt; part of make test-full
make sanitize     the helper in C under Clang's analyzer, and the runtime's and the
                  programs' tests with it built under the sanitizers
make sections     list the report sections no test cites
make xref         the document tests alone, without a build: every citation and
                  document path resolves
make coverage     every section with how many tests cite it and its length, thinnest first
make golden       rewrite test/fixtures/emitted/, the Erlang the compiler emits for each
                  program `golden_names/0` lists: test/fixtures/programs/, hello and
                  services
make diagnostics  rewrite the outputs of docs/diagnostics.md, the errors the lexer, the
                  parser, the checker and the build give, from what ern build prints
make contents     rewrite the contents lists of the report and the guide from their headings
make site-expected  rewrite test/fixtures/site/expected/, the pages the site's generator
                  writes from its fixture, after a change to the look or the generation
                  that is meant
make site-unrunnable  rewrite site/unrunnable.md, the blocks the site's pages offer the
                  shell that a bare shell cannot run, which the generator gives Copy
                  alone, saying what the shell answered each; test-site-shell holds it
make format       lay out every Ernest module, and the Ernest blocks of the report and the
                  guide, as ern format does (report §11.6)
make unicode UC_SPEC=dir
                  write Terminal.width's table from Unicode's data in dir, OTP's
                  lib/stdlib/uc_spec of the host's version
make clean        remove every build product: build/, the tests' test/build/ and test/ebin/,
                  every compiled module beside its source and every crash dump; a node's
                  .ernest/ directory, which holds a key, is left
make clean-emacs  remove Emacs backup, auto-save, and lock files
```

While a change is worked on, it runs the targets of its kind; which run a commit needs is CLAUDE.md's *Tests*.

| A change to | Runs |
|---|---|
| the Erlang of one root | `make test-erl APP=<root>`, then `make test`; the parser and the formatter `make test-grammar` too, the checker and the emitter `make test-typed` |
| the runtime | `make test`, `make test-integration` |
| nodes, or the deployment guide | `make test`, `make test-nodes`, `make test-deployment` |
| the standard library, or a library under `src/libs/` | `make test-library`, then `make test`, `make test-integration` |
| the shell | `make test`, `make test-shell` |
| the installation, the release, or the manual pages | `make test-install`, which runs `test-manual` first; the pages alone `make test-manual` |
| the Emacs mode | `make test-emacs` |
| the language guide, the report, the README, `docs/diagnostics.md` or `docs/module_doc_template.md` | `make test`, `make test-guide`; report Appendix A `make test-grammar` too, report §11 `make test-manual` and `make test-shell` |
| the tour, its document or a chapter's program | `make test`, which holds its blocks to its files, and `make test-tour`, which runs its sessions |
| the site's templates, its assets or its generator | `make test-site`, then `make test`; which blocks get Paste and Load `make test-site-shell` too, and the client in `site/root/assets/js/` `make test-browser` |
| a document's blocks that the site offers the shell, the guide's, Why's and the library's pages | `make test-site-shell`, and `make site-unrunnable` where a block a bare shell cannot run is meant |
| the site's build, `make site` | `make test-site`, then `make site TAG=HEAD CONFIG=test/fixtures/site/config.json` |
| a proposal, or any other document | `make test-docs` |
| a path `make bench` measures | the part of `make bench` that measures it, `make bench-<part>`, beside the targets of its kind |

Which programs the tests compile and run is [`architecture.md`](architecture.md)'s *Tests*.

One root's test module runs alone as the suite runs it: its test beam by `make -s build/shared/test/ern_chunk_tests.beam`, then, from the repository's root, `ERN_TEST_DIR=$(mktemp -d) erl -noshell -pa build/*/ebin build/toolchain/*/ebin build/runtime/test build/shared/test -eval 'eunit:test(ern_chunk_tests, [])' -s init stop`. A whole `make test-full` takes about ten minutes: run it with its output in a file, and read the file for "timed out" and for EUnit's word for a canceled test, which it spells the British way, beside "failed", since EUnit prints `Failed: 0` beside a canceled test.

## Using

`bin/ern` is the toolchain, its first word the job, with long options only (report §11). Where the guide writes `ern`, this repository's `bin/` is on the `PATH`.

```
bin/ern build examples/hello.ern                  # writes examples/hello.erc
bin/ern run examples/hello.erc                    # hello, world
bin/ern build --build-root build/modules test/fixtures/programs/modules  # a tree, in dependency order
bin/ern run build/modules/main.erc                # loads net/http.erc by namespace
bin/ern build --emit-erl examples/hello.ern       # the Erlang source, for reading
bin/ern doc src/stdlib/list.ern                   # the module's documentation as CommonMark
bin/ern config --config-dir a                     # a/ with a key pair, which only dials, its key printed
bin/ern config --config-dir b --listen 127.0.0.1:8655  # b/, which listens there
bin/ern config --config-dir a --peer-dir b        # a's ernest.conf lists the node of b/
bin/ern reload --config-dir node                  # the node running from node/ reads its ernest.conf again
bin/ern stop --config-dir node                    # and ends, in order
bin/ern shell                                     # a shell over the standard library
bin/ern shell build/modules/main.erc              # a shell beside a running program
bin/ern test build/shell/ernest/shell/editor.erc  # the module's tests
bin/ern test build/libs                           # the tests of every module under it
```

A program whose source tree `app` uses a library of the toolchain's own, `Ets` or `Markdown`, names no flag for it: the build of each library under `build/libs` ends every job's load path (report §11.1, §11.2). A library of one's own is added with `--load-path`, both to build and to run:

```
bin/ern build --load-path ../mylib/build --build-root build/app app
bin/ern run --load-path ../mylib/build build/app/main.erc
```

The shell's `:help` lists its commands; the language guide §9.3 teaches the shell, report §11.2 defines it, and [`design/shell.md`](design/shell.md) says how it is built.

## What the toolchain accepts

The toolchain is the report, on one node and across nodes. Everything the report describes type-checks, compiles and runs: no construct waits for a later milestone today. Where one does, it stands here as a row of a table, what the toolchain refuses or does not yet do, with the milestone of the [plan](plan.md) that lifts it.

Every refusal the toolchain makes for a later milestone's sake says `… is not implemented` in its error text and names no milestone, which the row here names, and `unimplemented_listed_test` in `src/toolchain/cli/test/ern_cli_tests.erl` fails when such a text is missing from this section. Runtime behavior that stands in for a later milestone is listed by hand. `make sections` prints only a section of a milestone not yet built, which that milestone's plan item names.
