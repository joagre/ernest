# Top-level build. Each application under lib/ has its own src/Makefile;
# this one just runs them in order.

APPS = utils lexer parser type_system runtime

all test clean:
	@for app in $(APPS); do $(MAKE) -C lib/$$app/src $@ || exit 1; done

# Emacs backup (foo~), auto-save (#foo#), and lock (.#foo) files, anywhere.
clean-emacs:
	find . -path ./.git -prune -o \( -name '*~' -o -name '#*#' -o -name '.#*' \) -print0 \
	  | xargs -0 rm -f

.PHONY: all test clean clean-emacs
