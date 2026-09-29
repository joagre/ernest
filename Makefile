# Top-level build. Each application under erl/ has its own src/Makefile;
# this one just runs them in order.

APPS = utils lexer parser format typer runtime emitter cli

# Every Ernest source of the repository, which `make format` lays out and
# the Emacs mode's tests read (report §11.6, docs/emacs_mode.md).
ERNEST_SOURCES = stdlib/*.ern shell/*.ern shell/shell/*.ern examples/*.ern \
		examples/modules/*.ern examples/modules/*/*.ern test/*/*.ern libs/*/*.ern tools/*.ern

# What the Ernest trees are built from: the compiler's beams, and each
# tree's sources and the directories that hold them, so that a source
# added or removed is seen and the sweep of §11.1 runs. Each tree is a
# stamp file that make rebuilds only when one of these is newer, so a make
# with nothing to do starts no build; the build records then decide
# what inside a tree to compile.
TOOL = $(filter-out %_tests.beam,$(wildcard erl/*/ebin/*.beam))
# The top directory is written `dir/.`, since `stdlib`, `libs` and `shell`
# are also the names of targets. A name that begins with a dot, an editor's
# lock file among them, is no source (report §11.1).
sources = $(shell find $(1) -mindepth 1 -name '.*' -prune -o -name '*.ern' -print) $(1)/. \
	$(shell find $(1) -mindepth 1 -name '.*' -prune -o -type d -print)

# The helper that runs a program for Os.run (report Appendix E.23), written
# in C since the host's ports cannot keep a program's standard error apart,
# end its input while its output is read, or kill it.
EXEC = erl/runtime/priv/ern_exec
CC ?= cc

all: $(EXEC)
	@for app in $(APPS); do $(MAKE) -C erl/$$app/src $@ || exit 1; done
	@$(MAKE) -s shell
	@$(MAKE) -s man

$(EXEC): erl/runtime/c_src/ern_exec.c
	@mkdir -p $(dir $@)
	$(CC) -std=c99 -pedantic -O2 -Wall -Wextra -Werror -o $@ $<

stdlib: build/stdlib/.built
libs: build/libs/.built
shell: build/shell/.built
man: build/man/.built

# The standard library written in Ernest: stdlib/ compiled by ern build into
# build/stdlib under its Erlang module name, where the tools put it on the
# code path and the checker reads its interface (plan, MVP 2.5). ern build
# recompiles what a changed compiler changes (report §11.1). A copy under
# the Erlang name whose module the sweep removed is removed with it.
build/stdlib/.built: $(TOOL) $(call sources,stdlib)
	@bin/ern build --build-root build/stdlib stdlib
	@for f in build/stdlib/*.erc; do \
	  cp $$f build/stdlib/ern@$$(basename $$f .erc).beam; done
	@for b in build/stdlib/ern@*.beam; do m=$${b#build/stdlib/ern@}; \
	  [ -f build/stdlib/$${m%.beam}.erc ] || rm -f $$b; done
	@touch $@

# The libraries (plan, MVP 3.2): each libs/<name>/ is a source root of its
# own, compiled into build/libs/<name>, which a program adds with
# --load-path.
build/libs/.built: build/stdlib/.built $(TOOL) $(call sources,libs)
	@for d in libs/*/; do n=$$(basename $$d); \
	  bin/ern build --source-root $$d --build-root build/libs/$$n $$d || exit 1; done
	@touch $@

