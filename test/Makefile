# The tests that span the applications, by area: the programs in six
# parts (the example programs, the signals and the streams,
# ern_integration_tests, with the measuring machine's reach over every
# function, ern_measure_tests, and the bench's comparison of a run with
# the last and the release's, ern_last_run_tests; nodes on one machine,
# ern_nodes_tests and ern_machine_tests; the deployment guide run on them,
# ern_deployment_tests; the tour run on them, ern_tour_tests; the manual
# pages, ern_manual_tests; and the installation and the release,
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
# the bench's comparison of a run with the last and the release's, which
# starts nothing
LAST_RUN_TESTS = ern_last_run_tests
NODES = ern_nodes_tests ern_machine_tests
DEPLOYMENT = ern_deployment_tests
TOUR = ern_tour_tests
MANUAL = ern_manual_tests
INSTALL = ern_install_tests
DOCS = ern_docs_tests ern_style_tests
GUIDE = ern_guide_tests
GRAMMAR = ern_grammar_tests ern_grammar_programs_tests
TYPED = ern_typed_programs_tests
SHELL_TESTS = ern_terminal_tests ern_shell_tests
BEAMS = $(patsubst %,$(EBIN)/%.beam,$(INTEGRATION) $(MEASURE) $(LAST_RUN_TESTS) $(NODES) \
	  $(DEPLOYMENT) $(TOUR) $(MANUAL) $(INSTALL) $(DOCS) $(GUIDE) $(GRAMMAR) ern_grammar $(TYPED) \
	  $(SHELL_TESTS) ern_pty ern_repository ern_measure)

