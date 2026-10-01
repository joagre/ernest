# The diagnostics

Errors the lexer, the parser and the checker give, each with one small program that gives it and what `ern build` prints for it, laid out as report §11.5 says; an error only the shell gives is shown in a session. `test/ern_guide_tests.erl` holds each output to the compiler's, and `make diagnostics` writes the outputs anew from the compiler, after a change to a message that is meant.

## The lexer (report §2)

### A character outside the language (§2.1)

```ernest-rejected
export fn main() : Unit with Never = Io.println(§)
```

```console
$ ern build example.ern
example.ern:1:49: illegal character '§'
1 | export fn main() : Unit with Never = Io.println(§)
  |                                                 ^
```

### A name longer than 255 characters (§2.3)

```ernest-rejected
export fn main() : Unit with Never = { let aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 1; Unit }
```

```console
$ ern build example.ern
example.ern:1:44: a name is at most 255 characters long
1 | export fn main() : Unit with Never = { let aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 1; Unit }
  |                                            ^
```

### An underscore that does not stand between two digits (§2.5)

```ernest-rejected
export fn size() : Int = 1_
```

```console
$ ern build example.ern
example.ern:1:27: _ must stand between two digits
1 | export fn size() : Int = 1_
  |                           ^
```

### An underscore after a base prefix (§2.5)

```ernest-rejected
export fn mask() : Int = 0x_FF
```

```console
$ ern build example.ern
example.ern:1:28: _ must stand between two digits
1 | export fn mask() : Int = 0x_FF
  |                            ^
```

### A letter directly after a number (§2.5)

```ernest-rejected
export fn width() : Int = 12px
```

```console
$ ern build example.ern
example.ern:1:29: p cannot follow a number directly
1 | export fn width() : Int = 12px
  |                             ^
```

### A base prefix with no digit (§2.5)

```ernest-rejected
export fn mask() : Int = 0x
```

```console
$ ern build example.ern
example.ern:1:26: 0x needs a hexadecimal digit
1 | export fn mask() : Int = 0x
  |                          ^
```

### A digit outside the base (§2.5)

```ernest-rejected
export fn flags() : Int = 0b102
```

```console
$ ern build example.ern
example.ern:1:31: 2 is not a binary digit
1 | export fn flags() : Int = 0b102
  |                               ^
```

### An uppercase base prefix (§2.5)

```ernest-rejected
export fn mask() : Int = 0XFF
```

```console
$ ern build example.ern
example.ern:1:26: a base prefix is lowercase: 0x
1 | export fn mask() : Int = 0XFF
  |                          ^
```

### A float beyond the largest finite Float (§2.5)

```ernest-rejected
export fn huge() : Float = 1.0e400
```

```console
$ ern build example.ern
example.ern:1:28: the float literal is beyond the largest finite Float
1 | export fn huge() : Float = 1.0e400
  |                            ^
```

### A raw string that never closes (§2.5)

```ernest-rejected
export fn pattern() : String = `\d+
```

```console
$ ern build example.ern
example.ern:1:32: unterminated raw string
1 | export fn pattern() : String = `\d+
  |                                ^
```

### A line break inside a string (§2.5)

```ernest-rejected
export fn greeting() : String = "hello
world"
```

```console
$ ern build example.ern
example.ern:1:39: newline in string literal; use \n
1 | export fn greeting() : String = "hello
  |                                       ^
```

### An empty character literal (§2.5)

```ernest-rejected
export fn blank() : Char = ''
```

```console
$ ern build example.ern
example.ern:1:28: empty char literal
1 | export fn blank() : Char = ''
  |                            ^
```

### A line break inside a character literal (§2.5)

```ernest-rejected
export fn newline() : Char = '
'
```

```console
$ ern build example.ern
example.ern:1:30: newline in char literal; use '\n'
1 | export fn newline() : Char = '
  |                              ^
```

### A character literal of two characters (§2.5)

```ernest-rejected
export fn letter() : Char = 'ab'
```

```console
$ ern build example.ern
example.ern:1:29: a char literal holds one code point; a string is written between double quotes
1 | export fn letter() : Char = 'ab'
  |                             ^
```

### A Unicode escape with no digit (§2.5)

```ernest-rejected
export fn nothing() : String = "\u{}"
```

```console
$ ern build example.ern
example.ern:1:33: \u{ needs one to six hex digits
1 | export fn nothing() : String = "\u{}"
  |                                 ^
```

### A Unicode escape of a surrogate (§2.5)

```ernest-rejected
export fn half() : String = "\u{D800}"
```

```console
$ ern build example.ern
example.ern:1:30: \u{D800} is not a Unicode scalar value
1 | export fn half() : String = "\u{D800}"
  |                              ^
```

### A Unicode escape that does not close (§2.5)

```ernest-rejected
export fn open() : String = "\u{41"
```

```console
$ ern build example.ern
example.ern:1:30: \u{ needs one to six hex digits followed by }
1 | export fn open() : String = "\u{41"
  |                              ^
```

### An escape the language does not have (§2.5)

```ernest-rejected
export fn bell() : String = "\a"
```

```console
$ ern build example.ern
example.ern:1:30: unknown escape \a
1 | export fn bell() : String = "\a"
  |                              ^
```

### A line break after a backslash (§2.5)

```ernest-rejected
export fn cut() : String = "\
```

```console
$ ern build example.ern
example.ern:1:29: a line break cannot follow `\`; use \n
1 | export fn cut() : String = "\
  |                             ^
```

### A block comment that never closes (§2.2)

```ernest-rejected
export fn one() : Int = 1 /* the rest is a comment
```

```console
$ ern build example.ern
example.ern:1:27: unterminated block comment
1 | export fn one() : Int = 1 /* the rest is a comment
  |                           ^
```

### A doc comment after code (§2.2)

```ernest-rejected
export fn one() : Int = 1 /// the one
```

```console
$ ern build example.ern
example.ern:1:27: a doc comment `///` stands on a line of its own; a note after code is written `//`
1 | export fn one() : Int = 1 /// the one
  |                           ^
```

## The parser (report §4, §5, Appendix A)

### Tokens after a whole input at the shell (§11.2)

```console
$ ern shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> 1 )
input 1:1:3: expected end of input instead of `)`
1 | 1 )
  |   ^
```

### Something that begins no declaration (§4.1)

```ernest-rejected
type Coin = Coin(Int)

1
```

```console
$ ern build example.ern
example.ern:3:1: expected a declaration (type, abstract, fn, let, foreign) instead of integer 1
2 | 
3 | 1
  | ^
```

### A result annotated with `->` (§4.5)

```ernest-rejected
fn double(n : Int) -> Int = n * 2
```

```console
$ ern build example.ern
example.ern:1:20: a function's result is annotated with `:`, not `->`
1 | fn double(n : Int) -> Int = n * 2
  |                    ^^
  | = help: write `: T` after the parameters, as a parameter's type is written
```

### A function written in two clauses (§4.4)

```ernest-rejected
fn size(xs : List(Int)) : Int = 0

fn size(xs : List(Int)) : Int = List.size(xs)
```

```console
$ ern build example.ern
example.ern:3:1: a function has one clause
1 | fn size(xs : List(Int)) : Int = 0
  | --------------------------------- first clause
...
3 | fn size(xs : List(Int)) : Int = List.size(xs)
  | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: write one clause whose body is a `match`
```

### `abstract` before something other than a type (§3.8)

```ernest-rejected
abstract fn hidden() : Int = 1
```

```console
$ ern build example.ern
example.ern:1:10: expected `type` after `abstract`
1 | abstract fn hidden() : Int = 1
  |          ^^
```

### An abstract type with a signature (§3.8)

```ernest-rejected
abstract type Stack = Stack(List(Int)) with { push }
```

```console
$ ern build example.ern
example.ern:1:40: an abstract type has no signature: every definition of its module may use its constructors, so leave out `with { ... }`
1 | abstract type Stack = Stack(List(Int)) with { push }
  |                                        ^^^^
```

### A type member without its name (§4.2)

```ernest-rejected
type Coin = Coin(Int)

fn Coin.1() -> Int = 1
```

```console
$ ern build example.ern
example.ern:3:9: expected an operator, `compare` or `negate` after `.` instead of integer 1
2 | 
3 | fn Coin.1() -> Int = 1
  |         ^
```

### A type's name where a function's name stands (§4.2)

```ernest-rejected
type Coin = Coin(Int)

fn Coin() : Int = 1
```

```console
$ ern build example.ern
example.ern:3:4: expected a name instead of type name `Coin`
2 | 
3 | fn Coin() : Int = 1
  |    ^^^^
  | = help: a function's name begins with a lowercase letter
```

### A type's other operation declared as a member (§4.5)

```ernest-rejected
type Stack = Stack(List(Int))

fn Stack.push(s : Stack, n : Int) : Stack = s
```

```console
$ ern build example.ern
example.ern:3:10: `push` cannot be a member of Stack: a member is an operator, `compare` or `negate`
2 | 
3 | fn Stack.push(s : Stack, n : Int) : Stack = s
  |          ^^^^
  | = help: a type's other operations are functions of its module: write `fn push`
```

### A member declared with `let` (§4.5)

```ernest-rejected
type Stack = Stack(List(Int))

