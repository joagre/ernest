# Language feedback

What writing Ernest has felt against the principles, and what a reader found that questions a rule of the language rather than showing a defect (CLAUDE.md, *Defects and gaps*). An entry stays until a plan item decides it: a report change, a "Later" entry in the log, a question in the plan, or a line saying it was weighed and left alone. An entry keeps its number, which the plan, the log and the code cite; the next is 135.

133. **A vector cannot be multiplied by a number with `*`** (2026-10-20, `ernest-epx`'s `examples/raytracer.ern`, `Vector`). §4.8 makes an operator's member take two values of its own type, so `fn Vector.*(Vector, Float)` is refused and scaling is the function `scaled`, and vector arithmetic mixes operators with a call where the proposal itself had written `*`. Principle 1.

134. **`Float.sqrt` and `Float.pow` answer `Optional` where the argument cannot fail them** (2026-10-20, the same, `length` and `glint`). The square root of a sum of squares and a base not below zero to a power each carry a `None` arm that cannot run, here a `fault` naming why. Principle 3.
