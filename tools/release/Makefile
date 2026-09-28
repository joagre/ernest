# Ernest @VERSION@, compiled. make compiles the helper Os.run runs a
# program through, the one part in C, for this machine; make install
# installs Ernest under PREFIX, /usr/local by default, each path after
# DESTDIR, which a packager passes; make uninstall removes it. The
# installation is described by share/doc/ernest/README.md and made by
# install.sh, as the checkout's is.

PREFIX = /usr/local
DESTDIR =
CC = cc
HELPER = lib/ernest/erl/runtime/priv/ern_exec

all: $(HELPER)

$(HELPER): ern_exec.c
	@mkdir -p lib/ernest/erl/runtime/priv
	$(CC) -std=c99 -pedantic -O2 -Wall -Wextra -o $(HELPER) ern_exec.c

install: all
	@sh install.sh install . "$(DESTDIR)" "$(PREFIX)"

uninstall:
	@sh install.sh uninstall "$(DESTDIR)" "$(PREFIX)"

.PHONY: all install uninstall
