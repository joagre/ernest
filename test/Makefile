# The tests that span the applications, by area: the programs in five
# parts (the example programs, the signals and the streams,
# ern_integration_tests, with the measuring machine's reach over every
# function, ern_measure_tests; nodes on one machine, ern_nodes_tests; the
# deployment guide run on them, ern_deployment_tests; the manual pages,
# ern_manual_tests; and the installation and the release,
# ern_install_tests), the documents and the style, the guide's examples,
# the grammar with the programs generated from it, the well-typed programs
# generated and run, and the shell and the terminal, driven through the
# pseudo-terminal, which python3 opens since Erlang cannot (ern_pty.py).
# Beside them, the loads, the service manager's checks and the bench, which
# a release runs, and the targets that write the catalog, the contents
# lists and the layout anew.

EBIN = ebin
ERLC_FLAGS = +debug_info -Werror

# The suites by area (plan, MVP 2.6, MVP 3.9): each area has a target of
# its own, which the repository's Makefile runs as `make test-<area>`,
# alone for a change that touches the area and side by side with the others
# under `make test-full`.
INTEGRATION = ern_integration_tests
# a launch of its own, which shares no host with the programs' runs
MEASURE = ern_measure_tests
NODES = ern_nodes_tests
DEPLOYMENT = ern_deployment_tests
MANUAL = ern_manual_tests
INSTALL = ern_install_tests
DOCS = ern_docs_tests ern_style_tests
GUIDE = ern_guide_tests
GRAMMAR = ern_grammar_tests ern_grammar_programs_tests
TYPED = ern_typed_programs_tests
SHELL_TESTS = ern_terminal_tests ern_shell_tests
BEAMS = $(patsubst %,$(EBIN)/%.beam,$(INTEGRATION) $(MEASURE) $(NODES) $(DEPLOYMENT) $(MANUAL) \
	  $(INSTALL) $(DOCS) $(GUIDE) $(GRAMMAR) ern_grammar $(TYPED) $(SHELL_TESTS) ern_pty \
	  ern_repository ern_measure)

# Run the EUnit modules $(1), with the toolchain on the code path.
EUNIT = erl -noshell -pa ../erl/*/ebin -pa $(EBIN) -eval \
	  'halt(case eunit:test([$(subst $(space),$(comma) ,$(strip $(1)))]) of ok -> 0; _ -> 1 end).'
comma := ,
space := $(subst ,, )

# The same, each module's tests side by side, as many at once as the host
# has schedulers, for the areas whose tests each start a host of their own.
EUNIT_SIDE_BY_SIDE = erl -noshell -pa ../erl/*/ebin -pa $(EBIN) \
	  -eval 'N = erlang:system_info(schedulers_online), \
	  Ms = [$(subst $(space),$(comma) ,$(strip $(1)))], \
	  halt(case eunit:test({inparallel, [{inparallel, N, M} || M <- Ms]}) of \
	  ok -> 0; _ -> 1 end).'

# The test modules and the build directory, which make test-full readies
# before it runs the areas side by side.
beams: $(BEAMS) prepare

# ern_named, by which a test calls a unit's function by its Ernest name, is
# a module of the runtime's tests (erl/runtime/test); the measure and the
# typed programs call it too, so their targets build the runtime's tests.
named:
	@$(MAKE) -s -C ../erl/runtime/src beams

# The modules $(2), each one's tests side by side, in a directory of the
# run's own named for the part $(1), where the nodes its tests start live:
# each whose ernest.pid is still there when the tests end is stopped before
# the directory goes (report §11.2), so that a test that failed or ran out
# of time before it stopped its nodes leaves none running.
NODES_RUN = dir=$$(mktemp -d "$${TMPDIR:-/tmp}/ern_$(1)_XXXXXX") && \
	  ERN_TEST_DIR=$$dir $(call EUNIT_SIDE_BY_SIDE,$(2)); \
	  status=$$?; \
	  for pid in $$(find "$$dir" -name ernest.pid); do \
	    ../bin/ern stop --config-dir "$$(dirname "$$pid")" > /dev/null 2>&1; done; \
	  rm -rf "$$dir"; exit $$status

# The programs' five parts (plan, MVP 3.9). The example programs and the
# test programs, the signals and the streams, with the programs `measured`
# builds and the measuring machine's reach over every function.
integration: $(BEAMS) prepare measured named
	@$(call NODES_RUN,integration,$(INTEGRATION))
	$(call EUNIT,$(MEASURE))

# Nodes on one machine.
nodes: $(BEAMS) prepare
	@$(call NODES_RUN,nodes,$(NODES))

# The deployment guide run on nodes, through ern_nodes_tests' harness.
deployment: $(BEAMS) prepare
	@$(call NODES_RUN,deployment,$(DEPLOYMENT))

