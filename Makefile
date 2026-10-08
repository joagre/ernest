# The repository's build and its checks. `make` builds the toolchain's
# applications under erl/, each by its own src/Makefile over the rules
# erl/app.mk keeps once, the runtime's helper in C, and the standard
# library, the shell, the libraries and the tools written in Ernest; `make
# test` runs every test by area; docs/development.md names every other
# target and what it is for.

APPS = utils lexer parser format typer runtime emitter cli json

# Every Ernest source of the repository, which `make format` lays out and
# the Emacs mode's tests read (report §11.6, proposals/emacs/emacs_mode.md).
ERNEST_SOURCES = stdlib/*.ern shell/*.ern shell/shell/*.ern examples/*.ern \
		test/*/*.ern test/programs/modules/*.ern test/programs/modules/*/*.ern libs/*/*.ern \
		tools/*.ern proposals/operations/programs/*.ern \
		proposals/nodes_and_code/experiments/code_update/*/*.ern \
		proposals/nodes_and_code/experiments/code_update/*/*/*.ern

# The Ernest trees, stdlib/, libs/, shell/ and tools/, are built by `ern build`
# every time, and its own rule decides what in each to compile again, by the
# sources' and the interfaces' hashes (report §11.1): make keeps no stamp of
# its own, whose times would disagree with the sources' contents. A copy of
# a module under its Erlang name is written only where its content differs.

# The helper that runs a program for Os.run (report Appendix E.23), written
# in C since the host's ports cannot keep a program's standard error apart,
# end its input while its output is read, or kill it.
EXEC = erl/runtime/priv/ern_exec

all: $(EXEC)
	@for app in $(APPS); do $(MAKE) -C erl/$$app/src $@ || exit 1; done
	@$(MAKE) -s shell man

$(EXEC): erl/runtime/c_src/ern_exec.c
	@mkdir -p $(dir $@)
	$(CC) -std=c99 -pedantic -O2 -Wall -Wextra -Werror -o $@ $<

# The standard library written in Ernest: stdlib/ compiled by ern build into
# build/stdlib under its Erlang module name, where the tools put it on the
# code path and the checker reads its interface (plan, MVP 2.5). ern build
# recompiles what a changed compiler changes (report §11.1). A copy under
# the Erlang name whose module the sweep removed is removed with it.
stdlib:
	@bin/ern build --build-root build/stdlib stdlib
	@for f in build/stdlib/*.erc; do b=build/stdlib/ern@$$(basename $$f .erc).beam; \
	  cmp -s $$f $$b || cp $$f $$b; done
	@for b in build/stdlib/ern@*.beam; do m=$${b#build/stdlib/ern@}; \
	  [ -f build/stdlib/$${m%.beam}.erc ] || rm -f $$b; done

# The libraries (plan, MVP 3.2): each libs/<name>/ is a source root of its
# own, compiled into build/libs/<name>, which a program adds with
# --load-path. libs/ansi is compiled first, since libs/markdown writes
# its styles with it (report Appendix G.3).
LIB_PATH = --load-path build/libs/ansi --load-path build/libs/markdown
libs: stdlib
	@bin/ern build --source-root libs/ansi --build-root build/libs/ansi libs/ansi
	@for d in libs/*/; do n=$$(basename $$d); [ $$n = ansi ] && continue; \
	  bin/ern build --source-root $$d --load-path build/libs/ansi --build-root build/libs/$$n $$d \
	  || exit 1; done

