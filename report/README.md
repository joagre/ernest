# The report

The definition of Ernest, in three files, and the only normative document: where another document and the report differ, the report holds. It is for whoever builds or checks a toolchain, writes a library against the language's exact rules, or wants to know what a sentence of the guide rests on. It states each rule once, in the register of a language report, with no rationale; the reasons are the log's, [`docs/log.md`](../docs/log.md), dated.

| File | What it holds |
|---|---|
| [`language.md`](language.md) | §0, the five principles that decide what goes in; §1 to §9, the language, from its lexical elements through types, declarations, expressions, processes, errors and programs to the prelude; Appendix A, the grammar; Appendix B, examples; Appendix F, the glossary of the report's terms |
| [`toolchain.md`](toolchain.md) | §10, what every runtime must give; §11, the toolchain: `ern`'s jobs, the shell, the configuration directory, documentation, diagnostics, the formatter, options and exit status; §12, the runtime, how this one gives it: its system processes, the host binding, the causes it raises, termination, the carrier, the frames, the exchange and the utilization measure; Appendix C, the configuration file; Appendix H, the canonical form by which code is known across nodes |
| [`library.md`](library.md) | Appendix D, a foreign library; Appendix E, the standard library, module by module, with E.0's rules of admission and shape; Appendix G, the libraries beside it |

How to read it. §0 first, since it decides every question the rest leaves open; then the section a question names, since the report is written to be read by section and cited by number, `§6.5`, `E.27`, and its numbers never change. Appendix A, the grammar, wins over the prose where the two conflict, and §0's principles are the tiebreaker where the grammar is silent. Each file's third line is its revision date. The three together are about seventy thousand words, a long day read through, which no reader needs to do: the guide, [`guide/`](../guide/), teaches the language in order and names the section for each rule.

What holds it to the code: every section has a test that cites it, and `make sections` names one that has none.
