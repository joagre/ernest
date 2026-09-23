# Top-level build. Each application under erl/ has its own src/Makefile;
# this one just runs them in order.

APPS = utils lexer parser typer runtime emitter cli

all:
	@for app in $(APPS); do $(MAKE) -C erl/$$app/src $@ || exit 1; done
	@$(MAKE) -s stdlib
	@$(MAKE) -s shell
	@$(MAKE) -s libs

# The standard library written in Ernest: stdlib/ compiled by ernc into
# build/stdlib under its Erlang module name, where the tools put it on the
# code path and the checker reads its interface (plan, MVP 2.5).
# A changed compiler with an unchanged VERSION leaves ernc's build records
# valid (report §11.1), so the tree is rebuilt whenever a compiler beam is
# newer than the last standard library build.
stdlib:
	@if [ -n "$$(find erl -name '*.beam' -newer build/stdlib/.built 2>/dev/null)" ] \
	   || [ ! -f build/stdlib/.built ]; then rm -rf build/stdlib; fi
	@bin/ernc --out-dir build/stdlib stdlib
	@touch build/stdlib/.built
	@for f in build/stdlib/*.erc; do \
	  cp $$f build/stdlib/ern@$$(basename $$f .erc).beam; done

# The shell, written in Ernest (report §11.2, plan MVP 2.6): shell/ compiled
# by ernc into build/shell, where `ern --shell` finds it on the code path.
# Rebuilt when a compiler beam is newer, as the standard library is.
shell: stdlib
	@if [ -n "$$(find erl -name '*.beam' -newer build/shell/.built 2>/dev/null)" ] \
	   || [ ! -f build/shell/.built ]; then rm -rf build/shell; fi
	@bin/ernc --out-dir build/shell shell
	@touch build/shell/.built
	@find build/shell -name '*.erc' | while read f; do \
	  m=$${f#build/shell/}; \
	  cp $$f build/shell/ern@$$(echo $${m%.erc} | tr / @).beam; done

# The libraries (plan, MVP 2.7): each libs/<name>/ is a source root of its
# own, compiled into build/libs/<name>, which a program adds with
# --load-path. Rebuilt when a compiler beam is newer, as the standard
# library is.
libs: stdlib
	@for d in libs/*/; do n=$$(basename $$d); \
	  if [ -n "$$(find erl -name '*.beam' -newer build/libs/$$n/.built 2>/dev/null)" ] \
	     || [ ! -f build/libs/$$n/.built ]; then rm -rf build/libs/$$n; fi; \
	  bin/ernc --source-root $$d --out-dir build/libs/$$n $$d || exit 1; \
	  touch build/libs/$$n/.built; done

# The standard library's pages, one per module beside its .erc in
# build/stdlib, and index.md listing them (report §11.4).
doc: all
	@bin/ernc --doc --out-dir build/stdlib stdlib

# The unit tests of every application, then the integration tests in test/.
test: all
	@for app in $(APPS); do $(MAKE) -C erl/$$app/src $@ || exit 1; done
	@$(MAKE) -C test $@
	@$(MAKE) -s emacs-mode

# The Emacs mode's tests (docs/emacs_mode.md). It is an editor and not
# part of the toolchain, so a machine without Emacs skips them; they are
# the only tests `make test` will run and not have built. EMACS names the
# Emacs to run them under: `make emacs-mode EMACS=/opt/emacs-29/bin/emacs`.
EMACS ?= emacs
EMACS_TESTS = lint colour editing broken reindent flatten typing
emacs-mode:
	@if ! command -v $(EMACS) >/dev/null 2>&1; then \
	  if [ "$(origin EMACS)" = file ]; then \
	    echo "  Emacs not installed; the mode's tests were skipped."; exit 0; fi; \
	  echo "  $(EMACS): no such Emacs"; exit 1; fi
	@cd emacs && for t in $(EMACS_TESTS); do \
	  $(EMACS) -Q -batch -l test/$$t.el $(EMACS_CORPUS) || exit 1; done

clean:
	@for app in $(APPS); do $(MAKE) -C erl/$$app/src $@ || exit 1; done
	@$(MAKE) -C test $@
	@rm -rf build/stdlib build/shell build/libs examples/*.erc examples/**/*.erc

# Rewrite test/golden/*.erl, the Erlang source the compiler emits for every
# MVP 1 example, after an intended change to the emitter.
golden: all
	@$(MAKE) -s -C erl/emitter/src ../ebin/ern_emitter_tests.beam
	@cd erl/emitter/src && erl -noshell -pa ../../*/ebin -pa $(abspath build/stdlib) \
	  -eval 'ern_emitter_tests:write_golden(), halt().'

# Every `§x.y`, `Appendix X`, and `E.n` in a live document names a heading of the
# report, and the guide's own bare `§x.y` a heading of the guide; a test in test/.
xref:
	@$(MAKE) -s -C test xref

# Report sections no test cites (every test function carries a `%% report §x.y` line).
sections:
	@grep -oE '^#{2,3} [0-9]+\.[0-9]+' ernest_report.md | sed 's/^#* //' | \
	  while read s; do grep -q "§$$s\b" erl/*/test/*.erl test/*.erl || echo "§$$s"; done

# Every report section with the number of tests citing it and its length in
# words, thinnest first: few citations on a long section is where a rule can
# hide untested. A heuristic, not a proof.
coverage:
	@awk '/^#{2,3} [0-9]+\.[0-9]+/ { if (s != "") print s, w; s = $$2; w = 0; next } \
	      /^#/ { if (s != "") print s, w; s = ""; next } \
	      s != "" { w += NF } END { if (s != "") print s, w }' ernest_report.md | \
	  while read s w; do c=$$(cat erl/*/test/*.erl test/*.erl | grep -o "§$$s\b" | wc -l); \
	    printf '%3d cites %5d words  §%s\n' $$c $$w $$s; done | sort -k1,1n -k3,3nr

# Emacs backup (foo~), auto-save (#foo#), and lock (.#foo) files, anywhere.
clean-emacs:
	find . -path ./.git -prune -o \( -name '*~' -o -name '#*#' -o -name '.#*' \) -print0 \
	  | xargs -0 rm -f

EMACS_CORPUS = ../stdlib/*.ern ../shell/*.ern ../shell/shell/*.ern ../examples/*.ern \
		../examples/modules/*.ern ../examples/modules/*/*.ern ../test/*/*.ern ../libs/*/*.ern

.PHONY: all libs test clean clean-emacs emacs-mode sections coverage golden xref stdlib shell doc
