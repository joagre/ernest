# The per-application rules, which each erl/*/src/Makefile includes and
# make runs in that src directory. Compiles src/*.erl and test/*.erl into
# ../ebin, tracking header dependencies with erlc's -MMD so that a changed
# .hrl rebuilds its users.

EBIN = ../ebin
ERLC = erlc
# VERSION at the top of the repository is the toolchain's version; a bump rebuilds.
ERLC_FLAGS = +debug_info -Werror -I ../include -DVERSION='"$(shell cat ../../../VERSION)"'

# Lets -include_lib("app/include/x.hrl") find sibling apps under erl/.
export ERL_LIBS = $(abspath ../..)

SRC = $(wildcard *.erl)
TEST_SRC = $(wildcard ../test/*.erl)
BEAM = $(SRC:%.erl=$(EBIN)/%.beam)
TEST_BEAM = $(TEST_SRC:../test/%.erl=$(EBIN)/%.beam)
DEPS = $(BEAM:.beam=.Pbeam) $(TEST_BEAM:.beam=.Pbeam)

all: $(BEAM)

# The application and its tests compiled, which make test does once before
# it runs one application's tests in several hosts at once.
beams: $(BEAM) $(TEST_BEAM)

$(BEAM) $(TEST_BEAM): ../../../VERSION

# With PARTS=n and PART=i, every nth test of the application from the ith,
# so that make test can run one application's tests in several hosts at once.
PARTS = 1
PART = 0
TESTS = Modules = [list_to_atom(filename:basename(File, ".beam")) \
	           || File <- lists:sort(filelib:wildcard("$(EBIN)/*_tests.beam"))], \
	Tests = [case lists:suffix("_test_", atom_to_list(Function)) of \
	             true -> {generator, Module, Function}; false -> {Module, Function} end \
	         || Module <- Modules, {Function, 0} <- Module:module_info(exports), \
	            lists:suffix("_test", atom_to_list(Function)) \
	            orelse lists:suffix("_test_", atom_to_list(Function))], \
	Mine = [Test || {Index, Test} <- lists:enumerate(0, Tests), \
	                Index rem $(PARTS) =:= $(PART)], \
	halt(case eunit:test(Mine, []) of ok -> 0; _ -> 1 end).

# The tests run with the standard library on the path, and the shell's
# tree, which holds libs/markdown's module for `ern doc --man` (report §11.4).
# A test makes what it needs under one directory of the run's own,
# ERN_TEST_DIR, which is removed when the run ends, whatever its outcome.
test: $(BEAM) $(TEST_BEAM)
	@dir=$$(mktemp -d "$${TMPDIR:-/tmp}/ern_test_XXXXXX") && \
	  ERN_TEST_DIR=$$dir erl -noshell -pa $(EBIN) -pa $(abspath ../../../build/stdlib) \
	  -pa $(abspath ../../../build/shell) -eval '$(TESTS)'; \
	  status=$$?; rm -rf "$$dir"; exit $$status

clean:
	rm -f $(EBIN)/*.beam $(EBIN)/*.Pbeam

$(EBIN)/%.beam: %.erl | $(EBIN)
	$(ERLC) $(ERLC_FLAGS) -MMD -MP -MF $(EBIN)/$*.Pbeam -MT $@ -o $(EBIN) $<

$(EBIN)/%.beam: ../test/%.erl | $(EBIN)
	$(ERLC) $(ERLC_FLAGS) -MMD -MP -MF $(EBIN)/$*.Pbeam -MT $@ -o $(EBIN) $<

$(EBIN):
	mkdir -p $(EBIN)

-include $(DEPS)

.PHONY: beams all test clean
