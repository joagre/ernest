# Ernest module Float

*Since 0.1.0.*

Operations on `Float`, IEEE 754 double precision restricted to the
finite range (report §3.1). The arithmetic and the ordering are the
prelude's (report §9.6); this module provides them with the rest. No
operation here returns an infinity or a NaN: one that would, faults,
and one with no answer gives `None`. The module holds the operations of
the type itself; mathematics over collections of floats is a library.

## Examples

```ernest
Float.toString(Float.abs(-2.5) * 2.0)
// => "5.0"
```

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

Faults with `Fault("float arithmetic error")` when the result is not
finite (report §3.1).

## Float.-

```ernest
Float.-(left : Float, right : Float) : Float
```

The difference, rounded to the nearest `Float`.

### Errors

Faults with `Fault("float arithmetic error")` when the result is not
finite (report §3.1).

## Float.*

```ernest
Float.*(left : Float, right : Float) : Float
```

The product, rounded to the nearest `Float`.

### Errors

Faults with `Fault("float arithmetic error")` when the result is not
finite (report §3.1).

## Float./

```ernest
Float./(dividend : Float, divisor : Float) : Float
```

The quotient, rounded to the nearest `Float`.

### Errors

Faults with `Fault("float arithmetic error")` when the result is not
finite (report §3.1), which a divisor of `0.0` makes it.

## Float.negate

```ernest
Float.negate(float : Float) : Float
```

`-float`, which prefix `-` calls.

### Examples

```ernest
Float.negate(1.5)
// => -1.5
```

## Float.compare

```ernest
Float.compare(left : Float, right : Float) : Ordering
```

The numeric order, which `<` and the other comparisons use.

### Examples

```ernest
Float.compare(2.0, 1.0)
// => Greater
```

## Float.abs

```ernest
Float.abs(float : Float) : Float
```

The magnitude.

## Float.min

```ernest
Float.min(left : Float, right : Float) : Float
```

The smaller.

### Examples

```ernest
#(Float.min(1.0, 2.0), Float.max(1.0, 2.0))
// => #(1.0, 2.0)
```

## Float.max

```ernest
Float.max(left : Float, right : Float) : Float
```

The larger.

## Float.toString

```ernest
Float.toString(float : Float) : String
```

The shortest digits that read back as the same value, always with a
fraction: `100.0`, not `100`. From 0.0001 to below 1.0e16 they are
written plain; beyond, as one digit, the point, the rest, and the
exponent, whose sign is written only when it is negative.

### Examples

```ernest
#(Float.toString(1.0e15), Float.toString(1.0e16), Float.toString(0.00001))
// => #("1000000000000000.0", "1.0e16", "1.0e-5")
```

## Float.round

```ernest
Float.round(float : Float) : Int
```

The nearest `Int`, ties to even.

## Float.truncate

```ernest
Float.truncate(float : Float) : Int
```

Toward zero, so `-2.7` gives `-2`.

### Examples

```ernest
#(Float.truncate(-2.7), Float.floor(-2.7))
// => #(-2, -3)
```

## Float.floor

```ernest
Float.floor(float : Float) : Int
```

The greatest `Int` not above `float`.

### Examples

```ernest
#(Float.floor(2.7), Float.floor(-2.7))
// => #(2, -3)
```

## Float.ceil

```ernest
Float.ceil(float : Float) : Int
```

The least `Int` not below `float`.

### Examples

```ernest
#(Float.ceil(2.2), Float.ceil(-2.2))
// => #(3, -2)
```

## Float.sqrt

```ernest
Float.sqrt(float : Float) : Optional(Float)
```

The square root, or `None` below zero.

### Examples

```ernest
#(Float.sqrt(9.0), Float.sqrt(-1.0))
// => #(Some(3.0), None)
```

## Float.pow

```ernest
Float.pow(base : Float, exponent : Float) : Optional(Float)
```

`base` raised to `exponent`, or `None` where no real number is: a
negative base with a fractional exponent, and zero to a negative power.

### Errors

Faults with `Fault("float arithmetic error")` when the result is too
large to be finite, as `Float.exp` does (report §3.1).

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

Faults with `Fault("float arithmetic error")` when the result is not
finite (report §3.1).

### Examples

```ernest
Float.exp(0.0)
// => 1.0
```

## Float.log

```ernest
Float.log(float : Float) : Optional(Float)
```

The natural logarithm, or `None` at zero and below.

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

The ratio of a circle's circumference to its diameter, the nearest
`Float` to it, a constant of the type (report Appendix E.0 rule 3).

### Examples

```ernest
Float.cos(Float.pi)
// => -1.0
```

## Float.sin

```ernest
Float.sin(float : Float) : Float
```

The sine of an angle in radians, as the other trigonometric functions
take and give.

### Examples

```ernest
#(Float.sin(0.0), Float.cos(0.0), Float.tan(0.0))
// => #(0.0, 1.0, 0.0)
```

## Float.cos

```ernest
Float.cos(float : Float) : Float
```

The cosine.

## Float.tan

```ernest
Float.tan(float : Float) : Float
```

The tangent.

## Float.asin

```ernest
Float.asin(float : Float) : Optional(Float)
```

The angle whose sine is `float`, or `None` outside -1.0 to 1.0.

### Examples

```ernest
#(Float.asin(0.0), Float.acos(2.0))
// => #(Some(0.0), None)
```

## Float.acos

```ernest
Float.acos(float : Float) : Optional(Float)
```

The angle whose cosine is `float`, or `None` outside -1.0 to 1.0.

## Float.atan

```ernest
Float.atan(float : Float) : Float
```

The angle whose tangent is `float`.

### Examples

```ernest
Float.atan(0.0)
// => 0.0
```

## Float.atan2

```ernest
Float.atan2(y : Float, x : Float) : Float
```

The angle of the point `#(x, y)`, the `y` given first, which keeps the
quadrant that `atan(y / x)` loses.

### Examples

```ernest
Float.atan2(0.0, 1.0)
// => 0.0
```

---

Generated by ern 0.3.0 from float.ern.