# The shell, written in Ernest (report §11.2, plan MVP 2.6): shell/ compiled
# by ern build into build/shell, where `ern shell` finds it on the code path.
# It renders documentation with libs/markdown, which it is compiled against
# and which ships beside it. A copy whose module is gone is removed, as the
# standard library's are.
build/shell/.built: build/stdlib/.built build/libs/.built $(TOOL) $(call sources,shell)
	@bin/ern build --load-path build/libs/markdown --build-root build/shell shell
	@find build/shell -name '*.erc' | while read f; do \
	  m=$${f#build/shell/}; \
	  cp $$f build/shell/ern@$$(echo $${m%.erc} | tr / @).beam; done
	@cp build/libs/markdown/markdown.erc build/shell/ern@markdown.beam
	@for b in build/shell/ern@*.beam; do m=$${b#build/shell/ern@}; \
	  [ "$$m" = markdown.beam ] || [ -f build/shell/$$(echo $${m%.beam} | tr @ /).erc ] \
	  || rm -f $$b; done
	@touch $@

# The standard library's pages, one per module beside its .erc in
# build/stdlib, and index.md listing them (report §11.4).
doc: all
	@bin/ern doc --build-root build/stdlib stdlib

# The manual pages (report §11, §11.4): the prelude's and every standard
# library module's, beside the modules' .erc in build/stdlib, each
# library's beside its own in build/libs, and ern(1), §11 of the report,
# which tools/manual.ern writes into build/man with the standard library's
# pages in its SEE ALSO. make writes them, so that make install, which a
# user may run as another, only copies. A page is written whole or not at
# all.
build/man/.built: $(TOOL) build/stdlib/.built build/libs/.built build/tools/.built \
		  ernest_report.md
	@bin/ern doc --man --build-root build/stdlib stdlib
	@for d in libs/*/; do n=$$(basename $$d); \
	  bin/ern doc --man --source-root $$d --build-root build/libs/$$n $$d || exit 1; done
	@mkdir -p build/man
	@bin/ern run --load-path build/libs/markdown build/tools/manual.erc \
	  ernest_report.md $$(cat VERSION) build/stdlib > build/man/ern.1.new
	@mv build/man/ern.1.new build/man/ern.1
	@touch $@

# The installation (docs/install.md): the toolchain's tree under
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
# from tools/release (docs/install.md).
release: all
	@sh tools/install.sh release build/release $$(cat VERSION)

# The programs of the build written in Ernest, tools/*.ern, compiled into
# build/tools against libs/markdown.
build/tools/.built: build/libs/.built $(TOOL) $(call sources,tools)
	@bin/ern build --load-path build/libs/markdown --build-root build/tools tools
	@touch $@

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
# the jobs in the order given, so the longest come first. The modules under test/ are compiled first,
# once. A change may run its own area's target as it is worked on.
JOBS := $(shell getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
test: all
	@$(MAKE) -s -C test beams
	@$(MAKE) -s -j$(JOBS) -O test-guide $(EMACS_JOBS) $(APP_JOBS) test-docs
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
# the guide's examples, and the shell with the terminal.
test-programs: all
	@$(MAKE) -C test programs
test-docs:
	@$(MAKE) -C test docs
test-guide: all
	@$(MAKE) -C test guide
test-shell: all
	@$(MAKE) -C test shell

# The loads of docs/memory.md, which a release runs (docs/review.md).
load: all
	@$(MAKE) -C test load

# The benchmark: what an Ernest operation costs beside the same operation in
# Erlang (test/ern_bench.erl).
bench: all
	@$(MAKE) -C test bench

# The Emacs mode's tests (docs/emacs_mode.md). It is an editor and not
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
	@rm -rf build/stdlib build/shell build/libs build/tools build/man build/release \
	  build/dialyzer build/dialyzer.plt build/sanitize \
	  examples/*.erc \
	  examples/**/*.erc $(EXEC)

# Rewrite test/golden/*.erl, the Erlang source the compiler emits for every
# MVP 1 example, after an intended change to the emitter.
golden: all
	@$(MAKE) -s -C erl/emitter/src ../ebin/ern_emitter_tests.beam
	@cd erl/emitter/src && erl -noshell -pa ../../*/ebin -pa $(abspath build/stdlib) \
	  -eval 'ern_emitter_tests:write_golden(), halt().'

# Dialyzer over the toolchain's Erlang, its tests aside, and over the Erlang
# the compiler writes for the standard library, the shell and the
# libraries, a library's .erc copied under its module's name, since
# Dialyzer reads only a .beam (docs/review.md). The table of the
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
	  $(filter-out build/shell/ern@markdown.beam,$(wildcard build/shell/ern@*.beam)) \
	  build/dialyzer/*.beam

# The helper in C under Clang's static analyzer and under the address and
# undefined-behaviour sanitizers (docs/review.md): the analyzer
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

# Every `§x.y`, `Appendix X`, and `E.n` in a live document names a heading of the
# report, and the guide's own bare `§x.y` a heading of the guide; a test in test/.
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
	@grep -oE '^#{2,3} ([0-9]+(\.[0-9]+)?\.? |Appendix [A-Z](\.[0-9]+)?\.)' ernest_report.md | \
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
	      s != "" { w += NF } END { if (s != "") print s, w }' ernest_report.md | \
	  while read s w; do c=$$(cat erl/*/test/*.erl test/*.erl | grep -o "\(guide \)\?§$$s\b" | grep -v '^guide' | wc -l); \
	    printf '%3d cites %5d words  §%s\n' $$c $$w $$s; done | sort -k1,1n -k3,3nr

# Emacs backup (foo~), auto-save (#foo#), and lock (.#foo) files, anywhere.
clean-emacs:
	find . -path ./.git -prune -o \( -name '*~' -o -name '#*#' -o -name '.#*' \) -print0 \
	  | xargs -0 rm -f

EMACS_CORPUS = $(ERNEST_SOURCES:%=../%)

.PHONY: all libs test test-erl test-programs test-docs test-guide test-shell load bench test-emacs \
        $(APP_TESTS) $(APP_PARTS) $(EMACS_ALL) clean clean-emacs sections coverage golden xref contents format stdlib shell doc man install uninstall release unicode \
        dialyzer sanitize diagnostics
