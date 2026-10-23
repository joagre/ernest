# The repository's build and its checks. `make` builds the toolchain's
# applications under erl/, each by its own src/Makefile over the rules
# erl/app.mk keeps once, the runtime's helper in C, and the standard
# library, the shell, the libraries and the tools written in Ernest; `make
# test` runs every test by area; docs/development.md names every other
# target and what it is for.

APPS = shared lexer parser formatter checker runtime emitter cli json

# The jobs a make runs side by side, as many as the host has cores.
JOBS := $(shell getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)

# Every Ernest source of the repository, which `make format` lays out and
# the Emacs mode's tests read (report §11.6, docs/design/emacs_mode.md).
ERNEST_SOURCES = src/stdlib/*.ern src/shell/*.ern src/shell/shell/*.ern examples/*.ern \
		examples/upgrade/*/*.ern \
		test/fixtures/*/*.ern test/fixtures/programs/modules/*.ern \
		test/fixtures/programs/modules/*/*.ern \
		src/libs/*/*.ern tools/*.ern

# The Ernest trees, src/stdlib/, src/libs/, src/shell/ and tools/, are built by `ern build`
# every time, and its own rule decides what in each to compile again, by the
# sources' and the interfaces' hashes (report §11.1): make keeps no stamp of
# its own, whose times would disagree with the sources' contents. Each
# module is one file, its .erc, which ern loads by its namespace as it is
# first called (report §11.2), and the host's code path holds none.

# The helper that runs a program for Os.run (report Appendix E.23), written
# in C since the host's ports cannot keep a program's standard error apart,
# end its input while its output is read, or kill it.
EXEC = erl/runtime/priv/ern_exec

all: $(EXEC)
	@$(MAKE) $(SIDE_BY_SIDE) -O $(APP_BUILDS)
	@$(MAKE) -s manual

# The applications under erl/, side by side, since none needs another's
# compiled code to compile: they share headers alone, which each
# src/Makefile names. One make runs them, as many at once as the host has
# cores, or within the count of a make that already runs jobs side by side,
# as make test-full's phases do, since a make started with a -j of its own
# runs apart from the count.
SIDE_BY_SIDE = $(if $(findstring jobserver,$(MAKEFLAGS)),,-j$(JOBS))
APP_BUILDS = $(APPS:%=app-%)
$(APP_BUILDS): app-%:
	@$(MAKE) -C erl/$*/src all

$(EXEC): erl/runtime/c_src/ern_exec.c
	@mkdir -p $(dir $@)
	$(CC) -std=c99 -pedantic -O2 -Wall -Wextra -Werror -o $@ $<

# The standard library written in Ernest: src/stdlib/ compiled by ern build
# into build/stdlib, where the checker reads its interfaces and a run loads
# its modules (report §11.1, plan MVP 2.5). ern build recompiles what a
# changed compiler changes (report §11.1).
stdlib:
	@bin/ern build --verbose --build-root build/stdlib src/stdlib

