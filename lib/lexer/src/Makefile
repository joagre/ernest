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
BEAM = $(SRC:%.erl=$(EBIN)/%.beam)
TEST_BEAM = $(TEST_SRC:../test/%.erl=$(EBIN)/%.beam)
DEPS = $(BEAM:.beam=.Pbeam) $(TEST_BEAM:.beam=.Pbeam)

all: $(BEAM)

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
