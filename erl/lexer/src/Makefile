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

$(BEAM) $(TEST_BEAM): ../../../VERSION

test: $(BEAM) $(TEST_BEAM)
	erl -noshell -pa $(EBIN) -eval \
	  'halt(case eunit:test({dir, "$(EBIN)"}, []) of ok -> 0; _ -> 1 end).'

clean:
	rm -f $(EBIN)/*.beam $(EBIN)/*.Pbeam

$(EBIN)/%.beam: %.erl | $(EBIN)
	$(ERLC) $(ERLC_FLAGS) -MMD -MP -MF $(EBIN)/$*.Pbeam -MT $@ -o $(EBIN) $<

$(EBIN)/%.beam: ../test/%.erl | $(EBIN)
	$(ERLC) $(ERLC_FLAGS) -MMD -MP -MF $(EBIN)/$*.Pbeam -MT $@ -o $(EBIN) $<

$(EBIN):
	mkdir -p $(EBIN)

-include $(DEPS)

.PHONY: all test clean
