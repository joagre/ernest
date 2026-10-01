# Generic per-application Makefile. Identical in every erl/*/src.
# Compiles src/*.erl and test/*.erl into ../ebin, tracking header
# dependencies with erlc's -MMD so that a changed .hrl rebuilds its users.

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

# The standard library, and the shell's tree, which holds libs/markdown's
# module for `ern doc --man` (report §11.4). With PARTS=n and PART=i, every
# nth test of the application from the ith, so that make test can run one
# application's tests in several hosts at once.
PARTS = 1
PART = 0
TESTS = Ms = [list_to_atom(filename:basename(F, ".beam")) \
	      || F <- lists:sort(filelib:wildcard("$(EBIN)/*_tests.beam"))], \
	Ts = [case lists:suffix("_test_", atom_to_list(F)) of \
	          true -> {generator, M, F}; false -> {M, F} end \
	      || M <- Ms, {F, 0} <- M:module_info(exports), \
	         lists:suffix("_test", atom_to_list(F)) \
	         orelse lists:suffix("_test_", atom_to_list(F))], \
	Mine = [T || {I, T} <- lists:enumerate(0, Ts), I rem $(PARTS) =:= $(PART)], \
	halt(case eunit:test(Mine, []) of ok -> 0; _ -> 1 end).
test: $(BEAM) $(TEST_BEAM)
	erl -noshell -pa $(EBIN) -pa $(abspath ../../../build/stdlib) \
	  -pa $(abspath ../../../build/shell) -eval '$(TESTS)'

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
