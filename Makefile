# Top-level build. Each application under erl/ has its own src/Makefile;
# this one just runs them in order.

APPS = utils lexer parser typer runtime emitter cli

all:
	@for app in $(APPS); do $(MAKE) -C erl/$$app/src $@ || exit 1; done
	@$(MAKE) -s stdlib

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
	  cp $$f build/stdlib/ernest@$$(basename $$f .erc).beam; done

# The standard library's pages, one per module beside its .erc in
# build/stdlib, and index.md listing them (report §11.4).
doc: all
	@bin/ernc --doc --out-dir build/stdlib stdlib

# The unit tests of every application, then the integration tests in test/.
test: all
	@for app in $(APPS); do $(MAKE) -C erl/$$app/src $@ || exit 1; done
	@$(MAKE) -C test $@

clean:
	@for app in $(APPS); do $(MAKE) -C erl/$$app/src $@ || exit 1; done
	@$(MAKE) -C test $@
	@rm -rf build/stdlib examples/*.erc examples/**/*.erc

# Rewrite test/golden/*.erl, the Erlang source the compiler emits for every
# MVP 1 example, after an intended change to the emitter.
golden: all
	@$(MAKE) -s -C erl/emitter/src ../ebin/ern_compiler_tests.beam
	@cd erl/emitter/src && erl -noshell -pa ../../*/ebin \
	  -eval 'ern_compiler_tests:write_golden(), halt().'

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

.PHONY: all test clean clean-emacs sections coverage golden xref stdlib doc