# The shell, written in Ernest (report §11.2, plan MVP 2.6): shell/ compiled
# by ern build into build/shell, where `ern shell` finds it on the code path.
# It renders documentation with libs/markdown, and styles it with
# libs/ansi, which it is compiled against and which ship beside it. A copy
# whose module is gone is removed, as the standard library's are.
shell: stdlib libs
	@bin/ern build $(LIB_PATH) --build-root build/shell shell
	@find build/shell -name '*.erc' | while read f; do \
	  m=$${f#build/shell/}; b=build/shell/ern@$$(echo $${m%.erc} | tr / @).beam; \
	  cmp -s $$f $$b || cp $$f $$b; done
	@for l in ansi markdown; do cmp -s build/libs/$$l/$$l.erc build/shell/ern@$$l.beam \
	  || cp build/libs/$$l/$$l.erc build/shell/ern@$$l.beam; done
	@for b in build/shell/ern@*.beam; do m=$${b#build/shell/ern@}; \
	  [ "$$m" = markdown.beam ] || [ "$$m" = ansi.beam ] \
	  || [ -f build/shell/$$(echo $${m%.beam} | tr @ /).erc ] || rm -f $$b; done

# The standard library's pages, one per module beside its .erc in
# build/stdlib, and index.md listing them (report §11.4).
doc: all
	@bin/ern doc --build-root build/stdlib stdlib

# The last release's pages as CommonMark in man/, which GitHub shows
# (docs/release_review.md, step 5): the prelude's and the standard
# library's under man/stdlib, with the index ern doc writes (report §11.4);
# each library's under man/libs/<name>, with an index linking them; and an
# index over the two, which links the report's §11 for ern itself. Each
# index is its directory's README.md, which GitHub shows when the directory
# is opened. They are written into build/pages and replace man/ whole, so a
# page whose module has gone goes.
pages: all
	@rm -rf build/pages
	@bin/ern doc --build-root build/pages/stdlib stdlib
	@for d in libs/*/; do n=$$(basename $$d); \
	  bin/ern doc --source-root $$d --load-path build/libs/ansi --build-root build/pages/libs/$$n \
	  $$d || exit 1; done
	@rm -rf man && mkdir man
	@cd build/pages && find . -name '*.md' ! -name index.md | tar cf - -T - \
	  | (cd ../../man && tar xf -)
	@cp build/pages/stdlib/index.md man/stdlib/README.md
	@{ printf '# Libraries\n\n'; \
	  for d in libs/*/; do n=$$(basename $$d); \
	    sed -n "s|^- \[\(.*\)\](\(.*\))\$$|- [\1]($$n/\2), \`libs/$$n\`|p" \
	      build/pages/libs/$$n/index.md; done; \
	} > man/libs/README.md
	@v=$$(cat VERSION); { \
	  printf '# Ernest %s\n\n' "$$v"; \
	  printf 'The pages `ern doc` wrote at the release of Ernest %s, ' "$$v"; \
	  printf 'which `main` may have gone past. A page holds a module'"'"'s doc block, '; \
	  printf 'then its declarations, each with its type and its own doc block '; \
	  printf '(report §11.4). Where Ernest is installed, `man Ernest.List` shows a '; \
	  printf 'module'"'"'s page and `man ern` the toolchain'"'"'s.\n\n'; \
	  printf -- '- [The prelude and the standard library](stdlib/README.md)\n'; \
	  printf -- '- [The libraries under `libs/`](libs/README.md)\n'; \
	  printf -- '- [`ern`, the toolchain and its shell](../report/toolchain.md#11-toolchain), '; \
	  printf 'the report'"'"'s §11, whose §11.2 gives the shell'"'"'s commands\n'; \
	} > man/README.md

# The manual pages (report §11, §11.4): the prelude's and every standard
# library module's, beside the modules' .erc in build/stdlib, each
# library's beside its own in build/libs, and ern(1), §11 of the report,
# which tools/manual.ern writes into build/man with the standard library's
# pages in its SEE ALSO. make writes them, so that make install, which a
# user may run as another, only copies. A page is written whole or not at
# all.
man: stdlib libs tools
	@bin/ern doc --man --build-root build/stdlib stdlib
	@for d in libs/*/; do n=$$(basename $$d); \
	  bin/ern doc --man --source-root $$d --load-path build/libs/ansi --build-root build/libs/$$n \
	  $$d || exit 1; done
	@mkdir -p build/man
	@bin/ern run $(LIB_PATH) build/tools/manual.erc \
	  report/toolchain.md $$(cat VERSION) build/stdlib > build/man/ern.1.new
	@mv build/man/ern.1.new build/man/ern.1

# The installation (proposals/install/install.md): the toolchain's tree under
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
# from tools/release (proposals/install/install.md).
release: all
	@sh tools/install.sh release build/release $$(cat VERSION)

# The programs of the build written in Ernest, tools/*.ern, compiled into
# build/tools against libs/markdown and libs/ansi, which it writes with.
tools: libs
	@bin/ern build $(LIB_PATH) --build-root build/tools tools

# Terminal.columns' width table in stdlib/terminal.ern, from the Unicode
# data of the version the host's grapheme segmentation follows: UC_SPEC is
# a directory holding EastAsianWidth.txt, emoji-data.txt and
# UnicodeData.txt, as OTP's source tree has in lib/stdlib/uc_spec.
unicode:
	@test -n "$(UC_SPEC)" || { echo "UC_SPEC=dir is required"; exit 1; }
	@escript tools/unicode_width.escript $(UC_SPEC)

# The tests by area (plan, MVP 2.6). `make test` runs the suite's jobs side
# by side, as many at once as the host has cores, each job's output together
# as it ends. One make runs each phase, since a make started with a -j of
# its own runs apart from the count. The unit tests run first, with the
# jobs that start no host: EUnit gives a test with no time of its own five
# seconds, which the load of the areas that start hosts would take from
# them. Those areas then run, each its own tests side by side. Make starts
# the jobs in the order given, so the longest come first. The modules under
# test/, and the tests of the applications run in parts, are compiled
# first, once, so that no two parts compile one module at once. A change
# may run its own area's target as it is worked on.
JOBS := $(shell getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
test: all
	@$(MAKE) -s -C test beams
	@for a in $(SPLIT_APPS); do $(MAKE) -s -C erl/$$a/src beams || exit 1; done
	@$(MAKE) -s -j$(JOBS) -O test-guide $(EMACS_JOBS) $(APP_JOBS) test-docs test-grammar \
	  test-typed
	@$(MAKE) -s -j$(JOBS) -O test-shell test-programs

# The unit tests of the applications under erl/, side by side, or of one
# with APP=typer.
APP_TESTS = $(APPS:%=test-app-%)
ifdef APP
test-erl: all
	@$(MAKE) -C erl/$(APP)/src test
else
test-erl: all
	@$(MAKE) -s -j $(APP_TESTS)
endif

$(APP_TESTS): test-app-%:
	@$(MAKE) -s -C erl/$*/src test

# The emitter's and the runtime's tests run programs and wait on them, so
# make test runs each in three hosts at once, every third test in each.
SPLIT_APPS = emitter runtime
APP_PARTS = $(foreach a,$(SPLIT_APPS),$(addprefix test-app-$(a)-,0 1 2))
APP_JOBS = $(APP_PARTS) $(filter-out $(SPLIT_APPS:%=test-app-%),$(APP_TESTS))

$(APP_PARTS): test-app-%:
	@$(MAKE) -s -C erl/$(firstword $(subst -, ,$*))/src test PARTS=3 \
	  PART=$(lastword $(subst -, ,$*))

# The areas under test/: the example programs, the documents and the style,
# the guide's examples, the grammar with the programs generated from it,
# the well-typed programs generated and run, and the shell with the
# terminal.
test-programs: all
	@$(MAKE) -C test programs
test-docs:
	@$(MAKE) -C test docs
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

# The benchmark: what an Ernest operation costs beside the same operation in
# Erlang (test/ern_bench.erl), and every function of the library beside the
# host's (test/ern_measure.erl).
bench: all
	@$(MAKE) -C test bench

# The Emacs mode's tests (proposals/emacs/emacs_mode.md). It is an editor and not
# part of the toolchain, so a machine without Emacs skips them; they are
# the only tests `make test` will run and not have built. `format` runs
# `ern format`, so the toolchain is built first. EMACS names the Emacs to
# run them under: `make test-emacs EMACS=/opt/emacs-29/bin/emacs`.
EMACS ?= emacs
EMACS_TESTS = flatten reindent format lint colour editing broken
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
	@cd emacs && $(EMACS) -Q -batch -l test/$*.el $(EMACS_CORPUS)

$(TYPING_PARTS): emacs-test-typing-%:
	@cd emacs && PARTS=4 PART=$* $(EMACS) -Q -batch -l test/typing.el $(EMACS_CORPUS)

clean:
	@for app in $(APPS); do $(MAKE) -C erl/$$app/src $@ || exit 1; done
	@$(MAKE) -C test $@
	@rm -rf build/stdlib build/shell build/libs build/tools build/man build/pages build/release \
	  build/dialyzer build/dialyzer.plt build/sanitize $(EXEC)
	@# sh reads `**` as `*`, so the programs' compiled modules are found
	@find examples test/programs -name '*.erc' -delete

# Rewrite test/golden/*.erl, the Erlang source the compiler emits for every
# program of test/programs/ and services, after an intended change to the emitter.
golden: all
	@$(MAKE) -s -C erl/emitter/src ../ebin/ern_emitter_tests.beam
	@cd erl/emitter/src && erl -noshell -pa ../../*/ebin -pa $(abspath build/stdlib) \
	  -eval 'ern_emitter_tests:write_golden(), halt().'

# Dialyzer over the toolchain's Erlang, its tests aside, and over the Erlang
# the compiler writes for the standard library, the shell and the
# libraries, a library's .erc copied under its module's name, since
# Dialyzer reads only a .beam (docs/release_review.md). The table of the
# host's applications the toolchain calls is built once, into
# build/dialyzer.plt, and Dialyzer checks it against the host at each run.
DIALYZER_APPS = erts kernel stdlib compiler syntax_tools crypto public_key asn1 parsetools
dialyzer: all
	@test -f build/dialyzer.plt || \
	  dialyzer --build_plt --output_plt build/dialyzer.plt --apps $(DIALYZER_APPS)
	@rm -rf build/dialyzer && mkdir -p build/dialyzer
	@for d in build/libs/*; do (cd $$d && find . -name '*.erc') | while read -r f; do \
	  m=$${f#./}; cp $$d/$$m build/dialyzer/ern@$$(echo $${m%.erc} | tr / @).beam; done; done
	@dialyzer --plt build/dialyzer.plt $(filter-out %_tests.beam,$(wildcard erl/*/ebin/*.beam)) \
	  $(wildcard build/stdlib/ern@*.beam) \
	  $(filter-out build/shell/ern@markdown.beam build/shell/ern@ansi.beam,\
	    $(wildcard build/shell/ern@*.beam)) \
	  build/dialyzer/*.beam

# The helper in C under Clang's static analyzer and under the address and
# undefined-behaviour sanitizers (docs/release_review.md): the analyzer
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

# Rewrite the outputs of test/diagnostics.md, the catalogue of the front
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

EMACS_CORPUS = $(ERNEST_SOURCES:%=../%)

.PHONY: all stdlib libs shell tools man test test-erl test-programs test-docs test-guide \
        test-grammar test-typed test-shell load service bench test-emacs $(APP_TESTS) $(APP_PARTS) \
        $(EMACS_ALL) clean clean-emacs sections coverage golden xref contents format doc pages \
        install uninstall release unicode dialyzer sanitize diagnostics
