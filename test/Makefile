# The integration tests: every MVP 1 program compiled with bin/ernc and run
# with bin/ern, output compared with expected/<name>.out; the document
# tests, every citation in a live document resolving to a heading; and the
# style tests, what docs/style.md says a machine can check.

EBIN = ebin
ERLC_FLAGS = +debug_info -Werror

test: $(EBIN)/ern_integration_tests.beam $(EBIN)/ern_docs_tests.beam $(EBIN)/ern_style_tests.beam
	erl -noshell -pa ../erl/*/ebin -pa $(abspath ../build/stdlib) -pa $(EBIN) -eval \
	  'halt(case eunit:test([ern_integration_tests, ern_docs_tests, ern_style_tests], []) of ok -> 0; _ -> 1 end).'

xref: $(EBIN)/ern_docs_tests.beam
	erl -noshell -pa $(EBIN) -eval \
	  'halt(case eunit:test(ern_docs_tests, []) of ok -> 0; _ -> 1 end).'

clean:
	rm -rf $(EBIN) build

$(EBIN)/%.beam: %.erl | $(EBIN)
	erlc $(ERLC_FLAGS) -o $(EBIN) $<

$(EBIN):
	mkdir -p $(EBIN)

.PHONY: test xref clean
