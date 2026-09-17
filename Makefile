# Top-level build. Each application under lib/ has its own src/Makefile;
# this one just runs them in order.

APPS = utils tokenizer parser type_system

all test clean:
	@for app in $(APPS); do $(MAKE) -C lib/$$app/src $@ || exit 1; done

.PHONY: all test clean