# The libraries (plan, MVP 3.2): each src/libs/<name>/ is a source root of
# its own, compiled into build/libs/<name>, which ends every job's load path
# (report §11.1, §11.2), each after the standard library and beside the
# others, but libs/markdown, which writes its styles with libs/ansi (report
# Appendix G.3) and is compiled after it, against it. A job waits on no
# build it does not read, so that a make with nothing to do is as deep as
# the builds' uses and no deeper (the log's *A Make With Nothing to Do*). A
# library whose directory is gone has its build removed with it.
LIBS = $(sort $(notdir $(patsubst %/,%,$(wildcard src/libs/*/))))
LIB_BUILDS = $(LIBS:%=lib-%)
libs: $(LIB_BUILDS)
	@for d in build/libs/*/; do [ -d "src/libs/$$(basename $$d)" ] || rm -rf "$$d"; done

lib-markdown: lib-ansi
	@bin/ern build --verbose --source-root src/libs/markdown --build-root build/libs/markdown \
	  src/libs/markdown

$(filter-out lib-markdown,$(LIB_BUILDS)): lib-%: stdlib
	@bin/ern build --verbose --source-root src/libs/$* --build-root build/libs/$* src/libs/$*

# The shell, written in Ernest (report §11.2, plan MVP 2.6): src/shell/
# compiled by ern build into build/shell, where `ern shell` loads it by
# namespace, with libs/ansi and libs/markdown, which it renders and styles
# documentation with and is compiled against, from their builds under
# build/libs.
shell: lib-ansi lib-markdown
	@bin/ern build --verbose --build-root build/shell src/shell

# The standard library's pages, one per module beside its .erc in
# build/stdlib, and index.md listing them (report §11.4).
doc: all
	@$(MAKE) -s pages-stdlib

# The pages in CommonMark (report §11.4), each beside its module's .erc,
# with index.md listing them: the prelude's and the standard library's in
# build/stdlib, and each library's in build/libs/<name>. `ern doc` reads
# each module from its .erc, which make has built, and compiles nothing.
PAGES = pages-stdlib $(LIBS:%=pages-%)
pages-stdlib:
	@bin/ern doc --build-root build/stdlib src/stdlib

$(LIBS:%=pages-%): pages-%:
	@bin/ern doc --source-root src/libs/$* --build-root build/libs/$* src/libs/$*

# The manual pages (report §11, §11.4): the prelude's and every standard
# library module's, beside the modules' .erc in build/stdlib, each
# library's beside its own in build/libs, and ern(1), §11 of the report,
# which tools/manual.ern writes into build/man with the standard library's
# pages in its SEE ALSO. make writes them, so that make install, which a
# user may run as another, only copies. What they are made from is built
# first: the trees, and libs/markdown, which lays a page out, and which
# `ern doc --man` loads from build/libs/markdown. The shell is built
# beside the pages, and every job runs side by side with those it does not
# need. `ern doc` writes a page only where none is there or the one there
# is older than what it is made from (report §11.4), and make writes ern(1)
# likewise by its prerequisites, so that a make with nothing to do writes
# none. ern(1) is made by a make of its own, which reads build/stdlib after
# `ern doc` has written there. A page is written whole or not at all.
MANUALS = manual-stdlib $(LIBS:%=manual-%)
manual:
	@$(MAKE) -s $(SIDE_BY_SIDE) -O shell tools $(MANUALS)
	@$(MAKE) -s build/man/ern.1

manual-stdlib: stdlib lib-markdown
	@bin/ern doc --man --build-root build/stdlib src/stdlib

$(LIBS:%=manual-%): manual-%: lib-% lib-markdown
	@bin/ern doc --man --source-root src/libs/$* --build-root build/libs/$* src/libs/$*

# ern(1)'s SEE ALSO names the pages in build/stdlib, so the directory is a
# prerequisite: its time changes whenever a file there is written, added or
# removed, a page among them, and a make with nothing to do changes none.
build/man/ern.1: report/toolchain.md build/tools/manual.erc VERSION build/stdlib
	@mkdir -p build/man
	@bin/ern run --verbose build/tools/manual.erc \
	  report/toolchain.md $$(cat VERSION) build/stdlib > $@.new
	@mv $@.new $@

# Every page: the manual pages make writes, and main's pages as CommonMark
# in docs/man/, which GitHub shows and a release commits
# (docs/release_review.md, step 5): the prelude's and the standard
# library's under docs/man/stdlib, with the index ern doc writes (report
# §11.4); each library's under docs/man/libs/<name>, with an index linking
# them; and an index over the two, which links the report's §11 for ern
# itself, two directories up. Each index is its directory's README.md,
# which GitHub shows when the directory is opened. They are written beside
# the build's .erc and copied, replacing docs/man/ whole, so a page whose
# module has gone goes.
man: all
	@$(MAKE) -s $(SIDE_BY_SIDE) -O $(PAGES)
	@rm -rf docs/man && mkdir docs/man
	@cd build && find stdlib $(LIBS:%=libs/%) -name '*.md' ! -name index.md | tar cf - -T - \
	  | (cd ../docs/man && tar xf -)
	@cp build/stdlib/index.md docs/man/stdlib/README.md
	@{ printf '# Libraries\n\n'; \
	  for n in $(LIBS); do \
	    sed -n "s|^- \[\(.*\)\](\(.*\))\$$|- [\1]($$n/\2), \`libs/$$n\`|p" \
	      build/libs/$$n/index.md; done; \
	} > docs/man/libs/README.md
	@v=$$(cat VERSION); { \
	  printf '# The manual pages\n\n'; \
	  printf 'The pages `ern doc` wrote from `main` when `make man` last ran, the last '; \
	  printf 'release then being Ernest %s; a module or a declaration that appeared ' "$$v"; \
	  printf 'after it ends its doc block with the release that brings it. A page holds a '; \
	  printf 'module'"'"'s doc block, then its declarations, each with its type and its '; \
	  printf 'own doc block (report §11.4). Where Ernest is installed, `man Ernest.List` '; \
	  printf 'shows a module'"'"'s page and `man ern` the toolchain'"'"'s.\n\n'; \
	  printf -- '- [The prelude and the standard library](stdlib/README.md)\n'; \
	  printf -- '- [The libraries under `src/libs/`](libs/README.md)\n'; \
	  printf -- '- [`ern`, the toolchain and its shell](../../report/toolchain.md#11-toolchain), '; \
	  printf 'the report'"'"'s §11, whose §11.2 gives the shell'"'"'s commands\n'; \
	} > docs/man/README.md

# The installation (docs/design/install.md): the toolchain's tree under
# $(PREFIX)/lib/ernest, bin/ern a link to its launcher, and the manual
# pages, the documents and the Emacs mode under $(PREFIX)/share, each path
# after $(DESTDIR), which a packager passes. make install stages the tree
# in a directory of its own outside the checkout, so that one run as
# another user writes nothing into it, and installs what it staged; make
# uninstall removes what the installation put there. Neither changes
# anything where a directory it must write cannot be written.
PREFIX = /usr/local
DESTDIR =

install: all
	@stage=$$(mktemp -d) && trap 'rm -rf "$$stage"' EXIT && \
	  sh tools/install.sh stage "$$stage/ernest" && \
	  sh tools/install.sh install "$$stage/ernest" "$(DESTDIR)" "$(PREFIX)"

uninstall:
	@sh tools/install.sh uninstall "$(DESTDIR)" "$(PREFIX)"

# The release archive, build/release/ern-$(VERSION).tar.gz: the tree make
# install stages, the helper as its C source, which the archive's own make
# compiles where it is installed, and a Makefile and a README of its own
# from tools/release (docs/design/install.md).
release: all
	@sh tools/install.sh release build/release $$(cat VERSION)

# The programs of the build written in Ernest, tools/*.ern, compiled into
# build/tools against libs/markdown and libs/ansi, which it writes with.
tools: lib-ansi lib-markdown
	@bin/ern build --verbose --build-root build/tools tools

# Terminal.width's table in src/stdlib/terminal.ern, from the Unicode
# data of the version the host's grapheme segmentation follows: UC_SPEC is
# a directory holding EastAsianWidth.txt, emoji-data.txt and
# UnicodeData.txt, as OTP's source tree has in lib/stdlib/uc_spec.
unicode:
	@test -n "$(UC_SPEC)" || { echo "UC_SPEC=dir is required"; exit 1; }
	@escript tools/unicode_width.escript $(UC_SPEC)

# The tests by area (plan, MVP 2.6), in two runs (MVP 3.9). `make test` is
# the light run, for every commit: the applications' unit tests, the
# library's examples, and the tests of the documents and the style. `make
# test-full` is every area, for the commit that closes a plan item and for
# a release. The light run and the full run's first phase run their jobs
# side by side, as many at once as the host has cores, each job's output
# together as it ends. One make runs each phase, since a make started with
# a -j of its own runs apart from the count, and takes `all` as made (-o),
# since the run made it before the phase. In the full run the unit tests
# run first, with the jobs that start no host: EUnit gives a test with no
# time of its own five seconds, which the load of the areas that start
# hosts would take from them. Make starts those jobs in the order given, so
# the longest come first. The
# areas that start hosts then run one after another, each whatever the one
# before it ended with: each runs its own tests side by side, as many at
# once as the host has schedulers (test/Makefile), which is what the host
# carries, and the six side by side ran six times as many, at a load of
# about 117 on eight cores on 2026-10-13, where tests ran past their
# limits. The tests of the applications run in parts, and in the full run
# the modules under test/, are compiled first, once, so that no two parts
# compile one module at once. A change runs its own area's target as it is
# worked on (docs/development.md, *Building*).
test: all
	@for a in $(SPLIT_APPS); do $(MAKE) -s -C erl/$$a/src beams || exit 1; done
	@$(MAKE) -s -j$(JOBS) -O -o all $(APP_JOBS) test-library test-docs

test-full: all
	@$(MAKE) -s -C test beams
	@for a in $(SPLIT_APPS); do $(MAKE) -s -C erl/$$a/src beams || exit 1; done
	@$(MAKE) -s -j$(JOBS) -O -o all test-guide $(EMACS_JOBS) $(APP_JOBS) test-library \
	  test-docs test-grammar test-typed
	@$(MAKE) -s -j1 -k -o all test-shell $(PROGRAM_PARTS)

# The unit tests of the applications under erl/, side by side, or of one
# with APP=checker. The runtime's tests are compiled first, since the
# emitter's call one of their modules, ern_named.
APP_TESTS = $(APPS:%=test-app-%)
ifdef APP
test-erl: all
	@$(MAKE) -s -C erl/runtime/src beams
	@$(MAKE) -C erl/$(APP)/src test
else
test-erl: all
	@$(MAKE) -s -C erl/runtime/src beams
	@$(MAKE) -s -j $(APP_TESTS)
endif

$(APP_TESTS): test-app-%:
	@$(MAKE) -s -C erl/$*/src test

# The emitter's, the runtime's and the command line's tests run programs and
# wait on them, so make test runs each in three hosts at once, every third
# test in each.
SPLIT_APPS = emitter runtime cli
APP_PARTS = $(foreach a,$(SPLIT_APPS),$(addprefix test-app-$(a)-,0 1 2))
APP_JOBS = $(APP_PARTS) $(filter-out $(SPLIT_APPS:%=test-app-%),$(APP_TESTS))

$(APP_PARTS): test-app-%:
	@$(MAKE) -s -C erl/$(firstword $(subst -, ,$*))/src test PARTS=3 \
	  PART=$(lastword $(subst -, ,$*))

# The library's doc examples, the standard library's and the libraries',
# with the libraries' own tests, each a case `ern test` runs over the
# library's build, an example a program of its own (report §11.2, Appendix
# E.0 shape rule 6): one line where every case passed, and all `ern test`
# wrote where one did not.
test-library: all
	@out=$$(mktemp "$${TMPDIR:-/tmp}/ern_library_XXXXXX") || exit 1; \
	  bin/ern test build/stdlib > "$$out" 2>&1; stdlib=$$?; \
	  bin/ern test build/libs >> "$$out" 2>&1; libs=$$?; \
	  if [ $$stdlib -eq 0 ] && [ $$libs -eq 0 ]; then \
	    echo "  All $$(grep -c ': passed$$' "$$out") cases of build/stdlib and build/libs passed."; \
	    status=0; \
	  else cat "$$out"; status=1; fi; \
	  rm -f "$$out"; exit $$status

# The areas under test/: the programs in six parts, the documents and the
# style, the guide's examples, the grammar with the programs generated from
# it, the well-typed programs generated and run, and the shell with the
# terminal. The programs' parts are nodes on one machine, the manual pages,
# the installation with the release archive, the deployment guide run on
# nodes, the tour's programs and sessions run on nodes, and the example
# programs with the signals and the streams;
# test-programs runs them one after another, as the full run does.
# test-manual and test-install both write the manual pages under
# build/stdlib, `ern doc --man` there and make install's `make manual`, so
# test-install runs after test-manual, always: alone it pays the pages'
# test, about 5 s, for a rule with no case.
PROGRAM_PARTS = test-nodes test-manual test-install test-deployment test-tour test-integration
test-programs:
	@$(MAKE) -s -j1 -k $(PROGRAM_PARTS)
test-integration: all
	@$(MAKE) -C test integration
test-nodes: all
	@$(MAKE) -C test nodes
test-deployment: all
	@$(MAKE) -C test deployment
test-tour: all
	@$(MAKE) -C test tour
test-manual: all
	@$(MAKE) -C test manual
test-install: all test-manual
	@$(MAKE) -C test install
test-docs:
	@$(MAKE) -C test docs
	@sh tools/paragraphs.sh

# The prose paragraphs past about a hundred words, for their writer to read
# again (CLAUDE.md, *Writing*); test-docs lists them too, and fails on none.
paragraphs:
	@sh tools/paragraphs.sh
test-guide: all
	@$(MAKE) -C test guide
test-grammar: all
	@$(MAKE) -C test grammar
test-typed: all
	@$(MAKE) -C test typed
test-shell: all
	@$(MAKE) -C test shell

# The loads of docs/memory.md, which a release runs (docs/release_review.md).
load: all
	@$(MAKE) -C test load

# The service manager's checks, which a release runs (docs/release_review.md).
service: all
	@$(MAKE) -C test service

# The benchmark, every part in order: what an Ernest operation costs beside
# the same operation in Erlang (test/ern_bench.erl), every function of the
# library beside the host's (test/ern_measure.erl), and the parts after them
# that test/Makefile names, each table compared with its last run and the
# release's.
bench: all
	@$(MAKE) -C test bench

# Each part of the benchmark alone, its tables alone compared (plan, MVP
# 3.295): bench-core, bench-library and the rest, as test/Makefile names
# them; make bench whole is the closing run before a commit that closes a
# plan item.
BENCH_PARTS = core library nodes code spawn restarting burst foreign call rules language programs
$(addprefix bench-,$(BENCH_PARTS)): all
	@$(MAKE) -C test $@

# The last runs' tables kept as the release's, a table at a time, which every
# later run is compared with too; the release review runs it
# (docs/release_review.md), and so does a first run on a new machine.
bench-release:
	@$(MAKE) -C test bench-release

# The bench's two node parts across the machines of
# test/machines/machines.txt (the log's *The Machines*), each machine checked
# against this checkout first; run by hand, on the user's machines.
bench-machines: all
	@$(MAKE) -C test bench-machines

# The push's experiment across the machines of test/machines/machines.txt
# (the log's *The Numbers Across Machines*), each machine checked against this checkout
# first; run by hand, on the user's machines, with MEASURING, PEERS,
# INTERVALS, RUNS and UTILIZATION as test/Makefile says.
bench-pick: all
	@$(MAKE) -C test bench-pick

# The Emacs mode's tests (docs/design/emacs_mode.md). It is an editor and not
# part of the toolchain, so a machine without Emacs skips them; they are
# the only tests `make test-full` will run and not have built. `format` runs
# `ern format`, so the toolchain is built first. EMACS names the Emacs to
# run them under: `make test-emacs EMACS=/opt/emacs-29/bin/emacs`.
EMACS ?= emacs
EMACS_TESTS = flatten reindent format lint color editing broken
# typing.el costs the square of a file's length, so it runs in four parts,
# the largest files in different parts, the longest jobs first.
TYPING_PARTS = $(addprefix emacs-test-typing-,0 1 2 3)
EMACS_ALL = $(TYPING_PARTS) $(EMACS_TESTS:%=emacs-test-%)
EMACS_JOBS = $(if $(shell command -v $(EMACS) 2>/dev/null),$(EMACS_ALL),test-emacs)
test-emacs: all
	@if ! command -v $(EMACS) >/dev/null 2>&1; then \
	  if [ "$(origin EMACS)" = file ]; then \
	    echo "  Emacs not installed; the mode's tests were skipped."; exit 0; fi; \
	  echo "  $(EMACS): no such Emacs"; exit 1; fi
	@$(MAKE) -s -j $(EMACS_ALL)

# One Emacs test, each in an Emacs of its own, so they run side by side.
$(EMACS_TESTS:%=emacs-test-%): emacs-test-%:
	@cd editors/emacs && $(EMACS) -Q -batch -l test/$*.el $(EMACS_CORPUS)

$(TYPING_PARTS): emacs-test-typing-%:
	@cd editors/emacs && PARTS=4 PART=$* $(EMACS) -Q -batch -l test/typing.el $(EMACS_CORPUS)

clean:
	@for app in $(APPS); do $(MAKE) -C erl/$$app/src $@ || exit 1; done
	@$(MAKE) -C test $@
	@# every build product is under build/, which make writes again; a compiled
	@# module beside its source, and a crash dump, are left wherever a run put them
	@rm -rf build $(EXEC)
	@find . -path ./build -prune -o \( -name '*.erc' -o -name 'erl_crash.dump' \) -type f -print0 \
	  | xargs -0 rm -f

# Rewrite test/fixtures/golden/*.erl, the Erlang source the compiler emits for
# every program of test/fixtures/programs/ and services, after an intended change
# to the emitter.
golden: all
	@$(MAKE) -s -C erl/emitter/src ../ebin/ern_emitter_tests.beam
	@cd erl/emitter/src && erl -noshell -pa ../../*/ebin \
	  -eval 'ern_emitter_tests:write_golden(), halt().'

# Dialyzer over the toolchain's Erlang, its tests aside, and over the Erlang
# the compiler writes for the standard library, the shell and the
# libraries, each .erc copied into build/dialyzer under its module's name,
# since Dialyzer reads a module only from a file whose name ends in .beam
# (docs/release_review.md). The table of the host's applications the
# toolchain calls is built once, into build/dialyzer.plt, and Dialyzer
# checks it against the host at each run. A function one of those
# applications calls in another the table does not hold, os_mon's alarms
# in sasl, is the host's and not the toolchain's, and is not said as the
# table is built, where it ended the first run with status 2.
DIALYZER_APPS = erts kernel stdlib compiler syntax_tools crypto public_key asn1 parsetools \
		os_mon
dialyzer: all
	@test -f build/dialyzer.plt || dialyzer --build_plt -Wno_unknown \
	  --output_plt build/dialyzer.plt --apps $(DIALYZER_APPS)
	@rm -rf build/dialyzer && mkdir -p build/dialyzer
	@for d in build/stdlib build/shell build/libs/*; do (cd $$d && find . -name '*.erc') \
	  | while read -r f; do m=$${f#./}; \
	    cp $$d/$$m build/dialyzer/ern@$$(echo $${m%.erc} | tr / @).beam; done; done
	@dialyzer --plt build/dialyzer.plt $(filter-out %_tests.beam,$(wildcard erl/*/ebin/*.beam)) \
	  build/dialyzer/*.beam

# The helper in C under Clang's static analyzer and under the address and
# undefined-behavior sanitizers (docs/release_review.md): the analyzer
# over its source, which must say nothing; then the helper built with the
# sanitizers where make builds it, the runtime's tests and the programs'
# run with it, each sanitizer writing what it finds into build/sanitize,
# and the helper built again as make builds it, whatever the tests did. It
# passes where nothing was written.
SANITIZE = $(abspath build/sanitize)
sanitize: all
	@found=$$(clang --analyze -Xclang -analyzer-output=text -std=c99 -o /dev/null \
	  erl/runtime/c_src/ern_exec.c 2>&1); test -z "$$found" || { echo "$$found"; exit 1; }
	@rm -rf $(SANITIZE) && mkdir -p $(SANITIZE)
	@trap 'rm -f $(EXEC); $(MAKE) -s $(EXEC)' EXIT; \
	  clang -std=c99 -pedantic -g -O1 -fno-omit-frame-pointer -fsanitize=address,undefined \
	    -fno-sanitize-recover=undefined -o $(EXEC) erl/runtime/c_src/ern_exec.c && \
	  export ASAN_OPTIONS=log_path=$(SANITIZE)/address \
	    UBSAN_OPTIONS=log_path=$(SANITIZE)/undefined:print_stacktrace=1 && \
	  $(MAKE) -s test-erl APP=runtime && $(MAKE) -s test-programs
	@if [ -n "$$(ls $(SANITIZE))" ]; then cat $(SANITIZE)/*; exit 1; fi

# The document tests (test/ern_docs_tests.erl): every citation of a live
# document and of the code names a heading, the contents lists are
# current, and what the documents name exists.
xref:
	@$(MAKE) -s -C test xref

# Rewrite the outputs of docs/diagnostics.md, the catalog of the front
# end's errors, from what the compiler prints, after a change to a message
# that is meant.
diagnostics: all
	@$(MAKE) -s -C test diagnostics

# Rewrite the contents lists of the report and the guide from their headings;
# a test in test/ fails while one differs.
contents:
	@$(MAKE) -s -C test contents

# Every Ernest source laid out, and the Ernest blocks of the guide and the
# report (report §11.6); `make test` fails while one is not.
format: all
	@bin/ern format $(ERNEST_SOURCES)
	@$(MAKE) -s -C test format

# Report sections no test cites (every test function carries a `%% report §x.y` line):
# every numbered section and every appendix, a chapter cited through its sections.
sections:
	@grep -ohE '^#{2,3} ([0-9]+(\.[0-9]+)?\.? |Appendix [A-Z](\.[0-9]+)?\.)' report/*.md | \
	  sed -E 's/^#+ //; s/\.? $$//; s/\.$$//; s/^([0-9])/§\1/' | \
	  while read -r s; do p=$$(printf '%s' "$$s" | sed 's/\./\\./g'); \
	    grep -ohE "(guide )?$$p\b" erl/*/test/*.erl test/*.erl | \
	    grep -qv '^guide' || echo "$$s"; done

# Every report section with the number of tests citing it and its length in
# words, thinnest first: few citations on a long section is where a rule can
# hide untested. A heuristic, not a proof.
coverage:
	@awk '/^#{2,3} [0-9]+\.[0-9]+/ { if (s != "") print s, w; s = $$2; w = 0; next } \
	      /^#/ { if (s != "") print s, w; s = ""; next } \
	      s != "" { w += NF } END { if (s != "") print s, w }' report/*.md | \
	  while read s w; do \
	    c=$$(cat erl/*/test/*.erl test/*.erl | grep -o "\(guide \)\?§$$s\b" | grep -v '^guide' \
	         | wc -l); \
	    printf '%3d cites %5d words  §%s\n' $$c $$w $$s; done | sort -k1,1n -k3,3nr

# Emacs backup (foo~), auto-save (#foo#), and lock (.#foo) files, anywhere.
clean-emacs:
	find . -path ./.git -prune -o \( -name '*~' -o -name '#*#' -o -name '.#*' \) -print0 \
	  | xargs -0 rm -f

EMACS_CORPUS = $(ERNEST_SOURCES:%=../../%)

.PHONY: all $(APP_BUILDS) stdlib libs $(LIB_BUILDS) shell tools manual $(MANUALS) \
        man $(PAGES) \
        test test-full test-erl \
        test-programs $(PROGRAM_PARTS) test-library test-docs test-guide test-grammar \
        test-typed test-shell \
        load service bench $(addprefix bench-,$(BENCH_PARTS)) bench-release bench-machines \
        bench-pick \
        test-emacs $(APP_TESTS) $(APP_PARTS) $(EMACS_ALL) \
        clean clean-emacs \
        sections coverage golden xref contents format doc install uninstall release unicode \
        paragraphs \
        dialyzer sanitize diagnostics
