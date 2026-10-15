# Ernest module Int

*Since 0.1.0.*

Integers of any size.

An `Int` never overflows: arithmetic on it is exact however large the
numbers grow. Use a `Float` for fractions and measurements.

The operators, `+`, `-`, `*`, `/`, `%` and the comparisons, are this
module's, and the language calls them for an `Int`. `/` and `%` fault on a
divisor of 0; `div` and `rem` answer `None` instead.

## Examples

The larger of `abs(-7)` and 3, as text:

```ernest
Int.toString(Int.max(Int.abs(-7), 3))
// => "7"
```

`div` rounds toward zero and `rem` takes the sign of the dividend; a
division by zero is `None`:

```ernest
#(Int.div(-7, 3), Int.rem(-7, 3), Int.div(1, 0))
// => #(Some(-2), Some(-1), None)
```

## See also

`Float`, `String.toInt`.

## Int.+

```ernest
Int.+(left : Int, right : Int) : Int
```

The sum.

## Int.-

```ernest
Int.-(left : Int, right : Int) : Int
```

The difference.

## Int.*

```ernest
Int.*(left : Int, right : Int) : Int
```

The product.

## Int./

```ernest
Int./(dividend : Int, divisor : Int) : Int
```

The quotient, truncated toward zero: `-7 / 3` is `-2`.

### Errors

Faults where `divisor` is 0, with the cause `division by zero`. `Int.div`
answers `None` instead.

## Int.%

```ernest
Int.%(dividend : Int, divisor : Int) : Int
```

The remainder of `/`, with the sign of `dividend`: `-7 % 3` is `-1`.

### Errors

Faults where `divisor` is 0, with the cause `division by zero`. `Int.rem`
answers `None` instead.

## Int.negate

```ernest
Int.negate(int : Int) : Int
```

`-int`, which a prefix `-` calls.

### Examples

```ernest
Int.negate(5)
// => -5
```

## Int.div

```ernest
Int.div(dividend : Int, divisor : Int) : Optional(Int)
```

`dividend / divisor`, truncated toward zero, or `None` where `divisor` is 0.

## Int.rem

```ernest
Int.rem(dividend : Int, divisor : Int) : Optional(Int)
```

`dividend % divisor`, the remainder with the sign of `dividend`, or `None`
where `divisor` is 0.

## Int.compare

```ernest
Int.compare(left : Int, right : Int) : Ordering
```

Compares two integers by size, the order `<` and the other comparisons use.

### Examples

```ernest
Int.compare(1, 2)
// => Less
```

## Int.abs

```ernest
Int.abs(int : Int) : Int
```

The absolute value: `abs(-3)` is `3`.

## Int.min

```ernest
Int.min(left : Int, right : Int) : Int
```

The smaller of the two.

### Examples

```ernest
Int.min(1, 2)
// => 1
```

## Int.max

```ernest
Int.max(left : Int, right : Int) : Int
```

The larger of the two.

## Int.bitAnd

```ernest
Int.bitAnd(left : Int, right : Int) : Int
```

The bitwise and of the two, each taken as its two's complement form.

### Examples

```ernest
#(Int.bitAnd(6, 3), Int.bitOr(6, 3), Int.bitXor(6, 3), Int.bitNot(6))
// => #(2, 7, 5, -7)
```

## Int.bitOr

```ernest
Int.bitOr(left : Int, right : Int) : Int
```

The bitwise or of the two, each taken as its two's complement form.

## Int.bitXor

```ernest
Int.bitXor(left : Int, right : Int) : Int
```

The bitwise exclusive or of the two, each taken as its two's complement
form.

## Int.bitNot

```ernest
Int.bitNot(int : Int) : Int
```

Each bit of the two's complement form flipped, which is `-int - 1`.

### Examples

```ernest
#(Int.bitNot(0), Int.bitNot(5))
// => #(-1, -6)
```

## Int.shiftLeft

```ernest
Int.shiftLeft(int : Int, count : Int) : Int
```

`int` shifted left by `count` bits, which is `int` times two to the power
`count`. A `count` below 0 shifts nothing.

### Errors

Faults where the result is larger than the host can hold, with the cause
`error:system_limit`.

### Examples

```ernest
#(Int.shiftLeft(3, 2), Int.shiftRight(-7, 2), Int.shiftLeft(3, -1))
// => #(12, -2, 3)
```

## Int.shiftRight

```ernest
Int.shiftRight(int : Int, count : Int) : Int
```

`int` shifted right by `count` bits, the sign kept, which is `int` divided
by two to the power `count`, rounded down. A `count` below 0 shifts nothing.

## Int.toString

```ernest
Int.toString(int : Int) : String
```

The decimal digits of `int`, with a leading `-` where it is negative.

## Int.pow

```ernest
Int.pow(base : Int, exponent : Int) : Optional(Int)
```

`base` raised to `exponent`, exactly, or `None` where `exponent` is
negative, whose result is no integer.

### Examples

```ernest
#(Int.pow(2, 10), Int.pow(2, -1))
// => #(Some(1024), None)
```

## Int.toStringBase

```ernest
Int.toStringBase(int : Int, base : Int) : Optional(String)
```

The digits of `int` in `base`, 2 to 36, letters in upper case, with a
leading `-` where it is negative, or `None` for a base outside 2 to 36.

### Examples

```ernest
#(Int.toStringBase(255, 16), Int.toStringBase(5, 1))
// => #(Some("FF"), None)
```

## Int.toFloat

```ernest
Int.toFloat(int : Int) : Float
```

The `Float` nearest to `int`, a tie to the even one. A large integer loses
its low digits, since a `Float` holds about sixteen.

### Errors

Faults where `int` is beyond the largest finite `Float`, with the cause `Int
out of Float range`.

### Examples

```ernest
Int.toFloat(7)
// => 7.0
```

---

Generated by ern 0.3.1 from int.ern.
