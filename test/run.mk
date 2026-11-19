# The run's directory and its home, stated once: test/Makefile's areas and
# the repository's Makefile's unit tests of the roots include this file.

# The run's startup file, found from this file's own place, so that the path
# holds from the directory of either Makefile that includes it. Read before
# another include adds to MAKEFILE_LIST.
RUN_STARTUP := $(dir $(lastword $(MAKEFILE_LIST)))fixtures/session/startup

# A comma, which the argument of a call cannot hold as written.
comma := ,

# The command $(2) in a directory of the run's own, named for $(1), an area
# or the roots' unit tests, which its tests make their homes, sources and
# inputs under (ERN_TEST_DIR) and which is removed when the command ends,
# whatever its outcome; the step $(3), where one is given, runs before it
# goes. The status is the command's. Every area of make test-full and the
# roots' unit tests run in one.
#
# The run's HOME is there too, its startup file test/fixtures/session/startup,
# so that a shell a test starts without naming a home of its own runs no
# startup file of the person's: it prints that file's line and ends before
# its first input (report §11.2), so its test fails. ern_shell_tests'
# inherited_home holds both.
AREA_RUN = dir=$$(mktemp -d "$${TMPDIR:-/tmp}/ern_$(1)_XXXXXX") && \
	  mkdir -p "$$dir/home/.ernest" && cp $(RUN_STARTUP) "$$dir/home/.ernest" && \
	  HOME="$$dir/home" ERN_TEST_DIR=$$dir $(2); \
	  status=$$?; $(3) rm -rf "$$dir"; exit $$status