# The manual pages and the installation start no node. Both write the
# manual pages under ../build/stdlib, `ern doc --man` there and make
# install's `make manual`, so the two never run at once (the repository's
# Makefile, test-install).
manual: $(BEAMS) prepare
	$(call EUNIT,$(MANUAL))

install: $(BEAMS) prepare
	$(call EUNIT,$(INSTALL))

# The load programs, the benchmark and the service checks' program, which
# `load`, `bench` and `service` run and no test does, are built with the
# programs, and their harnesses compiled, the probe the code costs' nodes
# load among them, so that a change that breaks one is seen by `make
# test-full`.
measured: prepare $(EBIN)/ern_load.beam $(EBIN)/ern_bench.beam $(EBIN)/ern_service_tests.beam \
	  $(EBIN)/ern_node_costs.beam $(EBIN)/ern_code_costs.beam
	@mkdir -p build/load build/bench/probe build/service
	@erlc $(ERLC_FLAGS) -o build/bench/probe fixtures/bench/ern_code_probe.erl
	@for p in $(LOADS); do \
	  ../bin/ern build --source-root fixtures/load --build-root build/load fixtures/load/$$p.ern \
	  || exit 1; done
	@../bin/ern build --source-root fixtures/bench --build-root build/bench \
	  fixtures/bench/bench.ern
	@../bin/ern build --source-root fixtures/service --build-root build/service \
	  fixtures/service/service.ern

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
typed: $(BEAMS) named
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
	erl -noshell -pa ../erl/*/ebin -pa $(EBIN) -eval \
	  'ern_guide_tests:write_diagnostics(), halt().'

contents: $(EBIN)/ern_docs_tests.beam
	erl -noshell -pa $(EBIN) -eval 'ern_docs_tests:write_contents(), halt().'

format: $(EBIN)/ern_style_tests.beam
	erl -noshell -pa ../erl/*/ebin -pa $(EBIN) -eval 'ern_style_tests:write_formatted(), halt().'

# The load programs under fixtures/load/ and the shell under a long
# session, each in a node of its own, as docs/memory.md says; not part of
# `make test-full`, and run before every release (docs/release_review.md).
# Each prints its samples and whether it stayed flat, into build/load/ as
# well.
LOADS = processes supervisors sockets programs files alarms
LOAD = erl -noinput -pa ../erl/*/ebin -pa $(EBIN)
load: $(EBIN)/ern_load.beam measured
	@mkdir -p build/load/home
	@$(LOAD) -eval 'ern_load:main(["inputs", "build/load/shell.in"])'
	@status=0; \
	for p in $(LOADS); do $(LOAD) -eval "ern_load:main([\"$$p\"])" 2>/dev/null || status=1; done; \
	HOME=$(abspath build/load/home) $(LOAD) \
	  -eval 'ern_load:main(["shell"])' < build/load/shell.in > build/load/shell.out 2>&1 \
	  || status=1; \
	cat build/load/shell.txt; exit $$status

# The service manager's checks: the program of fixtures/service/ run under
# the user's systemd on Linux and launchd on macOS (ern_service_tests.erl);
# not part of `make test-full`, which a host without a service manager runs
# too, and run before every release (docs/release_review.md).
service: measured
	$(call EUNIT,ern_service_tests)

# The benchmark: fixtures/bench/bench.ern built and run as a user runs a
# program, and its times printed beside the same operations in Erlang by ern_bench,
# the faults its raises measure reported into build/bench/faults.txt;
# then every function of the library measured against the host's by
# ern_measure (plan MVP 2.99d item 1), its whole table in
# build/bench/library.txt; then the costs between two nodes, ern_node_costs,
# and MVP 3.2's of code that crosses, ern_code_costs, on nodes it starts.
# Not part of `make test-full`, since it measures and asserts nothing.
bench: $(EBIN)/ern_bench.beam $(EBIN)/ern_measure.beam $(EBIN)/ern_node_costs.beam \
	  $(EBIN)/ern_code_costs.beam measured named
	@../bin/ern run build/bench/bench.erc > build/bench/ernest.txt 2> build/bench/faults.txt \
	  || { tail -20 build/bench/faults.txt >&2; exit 1; }
	@erl -noinput -pa $(EBIN) -eval 'ern_bench:main(["build/bench/ernest.txt"])'
	@erl -noinput -pa ../erl/*/ebin -pa $(EBIN) \
	  -eval 'ern_measure:main(["build/bench/library.txt"])'
	@erl -noinput -pa ../erl/*/ebin -pa $(EBIN) \
	  -eval 'ern_node_costs:main(["build/bench/nodes"])'
	@erl -noinput -pa ../erl/*/ebin -pa $(EBIN) \
	  -eval 'ern_code_costs:main(["build/bench/code"])'

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

.PHONY: integration nodes deployment manual install docs guide grammar typed shell prepare \
	named measured xref load service bench clean