# A host with the toolchain and the modules here on its code path, which
# reads no input: the loads' runs and the bench's.
HOST = erl -noinput -pa ../erl/*/ebin -pa $(EBIN)

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
beams: $(BEAMS) prepare machines

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

# The programs' six parts (plan, MVP 3.9). The example programs and the
# test programs, the signals and the streams, with the programs `measured`
# builds, the measuring machine's reach over every function, and the
# bench's comparison of a run with the last and the release's.
integration: $(BEAMS) prepare measured named
	@$(call NODES_RUN,integration,$(INTEGRATION))
	$(call EUNIT,$(MEASURE) $(LAST_RUN_TESTS))

# Nodes on one machine, with the machines' tools ern_machine_tests tests.
nodes: $(BEAMS) prepare machines
	@$(call NODES_RUN,nodes,$(NODES))

# The deployment guide run on nodes, through ern_nodes_tests' harness.
deployment: $(BEAMS) prepare
	@$(call NODES_RUN,deployment,$(DEPLOYMENT))

# The tour's programs and sessions, tour/1/ to tour/8/, its shell a node
# beside two bare nodes, through ern_nodes_tests' harness.
tour: $(BEAMS) prepare
	@$(call NODES_RUN,tour,$(TOUR))

# The manual pages and the installation start no node. Both write the
# manual pages under ../build/stdlib, `ern doc --man` there and make
# install's `make manual`, so the two never run at once (the repository's
# Makefile, test-install).
manual: $(BEAMS) prepare
	$(call EUNIT,$(MANUAL))

install: $(BEAMS) prepare
	$(call EUNIT,$(INSTALL))

# The bench's parts, in the order `bench` runs them (plan, MVP 3.295), and
# their harnesses: core's ern_bench, library's ern_measure and each other
# part's ern_<part>_costs, with the harness the parts share, ern_costs, and
# the memory of their runs, ern_last_run.
BENCH_PARTS = core library nodes code spawn restarting burst foreign call rules language programs
BENCH_BEAMS = $(patsubst %,$(EBIN)/%.beam,ern_bench ern_measure ern_costs ern_last_run \
	  $(patsubst %,ern_%_costs,$(filter-out core library,$(BENCH_PARTS))))

# The load programs, the benchmark and the service checks' program, which
# `load`, `bench` and `service` run and no test does, are built with the
# programs, and their harnesses compiled, so that a change that breaks one
# is seen by `make test-full`.
measured: prepare $(EBIN)/ern_load.beam $(BENCH_BEAMS) $(EBIN)/ern_service_tests.beam \
	  $(EBIN)/ern_pick_costs.beam benched
	@mkdir -p build/load build/service
	@for p in $(LOADS); do \
	  ../bin/ern build --verbose --source-root fixtures/load --build-root build/load \
	    fixtures/load/$$p.ern || exit 1; done
	@../bin/ern build --verbose --source-root fixtures/service --build-root build/service \
	  fixtures/service/service.ern

# What the bench's parts run beside their harnesses: the programs under
# fixtures/bench/, built; the probes the nodes of the code part and of
# bench-pick load and the Erlang twins of the language's part and the
# programs' part, each compiled where its source is newer; and the
# machines' tools the node parts call.
BENCH_PROBES = $(patsubst fixtures/bench/%.erl,build/bench/probe/%.beam, \
	  $(wildcard fixtures/bench/ern_*_probe.erl))
BENCH_TWINS = $(patsubst fixtures/bench/%.erl,build/bench/twins/%.beam, \
	  $(wildcard fixtures/bench/ern_*_twin.erl))
benched: prepare $(BENCH_PROBES) $(BENCH_TWINS) machines
	@../bin/ern build --verbose --build-root build/bench fixtures/bench

build/bench/probe/%.beam: fixtures/bench/%.erl
	@mkdir -p $(@D)
	@erlc $(ERLC_FLAGS) -o $(@D) $<

build/bench/twins/%.beam: fixtures/bench/%.erl
	@mkdir -p $(@D)
	@erlc $(ERLC_FLAGS) -o $(@D) $<

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

diagnostics: $(EBIN)/ern_guide_tests.beam $(EBIN)/ern_pty.beam
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
load: $(EBIN)/ern_load.beam measured
	@mkdir -p build/load/home
	@$(HOST) -eval 'ern_load:main(["inputs", "build/load/shell.in"])'
	@status=0; \
	for p in $(LOADS); do $(HOST) -eval "ern_load:main([\"$$p\"])" 2>/dev/null || status=1; done; \
	HOME=$(abspath build/load/home) $(HOST) \
	  -eval 'ern_load:main(["shell"])' < build/load/shell.in > build/load/shell.out 2>&1 \
	  || status=1; \
	cat build/load/shell.txt; exit $$status

# The service manager's checks: the program of fixtures/service/ run under
# the user's systemd on Linux and launchd on macOS (ern_service_tests.erl);
# not part of `make test-full`, which a host without a service manager runs
# too, and run before every release (docs/release_review.md).
service: measured
	$(call EUNIT,ern_service_tests)

# The benchmark, in parts (plan, MVP 3.295), each run alone by a target
# of its own, bench-<part>, in this order by `bench`.
# core: fixtures/bench/bench.ern built and run as a user runs a program,
# and its times printed beside the same operations in Erlang by ern_bench,
# in build/bench/bench.txt, the modules it read and the faults its raises
# measure reported into build/bench/faults.txt.
# library: every function of the library measured against the host's by
# ern_measure (plan MVP 2.99d item 1), its whole table in
# build/bench/library.txt.
# nodes and code: the costs between two nodes, ern_nodes_costs, and MVP
# 3.2's of code that crosses, ern_code_costs, on nodes it starts, in
# build/bench/nodes.txt and code.txt.
# spawn: a spawn, a spawnMonitored and a monitor beside the host's, on
# every scheduler and on one, ern_spawn_costs, in build/bench/spawn.txt,
# spawn_monitored.txt and monitor.txt.
# restarting: entering restarting beside the host's try,
# ern_restarting_costs, in build/bench/restarting.txt.
# burst: four bursts against their size, ern_burst_costs, in
# build/bench/burst.txt.
# foreign: the pieces of a foreign call, and the host's call, the foreign
# fn and the look's key by one process and by eight at once,
# ern_foreign_costs, in build/bench/foreign.txt.
# call: the pieces of a call with one caller, eight pairs and eight callers
# of one callee, ern_call_costs, in build/bench/call.txt.
# rules: the rows the cost rules ask for that no other part has, a
# top-level let's read, a timed receive, a message to a system process and
# a bare launch, ern_rules_costs, in build/bench/rules.txt.
# language: each construct the compiler writes code for beside the plain
# Erlang for the same thing, ern_language_costs, in
# build/bench/language.txt.
# programs: three programs written twice, in Ernest and in Erlang by hand,
# ern_programs_costs, in build/bench/programs.txt, the Erlang twins of the
# three under fixtures/bench/ and compiled into build/bench/twins/ (plan,
# MVP 3.29).
# The memory is kept a table at a time, ern_last_run. As a run begins,
# each of its tables the run before wrote moves to build/bench/last/, in
# place of the one there, and the rest of last/ stays; at its end every
# row of its tables that moved by more than a fifth against last/, and
# against the release's run that bench-release keeps in
# build/bench/release/, is named in build/bench/moved.txt, the last run's
# comparison, the whole's or a part's, with the rows on either side that
# match none of the other's: a table with a ratio by its ratios, any other
# by its numbers. A part that failed leaves no table, so the next run is
# compared with the one before it. Every table is compared but
# the library's, whose numbers are each the fastest of three timings of a
# millisecond, its ratios to the host's among them, and move by more than
# a fifth from run to run with nothing changed (the log's *`make bench`
# Read Against the Cost Rules*, *The Sitting on §8.6's Bookkeeping*), so
# bench-library keeps and compares nothing. `bench` runs every part and
# compares every table. Not part of `make test-full`, since it measures
# and asserts nothing.
COMPARED_PARTS = $(filter-out library,$(BENCH_PARTS))
BENCH_TABLES = $(foreach Part,$(COMPARED_PARTS),$(TABLES_$(Part)))
BENCH_RUN = $(HOST) -eval
# The memory of the runs, ern_last_run's step $(1), keep, release or
# compare, over the tables $(2).
LAST_RUN = $(BENCH_RUN) \
	  'ern_last_run:main(["$(1)", "build/bench"$(foreach Table,$(2),$(comma) "$(Table)")])'
# A part that prints its table, which goes to build/bench/$(2) and is
# printed, whatever the part's outcome, and is removed where the part
# failed, a table it did not finish.
PRINTED = $(BENCH_RUN) '$(1)' > build/bench/$(2); status=$$?; cat build/bench/$(2); \
	  [ $$status = 0 ] || rm build/bench/$(2); exit $$status
# A part, ern_$(1)_costs, that writes its tables in build/bench/.
COSTS = @$(BENCH_RUN) 'ern_$(1)_costs:main(["build/bench"])'

# Each part's tables, those the comparison reads, and its run.
TABLES_core = bench.txt
define RUN_core
@../bin/ern run --verbose build/bench/bench.erc > build/bench/ernest.txt \
  2> build/bench/faults.txt || { tail -20 build/bench/faults.txt >&2; exit 1; }
@$(call PRINTED,ern_bench:main(["build/bench/ernest.txt"]),bench.txt)
endef
RUN_library = @$(BENCH_RUN) 'ern_measure:main(["build/bench/library.txt"])'
TABLES_nodes = nodes.txt
RUN_nodes = @$(call PRINTED,ern_nodes_costs:main(["build/bench/nodes"]),nodes.txt)
TABLES_code = code.txt
RUN_code = @$(call PRINTED,ern_code_costs:main(["build/bench/code"]),code.txt)
TABLES_spawn = spawn.txt spawn_monitored.txt monitor.txt
RUN_spawn = $(call COSTS,spawn)
TABLES_restarting = restarting.txt
RUN_restarting = $(call COSTS,restarting)
TABLES_burst = burst.txt
RUN_burst = $(call COSTS,burst)
TABLES_foreign = foreign.txt
RUN_foreign = $(call COSTS,foreign)
TABLES_call = call.txt
RUN_call = $(call COSTS,call)
TABLES_rules = rules.txt
RUN_rules = $(call COSTS,rules)
TABLES_language = language.txt
RUN_language = $(call COSTS,language)
TABLES_programs = programs.txt
RUN_programs = $(call COSTS,programs)

bench: $(BENCH_BEAMS) benched named
	@$(call LAST_RUN,keep,$(BENCH_TABLES))
	$(RUN_core)
	$(RUN_library)
	$(RUN_nodes)
	$(RUN_code)
	$(RUN_spawn)
	$(RUN_restarting)
	$(RUN_burst)
	$(RUN_foreign)
	$(RUN_call)
	$(RUN_rules)
	$(RUN_language)
	$(RUN_programs)
	@$(call LAST_RUN,compare,$(BENCH_TABLES))

$(addprefix bench-,$(COMPARED_PARTS)): bench-%: $(BENCH_BEAMS) benched named
	@$(call LAST_RUN,keep,$(TABLES_$*))
	$(RUN_$*)
	@$(call LAST_RUN,compare,$(TABLES_$*))

bench-library: $(EBIN)/ern_measure.beam named
	$(RUN_library)

# The tables in build/bench/ kept in build/bench/release/ as the release's
# run, which every later run is compared with too (docs/release_review.md),
# a table at a time, each in place of the one there, and named.
bench-release: $(EBIN)/ern_last_run.beam
	@$(call LAST_RUN,release,$(BENCH_TABLES))

# The bench's two node parts across the machines of machines/machines.txt
# (the log's *The Machines*): ern_nodes_costs's store on the first machine
# after this one and its desk here, and ern_code_costs's nodes over the
# machines after this one in turn, its measuring node here, each machine
# checked first (ern_machines). Each table is written to
# build/bench/<part>-machines.txt and printed. Not part of `make
# test-full`, which runs on any checkout and these on the user's machines
# alone.
bench-machines: measured named
	@$(call ACROSS,nodes)
	@$(call ACROSS,code)

# The part ern_$(1)_costs run across the machines, its table written to
# build/bench/$(1)-machines.txt and printed, as a part's on this machine,
# and its arguments, its directory and the machines' file.
ACROSS = $(call PRINTED,ern_$(1)_costs:main($(call ACROSS_ARGUMENTS,$(1))),$(1)-machines.txt)
ACROSS_ARGUMENTS = ["build/bench/$(1)-machines", "machines/machines.txt"]

# The push's experiment across the machines of machines/machines.txt (the
# log's *The Numbers Across Machines*, ern_pick_costs): a burst and a
# stream of computes from a measuring node, falling over bare nodes under
# `Peer.compute`'s pick and under the least busy, with the packets and the
# processors' time beside them. MEASURING names the machine the measuring node runs
# on, this one by default; PEERS the peers, machine:count,..., in place of
# the two arrangements of the default; INTERVALS the utilization-intervals
# the last arrangement's stream runs at again, 1000,500 by default; RUNS the
# bursts and the streams, 7,3; UTILIZATION how every node measures its
# utilization, run-queue or schedulers (Appendix C), the configuration's
# default where it is left out. Its table is written to
# build/bench/pick-machines.txt and printed, each run's lines kept in
# build/bench/pick-machines-raw/. Not part of `make test-full`.
bench-pick: measured named
	@$(call PRINTED,$(PICKED),pick-machines.txt)

PICKED = ern_pick_costs:main(["build/bench/pick-machines", "machines/machines.txt", $(PICK)])
PICK = "$(MEASURING)", "$(PEERS)", "$(INTERVALS)", "$(RUNS)", "$(UTILIZATION)"

# The machines' tools, which test/machines/nodes.sh runs and the bench's
# node parts call (ern_machines).
machines: $(EBIN)/ern_machine.beam $(EBIN)/ern_machine_node.beam $(EBIN)/ern_machines.beam

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

.PHONY: integration nodes deployment tour manual install docs guide grammar typed shell prepare \
	named measured benched xref load service bench $(addprefix bench-,$(BENCH_PARTS)) \
	bench-release bench-machines bench-pick machines clean
