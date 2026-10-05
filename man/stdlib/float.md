# Ernest module Float

*Since 0.1.0.*

Floating-point numbers, always finite.

A `Float` is a double-precision number. Use it for measurements and
fractions, and an `Int` for counts and anything that must be exact: `0.1 +
0.2` is not `0.3` in floating point.

**Always finite.** There is no infinity, no NaN and no negative zero. An
operation whose result would be infinite or no number, an overflow or a
division by zero, faults with the cause `float arithmetic error`. A function
with no answer for an argument, the square root of a negative number,
answers `None` instead (report §3.1).

The operators, `+`, `-`, `*`, `/` and the comparisons, are this module's,
and the language calls them for a `Float`. An `Int` and a `Float` do not
mix: `Int.toFloat` and `round` convert between them.

## Examples

An absolute value, doubled, as text:

```ernest
Float.toString(Float.abs(-2.5) * 2.0)
// => "5.0"
```

Rounding: `round` takes a half to the even neighbour, `floor` goes down and
`ceil` up:

```ernest
#(Float.round(2.5), Float.round(3.5), Float.floor(-2.5), Float.ceil(-2.5))
// => #(2, 4, -3, -2)
```

## See also

`Int.toFloat`, `String.toFloat`.

## Float.+

```ernest
Float.+(left : Float, right : Float) : Float
```

The sum, rounded to the nearest `Float`.

### Errors

Faults where the result is too large to be finite, with the cause `float
arithmetic error`.

## Float.-

```ernest
Float.-(left : Float, right : Float) : Float
```

The difference, rounded to the nearest `Float`.

### Errors

Faults where the result is too large to be finite, with the cause `float
arithmetic error`.

## Float.*

```ernest
Float.*(left : Float, right : Float) : Float
```

The product, rounded to the nearest `Float`.

### Errors

Faults where the result is too large to be finite, with the cause `float
arithmetic error`.

## Float./

```ernest
Float./(dividend : Float, divisor : Float) : Float
```

The quotient, rounded to the nearest `Float`.

### Errors

Faults where the result would not be finite, a `divisor` of 0.0 among them,
with the cause `float arithmetic error`.

## Float.negate

```ernest
Float.negate(float : Float) : Float
```

`-float`, which a prefix `-` calls.

### Examples

```ernest
Float.negate(1.5)
// => -1.5
```

## Float.compare

```ernest
Float.compare(left : Float, right : Float) : Ordering
```

Compares two floats by size, the order `<` and the other comparisons use.

### Examples

```ernest
Float.compare(2.0, 1.0)
// => Greater
```

## Float.abs

```ernest
Float.abs(float : Float) : Float
```

The absolute value: `abs(-1.5)` is `1.5`.

## Float.min

```ernest
Float.min(left : Float, right : Float) : Float
```

The smaller of the two.

### Examples

```ernest
#(Float.min(1.0, 2.0), Float.max(1.0, 2.0))
// => #(1.0, 2.0)
```

## Float.max

```ernest
Float.max(left : Float, right : Float) : Float
```

The larger of the two.

## Float.toString

```ernest
Float.toString(float : Float) : String
```

The shortest digits that read back as the same value, always with a
fraction: `100.0`, not `100`. From 0.0001 to below 1.0e16 they are written
plain, and beyond as one digit, the point, the rest and the exponent:
`1.0e16`.

### Examples

```ernest
#(Float.toString(1.0e15), Float.toString(1.0e16), Float.toString(0.00001))
// => #("1000000000000000.0", "1.0e16", "1.0e-5")
```

## Float.round

```ernest
Float.round(float : Float) : Int
```

The nearest `Int`, a tie to the even one: `round(2.5)` is `2` and
`round(3.5)` is `4`.

## Float.truncate

```ernest
Float.truncate(float : Float) : Int
```

The `Int` toward zero: `-2.7` gives `-2`.

### Examples

```ernest
#(Float.truncate(-2.7), Float.floor(-2.7))
// => #(-2, -3)
```

## Float.floor

```ernest
Float.floor(float : Float) : Int
```

The greatest `Int` not above `float`: `-2.7` gives `-3`.

### Examples

```ernest
#(Float.floor(2.7), Float.floor(-2.7))
// => #(2, -3)
```

## Float.ceil

```ernest
Float.ceil(float : Float) : Int
```

The least `Int` not below `float`: `2.1` gives `3`.

### Examples

```ernest
#(Float.ceil(2.2), Float.ceil(-2.2))
// => #(3, -2)
```

## Float.sqrt

```ernest
Float.sqrt(float : Float) : Optional(Float)
```

The square root, or `None` for a number below zero.

### Examples

```ernest
#(Float.sqrt(9.0), Float.sqrt(-1.0))
// => #(Some(3.0), None)
```

## Float.pow

```ernest
Float.pow(base : Float, exponent : Float) : Optional(Float)
```

`base` raised to `exponent`, or `None` where the result is no real number: a
negative base with a fractional exponent, or zero to a negative power.

### Errors

Faults where the result is too large to be finite, with the cause `float
arithmetic error`.

### Examples

```ernest
#(Float.pow(2.0, 10.0), Float.pow(-8.0, 0.5), Float.pow(0.0, -1.0))
// => #(Some(1024.0), None, None)
```

## Float.exp

```ernest
Float.exp(float : Float) : Float
```

`e` raised to the power `float`.

### Errors

Faults where the result is too large to be finite, with the cause `float
arithmetic error`.

### Examples

```ernest
Float.exp(0.0)
// => 1.0
```

## Float.log

```ernest
Float.log(float : Float) : Optional(Float)
```

The natural logarithm, or `None` for zero and below.

### Examples

```ernest
#(Float.log(1.0), Float.log(0.0))
// => #(Some(0.0), None)
```

## Float.pi

```ernest
Float.pi : Float
```

*Since 0.2.0.*

The ratio of a circle's circumference to its diameter, as the nearest
`Float`.

### Examples

```ernest
Float.cos(Float.pi)
// => -1.0
```

## Float.sin

```ernest
Float.sin(float : Float) : Float
```

The sine of an angle in radians. The other trigonometric functions take and
give radians too.

### Examples

```ernest
#(Float.sin(0.0), Float.cos(0.0), Float.tan(0.0))
// => #(0.0, 1.0, 0.0)
```

## Float.cos

```ernest
Float.cos(float : Float) : Float
```

The cosine of an angle in radians.

## Float.tan

```ernest
Float.tan(float : Float) : Float
```

The tangent of an angle in radians.

## Float.asin

```ernest
Float.asin(float : Float) : Optional(Float)
```

The angle, in radians, whose sine is `float`, or `None` outside -1.0 to 1.0.

### Examples

```ernest
#(Float.asin(0.0), Float.acos(2.0))
// => #(Some(0.0), None)
```

## Float.acos

```ernest
Float.acos(float : Float) : Optional(Float)
```

The angle, in radians, whose cosine is `float`, or `None` outside -1.0 to
1.0.

## Float.atan

```ernest
Float.atan(float : Float) : Float
```

The angle, in radians, whose tangent is `float`.

### Examples

```ernest
Float.atan(0.0)
// => 0.0
```

## Float.atan2

```ernest
Float.atan2(y : Float, x : Float) : Float
```

The angle, in radians, of the point `#(x, y)`, `y` given first. It keeps the
quadrant that `atan(y / x)` loses, and takes an `x` of 0.0.

### Examples

```ernest
Float.atan2(0.0, 1.0)
// => 0.0
```

---

Generated by ern 0.3.1 from float.ern.
