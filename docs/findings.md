# The findings of the tour's outline

Found on 2026-10-23 while writing MVP 3.3's outline, [`proposals/tour/outline.md`](proposals/tour/outline.md), against report §3.11, §6.10, §11.2 and Appendix H, and by the spike that ran its sessions the same day. Each line stays until a plan item decides it, and carries what became of it once decided; the file goes when every line is done, dropped or planned.

## The lines

**The documents**

- T1 `fix`, done 2026-10-23: `why.md`'s fragment under *Code known by its hash*, `Peer.spawn("foo", fn() = count(0), 5000)`, stands after the message type that carries `Upgrade`, at which the spawn is refused as bound to its node (report §3.11); it is a fragment, which nothing checks. The fix, decided 2026-10-23: the sentence before the fragment names the first claim's counter, whose messages carry no function.
- T2 `planned`: the plan's MVP 3.3 sketch, items 2 and 7, has the counter spawned on the peer in chapter 2 moved to new code in chapter 7, and the refusal across versions and the `Upgrade` in one chapter. A process keeps its mailbox type for life, a type that carries `Upgrade` is bound, and the refusal is a type change where the move is a loop change, so neither can be built (the outline's section 1). The plan's sketch is rewritten from the outline when the outline is decided.

**The toolchain's messages**

- S1 `fix`: `a.compare(b)` written on a value of a type variable under `needs k.compare` is refused with `the type whose field compare is read is not determined; annotate it`, and an annotation does not help; the fix is `k.compare(a, b)` (report §4.9), which the help should name where a requirement on the variable is in force.
- S2 `fix`: a constructor of a private type named at the prompt, `Counter.Inc`, is refused with `unknown constructor Counter.Inc`, while the shell prints the type's name in an address's type; the message should say the type is not exported (report §4.2).