let Stack.empty = Stack([])
```

```console
$ ern build example.ern
example.ern:3:5: a `let` declares no member of Stack
2 | 
3 | let Stack.empty = Stack([])
  |     ^^^^^
  | = help: a type's values are named in its module, as its functions are: write `let empty`
```

### An operator declared with `let` (§4.5)

```ernest-rejected
type Money = Money(Int)

let Money.+ = 1
```

```console
$ ern build example.ern
example.ern:3:5: a `let` declares no member of Money
2 | 
3 | let Money.+ = 1
  |     ^^^^^
  | = help: a member is declared with `fn`: write `fn Money.+(...)`
```

### A declaration with no name (§4.4)

```ernest-rejected
fn 1() -> Int = 1
```

```console
$ ern build example.ern
example.ern:1:4: expected a name instead of integer 1
1 | fn 1() -> Int = 1
  |    ^
```

### `<-` in a top-level `let` (§4.6)

```ernest-rejected
let x <- Some(1)
```

```console
$ ern build example.ern
example.ern:1:7: `<-` is a block form
1 | let x <- Some(1)
  |       ^^
  | = help: a top-level `let` uses `=`
```

### A foreign function without its result type (§8.4)

```ernest-rejected
foreign fn now() = "erlang:monotonic_time/0"
```

```console
$ ern build example.ern
example.ern:1:18: a foreign function declares its result type
1 | foreign fn now() = "erlang:monotonic_time/0"
  |                  ^
```

### A foreign function whose implementation is not a string (§8.4)

```ernest-rejected
foreign fn now() : Int = erlang
```

```console
$ ern build example.ern
example.ern:1:26: expected the implementation name as a string instead of identifier `erlang`
1 | foreign fn now() : Int = erlang
  |                          ^^^^^^
```

### `foreign` before something other than `type` or `fn` (§8.4)

```ernest-rejected
foreign let now = 1
```

```console
$ ern build example.ern
example.ern:1:9: expected `type` or `fn` after `foreign` instead of `let`
1 | foreign let now = 1
  |         ^^^
```

### Empty parentheses where a type stands (§3.2)

```ernest-rejected
fn f() : () = 1
```

```console
$ ern build example.ern
example.ern:1:10: expected a type inside the parentheses, or `->` after them
1 | fn f() : () = 1
  |          ^
  | = help: the type whose one value is written () is Unit
```

### Parenthesized types that are no function type (§3.2)

```ernest-rejected
fn f(pair : (Int, Int)) : Int = 1
```

```console
$ ern build example.ern
example.ern:1:23: expected `->` after a parameter list instead of `)`
1 | fn f(pair : (Int, Int)) : Int = 1
  |                       ^
  | = help: a tuple type is written with `#(`, as #(Int, Int)
```

### A qualified type that ends in a lowercase name (§3.2)

```ernest-rejected
fn f(xs : List.a) : Int = 1
```

```console
$ ern build example.ern
example.ern:1:11: expected a type name; a qualified type ends in an uppercase name
1 | fn f(xs : List.a) : Int = 1
  |           ^^^^^^
  | = help: a type's arguments are written in parentheses, as List(a), and a lowercase name after `.` names a value
```

### Something that is no type where a type stands (§3.2)

```ernest-rejected
fn f(x : 1) : Int = 1
```

```console
$ ern build example.ern
example.ern:1:10: expected a type instead of integer 1
1 | fn f(x : 1) : Int = 1
  |          ^
```

### A qualified name that ends in no name (§2.3)

```ernest-rejected
fn f() : Int = List.1
```

```console
$ ern build example.ern
example.ern:1:21: expected a name after `.` instead of integer 1
1 | fn f() : Int = List.1
  |                     ^
```

### Two expressions with nothing between them (§5)

```ernest-rejected
fn f() : Int = 1 2
```

```console
$ ern build example.ern
example.ern:1:18: unexpected integer 2 after an expression
1 | fn f() : Int = 1 2
  |                  ^
  | = help: a call is written f(x), and statements are separated by `;`
```

### An `if` without its `else` (§5.2)

```ernest-rejected
fn f(b : Bool) : Int = if b then 1
```

```console
$ ern build example.ern
example.ern:1:24: `if` needs an `else`
1 | fn f(b : Bool) : Int = if b then 1
  |                        ^^
  | = help: every `if` is an expression; give the other branch a value
```

### `_` where an expression stands (§5.10)

```ernest-rejected
fn f() : Int = _
```

```console
$ ern build example.ern
example.ern:1:16: `_` is a pattern, not an expression
1 | fn f() : Int = _
  |                ^
```

### A reserved word as an operand (§5)

```ernest-rejected
fn f(b : Bool) : Int = 1 + if b then 1 else 2
```

```console
$ ern build example.ern
example.ern:1:28: `if` is not an operand
1 | fn f(b : Bool) : Int = 1 + if b then 1 else 2
  |                            ^^
  | = help: parenthesize it
```

### Something that is no expression where one stands (§5)

```ernest-rejected
fn f() : Int = )
```

```console
$ ern build example.ern
example.ern:1:16: expected an expression instead of `)`
1 | fn f() : Int = )
  |                ^
```

### Empty parentheses after a nullary constructor (§3.3)

```ernest-rejected
fn f() : Optional(Int) = None()
```

```console
$ ern build example.ern
example.ern:1:31: empty parentheses after None
1 | fn f() : Optional(Int) = None()
  |                               ^
  | = help: a constructor without fields is written without parentheses, None; one with fields has its fields inside them
```

### An empty block (§5.4)

```ernest-rejected
fn f() : Int = {}
```

```console
$ ern build example.ern
example.ern:1:17: a block needs at least one expression
1 | fn f() : Int = {}
  |                 ^
```

### Two errors of one block (§11.5)

```ernest-rejected
fn f() : Unit with Never = {
    Io.println(1);
    Io.println(2);
    Unit
}
```

```console
$ ern build example.ern
example.ern:2:16: the argument does not fit Io.println: expected String, found Int
1 | fn f() : Unit with Never = {
2 |     Io.println(1);
  |     ---------- Io.println : (String) -> Unit with e
  |                ^

example.ern:3:16: the argument does not fit Io.println: expected String, found Int
2 |     Io.println(1);
3 |     Io.println(2);
  |     ---------- Io.println : (String) -> Unit with e
  |                ^
```

### A block that ends with `;` (§5.4)

```ernest-rejected
fn f() : Int = {
    1;
}
```

```console
$ ern build example.ern
example.ern:2:6: a block ends with an expression
1 | fn f() : Int = {
2 |     1;
  |      ^
  | = help: remove the trailing `;`
```

### A block that ends with a `let` (§5.4)

```ernest-rejected
fn f() : Int = {
    let x = 1
}
```

```console
$ ern build example.ern
example.ern:3:1: a block ends with an expression, not a `let`
2 |     let x = 1
3 | }
  | ^
  | = help: add the expression the block is worth after it
```

### A block that ends with a local function (§5.4)

```ernest-rejected
fn f() : Int = {
    fn g() : Int = 1
}
```

```console
$ ern build example.ern
example.ern:3:1: a block ends with an expression, not a `fn`
2 |     fn g() : Int = 1
3 | }
  | ^
  | = help: add the expression the block is worth after it
```

### A statement followed by neither `;` nor `}` (§5.4)

```ernest-rejected
fn f() : Int = {
    let x = 1;
    x )
}
```

```console
$ ern build example.ern
example.ern:3:7: expected `;` or `}` instead of `)`
2 |     let x = 1;
3 |     x )
  |       ^
