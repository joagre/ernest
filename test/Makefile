# The tests that span the applications, by area: the programs (the example
# programs, the signals, the streams, the installation and the release,
# ern_integration_tests, and the measuring machine's reach over every
# function, ern_measure_tests), the documents and the style, the guide's
# examples, the grammar with the programs generated from it, the
# well-typed programs generated and run, and the shell and the terminal,
# driven through the pseudo-terminal, which python3 opens since Erlang
# cannot (ern_pty.py). Beside them, the loads, the service manager's
# checks and the bench, which a release runs, and the targets that write
# the catalogue, the contents lists and the layout anew.

EBIN = ebin
ERLC_FLAGS = +debug_info -Werror

# The suites by area (plan, MVP 2.6): `test` runs them all, side by side
# under `make -j`, and each area has a target of its own for a change that
# touches it alone.
PROGRAMS = ern_integration_tests
# a launch of its own, which shares no host with the programs' runs
MEASURE = ern_measure_tests
DOCS = ern_docs_tests ern_style_tests
GUIDE = ern_guide_tests
GRAMMAR = ern_grammar_tests ern_grammar_programs_tests
TYPED = ern_typed_programs_tests
SHELL_TESTS = ern_terminal_tests ern_shell_tests
BEAMS = $(patsubst %,$(EBIN)/%.beam,$(PROGRAMS) $(DOCS) $(GUIDE) $(GRAMMAR) ern_grammar \
	  $(TYPED) $(SHELL_TESTS) ern_pty ern_repository ern_measure $(MEASURE))

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

test: programs docs guide grammar typed shell

# The test modules and the build directory, which make test readies before
# it runs the areas side by side.
beams: $(BEAMS) prepare

programs: $(BEAMS) prepare measured
	$(call EUNIT_SIDE_BY_SIDE,$(PROGRAMS))
	$(call EUNIT,$(MEASURE))

# The load programs, the benchmark and the service checks' program, which
# `load`, `bench` and `service` run and no test does, are built with the
# programs, and their harnesses compiled, so that a change that breaks one
# is seen by `make test`.
measured: prepare $(EBIN)/ern_load.beam $(EBIN)/ern_bench.beam $(EBIN)/ern_service_tests.beam
	@mkdir -p build/load build/bench build/service
	@for p in $(LOADS); do \
	  ../bin/ern build --source-root load --build-root build/load load/$$p.ern || exit 1; done
	@../bin/ern build --source-root bench --build-root build/bench bench/bench.ern
	@../bin/ern build --source-root service --build-root build/service service/service.ern

docs: $(BEAMS)
	$(call EUNIT,$(DOCS))

guide: $(BEAMS) prepare
	@dir=$$(mktemp -d "$${TMPDIR:-/tmp}/ern_guide_XXXXXX") && \
	  ERN_TEST_DIR=$$dir $(call EUNIT,$(GUIDE)); \
	  status=$$?; rm -rf "$$dir"; exit $$status

# Appendix A read as data, and the programs generated from it (MVP 2.99c
# item 1), whose seed ERN_SEED gives again.
grammar: $(BEAMS)
	$(call EUNIT,$(GRAMMAR))

# Well-typed programs generated, checked, compiled and run in one host
# (MVP 2.99c item 3), whose seed ERN_SEED gives again.
typed: $(BEAMS)
	$(call EUNIT,$(TYPED))

# The shell's and the terminal's tests make their homes, sources, inputs
# and step files under one directory of the run's own, which is removed
# when the run ends, whatever its outcome (ern_pty:run_dir/0).
shell: $(BEAMS) prepare
	@dir=$$(mktemp -d "$${TMPDIR:-/tmp}/ern_shell_XXXXXX") && \
	  ERN_TEST_DIR=$$dir $(call EUNIT_SIDE_BY_SIDE,$(SHELL_TESTS)); \
	  status=$$?; rm -rf "$$dir"; exit $$status

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

# The service manager's checks: the program of service/ run under the
# user's systemd on Linux and launchd on macOS (ern_service_tests.erl);
# not part of `test`, which a host without a service manager runs too, and
# run before every release (docs/release_review.md).
service: measured
	$(call EUNIT,ern_service_tests)

# The benchmark: bench/bench.ern built and run as a user runs a program,
# and its times printed beside the same operations in Erlang by ern_bench;
# then every function of the library measured against the host's by
# ern_measure (plan MVP 2.99d item 1), its whole table in
# build/bench/library.txt. Not part of `test`, since it measures and
# asserts nothing.
bench: $(EBIN)/ern_bench.beam $(EBIN)/ern_measure.beam measured
	@../bin/ern run build/bench/bench.erc > build/bench/ernest.txt
	@erl -noinput -pa $(EBIN) -eval 'ern_bench:main(["build/bench/ernest.txt"])'
	@erl -noinput -pa ../erl/*/ebin -pa $(abspath ../build/stdlib) -pa $(EBIN) \
	  -eval 'ern_measure:main(["build/bench/library.txt"])'

clean:
	rm -rf $(EBIN) build

# ERL_LIBS lets -include_lib("app/include/x.hrl") find the applications
# under erl/; it is the compiler's alone, so that no program a test runs
# finds the toolchain's modules through it. erlc's -MMD records the headers
# each module includes, so that a changed record rebuilds the tests that
# match it, as erl/app.mk does for the applications.
$(EBIN)/%.beam: %.erl | $(EBIN)
	ERL_LIBS=$(abspath ../erl) erlc $(ERLC_FLAGS) -MMD -MP -MF $(EBIN)/$*.Pbeam -MT $@ \
	  -o $(EBIN) $<

-include $(wildcard $(EBIN)/*.Pbeam)

$(EBIN):
	mkdir -p $(EBIN)

.PHONY: test programs docs guide grammar typed shell prepare measured xref load service bench clean
