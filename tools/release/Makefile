# Ernest @VERSION@, compiled. make compiles the helper Os.run runs a
# program through, the one part in C, for this machine; make install
# installs Ernest under PREFIX, /usr/local by default, each path after
# DESTDIR, which a packager passes; make uninstall removes it. The
# installation is described by README.md, which it installs as
# share/doc/ernest/README.md, and made by install.sh, as the checkout's is.

PREFIX = /usr/local
DESTDIR =
HELPER = lib/ernest/erl/runtime/priv/ern_exec

all: $(HELPER)

# The C compiler is make's, `cc`, or the one CC names in the environment.
# The archive leaves out -Werror, which the checkout's build gives: a
# warning a compiler of the installing machine gives is no reason to refuse
# the installation (the log's *One Archive, Compiled Where It Is
# Installed*).
$(HELPER): ern_exec.c
	@mkdir -p lib/ernest/erl/runtime/priv
	$(CC) -std=c99 -pedantic -O2 -Wall -Wextra -o $(HELPER) ern_exec.c

install: all
	@sh install.sh install . "$(DESTDIR)" "$(PREFIX)"

uninstall:
	@sh install.sh uninstall "$(DESTDIR)" "$(PREFIX)"

.PHONY: all install uninstall