```

### A `let` without `=` or `<-` (§5.4)

```ernest-rejected
fn f() : Int = {
    let x 1;
    x
}
```

```console
$ ern build example.ern
example.ern:2:11: expected `=` or `<-` instead of integer 1
1 | fn f() : Int = {
2 |     let x 1;
  |           ^
```

### `as` without a name (§5.10)

```ernest-rejected
fn f(x : Int) : Int =
    match x {
        1 as 2 -> 1
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:14: expected a name after `as` instead of integer 2
2 |     match x {
3 |         1 as 2 -> 1
  |              ^
```

### A negative pattern that is no number (§5.10)

```ernest-rejected
fn f(x : Int) : Int =
    match x {
        -a -> 1
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:10: expected a number after `-` in a pattern instead of identifier `a`
2 |     match x {
3 |         -a -> 1
  |          ^
```

### A function's name where a pattern's constructor stands (§5.10)

```ernest-rejected
fn f(xs : List(Int)) : Int =
    match xs {
        List.map -> 1
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:9: expected a constructor; a pattern cannot name a function or value
2 |     match xs {
3 |         List.map -> 1
  |         ^^^^^^^^
```

### Something that is no pattern where one stands (§5.10)

```ernest-rejected
fn f(x : Int) : Int =
    match x {
        ) -> 1
    }
```

```console
$ ern build example.ern
example.ern:3:9: expected a pattern instead of `)`
2 |     match x {
3 |         ) -> 1
  |         ^
```

### A constructor pattern the input ends inside (§5.10)

```ernest-rejected
fn f(x : Optional(Int)) : Int =
    match x {
        Some(
```

```console
$ ern build example.ern
example.ern:4:1: expected a pattern instead of end of input
3 |         Some(
4 | 
  | ^
```

### `unit`, which a size does not take (§5.11)

```ernest-rejected
fn f(n : Int) : Bytes = <<n:size(2)-unit(8)>>
```

```console
$ ern build example.ern
example.ern:1:37: there is no `unit` specifier
1 | fn f(n : Int) : Bytes = <<n:size(2)-unit(8)>>
  |                                     ^^^^
  | = help: a size counts bits, and octets for `bytes`: write `size(n * 8)`
```

### A bitstring specifier the language does not have (§5.11)

```ernest-rejected
fn f(b : Bytes) : Bytes = <<b:wide>>
```

```console
$ ern build example.ern
example.ern:1:31: unknown bitstring specifier `wide`
1 | fn f(b : Bytes) : Bytes = <<b:wide>>
  |                               ^^^^
```

### Something that is no bitstring specifier (§5.11)

```ernest-rejected
fn f(b : Bytes) : Bytes = <<b:1>>
```

```console
$ ern build example.ern
example.ern:1:31: expected a bitstring specifier instead of integer 1
1 | fn f(b : Bytes) : Bytes = <<b:1>>
  |                               ^
```

### A missing parenthesis (§4.4)

```ernest-rejected
fn f(x : Int -> Int = x
```

```console
$ ern build example.ern
example.ern:1:14: expected `)` instead of `->`
1 | fn f(x : Int -> Int = x
  |              ^^
```

### `<-` where a comparison with a negative number was meant (§2.6)

```ernest-rejected
fn f(a : Int) : Bool = if a<-1 then true else false
```

```console
$ ern build example.ern
example.ern:1:28: expected `then` instead of `<-`
1 | fn f(a : Int) : Bool = if a<-1 then true else false
  |                            ^^
  | = help: `<-` is one token; write `a < -1` to compare with a negative number
```

### A lowercase name where a type's name stands (§3.3)

```ernest-rejected
type point = Point(Int)
```

```console
$ ern build example.ern
example.ern:1:6: expected a type name instead of identifier `point`
1 | type point = Point(Int)
  |      ^^^^^
  | = help: a type name begins with an uppercase letter: Point
```

## Types (report §3)

### A type given the wrong number of arguments (§3.9)

```ernest-rejected
fn f(x : Optional(Int, Int)) : Int = 0
```

```console
$ ern build example.ern
example.ern:1:10: Optional takes 1 type argument, not 2
1 | fn f(x : Optional(Int, Int)) : Int = 0
  |          ^^^^^^^^^^^^^^^^^^
```

### A type nothing declares (§3)

```ernest-rejected
fn f(x : Colour) : Int = 0
```

```console
$ ern build example.ern
example.ern:1:10: unknown type Colour
1 | fn f(x : Colour) : Int = 0
  |          ^^^^^^
```

### A qualified type nothing declares (§4.2)

```ernest-rejected
fn f(x : Shapes.Colour) : Int = 0
```

```console
$ ern build example.ern
example.ern:1:10: unknown type Shapes.Colour
1 | fn f(x : Shapes.Colour) : Int = 0
  |          ^^^^^^^^^^^^^
```

### `Prelude.` before a type the prelude lacks (§4.2)

```ernest-rejected
fn f(x : Prelude.Colour) : Int = 0
```

```console
$ ern build example.ern
example.ern:1:10: the prelude declares no type Colour
1 | fn f(x : Prelude.Colour) : Int = 0
  |          ^^^^^^^^^^^^^^
```

### A type named `Prelude` (§4.2)

```ernest-rejected
type Prelude = Prelude
```

```console
$ ern build example.ern
example.ern:1:1: Prelude names the prelude, and a type may not take it
1 | type Prelude = Prelude
  | ^^^^^^^^^^^^^^^^^^^^^^
```

### A type declared twice (§4.3)

```ernest-rejected
type Colour = Red
type Colour = Blue
```

```console
$ ern build example.ern
example.ern:2:1: type Colour is declared twice
1 | type Colour = Red
  | ----------------- first declared here
2 | type Colour = Blue
  | ^^^^^^^^^^^^^^^^^^
```

### A constructor declared twice (§3.5)

```ernest-rejected
type Colour = Red | Red
```

```console
$ ern build example.ern
example.ern:1:21: constructor Red is declared twice
1 | type Colour = Red | Red
  |               --- first declared here
  |                     ^^^
```

### A field named twice in a constructor (§3.5)

```ernest-rejected
type Point = Point(x : Int, x : Int)
```

```console
$ ern build example.ern
example.ern:1:29: field x is declared twice
1 | type Point = Point(x : Int, x : Int)
  |                    ------- first declared here
  |                             ^^^^^^^
```

### A type variable that is no parameter (§3.9)

```ernest-rejected
type Box = Box(a)
```

```console
$ ern build example.ern
example.ern:1:16: type variable a is not a parameter of the type
1 | type Box = Box(a)
  |                ^
```

## Declarations (report §4)

### A value declared twice (§4.5)

```ernest-rejected
let n = 1

let n = 2
```

```console
$ ern build example.ern
example.ern:3:1: value n is declared twice
1 | let n = 1
  | --------- first declared here
...
3 | let n = 2
  | ^^^^^^^^^
```

### A member of a type the module does not declare (§4.2)

```ernest-rejected
fn Colour.negate(n : Int) : Int = n
```

```console
$ ern build example.ern
example.ern:1:1: Colour is not a type declared in this module
1 | fn Colour.negate(n : Int) : Int = n
  | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

### An operator member of the wrong shape (§4.8)

```ernest-rejected
type Money = Money(Int)

fn Money.+(a : Money, b : Int) : Money = a
```

```console
$ ern build example.ern
example.ern:3:1: Money.+ must have the type (Money, Money) -> Money, not (Money, Int) -> Money
2 | 
3 | fn Money.+(a : Money, b : Int) : Money = a
  | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: a member named by an operator takes two values of its type and is pure
```

### A top-level `let` with an effect whose type is not determined (§4.6)

```ernest-rejected
let box = {
    let p : Address(Unit) = spawn(Local, fn() = Unit);
    []
}
```

```console
$ ern build example.ern
example.ern:1:1: the type of box is not determined (List(a)), and a top-level `let` whose initializer calls a process-only function is not generalized; annotate it
1 | let box = {
  | ^^^^^^^^^^^
```

### A foreign implementation of the wrong arity (§8.4)

```ernest-rejected
foreign fn size(t : Foreign) : Int =
    "erlang:tuple_size/2"
```

```console
$ ern build example.ern
example.ern:2:5: the implementation names arity 2, and size has 1 parameter
1 | foreign fn size(t : Foreign) : Int =
2 |     "erlang:tuple_size/2"
  |     ^^^^^^^^^^^^^^^^^^^^^
```

### A foreign implementation that is no `module:function/arity` (§8.4)

```ernest-rejected
foreign fn size(t : Foreign) : Int =
    "tuple_size"
```

```console
$ ern build example.ern
example.ern:2:5: the implementation of size is named module:function/arity, here module:function/1
1 | foreign fn size(t : Foreign) : Int =
2 |     "tuple_size"
  |     ^^^^^^^^^^^^
```

### A refutable parameter pattern (§4.5)

```ernest-rejected
fn f(Some(x)) : Int = x
```

```console
$ ern build example.ern
example.ern:1:6: a parameter pattern must be irrefutable
1 | fn f(Some(x)) : Int = x
  |      ^^^^^^^
  | = help: take the value whole, and match on it in the body
```

### A parameter pattern that does not fit its annotation (§4.5)

```ernest-rejected
fn f(#(a, b) : Int) : Int = a
```

```console
$ ern build example.ern
example.ern:1:6: the parameter pattern does not fit its annotation: expected Int, found #(a, b)
1 | fn f(#(a, b) : Int) : Int = a
  |      ^^^^^^^
  |                --- declared Int here
```

### A body that does not have the declared result type (§4.5)

```ernest-rejected
fn f() : Int = "one"
```

```console
$ ern build example.ern
example.ern:1:16: the body does not have the declared result type: expected Int, found String
1 | fn f() : Int = "one"
  |          --- result type Int declared here
  |                ^^^^^
```

### A value that does not have the declared type (§4.6)

```ernest-rejected
let n : Int = "one"
```

```console
$ ern build example.ern
example.ern:1:15: the value does not have the declared type: expected Int, found String
1 | let n : Int = "one"
  |         --- declared Int here
  |               ^^^^^
```

### A top-level `let` that depends on itself through a function (§8.5)

```ernest-rejected
let handlers = [f]

fn f() : Int = List.size(handlers)
```

```console
$ ern build example.ern
example.ern:1:1: the initializer of handlers depends on itself, through f
1 | let handlers = [f]
  | ^^^^^^^^^^^^^^^^^^
  | = help: `f` reads handlers when it is called; a `fn handlers() = ...` builds the value when it is asked for
```

## Names (report §4.2)

### A name nothing binds (§4.2)

```ernest-rejected
fn f() : Int = count
```

```console
$ ern build example.ern
example.ern:1:16: unknown name count
1 | fn f() : Int = count
  |                ^^^^^
```

### A qualified name nothing declares (§4.2)

```ernest-rejected
fn f() : Int = List.count([1])
```

```console
$ ern build example.ern
example.ern:1:16: unknown name List.count
1 | fn f() : Int = List.count([1])
  |                ^^^^^^^^^^
```

### `Prelude.` before a name deeper than a prelude namespace's (§4.2)

```ernest-rejected
fn f() : Unit with m = Prelude.Io.println("x")
```

```console
$ ern build example.ern
example.ern:1:24: Prelude.Io.println is written only where the module hides Io.println
1 | fn f() : Unit with m = Prelude.Io.println("x")
  |                        ^^^^^^^^^^^^^^^^^^
  | = help: nothing here hides it; write Io.println
```

### A constructor nothing declares (§4.2)

```ernest-rejected
fn f() : Int = {
    let c = Red;
    1
}
```

```console
$ ern build example.ern
example.ern:2:13: unknown constructor Red
1 | fn f() : Int = {
2 |     let c = Red;
  |             ^^^
```

### A shadowed prelude constructor where the prelude's is wanted (§4.2)

```ernest-rejected
type Place = Local | Remote

fn start() : Unit with m = {
    let _ = spawn(Local, fn() : Unit with Never = Unit);
    Unit
}
```

```console
$ ern build example.ern
example.ern:4:19: the argument does not fit spawn: expected Where, found Place
3 | fn start() : Unit with m = {
4 |     let _ = spawn(Local, fn() : Unit with Never = Unit);
  |             ----- spawn : (Where, () -> Unit with a) -> Address(a) with e
  |                   ----- `Local` here is this module's constructor, and the prelude's is `Prelude.Local`
  |                   ^^^^^
```

### `Prelude.` where nothing hides the name (§4.2)

```ernest-rejected
fn f() : Optional(Int) = Prelude.Some(1)
```

```console
$ ern build example.ern
example.ern:1:26: Prelude.Some is written only where the module hides the prelude's Some
1 | fn f() : Optional(Int) = Prelude.Some(1)
  |                          ^^^^^^^^^^^^
  | = help: nothing here hides it; write Some
```

### `Prelude.` before a constructor the prelude lacks (§4.2)

```ernest-rejected
fn f() : Int = {
    let c = Prelude.Red;
    1
}
```

```console
$ ern build example.ern
example.ern:2:13: the prelude declares no constructor Red
1 | fn f() : Int = {
2 |     let c = Prelude.Red;
  |             ^^^^^^^^^^^
```

### A qualified constructor nothing declares (§4.2)

```ernest-rejected
fn f() : Int = {
    let c = Colours.Red;
    1
}
```

```console
$ ern build example.ern
example.ern:2:13: unknown constructor Colours.Red
1 | fn f() : Int = {
2 |     let c = Colours.Red;
  |             ^^^^^^^^^^^
```

### Another module's abstract constructor (§4.4)

```ernest-rejected
fn f() : Random.Seed = Random.Seed(1)
```

```console
$ ern build example.ern
example.ern:1:24: Random.Seed is the constructor of an abstract type and is not visible outside its module
1 | fn f() : Random.Seed = Random.Seed(1)
  |                        ^^^^^^^^^^^^^^
```

### An abstract constructor of an earlier input (§4.4, §11.2)

```console
$ ern shell
Ernest 0.1.0. :help for the commands, :quit to leave.
> export abstract type Box = Box(Int)
abstract type Box
> Box(1)
input 2:1:1: Box is the constructor of an abstract type and is not visible outside the input that declared it
1 | Box(1)
  | ^^^^^^
```

### A private abstract type (§4.4)

```ernest-rejected
abstract type Box = Box(Int)
```

```console
$ ern build example.ern
example.ern:1:1: Box is an abstract type the module keeps private, which hides its constructors from no module
1 | abstract type Box = Box(Int)
  | ^^^^^^^^
  | = help: export it, or declare it `type`
```

### A private type in an exported signature (§4.2)

```ernest-rejected
type Box = Box(Int)

export fn f() : Box = Box(1)
```

```console
$ ern build example.ern
example.ern:3:8: f is exported and its type names Box, which this module keeps private
2 | 
3 | export fn f() : Box = Box(1)
  |        ^^^^^^^^^^^^^^^^^^^^^
  | = help: export Box, or declare it `abstract type` so that its constructors stay private (§4.4)
```

## Fields and construction (report §3.5, §5.6)

### A field of a type that has none (§3.5)

```ernest-rejected
fn f(n : Int) : Int = n.size
```

```console
$ ern build example.ern
example.ern:1:25: Int has no field size
1 | fn f(n : Int) : Int = n.size
  |                         ^^^^
```

### A field of a tuple (§3.5)

```ernest-rejected
fn f(t : #(Int, Int)) : Int = t.size
```

```console
$ ern build example.ern
example.ern:1:33: #(Int, Int) has no field size
1 | fn f(t : #(Int, Int)) : Int = t.size
  |                                 ^^^^
```

### A field the type lacks (§3.5)

```ernest-rejected
type Point = Point(x : Int)

fn f(p : Point) : Int = p.y
```

```console
$ ern build example.ern
example.ern:3:27: Point has no field y
2 | 
3 | fn f(p : Point) : Int = p.y
  |                           ^
```

### A field one constructor lacks (§3.5)

```ernest-rejected
type Shape = Circle(r : Int) | Dot

fn f(s : Shape) : Int = s.r
```

```console
$ ern build example.ern
example.ern:3:27: not every constructor of Shape has the field r: Dot has none
2 | 
3 | fn f(s : Shape) : Int = s.r
  |                           ^
```

### A field of two types (§3.5)

```ernest-rejected
type Shape = Circle(r : Int) | Square(r : Float)

fn f(s : Shape) : Int = s.r
```

```console
$ ern build example.ern
example.ern:3:27: Shape has no field r of one type: r is Int in Circle and Float in Square
2 | 
3 | fn f(s : Shape) : Int = s.r
  |                           ^
```

### A field of another module's abstract type (§4.4)

```ernest-rejected
fn f(s : Random.Seed) : Int = s.value
```

```console
$ ern build example.ern
example.ern:1:33: Random.Seed is abstract, and its fields are its module's alone
1 | fn f(s : Random.Seed) : Int = s.value
  |                                 ^^^^^
```

### A field of a value whose type is not determined (§4.8)

```ernest-rejected
fn f(p) = p.x
```

```console
$ ern build example.ern
example.ern:1:13: the type whose field x is read is not determined; annotate it
1 | fn f(p) = p.x
  |             ^
```

### A field read at another type than its own (§3.5)

```ernest-rejected
type Point = Point(x : Int)

fn f(p) : String = {
    let s : String = p.x;
    let q : Point = p;
    s
}
```

```console
$ ern build example.ern
example.ern:4:24: the field x: expected String, found Int
3 | fn f(p) : String = {
4 |     let s : String = p.x;
  |             ------ declared String here
  |                        ^
```

### Fields given to a constructor that has none (§5.6)

```ernest-rejected
fn f() : Unit = Unit(1)
```

```console
$ ern build example.ern
example.ern:1:17: Unit takes no fields
1 | fn f() : Unit = Unit(1)
  |                 ^^^^^^^
```

### Named fields given to a positional constructor (§5.6)

```ernest-rejected
fn f() : Optional(Int) = Some(value = 1)
```

```console
$ ern build example.ern
example.ern:1:26: Some has one positional field, not named fields
1 | fn f() : Optional(Int) = Some(value = 1)
  |                          ^^^^^^^^^^^^^^^
```

### A positional field given to a constructor of named fields (§5.6)

```ernest-rejected
type Point = Point(x : Int)

fn f() : Point = Point(1)
```

```console
$ ern build example.ern
example.ern:3:18: Point has named fields; write Point(x = value)
2 | 
3 | fn f() : Point = Point(1)
  |                  ^^^^^^^^
```

### A field given twice (§5.6)

```ernest-rejected
type Point = Point(x : Int)

fn f() : Point = Point(x = 1, x = 2)
```

```console
$ ern build example.ern
example.ern:3:31: field x is given twice
2 | 
3 | fn f() : Point = Point(x = 1, x = 2)
  |                        ----- first given here
  |                               ^^^^^
```

### A field the constructor lacks (§5.6)

```ernest-rejected
type Point = Point(x : Int)

fn f() : Point = Point(x = 1, y = 2)
```

```console
$ ern build example.ern
example.ern:3:18: Point has no field y
2 | 
3 | fn f() : Point = Point(x = 1, y = 2)
  |                  ^^^^^^^^^^^^^^^^^^^
```

### A field left out (§5.6)

```ernest-rejected
type Point = Point(x : Int, y : Int)

fn f() : Point = Point(x = 1)
```

```console
$ ern build example.ern
example.ern:3:18: missing field y
2 | 
3 | fn f() : Point = Point(x = 1)
  |                  ^^^^^^^^^^^^
```

### A field of the wrong type (§5.6)

```ernest-rejected
type Point = Point(x : Int)

fn f() : Point = Point(x = "one")
```

```console
$ ern build example.ern
example.ern:3:28: field x: expected Int, found String
2 | 
3 | fn f() : Point = Point(x = "one")
  |                  ----- Point declares x : Int
  |                            ^^^^^
```

### `..` from a value of another type (§5.6)

```ernest-rejected
type Point = Point(x : Int, y : Int)

fn f() : Point = Point(..5, x = 1)
```

```console
$ ern build example.ern
example.ern:3:26: the base of `..` must have the constructor's type: expected Point, found Int
2 | 
3 | fn f() : Point = Point(..5, x = 1)
  |                  ----- a constructor of Point
  |                          ^
```

### `..` on a type of two constructors (§5.6)

```ernest-rejected
type Shape = Circle(r : Int, x : Int) | Dot

fn f(s : Shape) : Shape = Circle(..s, r = 1)
```

```console
$ ern build example.ern
example.ern:3:27: `..` is allowed only on a type with one constructor, and Shape has 2
2 | 
3 | fn f(s : Shape) : Shape = Circle(..s, r = 1)
  |                           ^^^^^^^^^^^^^^^^^^
  | = help: give every field of Circle
```

## Operators (report §4.8)

### An operator on operands whose type is not determined (§4.8)

```ernest-rejected
fn f(a, b) = a + b
```

```console
$ ern build example.ern
example.ern:1:14: the operand type of `+` is not determined; annotate it
1 | fn f(a, b) = a + b
  |              ^^^^^
```

### An operator whose result is used at another type (§4.8)

```ernest-rejected
fn f(a, b) : Int = {
    let s : String = a + b;
    let n : Int = a;
    n
}
```

```console
$ ern build example.ern
example.ern:2:22: the result of `+`: expected String, found Int
1 | fn f(a, b) : Int = {
2 |     let s : String = a + b;
  |             ------ declared String here
  |                      ^^^^^
```

### An operator the type does not define (§4.8)

```ernest-rejected
fn f(a : Bool, b : Bool) : Bool = a + b
```

```console
$ ern build example.ern
example.ern:1:35: `+` is not defined on Bool
1 | fn f(a : Bool, b : Bool) : Bool = a + b
  |                                   ^^^^^
```

### Operands of two types (§4.8)

```ernest-rejected
fn f() : Int = 1 + "two"
```

```console
$ ern build example.ern
example.ern:1:20: both operands of `+` must have the same type: expected Int, found String
1 | fn f() : Int = 1 + "two"
  |                - the left operand has type Int
  |                    ^^^^^
```

### An operator member used at a type it was not declared for (§4.8)

```ernest-rejected
type Vec(a) = Vec(List(a))

fn Vec.+(a : Vec(Int), b : Vec(Int)) : Vec(Int) = a

fn f(v : Vec(String)) : Vec(String) = v + v
```

```console
$ ern build example.ern
example.ern:5:39: Vec.+ does not fit two operands of Vec(String): expected (Vec(String), Vec(String)) -> a, found (Vec(Int), Vec(Int)) -> Vec(Int)
2 | 
3 | fn Vec.+(a : Vec(Int), b : Vec(Int)) : Vec(Int) = a
  | ----------------------------------------------- Vec.+ : (Vec(Int), Vec(Int)) -> Vec(Int)
...
5 | fn f(v : Vec(String)) : Vec(String) = v + v
  |                                       ^^^^^
  | = help: the types differ at String and Int
```

### A `compare` that returns no Ordering, used as it is declared (§4.8)

```ernest-rejected
type Money = Money(Int)

fn Money.compare(a : Money, b : Money) : Int = if a < b then 1 else 2
```

```console
$ ern build example.ern
example.ern:3:42: Money.compare must have the type (Money, Money) -> Ordering, not (Money, Money) -> Int
2 | 
3 | fn Money.compare(a : Money, b : Money) : Int = if a < b then 1 else 2
  |                                          ^^^
  | = help: compare takes two values of its type, returns an Ordering, and is pure
```

### `&&` on a value that is no Bool (§4.8)

```ernest-rejected
fn f(b : Bool) : Bool = 1 && b
```

```console
$ ern build example.ern
example.ern:1:25: the left operand of `&&`: expected Bool, found Int
1 | fn f(b : Bool) : Bool = 1 && b
  |                         ^
```

### `||` on a value that is no Bool (§4.8)

```ernest-rejected
fn f(b : Bool) : Bool = b || 1
```

```console
$ ern build example.ern
example.ern:1:30: the right operand of `||`: expected Bool, found Int
1 | fn f(b : Bool) : Bool = b || 1
  |                              ^
```

### `!` on a value that is no Bool (§4.8)

```ernest-rejected
fn f() : Bool = !1
```

```console
$ ern build example.ern
example.ern:1:17: the operand of `!`: expected Bool, found Int
1 | fn f() : Bool = !1
  |                 ^^
```

### `::` onto a list of another type (§3.3)

```ernest-rejected
fn f() : List(Int) = 1 :: ["two"]
```

```console
$ ern build example.ern
example.ern:1:27: the right operand of `::` must be a list of the left operand's type: expected List(Int), found List(String)
1 | fn f() : List(Int) = 1 :: ["two"]
  |                      - the left operand has type Int
  |                           ^^^^^^^
  | = help: the types differ at Int and String
```

### `==` on functions (§3.10)

```ernest-rejected
fn f(g : () -> Int) : Bool = g == g
```

```console
$ ern build example.ern
example.ern:1:30: `==` is not defined on () -> Int: it contains a function or an address
1 | fn f(g : () -> Int) : Bool = g == g
  |                              ^^^^^^
```

### `==` reached through a function's type variable (§3.10)

```ernest-rejected
fn same(a, b) = a == b

fn f() : Bool = same(fn() = 1, fn() = 1)
```

```console
$ ern build example.ern
example.ern:3:17: () -> Int does not support equality (it contains a function or an address), which same requires: same : (a=, a=) -> Bool
2 | 
3 | fn f() : Bool = same(fn() = 1, fn() = 1)
  |                 ^^^^
```

## Expressions (report §5)

### A call with the wrong number of arguments (§5.2)

```ernest-rejected
fn g(a : Int) : Int = a

fn f() : Int = g(1, 2)
```

```console
$ ern build example.ern
example.ern:3:16: g takes 1 argument, not 2
2 | 
3 | fn f() : Int = g(1, 2)
  |                ^^^^^^^
  | = help: a call supplies all the arguments
```

### An argument of the wrong type (§5.2)

```ernest-rejected
fn g(a : Int) : Int = a

fn f() : Int = g("one")
```

```console
$ ern build example.ern
example.ern:3:18: the argument does not fit g: expected Int, found String
2 | 
3 | fn f() : Int = g("one")
  |                - g : (Int) -> Int
  |                  ^^^^^
```

### A call of a value that is no function (§5.2)

```ernest-rejected
fn f(n : Int) : Int = n(1)
```

```console
$ ern build example.ern
example.ern:1:23: n is not a function; it has type Int
1 | fn f(n : Int) : Int = n(1)
  |                       ^^^^
```

### A function applied to itself (§5.2)

```ernest-rejected
fn f(g) = g(g)
```

```console
$ ern build example.ern
example.ern:1:11: calling g needs it to be a function: a type that would contain itself (a against (a) -> b)
1 | fn f(g) = g(g)
  |           ^^^^
```

### A lambda body that does not have the declared type (§5.3)

```ernest-rejected
fn f() : () -> Int = fn() : Int = "one"
```

```console
$ ern build example.ern
example.ern:1:35: the lambda body does not have the declared type: expected Int, found String
1 | fn f() : () -> Int = fn() : Int = "one"
  |                             --- result type Int declared here
  |                                   ^^^^^
```

### A condition that is no Bool (§5.8)

```ernest-rejected
fn f() : Int = if 1 then 2 else 3
```

```console
$ ern build example.ern
example.ern:1:19: the condition of `if`: expected Bool, found Int
1 | fn f() : Int = if 1 then 2 else 3
  |                   ^
```

### Branches of two types (§5.8)

```ernest-rejected
fn f(b : Bool) = if b then 1 else "two"
```

```console
$ ern build example.ern
example.ern:1:35: the branches of `if` must have one type: expected Int, found String
1 | fn f(b : Bool) = if b then 1 else "two"
  |                            - the then branch has type Int
  |                                   ^^^^^
```

### A list of two types (§3.3)

```ernest-rejected
fn f() = [1, "two"]
```

```console
$ ern build example.ern
example.ern:1:14: list elements must have one type: expected Int, found String
1 | fn f() = [1, "two"]
  |           - the first element has type Int
  |              ^^^^^
```

### A statement whose value is dropped (§5.4)

```ernest-rejected
fn f() : Int = {
    1;
    2
}
```

```console
$ ern build example.ern
example.ern:2:5: this statement's value is discarded: expected Unit, found Int
1 | fn f() : Int = {
2 |     1;
  |     ^
  | = help: `let _ = ...` discards it on purpose
```

### A local function declared twice (§5.4)

```ernest-rejected
fn f() : Int = {
    fn g() : Int = 1;
    let n = 1;
    fn g() : Int = 2;
    g()
}
```

```console
$ ern build example.ern
example.ern:4:5: local function g is declared twice in the block
1 | fn f() : Int = {
2 |     fn g() : Int = 1;
  |     ---------------- first declared here
...
4 |     fn g() : Int = 2;
  |     ^^^^^^^^^^^^^^^^
```

### A type-member name on a local function (§5.4)

```ernest-rejected
fn f() : Int = {
    fn Int.negate(n : Int) : Int = n;
    1
}
```

```console
$ ern build example.ern
example.ern:2:5: a member, `fn Int.negate`, is a top-level form; a local function has a plain name
1 | fn f() : Int = {
2 |     fn Int.negate(n : Int) : Int = n;
  |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

### A recursive call at another type than the definition's (§4.5)

```ernest-rejected
fn f(x) = if x then f(1) else 2
```

```console
$ ern build example.ern
example.ern:1:23: the argument does not fit f: expected Bool, found Int
1 | fn f(x) = if x then f(1) else 2
  |                     - f : (Bool) -> a
  |                       ^
  | = help: a recursive call is at the definition's own type, so a call at another type goes to a second function (§3.9)
```

### A recursive use at another type than the `let`'s (§4.6)

```ernest-rejected
let f = fn(x) = if x then f(1) else 2
```

```console
$ ern build example.ern
example.ern:1:1: recursive use does not match the definition: expected (Bool) -> Int, found (Int) -> Int
1 | let f = fn(x) = if x then f(1) else 2
  | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: the types differ at Bool and Int

example.ern:1:1: the initializer of f depends on itself
1 | let f = fn(x) = if x then f(1) else 2
  | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: a recursive function is declared with `fn f(...) = ...`
```

### A type variable of an annotation used as a type (§3.9)

```ernest-rejected
fn id(x : a) : a = 1
```

```console
$ ern build example.ern
example.ern:1:20: the body does not have the declared result type: expected a, found Int
1 | fn id(x : a) : a = 1
  |                - result type a declared here
  |                    ^
```

### Two type variables of an annotation used as one (§3.9)

```ernest-rejected
fn f(x : a, y : b) : a = y
```

```console
$ ern build example.ern
example.ern:1:26: the body does not have the declared result type: expected a, found b
1 | fn f(x : a, y : b) : a = y
  |                      - result type a declared here
  |                          ^
```

### A reply passed where a function discards its argument (§3.9, §6.6)

```ernest-rejected
fn drop(x) = Unit

fn f(r : Reply(Int)) : Unit with m = drop(r)
```

```console
$ ern build example.ern
example.ern:3:38: a reply-carrying value, Reply(Int), passed where drop duplicates or discards its argument: drop : (a!) -> Unit
2 | 
3 | fn f(r : Reply(Int)) : Unit with m = drop(r)
  |                                      ^^^^
  | = help: a reply is discharged by answering it, passing it on once, or matching it (§6.6)
```

## Names in a block (report §5.4)

### A local function with a variable's name (§5.4)

```ernest-rejected
fn f() : Int = {
    let g = 1;
    fn g() : Int = 2;
    g()
}
```

```console
$ ern build example.ern
example.ern:3:5: local function g has the name of a variable in scope where it is declared
1 | fn f() : Int = {
2 |     let g = 1;
  |         - g is bound here
3 |     fn g() : Int = 2;
  |     ^^^^^^^^^^^^^^^^
  | = help: rename the function or the variable
```

### A local function used before the `let` it reads (§5.4)

```ernest-rejected
fn f() : Int = {
    let y = g();
    let x = 1;
    fn g() : Int = x;
    y
}
```

```console
$ ern build example.ern
example.ern:2:13: local function g is used before `let x`, which it references
1 | fn f() : Int = {
2 |     let y = g();
  |             ^
3 |     let x = 1;
  |         - `let x` is evaluated here
  | = help: use g after `let x`
```

## Binding with `<-` (report §5.5)

### `<-` on a value whose sum type is not determined (§5.5)

```ernest-rejected
fn g(x) = {
    let a <- x;
    x
}
```

```console
$ ern build example.ern
example.ern:2:5: `<-` needs to know whether the value is an Either or an Optional; annotate it
1 | fn g(x) = {
2 |     let a <- x;
  |     ^^^^^^^^^^
```

### `<-` on a value that is no sum type (§5.5)

```ernest-rejected
fn f() : Optional(Int) = {
    let x <- 1;
    Some(x)
}
```

```console
$ ern build example.ern
example.ern:2:5: `<-` needs an Either or an Optional, not Int
1 | fn f() : Optional(Int) = {
2 |     let x <- 1;
  |     ^^^^^^^^^^
```

### A `<-` pattern that does not fit the value inside (§5.5)

```ernest-rejected
fn f(o : Optional(Int)) : Optional(Int) = {
    let #(a, b) <- o;
    Some(a)
}
```

```console
$ ern build example.ern
example.ern:2:9: the pattern does not fit the value inside the sum type: expected Int, found #(Int, a)
1 | fn f(o : Optional(Int)) : Optional(Int) = {
2 |     let #(a, b) <- o;
  |         ^^^^^^^
  |                    - the value inside has type Int
```

### A block after `<-` of another sum type (§5.5)

```ernest-rejected
fn f(o : Optional(Int)) : Either(String, Int) = {
    let x <- o;
    Right(x)
}
```

```console
$ ern build example.ern
example.ern:2:14: the value of `<-` must have the block's sum type: expected Either(String, Int), found Optional(Int)
1 | fn f(o : Optional(Int)) : Either(String, Int) = {
  |                           ------------------- result type Either(String, Int) declared here
2 |     let x <- o;
  |              ^
```

### `<-` on an Optional that would contain itself (§5.5)

```ernest-rejected
fn f(o) = {
    let y <- o;
    if true then Some(o) else Some(y)
}
```

```console
$ ern build example.ern
example.ern:2:14: `<-` on an Optional: a type that would contain itself (Optional(a) against a)
1 | fn f(o) = {
2 |     let y <- o;
  |              ^
3 |     if true then Some(o) else Some(y)
  |     --------------------------------- the block's value has type Optional(a)
```

### `<-` on an Either that would contain itself (§5.5)

```ernest-rejected
fn f(o) = {
    let y <- o;
    if true then Right(o) else Right(y)
}
```

```console
$ ern build example.ern
example.ern:2:14: `<-` on an Either: a type that would contain itself (Either(a, b) against a)
1 | fn f(o) = {
2 |     let y <- o;
  |              ^
3 |     if true then Right(o) else Right(y)
  |     ----------------------------------- the block's value has type Either(a, b)
```

### A refutable `let` pattern (§4.6)

```ernest-rejected
fn f(o : Optional(Int)) : Int = {
    let Some(x) = o;
    x
}
```

```console
$ ern build example.ern
example.ern:2:5: a `let` pattern must be irrefutable
1 | fn f(o : Optional(Int)) : Int = {
2 |     let Some(x) = o;
  |     ^^^^^^^^^^^^^^^
  | = help: use `match` for a pattern that can fail
```

### A `let` pattern that does not fit the value (§4.6)

```ernest-rejected
fn f() : Int = {
    let #(a, b) = 1;
    a
}
```

```console
$ ern build example.ern
example.ern:2:9: the pattern does not fit the value: expected Int, found #(a, b)
1 | fn f() : Int = {
2 |     let #(a, b) = 1;
  |         ^^^^^^^
  |                   - the value has type Int
```

## Clauses and patterns (report §5.9, §5.10)

### A pattern that does not fit the value matched (§5.9)

```ernest-rejected
fn f(n : Int) : Int =
    match n {
        "one" -> 1
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:9: the pattern does not fit the value: expected Int, found String
1 | fn f(n : Int) : Int =
2 |     match n {
  |           - the value matched has type Int
3 |         "one" -> 1
  |         ^^^^^
```

### Clauses of two types (§5.9)

```ernest-rejected
fn f(n : Int) =
    match n {
        1 -> "one"
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:4:14: the clauses must have one type: expected String, found Int
2 |     match n {
3 |         1 -> "one"
  |              ----- the first clause has type String
4 |       | _ -> 0
  |              ^
```

### A process's function called in a guard (§5.9)

```ernest-rejected
fn f(n : Int) : Int with m =
    match n {
        k when Io.println("k") == Unit -> k
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:16: Io.println needs a process, and a guard is pure
2 |     match n {
3 |         k when Io.println("k") == Unit -> k
  |                ^^^^^^^^^^^^^^^
  |                ----------------------- a guard is pure (report §5.9)
  | = help: compute the value before the match
```

### A guard that is no Bool (§5.9)

```ernest-rejected
fn f(n : Int) : Int =
    match n {
        x when x -> 1
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:16: a guard is a Bool: expected Bool, found Int
2 |     match n {
3 |         x when x -> 1
  |                ^
```

### Fields matched on a constructor that has none (§5.10)

```ernest-rejected
fn f(o : Optional(Int)) : Int =
    match o {
        None(x) -> x
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:9: None takes no fields
2 |     match o {
3 |         None(x) -> x
  |         ^^^^^^^
```

### A positional constructor matched without its field (§5.10)

```ernest-rejected
fn f(o : Optional(Int)) : Int =
    match o {
        Some -> 1
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:9: Some has one positional field; write Some(p)
2 |     match o {
3 |         Some -> 1
  |         ^^^^
```

### A field matched twice (§5.10)

```ernest-rejected
type Point = Point(x : Int)

fn f(p : Point) : Int =
    match p {
        Point(x = a, x = b) -> a
    }
```

```console
$ ern build example.ern
example.ern:5:22: field x is matched twice
4 |     match p {
5 |         Point(x = a, x = b) -> a
  |               ----- first matched here
  |                      ^^^^^
```

### A field the constructor lacks, matched (§5.10)

```ernest-rejected
type Point = Point(x : Int)

fn f(p : Point) : Int =
    match p {
        Point(z = a) -> a
    }
```

```console
$ ern build example.ern
example.ern:5:15: Point has no field z
4 |     match p {
5 |         Point(z = a) -> a
  |               ^^^^^
```

### A constructor of named fields matched by position (§5.10)

```ernest-rejected
type Point = Point(x : Int)

fn f(p : Point) : Int =
    match p {
        Point(a) -> a
    }
```

```console
$ ern build example.ern
example.ern:5:9: Point has named fields; write Point(x = p)
4 |     match p {
5 |         Point(a) -> a
  |         ^^^^^^^^
```

### A constructor of named fields matched bare (§5.10)

```ernest-rejected
type Shape = Circle(r : Int) | Dot

fn f(s : Shape) : Int =
    match s {
        Circle -> 1
      | Dot -> 0
    }
```

```console
$ ern build example.ern
example.ern:5:9: Circle has named fields; write Circle() to match any Circle
4 |     match s {
5 |         Circle -> 1
  |         ^^^^^^
```

### A variable twice in one pattern (§5.10)

```ernest-rejected
fn f(p : #(Int, Int)) : Int =
    match p {
        #(x, x) -> x
    }
```

```console
$ ern build example.ern
example.ern:3:14: variable x appears twice in the pattern
2 |     match p {
3 |         #(x, x) -> x
  |           - first bound here
  |              ^
```

### A list pattern of two types (§5.10)

```ernest-rejected
fn f(xs : List(Int)) : Int =
    match xs {
        [1, "two"] -> 1
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:13: list elements must have one type: expected Int, found String
2 |     match xs {
3 |         [1, "two"] -> 1
  |          - the first element has type Int
  |             ^^^^^
```

### A `::` pattern whose tail is no list of the head's type (§5.10)

```ernest-rejected
fn f(xs : List(Int)) : Int =
    match xs {
        x :: 1 -> x
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:14: the tail of `::` must be a list of the head's type: expected List(a), found Int
2 |     match xs {
3 |         x :: 1 -> x
  |         - the head has type a
  |              ^
```

### Alternatives of two types (§5.10)

```ernest-rejected
fn f(n : Int) : Int =
    match n {
        1 or "one" -> 1
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:14: the alternatives of a clause match one type: expected Int, found String
2 |     match n {
3 |         1 or "one" -> 1
  |         - the first alternative has type Int
  |              ^^^^^
```

### Alternatives that bind a variable at two types (§5.10)

```ernest-rejected
fn f(e : Either(Int, String)) : Int =
    match e {
        Left(x) or Right(x) -> 1
    }
```

```console
$ ern build example.ern
example.ern:3:26: the alternatives bind `x` at one type: expected Int, found String
2 |     match e {
3 |         Left(x) or Right(x) -> 1
  |              - x is bound here at Int
  |                          ^
```

### Alternatives that bind different variables (§5.10)

```ernest-rejected
fn f(e : Either(Int, Int)) : Int =
    match e {
        Left(x) or Right(y) -> 1
    }
```

```console
$ ern build example.ern
example.ern:3:20: the alternatives of a clause bind different variables: `x` is bound by the first alternative and not by this one
2 |     match e {
3 |         Left(x) or Right(y) -> 1
  |                    ^^^^^^^^
  | = help: bind each name in every alternative, as `Some(1) as x or Some(2) as x`
```

### A `match` that misses a constructor (§5.10)

```ernest-rejected
fn get(o : Optional(Int)) : Int =
    match o {
        Some(x) -> x
    }
```

```console
$ ern build example.ern
example.ern:2:5: match on Optional(Int) is not exhaustive; missing None
1 | fn get(o : Optional(Int)) : Int =
2 |     match o {
  |     ^^^^^^^^^
```

### A clause that can never match (§5.10)

```ernest-rejected
fn get(o : Optional(Int)) : Int =
    match o {
        _ -> 0
      | None -> 1
    }
```

```console
$ ern build example.ern
example.ern:4:9: this clause can never match
2 |     match o {
3 |         _ -> 0
  |         - this pattern matches every value it would
4 |       | None -> 1
  |         ^^^^
  | = help: remove it, or move it above the patterns that cover it
```

## Bitstrings (report §5.11)

### A sign on a segment that is no integer (§5.11)

```ernest-rejected
fn f(b : Bytes) : Bytes = <<b:bytes-signed>>
```

```console
$ ern build example.ern
example.ern:1:29: `signed` applies to an `int` segment only, not a `bytes` one
1 | fn f(b : Bytes) : Bytes = <<b:bytes-signed>>
  |                             ^^^^^^^^^^^^^^
```

### A byte order on a `bytes` segment (§5.11)

```ernest-rejected
fn f(b : Bytes) : Bytes = <<b:bytes-big>>
```

```console
$ ern build example.ern
example.ern:1:29: `big` applies to an `int`, `float`, `utf16` or `utf32` segment, not a `bytes` one
1 | fn f(b : Bytes) : Bytes = <<b:bytes-big>>
  |                             ^^^^^^^^^^^
```

### A size on a UTF segment (§5.11)

```ernest-rejected
fn f(c : Char) : Bytes = <<c:utf8-size(8)>>
```

```console
$ ern build example.ern
example.ern:1:28: a utf segment has no size
1 | fn f(c : Char) : Bytes = <<c:utf8-size(8)>>
  |                            ^^^^^^^^^^^^^^
```

### A float of a size the runtime lacks (§5.11)

```ernest-rejected
fn f(x : Float) : Bytes = <<x:float-size(8)>>
```

```console
$ ern build example.ern
example.ern:1:29: a float segment is 16, 32, or 64 bits
1 | fn f(x : Float) : Bytes = <<x:float-size(8)>>
  |                             ^^^^^^^^^^^^^^^
```

### Two byte orders on one segment (§5.11)

```ernest-rejected
fn f(n : Int) : Bytes = <<n:size(16)-big-little>>
```

```console
$ ern build example.ern
example.ern:1:27: conflicting bitstring specifiers `big` and `little`
1 | fn f(n : Int) : Bytes = <<n:size(16)-big-little>>
  |                           ^^^^^^^^^^^^^^^^^^^^^
```

### A bitstring that is no whole number of bytes (§5.11)

```ernest-rejected
fn f() : Bytes = <<1:size(3)>>
```

```console
$ ern build example.ern
example.ern:1:18: the bitstring is 3 bits, not a multiple of 8
1 | fn f() : Bytes = <<1:size(3)>>
  |                  ^^^^^^^^^^^^^
```

### A bitstring pattern that is no whole number of bytes (§5.11)

```ernest-rejected
fn f(b : Bytes) : Int =
    match b {
        <<x:size(3)>> -> x
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:9: the pattern is 3 bits, not a multiple of 8
2 |     match b {
3 |         <<x:size(3)>> -> x
  |         ^^^^^^^^^^^^^
```

### A segment pattern that is no variable or literal (§5.11)

```ernest-rejected
fn f(b : Bytes) : Int =
    match b {
        <<[x]:size(8)>> -> x
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:11: a segment pattern is a variable, `_`, or a literal
2 |     match b {
3 |         <<[x]:size(8)>> -> x
  |           ^^^
```

### A size that is no Int (§5.11)

```ernest-rejected
fn f(b : Bytes) : Int =
    match b {
        <<x:size("eight")>> -> x
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:18: the size of a segment: expected Int, found String
2 |     match b {
3 |         <<x:size("eight")>> -> x
  |                  ^^^^^^^
```

### A size in a pattern that the match cannot compute (§5.11)

```ernest-rejected
fn f(n : Int, b : Bytes) : Int =
    match b {
        <<x:size(n / 2), _:bytes>> -> x
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:18: a size in a pattern is a variable, a top-level `let`, an Int literal, or `+`, `-`, `*` of them
2 |     match b {
3 |         <<x:size(n / 2), _:bytes>> -> x
  |                  ^^^^^
```

### A size that names a variable bound elsewhere in the same pattern (§5.11)

```ernest-rejected
fn f(p : #(Int, Bytes)) : Int =
    match p {
        #(n, <<x:size(n), _:bytes>>) -> x
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:23: n is bound in the same pattern, and a size names a variable an earlier segment of its bitstring binds, or one bound before the pattern
2 |     match p {
3 |         #(n, <<x:size(n), _:bytes>>) -> x
  |           - n is bound here
  |                       ^
  | = help: match the bitstring in a `match` of its own, once n is bound
```

### A `bytes` segment without a size before another segment (§5.11)

```ernest-rejected
fn f(b : Bytes) : Int =
    match b {
        <<rest:bytes, x:size(8)>> -> x
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:3:11: a `bytes` segment without a size takes the rest, so it is the last segment
2 |     match b {
3 |         <<rest:bytes, x:size(8)>> -> x
  |           ^^^^^^^^^^
```

## Mailboxes (report §6)

### A call that needs another mailbox (§6.1)

```ernest-rejected
fn g() : Unit with String = Unit

fn f() : Unit with Int = g()
```

```console
$ ern build example.ern
example.ern:3:26: g needs mailbox String, and the mailbox here is Int
2 | 
3 | fn f() : Unit with Int = g()
  |                    --- f is declared `with Int` here
  |                          ^^^
```

### A call that needs a process, from a pure function (§6.1)

```ernest-rejected
fn g() : Unit with String = Unit

fn f() : Unit = g()
```

```console
$ ern build example.ern
example.ern:3:17: g needs a process, and f is pure
2 | 
3 | fn f() : Unit = g()
  |          ---- `: Unit` with no `with` declares f pure
  |                 ^^^
  | = help: give f a mailbox type with `with`
```

### `receive` in a pure function (§6.3)

```ernest-rejected
fn f() : Int =
    receive {
        after 1 -> 1
    }
```

```console
$ ern build example.ern
example.ern:2:5: `receive` needs a process, and f is pure
1 | fn f() : Int =
  |          --- `: Int` with no `with` declares f pure
2 |     receive {
  |     ^^^^^^^^^
  | = help: give f a mailbox type with `with`
```

### `receive` in a function of mailbox Never (§6.8)

```ernest-rejected
fn f() : Int with Never =
    receive {
        n -> n
    }
```

```console
$ ern build example.ern
example.ern:2:5: f is declared with mailbox Never and cannot receive
1 | fn f() : Int with Never =
  |                   ----- f is declared `with Never` here
2 |     receive {
  |     ^^^^^^^^^
  | = help: only an `after` clause is allowed; give f another mailbox type with `with`
```

### `receive` in a top-level initializer (§4.6, §6.8)

```ernest-rejected
let n : Int =
    receive {
        n -> n
    }
```

```console
$ ern build example.ern
example.ern:2:5: a top-level initializer runs with mailbox Never and cannot receive
1 | let n : Int =
  | ------------- the initializer of n runs as a body of mailbox type Never
2 |     receive {
  |     ^^^^^^^^^
  | = help: receive in a process the initializer spawns
```

### An `after` time that is no Int (§6.3)

```ernest-rejected
fn f() : Int with Int =
    receive {
        after "soon" -> 1
    }
```

```console
$ ern build example.ern
example.ern:3:15: the `after` time is in milliseconds: expected Int, found String
2 |     receive {
3 |         after "soon" -> 1
  |               ^^^^^^
```

### An `after` body of another type than the clauses' (§6.3)

```ernest-rejected
fn f() =
    receive {
        n -> 1
      | after 10 -> "none"
    }
```

```console
$ ern build example.ern
example.ern:4:21: the `after` body must have the clauses' type: expected Int, found String
2 |     receive {
3 |         n -> 1
  |              - the first clause has type Int
4 |       | after 10 -> "none"
  |                     ^^^^^^
```

### A `receive` guard that orders a type of its own (§6.3)

```ernest-rejected
type Money = Money(Int)

fn Money.compare(a : Money, b : Money) : Ordering = Equal

fn f(limit : Money) : Int with Money =
    receive {
        m when m < limit -> 1
    }
```

```console
$ ern build example.ern
example.ern:7:16: a `receive` guard orders only Int, Float, String, and Char, not Money
6 |     receive {
7 |         m when m < limit -> 1
  |                ^^^^^^^^^
```

### A `receive` guard that calls a function (§6.3)

```ernest-rejected
fn f() : Int with Bool =
    receive {
        b when Bool.not(b) -> 1
    }
```

```console
$ ern build example.ern
example.ern:3:16: a `receive` guard combines `true`, `false`, Bool variables, and comparisons with `!`, `&&`, and `||`, and calls nothing
2 |     receive {
3 |         b when Bool.not(b) -> 1
  |                ^^^^^^^^^^^
  | = help: receive the message and `match` it
```

### A `receive` guard that compares a sum (§6.3)

```ernest-rejected
fn f() : Int with Int =
    receive {
        n when n + 1 > 2 -> 1
    }
```

```console
$ ern build example.ern
example.ern:3:16: a comparison in a `receive` guard compares variables, literals, and nullary constructors
2 |     receive {
3 |         n when n + 1 > 2 -> 1
  |                ^^^^^
  | = help: receive the message and `match` it
```

### A reply discarded with `_` (§6.6)

```ernest-rejected
fn drop(r : Reply(Int)) : Unit with m = {
    let _ = r;
    Unit
}
```

```console
$ ern build example.ern
example.ern:2:9: `_` would discard a reply-carrying value
1 | fn drop(r : Reply(Int)) : Unit with m = {
2 |     let _ = r;
  |         ^
```

### A reply duplicated with `as` (§6.6)

```ernest-rejected
fn twice(r : Reply(Int)) : Unit with m =
    match r {
        x as y -> answer(x, 1)
    }
```

```console
$ ern build example.ern
example.ern:3:9: `as` on a reply-carrying value would duplicate it
2 |     match r {
3 |         x as y -> answer(x, 1)
  |         ^^^^^^
```

### A positional field that carries a reply matched with `_` (§6.6)

```ernest-rejected
type Req = Get(Reply(Int))

fn serve(q : Req) : Unit with m =
    match q {
        Get(_) -> Unit
    }
```

```console
$ ern build example.ern
example.ern:5:9: the field of Get carries a reply and cannot be `_`
4 |     match q {
5 |         Get(_) -> Unit
  |         ^^^^^^
```

### A named field that carries a reply left out of a pattern (§6.6)

```ernest-rejected
type Req = Get(reply : Reply(Int), n : Int)

fn serve(q : Req) : Unit with m =
    match q {
        Get(n = n) -> Unit
    }
```

```console
$ ern build example.ern
example.ern:5:9: field reply of Get carries a reply and must be bound
4 |     match q {
5 |         Get(n = n) -> Unit
  |         ^^^^^^^^^^
```

### A list of replies given to a function that drops its elements (§6.6, §3.9)

```ernest-rejected
fn count(r : Reply(Int), waiting : List(Reply(Int))) : Int = List.size(r :: waiting)
```

```console
$ ern build example.ern
example.ern:1:62: a reply-carrying value, Reply(Int), passed where List.size duplicates or discards its argument: List.size : (List(a!)) -> Int
1 | fn count(r : Reply(Int), waiting : List(Reply(Int))) : Int = List.size(r :: waiting)
  |                                                              ^^^^^^^^^
  | = help: a reply is discharged by answering it, passing it on once, or matching it (§6.6)
```

### A lambda that captures a reply, bound and passed on (§6.6)

```ernest-rejected
fn later(r : Reply(Int)) : Unit with m = {
    let f = fn() = answer(r, 1);
    let g = f;
    g()
}
```

```console
$ ern build example.ern
example.ern:3:13: the lambda f captures a reply-carrying value and may only be called or passed directly to spawn or spawnMonitored
2 |     let f = fn() = answer(r, 1);
3 |     let g = f;
  |             ^
```

### A reply captured by a lambda that is passed to a function (§6.6)

```ernest-rejected
fn each(r : Reply(Int)) : Unit with m =
    List.foreach([1], fn(x) = answer(r, x))
```

```console
$ ern build example.ern
example.ern:2:23: the reply-carrying value r is captured by a lambda that is not called, bound by `let`, or passed directly to spawn or spawnMonitored
1 | fn each(r : Reply(Int)) : Unit with m =
2 |     List.foreach([1], fn(x) = answer(r, x))
  |                       ^^^^^^^^^^^^^^^^^^^^
```

### A reply captured by a local function (§6.6)

```ernest-rejected
fn later(r : Reply(Int)) : Unit with m = {
    fn g() : Unit with m = answer(r, 1);
    g()
}
```

```console
$ ern build example.ern
example.ern:2:5: the reply-carrying value r is captured by a local function
1 | fn later(r : Reply(Int)) : Unit with m = {
2 |     fn g() : Unit with m = answer(r, 1);
  |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: a local fn may be called many times; pass r to it as a parameter
```

### A reply answered twice (§6.6)

```ernest-rejected
fn twice(r : Reply(Int)) : Unit with m = {
    answer(r, 1);
    answer(r, 2)
}
```

```console
$ ern build example.ern
example.ern:3:12: the reply-carrying value r is consumed twice
1 | fn twice(r : Reply(Int)) : Unit with m = {
2 |     answer(r, 1);
  |            - first consumed here
3 |     answer(r, 2)
  |            ^
```

### A reply answered on one path only (§6.6)

```ernest-rejected
fn maybe(r : Reply(Int), b : Bool) : Unit with m = if b then answer(r, 1) else Unit
```

```console
$ ern build example.ern
example.ern:1:80: the reply-carrying value r is not consumed on this path
1 | fn maybe(r : Reply(Int), b : Bool) : Unit with m = if b then answer(r, 1) else Unit
  |                                                                     - consumed here, on another path
  |                                                                                ^^^^
```

### A reply never answered (§6.6)

```ernest-rejected
fn never(r : Reply(Int)) : Unit with m = Unit
```

```console
$ ern build example.ern
example.ern:1:42: the reply-carrying value r is never consumed
1 | fn never(r : Reply(Int)) : Unit with m = Unit
  |                                          ^^^^
```
