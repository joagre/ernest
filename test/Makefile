# The terminal tests need python3, which opens the pseudo-terminal that
# Erlang cannot (ern_pty.py).
#
# The integration tests: every MVP 1 program compiled with bin/ernc and run
# with bin/ern, output compared with expected/<name>.out; the document
# tests, every citation in a live document resolving to a heading; and the
# style tests, what docs/style.md says a machine can check.

EBIN = ebin
ERLC_FLAGS = +debug_info -Werror

# The suites by area (plan, MVP 2.6 checkpoint 4, step 3): `test` runs them
# all, and each area has a target of its own for a change that touches it
# alone.
PROGRAMS = ern_integration_tests
DOCS = ern_docs_tests ern_style_tests
GUIDE = ern_guide_tests
SHELL_TESTS = ern_terminal_tests ern_shell_tests
BEAMS = $(patsubst %,$(EBIN)/%.beam,$(PROGRAMS) $(DOCS) $(GUIDE) $(SHELL_TESTS))

# Run the EUnit modules $(1), with the toolchain and the standard library on
# the code path.
EUNIT = erl -noshell -pa ../erl/*/ebin -pa $(abspath ../build/stdlib) -pa $(EBIN) -eval \
	  'halt(case eunit:test([$(subst $(space),$(comma) ,$(strip $(1)))], []) of ok -> 0; _ -> 1 end).'
comma := ,
space := $(subst ,, )

test: $(BEAMS) prepare
	$(call EUNIT,$(PROGRAMS) $(DOCS) $(GUIDE) $(SHELL_TESTS))

programs: $(BEAMS) prepare
	$(call EUNIT,$(PROGRAMS))

docs: $(BEAMS)
	$(call EUNIT,$(DOCS))

guide: $(BEAMS) prepare
	$(call EUNIT,$(GUIDE))

shell: $(BEAMS) prepare
	$(call EUNIT,$(SHELL_TESTS))

# A changed compiler with an unchanged VERSION leaves ernc's build records
# valid (report §11.1), so the programs compiled here are thrown away
# whenever a toolchain beam is newer than the last run, as the standard
# library's build does.
prepare:
	@if [ -n "$$(find ../erl -name '*.beam' -newer build/.built 2>/dev/null)" ] \
	   || [ ! -f build/.built ]; then rm -rf build; fi
	@mkdir -p build && touch build/.built

xref: $(EBIN)/ern_docs_tests.beam
	erl -noshell -pa $(EBIN) -eval \
	  'halt(case eunit:test(ern_docs_tests, []) of ok -> 0; _ -> 1 end).'

clean:
	rm -rf $(EBIN) build

$(EBIN)/%.beam: %.erl | $(EBIN)
	erlc $(ERLC_FLAGS) -o $(EBIN) $<

$(EBIN):
	mkdir -p $(EBIN)

.PHONY: test programs docs guide shell prepare xref clean
