# Generic per-application Makefile. Identical in every lib/*/src.
# Compiles src/*.erl and test/*.erl into ../ebin, tracking header
# dependencies with erlc's -MMD so that a changed .hrl rebuilds its users.

EBIN = ../ebin
ERLC = erlc
ERLC_FLAGS = +debug_info -Werror -I ../include

# Lets -include_lib("app/include/x.hrl") find sibling apps under lib/.
export ERL_LIBS = $(abspath ../..)

SRC = $(wildcard *.erl)
TEST_SRC = $(wildcard ../test/*.erl)

# An Erlang module implementing an Ernest namespace is named by its atom,
# 'Ernest.Io', which erlc refuses to compile from a file of another name.
# Such sources are compiled from forms instead, into $(EBIN)/Ernest.Io.beam.
NS_SRC = $(shell grep -l "^-module.'Ernest\." $(SRC) /dev/null)
ERL_SRC = $(filter-out $(NS_SRC), $(SRC))
NS_STAMP = $(EBIN)/.namespaces

BEAM = $(ERL_SRC:%.erl=$(EBIN)/%.beam)
TEST_BEAM = $(TEST_SRC:../test/%.erl=$(EBIN)/%.beam)
DEPS = $(BEAM:.beam=.Pbeam) $(TEST_BEAM:.beam=.Pbeam)

all: $(BEAM) $(if $(NS_SRC), $(NS_STAMP))

$(NS_STAMP): $(NS_SRC) $(wildcard ../include/*.hrl) | $(EBIN)
	escript ../../compile_ns.escript $(EBIN) $(NS_SRC)
	touch $@

test: all $(TEST_BEAM)
	erl -noshell -pa $(EBIN) -eval \
	  'halt(case eunit:test({dir, "$(EBIN)"}, []) of ok -> 0; _ -> 1 end).'

clean:
	rm -f $(EBIN)/*.beam $(EBIN)/*.Pbeam $(NS_STAMP)

$(EBIN)/%.beam: %.erl | $(EBIN)
	$(ERLC) $(ERLC_FLAGS) -MMD -MP -MF $(EBIN)/$*.Pbeam -MT $@ -o $(EBIN) $<

$(EBIN)/%.beam: ../test/%.erl | $(EBIN)
	$(ERLC) $(ERLC_FLAGS) -MMD -MP -MF $(EBIN)/$*.Pbeam -MT $@ -o $(EBIN) $<

$(EBIN):
	mkdir -p $(EBIN)

-include $(DEPS)

.PHONY: all test clean
