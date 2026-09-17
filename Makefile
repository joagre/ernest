# Top-level build. Each application under lib/ has its own src/Makefile;
# this one just runs them in order.

APPS = utils lexer parser type_system runtime compiler cli

all:
	@for app in $(APPS); do $(MAKE) -C lib/$$app/src $@ || exit 1; done

# The unit tests of every application, then the integration tests in test/.
test clean:
	@for app in $(APPS); do $(MAKE) -C lib/$$app/src $@ || exit 1; done
	@$(MAKE) -C test $@

# Rewrite test/golden/*.erl, the Erlang source the compiler emits for every
# MVP 1 example, after an intended change to the emitter.
golden: all
	@$(MAKE) -s -C lib/compiler/src ../ebin/ern_compiler_tests.beam
	@cd lib/compiler/src && erl -noshell -pa ../../*/ebin \
	  -eval 'ern_compiler_tests:write_golden(), halt().'

# Report sections no test cites (every test function carries a `%% report §x.y` line).
sections:
	@grep -oE '^#{2,3} [0-9]+\.[0-9]+' ernest_report.md | sed 's/^#* //' | \
	  while read s; do grep -q "§$$s\b" lib/*/test/*.erl test/*.erl || echo "§$$s"; done

# Every report section with the number of tests citing it and its length in
# words, thinnest first: few citations on a long section is where a rule can
# hide untested. A heuristic, not a proof.
coverage:
	@awk '/^#{2,3} [0-9]+\.[0-9]+/ { if (s != "") print s, w; s = $$2; w = 0; next } \
	      /^#/ { if (s != "") print s, w; s = ""; next } \
	      s != "" { w += NF } END { if (s != "") print s, w }' ernest_report.md | \
	  while read s w; do c=$$(cat lib/*/test/*.erl test/*.erl | grep -o "§$$s\b" | wc -l); \
	    printf '%3d cites %5d words  §%s\n' $$c $$w $$s; done | sort -k1,1n -k3,3nr

# Emacs backup (foo~), auto-save (#foo#), and lock (.#foo) files, anywhere.
clean-emacs:
	find . -path ./.git -prune -o \( -name '*~' -o -name '#*#' -o -name '.#*' \) -print0 \
	  | xargs -0 rm -f

.PHONY: all test clean clean-emacs sections coverage golden
