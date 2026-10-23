# The documents

The project's own documents: what each file and directory here is, and the two READMEs that stand beside the code. What a user of Ernest reads is [`report/`](../report/) and [`guide/`](../guide/), each with a README of its own, and the tour, [`tour/`](../tour/).

- **[`development.md`](development.md)**: where things are, how to build and test them, and what the toolchain does not do yet.
- **[`plan.md`](plan.md)**: where the project stands and what comes next.
- **[`log.md`](log.md)**: the dated rationale for the report and the plan, and what was rejected. Not normative.
- **[`architecture.md`](architecture.md)**: how the toolchain is built, from the lexer to the runtime, and what each test runs.
- **[`design/`](design/)**: the design notes of built components, each changing when its component does: [`shell.md`](design/shell.md), how the shell is built; [`install.md`](design/install.md), how a checkout and the release archive are installed; [`emacs_mode.md`](design/emacs_mode.md), what the Emacs major mode does and the tests that judge it; [`runtime.md`](design/runtime.md), what the runtime keeps and where, the look, a launch, a call, a kill, the boundary and the frames, as they stand.
- **[`memory.md`](memory.md)**: how the project checks that nothing grows with the work done.
- **[`soundness.md`](soundness.md)**: the argument that a well-typed program does not go wrong, kept with the rules it covers.
- **[`otp_bugs.md`](otp_bugs.md)**: the defects found in OTP, each written as a report for OTP's tracker.
- **[`release_review.md`](release_review.md)**: what a release runs to be ready.
- **[`full_review.md`](full_review.md)**: every reader over the whole of its area, run seldom.
- **[`principles_review.md`](principles_review.md)**: the report and the guide read against §0, and §0 against what it decided.
- **[`style.md`](style.md)**: the repository's own style for its Erlang and its C, and the toolchain's glossary; an Ernest program's rules are [`guide/style.md`](../guide/style.md)'s.
- **[`module_doc_template.md`](module_doc_template.md)**: a documented module, as `ern doc` renders it.
- **[`diagnostics.md`](diagnostics.md)**: the catalog of the errors the lexer, the parser and the checker give, each with a program that gives it and what `ern build` prints for it, which `make diagnostics` writes and a test holds to the compiler.
- **[`language_feedback.md`](language_feedback.md)**: what writing Ernest has felt against the principles, until the plan decides it.
- **[`man/`](man/)**: the manual pages as CommonMark, which `make man` writes from `main` and a release commits: the prelude's and the standard library's, and each library's.
- **[`proposals/`](proposals/)**: what is designed, a directory for each proposal. The peer protocol of MVP 3.0 is there, decided, and the report's §8.7 is rewritten from it; and operations records are there as the record of what was built, with three programs the tests run.
- **[`src/shell/README.md`](../src/shell/README.md)**: a guide to the shell's code.
- **[`editors/emacs/README.md`](../editors/emacs/README.md)**: how to install the Emacs mode, and what it leaves to the reader's configuration.
