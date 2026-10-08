# The principles review

The report's rules and the guide judged on §0, and §0 on what it decided. It runs alone, apart from the release review of [`release_review.md`](release_review.md) and the full review of [`full_review.md`](full_review.md), and its readers read the report and the guide, L the log too, and the code only as *How it runs* allows, to see what a rule means. It changes no rule; its findings do, in the milestone the plan gives them. It judges rules and not defects, so it may run while another review's findings are open.

## When it runs

- When the user asks.
- Before a milestone that adds to the type system or to Appendix E.0's rules, which the plan names.

## How it runs

As the full review's readers run ([`full_review.md`](full_review.md), *How it runs*): each reader a session of its own, given its brief and its files and nothing that argues for them, editing nothing, all on one revision of the report, each handing in a numbered list, most serious first. A reader in doubt of what a rule means reads the code that implements it, `erl/` and `stdlib/`, as what is built and never as what is right.

## The readers

Four readers in five sessions.

- **P, the principles**, with the full review's brief, in two parts: §0 to §11 with Appendices A to D, and Appendix E with F and G. Beside the report it reads what the plan proposes to add, told that it is proposed and not decided, so that the addition is judged with what is there. It leaves out peers, which are unbuilt and tentative: §3.11, §8.3, §8.7, what §6.10 says of a peer and Appendix C's entries for one; and it still reports every rule elsewhere that exists only for them. For each rule it also says whether the principles as written would admit the opposite rule as well; where they would, the principles do not decide it, and the reader proposes the sentence for §0 or E.0 that would.
- **K, the cold reader**, with the full review's brief, over the whole report but peers: what "consistent" means, a rule another rule contradicts or makes unreachable, and a builder made to guess. In Appendix E it also reads every function against E.0's rules and every rule against its functions, and reports every list of exceptions inside a rule, which is a rule stated at the wrong level, with the rule restated so that the list falls out and only the exception the report must keep remains.
- **W, where the guide works hard.** Reads `guide/language.md` and the report. "Read the guide as one who knows the report. Report every place the guide explains why a rule is as it is, warns, or says 'note that', with the rule that made the sentence necessary; every place it teaches a way around a rule; every job it must teach two ways; and every example whose shape a reader of the report would not have predicted. Apart, list every rule of the report the guide never teaches and never uses."
- **L, the log.** Reads `docs/decisions.md` and the report. "Read the log's entries as a set. Group them into families, a family being the decisions one sentence would decide: what the host's semantics decide, what is refused when a program is compiled and what faults when it runs, what is a member and what a module function, what waits and what answers at once, and what the standard library admits, among the families you find. For each family, list its entries and the principle each cites, and say whether the principle as written implies the verdict or would have implied the opposite as well; where it would, the family lacks a deciding sentence, and you propose it. Apart, report every entry decided on cost, on time or for now, with whether its reason still holds; and every two entries that decided alike cases differently." It hands in the families, the one with the most undecided entries first.

## The models

Every reader runs on the most advanced model there is, of the two [`full_review.md`](full_review.md)'s *The models* names: each brief judges a rule, against §0, against another rule, against what the guide must say for it, or against the decisions that cite it, and none holds text to a rule already stated. The decisions with the user and the sentences they add to §0, E.0 or a section take the most advanced as well; the edits that carry a decision through the report, the guide and the code take the one below.

## The findings

- They go to `findings.md` under a heading of their own, by family, each line naming its reader's letter and number, the readers' lists below, as the full review's.
- A line's decision: `sentence`, a rule added to §0 or E.0; `report`, a rule changed or removed; `kept`, with the principle that keeps it; `guide`, the guide changed where its rule stays; `fix`, a defect or a disagreement between two sections the readers met on the way, fixed in the milestone's edits; `log`, an entry of the log marked superseded or its reason restated; `later`, to the log's *Later* with what would change it.
- The decisions are taken with the user one at a time, in prose, in two rounds. First the sentences, since they are the measure: P's and L's proposals are compared, one both make being the strongest, and each is accepted into §0 or E.0 or refused. Then each family, under the principles as they then read. A rule goes only where the smallest program that shows it reads better without it, never for being a rule (principle 1), and never where a program under `examples/` or one a newcomer wrote gets harder.
- A family decided is closed: the log records the principle that decided it, and it is not reopened before 1.0 but by a program that shows a case the decision did not.

## Its cost

Five sessions, half a day; the decisions at the user's pace; then the milestone the plan gives the edits.
