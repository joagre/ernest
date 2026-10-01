# The attack plan

The order in which the principles review's findings, [`findings.md`](findings.md), are worked, until they are; then this document goes. What the review is and how it decides is [`principles_review.md`](principles_review.md)'s, and why the order is this is the log's *The Attack Plan*. The aim is consistency and beauty, not a makeover: the five principles stand, each gains the sentence the log shows it lacked, and a rule changes only where the smallest program that shows it reads better without it and no program under `examples/` or one a newcomer wrote gets harder. Its outcome is a revised report, guide and code, committed rule by rule with their tests, never a list of suggestions: a finding ends as `report`, `kept` or `later`, and nothing else.

## The phases

1. **The principles' sentences** (done 2026-10-01, commits e7d7f74 to the fifth sentence's). Round 1, part one: decided with the user, one question a turn, in prose, the argument before the verdict; the report and the log change the same turn. Five: the host, a paragraph of §0; which reader principle 1 means; when a second spelling enters, under principle 2; what is refused when compiled, what faults when run, and what is silent, under principle 3; what is counted, and that a program count decides nothing, under principle 5.
2. **The sections' sentences** (done 2026-10-01, commits b7dc7b7 to the eleventh's). Round 1, part two, the same way. Ten: a failure's shape (§7.4, E.0 shape rule 4); what waits with a limit (E.0 shape rule 8); member or module function, and which operations are operators (§4.5, §4.8); what the prelude holds (§9); what the library admits (E.0 rules 1 to 4); the one silence (§6.2); who owns a process or a resource (§6.9); the reply discipline (§6.6); source order or a normal form (§3.5); one door for the host's values (§3.7). Two of them, what a value shows of itself (Appendix E.1) and the operators, are what MVP 2.99b's items 13 and 4 build on, and are decided here.
3. **MVP 2.99b's items 1 to 3** (done 2026-10-01, commits d60e7ff to the glossary's reading): the tests trusted, the style glossary, the language feedback's triage. Before any code changes, as the plan says.
4. **The defects and disagreements**, the lines marked `fix`: those that depend on no family, in the order of `findings.md`, each a commit with its conformance section. A defect inside a family goes with its family in phase 5.
5. **The families' rules**, round 2, in two halves. First the decisions: under the sentences as they then read, each rule of a family `report`, `kept` or `later`, a family a turn, in prose; then the rules that buy little, the rules that exist only for another, and where the guide works hard, the same way; a family decided is closed in the log and not reopened before 1.0 but by a program that shows a case the decision did not. Then the edits, once the list is closed, by area so that each is opened once: the parser and the checker; the runtime and the library; the emitter and the ABI; the prelude and the mechanical renames, `Local`, `Foreign.Term`, `Address.call`'s `Either`, scripted and read as a diff; the examples. A `report` line is a commit: the report, the log, the code and its tests, and the guide's programs where a signature changed, since `make test` runs them; `make test` green at each. New code is written in the glossary's names (MVP 2.99b's item 2), so that items 6 and 15 rename old code only. The guide's prose, §4.4, §5.2, §5.5, §7.2 and §7.3 whole, is rewritten in one pass at the end of the edits.
6. **The log**: the entries whose reason has lapsed or was abolished marked superseded, or their verdict restated on the reason that holds; one commit.
7. **Closure**: the log's entry for the review, its date, commit, counts against the release review's, `make bench` against the baseline below, and how many lines took each decision; `findings.md`'s heading goes, and this document with it. Then the release review ([`release_review.md`](release_review.md)) and Ernest 0.2.0, whose notes list the rules that changed, so that the review's work ships as one and the next newcomer's program measures it; MVP 2.99b resumes at item 4 after the tag.

## The rules of the road

- Phases 1 and 2 change the report, the guide and the log, and nothing else: no code, no test, and no example's output, since the report's `// =>` lines and the guide's programs are run by tests.
- A sentence of phase 2 that the code does not yet meet is a gap the plan names, dated to phase 5, where the rule's code and its examples change together, a commit each rule.
- The report and the guide before the review are the release's, tag `v0.1.0`, and every commit of the review since `57b8356` touches documents only until phase 4, but for MVP 2.99b's item 1 in phase 3, `d60e7ff`, which fixed an example and two test modules; if the review is abandoned, a revert of that range but that commit restores them and the code needs no undoing.

## Cost

Phases 1 and 2 are fifteen questions, at the user's pace. Phase 4 is about a week. Phase 5 is unknown until phase 2 has run, and bounded by its list; the plan's estimate is revised then.

## The baseline

`make bench` before phase 4's first edit, so that the closure measures every change the review makes to the code, phase 4's fixes among them: on 2026-10-01 at `7da6136`, the machine idle, the median of three runs, nanoseconds an iteration.

| Operation | Ernest | Erlang | Ratio |
|---|---|---|---|
| the loop alone | 7.6 | 7.7 | 1.0 |
| a record added by a function | 14.2 | 12.2 | 1.1 |
| two records compared | 16.0 | 14.5 | 1.1 |
| `Map.get`, `maps:find` | 21.8 | 20.4 | 1.1 |
| `Map.put`, `maps:put` | 143.6 | 187.9 | 0.8 |
| `List.map` over 100, `lists:map` | 1120.0 | 784.4 | 1.4 |
| `List.size` of 100, `length` | 253.0 | 127.9 | 1.9 |
| `String.size`, `string:length` | 91.2 | 90.6 | 1.0 |
| `<>` and `String.size` | 145.2 | 122.3 | 1.2 |
| `Bytes.size`, `byte_size` | 14.9 | 8.0 | 1.9 |
| send and receive to self | 143.6 | 139.3 | 1.0 |
| a call answered, as `gen_server`'s | 2097.0 | 1223.9 | 1.7 |
| spawn a process that returns | 5295.0 | 1559.2 | 3.4 |
