# The integration tests: every MVP 1 program compiled with bin/ernc and run
# with bin/ern, output compared with expected/<name>.out; and the document
# tests, every citation in a live document resolving to a heading.

EBIN = ebin
ERLC_FLAGS = +debug_info -Werror

test: $(EBIN)/ern_integration_tests.beam $(EBIN)/ern_docs_tests.beam
	erl -noshell -pa ../lib/*/ebin -pa $(EBIN) -eval \
	  'halt(case eunit:test([ern_integration_tests, ern_docs_tests], []) of ok -> 0; _ -> 1 end).'

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
