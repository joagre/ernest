# The terminal tests need python3, which opens the pseudo-terminal that
# Erlang cannot (ern_pty.py).
#
# The integration tests: every MVP 1 program compiled with bin/ern build and run
# with bin/ern run, output compared with expected/<name>.out; the document
# tests, every citation in a live document resolving to a heading; the
# style tests, what docs/style.md says a machine can check; the guide's
# examples, compiled and run; and the shell and the terminal, driven through
# the pseudo-terminal.

EBIN = ebin
ERLC_FLAGS = +debug_info -Werror

# The suites by area (plan, MVP 2.6): `test` runs them all, side by side
# under `make -j`, and each area has a target of its own for a change that
# touches it alone.
PROGRAMS = ern_integration_tests
DOCS = ern_docs_tests ern_style_tests
GUIDE = ern_guide_tests
SHELL_TESTS = ern_terminal_tests ern_shell_tests
BEAMS = $(patsubst %,$(EBIN)/%.beam,$(PROGRAMS) $(DOCS) $(GUIDE) $(SHELL_TESTS))

# Run the EUnit modules $(1), with the toolchain and the standard library on
# the code path.
EUNIT = erl -noshell -pa ../erl/*/ebin -pa $(abspath ../build/stdlib) -pa $(EBIN) -eval \
	  'halt(case eunit:test([$(subst $(space),$(comma) ,$(strip $(1)))]) of ok -> 0; _ -> 1 end).'
comma := ,
space := $(subst ,, )

# The same, each module's tests side by side, as many at once as the host
# has schedulers, for the areas whose tests each start a host of their own.
EUNIT_SIDE_BY_SIDE = erl -noshell -pa ../erl/*/ebin -pa $(abspath ../build/stdlib) -pa $(EBIN) \
	  -eval 'N = erlang:system_info(schedulers_online), \
	  Ms = [$(subst $(space),$(comma) ,$(strip $(1)))], \
	  halt(case eunit:test({inparallel, [{inparallel, N, M} || M <- Ms]}) of \
	  ok -> 0; _ -> 1 end).'

test: programs docs guide shell

# The test modules and the build directory, which make test readies before
# it runs the areas side by side.
beams: $(BEAMS) prepare

programs: $(BEAMS) prepare measured
	$(call EUNIT_SIDE_BY_SIDE,$(PROGRAMS))

# The load programs and the benchmark, which `load` and `bench` run and no
# test does, are built with the programs, so that a change that breaks one
# is seen by `make test`.
measured: prepare
	@mkdir -p build/load build/bench
	@for p in $(LOADS); do \
	  ../bin/ern build --source-root load --build-root build/load load/$$p.ern || exit 1; done
	@../bin/ern build --source-root bench --build-root build/bench bench/bench.ern

docs: $(BEAMS)
	$(call EUNIT,$(DOCS))

guide: $(BEAMS) prepare
	$(call EUNIT,$(GUIDE))

shell: $(BEAMS) prepare
	$(call EUNIT_SIDE_BY_SIDE,$(SHELL_TESTS))

# The programs compiled here stay between runs: ern build recompiles what a
# changed compiler changes (report §11.1).
prepare:
	@mkdir -p build

xref: $(EBIN)/ern_docs_tests.beam
	erl -noshell -pa $(EBIN) -eval \
	  'halt(case eunit:test(ern_docs_tests, []) of ok -> 0; _ -> 1 end).'

diagnostics: $(EBIN)/ern_guide_tests.beam
	erl -noshell -pa ../erl/*/ebin -pa $(abspath ../build/stdlib) -pa $(EBIN) -eval \
	  'ern_guide_tests:write_diagnostics(), halt().'

contents: $(EBIN)/ern_docs_tests.beam
	erl -noshell -pa $(EBIN) -eval 'ern_docs_tests:write_contents(), halt().'

format: $(EBIN)/ern_style_tests.beam
	erl -noshell -pa ../erl/*/ebin -pa $(EBIN) -eval 'ern_style_tests:write_formatted(), halt().'

# The load programs under load/ and the shell under a long session, each in
# a node of its own, as docs/memory.md says; not part of `test`, and run
# before every release (docs/release_review.md). Each prints its samples and whether
# it stayed flat, into build/load/ as well.
LOADS = processes supervisors sockets programs files alarms
LOAD = erl -noinput -pa ../erl/*/ebin -pa $(abspath ../build/stdlib) -pa $(EBIN)
load: $(EBIN)/ern_load.beam measured
	@mkdir -p build/load/home
	@$(LOAD) -eval 'ern_load:main(["inputs", "build/load/shell.in"])'
	@status=0; \
	for p in $(LOADS); do $(LOAD) -eval "ern_load:main([\"$$p\"])" 2>/dev/null || status=1; done; \
	HOME=$(abspath build/load/home) $(LOAD) -pa $(abspath ../build/shell) \
	  -eval 'ern_load:main(["shell"])' < build/load/shell.in > build/load/shell.out 2>&1 \
	  || status=1; \
	cat build/load/shell.txt; exit $$status

# The benchmark: bench/bench.ern built and run as a user runs a program,
# and its times printed beside the same operations in Erlang by ern_bench;
# not part of `test`, since it measures and asserts nothing.
bench: $(EBIN)/ern_bench.beam measured
	@../bin/ern run build/bench/bench.erc > build/bench/ernest.txt
	@erl -noinput -pa $(EBIN) -eval 'ern_bench:main(["build/bench/ernest.txt"])'

clean:
	rm -rf $(EBIN) build

# ERL_LIBS lets -include_lib("app/include/x.hrl") find the applications
# under erl/; it is the compiler's alone, so that no program a test runs
# finds the toolchain's modules through it.
$(EBIN)/%.beam: %.erl | $(EBIN)
	ERL_LIBS=$(abspath ../erl) erlc $(ERLC_FLAGS) -o $(EBIN) $<

$(EBIN):
	mkdir -p $(EBIN)

.PHONY: test programs docs guide shell prepare measured xref load bench clean
