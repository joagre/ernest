# The attack plan

The order in which the principles review's findings, [`findings.md`](findings.md), are worked, until they are; then this document goes. What the review is and how it decides is [`principles_review.md`](principles_review.md)'s, and why the order is this is the log's *The Attack Plan*. The aim is consistency and beauty, not a makeover: the five principles stand, each gains the sentence the log shows it lacked, and a rule changes only where the smallest program that shows it reads better without it and no program under `examples/` or one a newcomer wrote gets harder. Its outcome is a revised report, guide and code, committed rule by rule with their tests, never a list of suggestions: a finding ends as `report`, `kept` or `later`, and nothing else.

## The phases

1. **The principles' sentences.** Round 1, part one: decided with the user, one question a turn, in prose, the argument before the verdict; the report and the log change the same turn. Five: the host, a paragraph of §0; which reader principle 1 means; when a second spelling enters, under principle 2; what is refused when compiled, what faults when run, and what is silent, under principle 3; what is counted, and that a program count decides nothing, under principle 5.
2. **The sections' sentences.** Round 1, part two, the same way. Ten: a failure's shape (§7.4, E.0 shape rule 4); what waits with a limit (E.0 shape rule 8); member or module function, and which operations are operators (§4.5, §4.8); what the prelude holds (§9); what the library admits (E.0 rules 1 to 4); the one silence (§6.2); who owns a process or a resource (§6.9); the reply discipline (§6.6); source order or a normal form (§3.5); one door for the host's values (§3.7). Two of them, what a value shows of itself (Appendix E.1) and the operators, are what MVP 2.99b's items 13 and 4 build on, and are decided here.
3. **MVP 2.99b's items 1 to 3**: the tests trusted, the style glossary, the language feedback's triage. Before any code changes, as the plan says.
4. **The defects and disagreements**, the lines marked `fix`: those that depend on no family, in the order of `findings.md`, each a commit with its conformance section. A defect inside a family goes with its family in phase 5.
5. **The families' rules.** Round 2: under the sentences as they then read, each rule of a family `report`, `kept` or `later`, a family a turn; then the rules that buy little, the rules that exist only for another, and where the guide works hard, the same way. A `report` line is worked at once: the report, the log, the code and its tests, then the guide, a commit each rule. A family decided is closed in the log and not reopened before 1.0 but by a program that shows a case the decision did not.
6. **The log**: the entries whose reason has lapsed or was abolished marked superseded, or their verdict restated on the reason that holds; one commit.
7. **Closure**: the log's entry for the review, its date, commit, counts, and how many lines took each decision; `findings.md`'s heading goes, and this document with it; the next release's notes list the rules that changed; MVP 2.99b resumes at item 4.

## Cost

Phases 1 and 2 are fifteen questions, at the user's pace. Phase 4 is about a week. Phase 5 is unknown until phase 2 has run, and bounded by its list; the plan's estimate is revised then.
