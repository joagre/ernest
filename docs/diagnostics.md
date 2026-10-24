# The diagnostics

Errors the lexer, the parser, the checker and the build give, each with one small program that gives it, or two files where the error needs a second, and what `ern build` prints for it, laid out as report §11.5 says; an error only the shell gives is shown in a session. `test/ern_guide_tests.erl` holds each output to the compiler's, and `make diagnostics` writes the outputs anew from the compiler, after a change to a message that is meant.

## The lexer (report §2)

### A character outside the language (§2.1)

```ernest-rejected
export fn main() : Unit = Io.println(§)
```

```console
$ ern build example.ern
example.ern:1:38: illegal character `§`
1 | export fn main() : Unit = Io.println(§)
  |                                      ^
```

### A name longer than 255 characters (§2.3)

```ernest-rejected
export fn main() : Unit = { let aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 1; Unit }
```

```console
$ ern build example.ern
example.ern:1:33: a name is at most 255 characters long
1 | export fn main() : Unit = { let aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = 1; Unit }
  |                                 ^
```

### An underscore that does not stand between two digits (§2.5)

```ernest-rejected
export fn size() : Int = 1_
```

```console
$ ern build example.ern
example.ern:1:27: `_` must stand between two digits
1 | export fn size() : Int = 1_
  |                           ^
```

### An underscore after a base prefix (§2.5)

```ernest-rejected
export fn mask() : Int = 0x_FF
```

```console
$ ern build example.ern
example.ern:1:28: `_` must stand between two digits
1 | export fn mask() : Int = 0x_FF
  |                            ^
```

### A letter directly after a number (§2.5)

```ernest-rejected
export fn width() : Int = 12px
```

```console
$ ern build example.ern
example.ern:1:29: `p` cannot follow a number directly
1 | export fn width() : Int = 12px
  |                             ^
```

### A base prefix with no digit (§2.5)

```ernest-rejected
export fn mask() : Int = 0x
```

```console
$ ern build example.ern
example.ern:1:26: `0x` needs a hexadecimal digit
1 | export fn mask() : Int = 0x
  |                          ^
```

### A digit outside the base (§2.5)

```ernest-rejected
export fn flags() : Int = 0b102
```

```console
$ ern build example.ern
example.ern:1:31: `2` is not a binary digit
1 | export fn flags() : Int = 0b102
  |                               ^
```

### An uppercase base prefix (§2.5)

```ernest-rejected
export fn mask() : Int = 0XFF
```

```console
$ ern build example.ern
example.ern:1:26: a base prefix is lowercase: `0x`
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
example.ern:1:32: the raw string never closes
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
example.ern:1:39: a line break in a string literal; use `\n`
1 | export fn greeting() : String = "hello
  |                                       ^
```

### An empty character literal (§2.5)

```ernest-rejected
export fn blank() : Char = ''
```

```console
$ ern build example.ern
example.ern:1:28: empty character literal
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
example.ern:1:30: a line break in a character literal; use `'\n'`
1 | export fn newline() : Char = '
  |                              ^
```

### A character literal of two characters (§2.5)

```ernest-rejected
export fn letter() : Char = 'ab'
```

```console
$ ern build example.ern
example.ern:1:29: a character literal holds one code point; a string is written between double quotes
1 | export fn letter() : Char = 'ab'
  |                             ^
```

### A Unicode escape with no digit (§2.5)

```ernest-rejected
export fn nothing() : String = "\u{}"
```

```console
$ ern build example.ern
example.ern:1:33: `\u{` needs one to six hexadecimal digits
1 | export fn nothing() : String = "\u{}"
  |                                 ^
```

### A Unicode escape of a surrogate (§2.5)

```ernest-rejected
export fn half() : String = "\u{D800}"
```

```console
$ ern build example.ern
example.ern:1:30: `\u{D800}` is not a Unicode scalar value
1 | export fn half() : String = "\u{D800}"
  |                              ^
```

### A Unicode escape that does not close (§2.5)

```ernest-rejected
export fn open() : String = "\u{41"
```

```console
$ ern build example.ern
example.ern:1:30: `\u{` needs one to six hexadecimal digits followed by `}`
1 | export fn open() : String = "\u{41"
  |                              ^
```

### An escape the language does not have (§2.5)

```ernest-rejected
export fn bell() : String = "\a"
```

```console
$ ern build example.ern
example.ern:1:30: unknown escape `\a`
1 | export fn bell() : String = "\a"
  |                              ^
  | = help: the escapes are `\'`, `\"`, `\\`, `\n`, `\r`, `\t` and `\u{...}`, which writes any code point, a bell as `\u{7}`
```

### A line break after a backslash (§2.5)

```ernest-rejected
export fn cut() : String = "\
```

```console
$ ern build example.ern
example.ern:1:29: a line break cannot follow `\`; use `\n`
1 | export fn cut() : String = "\
  |                             ^
```

### A block comment that never closes (§2.2)

```ernest-rejected
export fn one() : Int = 1 /* the rest is a comment
```

```console
$ ern build example.ern
example.ern:1:27: the block comment never closes
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
Ernest 0.4.0. :help for the commands, :quit to leave.
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
example.ern:3:1: expected a declaration (export, type, abstract, fn, let, foreign) instead of integer 1
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

### `abstract` before something other than a type (§3.6, §4.4)

```ernest-rejected
abstract fn hidden() : Int = 1
```

```console
$ ern build example.ern
example.ern:1:10: expected `type` after `abstract`
1 | abstract fn hidden() : Int = 1
  |          ^^
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

### An operator's member named in an expression (§4.5)

```ernest-rejected
fn total(list : List(Int)) : Int =
    List.foldLeft(list, 0, Int.+)
```

```console
$ ern build example.ern
example.ern:2:28: `Int.+` names a member, which an expression reaches through `+`
1 | fn total(list : List(Int)) : Int =
2 |     List.foldLeft(list, 0, Int.+)
  |                            ^^^^^
  | = help: write `x + y`, or where a function is wanted a lambda, `fn(x, y) = x + y`
```

### A declaration with no name (§4.5)

```ernest-rejected
fn 1() -> Int = 1
```

```console
$ ern build example.ern
example.ern:1:4: expected a name instead of integer 1
1 | fn 1() -> Int = 1
  |    ^
```

### A reserved word where a name stands (§2.4)

```ernest-rejected
let after = 1
```

```console
$ ern build example.ern
example.ern:1:5: `after` is a reserved word, and names nothing
1 | let after = 1
  |     ^^^^^
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
example.ern:1:9: expected `type` or `fn` after `foreign` instead of the reserved word `let`
1 | foreign let now = 1
  |         ^^^
```

### Empty parentheses where a type stands (§3)

```ernest-rejected
fn f() : () = 1
```

```console
$ ern build example.ern
example.ern:1:10: expected a type inside the parentheses, or `->` after them
1 | fn f() : () = 1
  |          ^
  | = help: the type with one value is Unit, and its value is written Unit
```

### Parenthesized types that are no function type (§3, §3.2)

```ernest-rejected
fn f(pair : (Int, Int)) : Int = 1
```

```console
$ ern build example.ern
example.ern:1:23: expected `->` after a parameter list instead of `)`
1 | fn f(pair : (Int, Int)) : Int = 1
  |                       ^
  | = help: a tuple type is written with `#(`, as `#(Int, Int)`
```

### An equality mark in parentheses (§3, §4.7)

```ernest-rejected
fn f(x : (a=)) : Int = 1
```

```console
$ ern build example.ern
example.ern:1:11: a type in parentheses takes no equality mark
1 | fn f(x : (a=)) : Int = 1
  |           ^^
  | = help: write a; the mark is written in a foreign function's parameters alone
```

### A qualified type that ends in a lowercase name (§3)

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

### Something that is no type where a type stands (§3)

```ernest-rejected
fn f(x : 1) : Int = 1
```

```console
$ ern build example.ern
example.ern:1:10: expected a type instead of integer 1
1 | fn f(x : 1) : Int = 1
  |          ^
```

### A function type written with `fn` (§3.4)

```ernest-rejected
fn apply(g : fn(Int) -> Int) : Int = g(1)
```

```console
$ ern build example.ern
example.ern:1:14: expected a type instead of the reserved word `fn`
1 | fn apply(g : fn(Int) -> Int) : Int = g(1)
  |              ^^
  | = help: a function type is written without `fn`, as `(Int) -> Int`
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

### An `if` without its `else` (§5.8)

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

### Empty parentheses where an expression stands (§3.1)

```ernest-rejected
export fn main() : Unit = ()
```

```console
$ ern build example.ern
example.ern:1:28: expected an expression instead of `)`
1 | export fn main() : Unit = ()
  |                            ^
  | = help: Unit's one value is written Unit
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
fn f() : Unit = {
    Io.println(1);
    Io.println(2);
    Unit
}
```

```console
$ ern build example.ern
example.ern:2:16: the argument does not fit Io.println: expected String, found Int
1 | fn f() : Unit = {
2 |     Io.println(1);
  |     ---------- Io.println : (String) -> Unit
  |                ^

example.ern:3:16: the argument does not fit Io.println: expected String, found Int
2 |     Io.println(1);
3 |     Io.println(2);
  |     ---------- Io.println : (String) -> Unit
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
  | = help: a size counts bits, and octets for `bytes`: write `size(2 * 8)`
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
  | = help: a specifier is `size(N)`, `bytes`, `int`, `float`, `utf8`, `utf16`, `utf32`, `big`, `little`, `signed` or `unsigned`
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
  | = help: a size is written `size(1)`
```

### A missing parenthesis (§4.5)

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

### A lowercase name where a type's name stands (§2.3, §4.3)

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
fn f(x : Color) : Int = 0
```

```console
$ ern build example.ern
example.ern:1:10: unknown type Color
1 | fn f(x : Color) : Int = 0
  |          ^^^^^
```

### A qualified type nothing declares (§4.2)

```ernest-rejected
fn f(x : Shapes.Color) : Int = 0
```

```console
$ ern build example.ern
example.ern:1:10: unknown type Shapes.Color
1 | fn f(x : Shapes.Color) : Int = 0
  |          ^^^^^^^^^^^^
```

### A type another module keeps private (§4.2, §11.5)

```ernest-rejected
fn f(x : Supervisor.WatcherMsg) : Int = 0
```

```console
$ ern build example.ern
example.ern:1:10: Supervisor.WatcherMsg is a type Supervisor keeps private
1 | fn f(x : Supervisor.WatcherMsg) : Int = 0
  |          ^^^^^^^^^^^^^^^^^^^^^
```

### `Prelude.` before a type the prelude lacks (§4.2)

```ernest-rejected
fn f(x : Prelude.Color) : Int = 0
```

```console
$ ern build example.ern
example.ern:1:10: the prelude declares no type Color
1 | fn f(x : Prelude.Color) : Int = 0
  |          ^^^^^^^^^^^^^
```

### A type named `Prelude` (§4.2)

```ernest-rejected
type Prelude = Prelude
```

```console
$ ern build example.ern
example.ern:1:6: Prelude names the prelude, and a type may not take it
1 | type Prelude = Prelude
  |      ^^^^^^^
```

### A type declared twice (§4.3)

```ernest-rejected
type Color = Red
type Color = Blue
```

```console
$ ern build example.ern
example.ern:2:1: type Color is declared twice
1 | type Color = Red
  | ---------------- first declared here
2 | type Color = Blue
  | ^^^^^^^^^^^^^^^^^
```

### A constructor declared twice (§3.5)

```ernest-rejected
type Color = Red | Red
```

```console
$ ern build example.ern
example.ern:1:20: constructor Red is declared twice
1 | type Color = Red | Red
  |              --- first declared here
  |                    ^^^
```

### A constructor named as a type (§3.1)

```ernest-rejected
type Word = String
```

```console
$ ern build example.ern
example.ern:1:13: constructor String is named as the type String
1 | type Word = String
  |             ^^^^^^
  | = help: there are no type aliases; a type that holds a String is written type Word = Word(String)
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

### A constructor with two positional fields (§3.5)

```ernest-rejected
type Vec = Vec(Float, Float)
```

```console
$ ern build example.ern
example.ern:1:21: a constructor has exactly one positional field
1 | type Vec = Vec(Float, Float)
  |                     ^
  | = help: name the fields, `Vec(x : ..., y : ...)`, or hold a tuple, `Vec(#(..., ...))`
```

### A constructor pattern with two positional fields (§3.5, §5.10)

```ernest-rejected
type Point = Point(x : Int, y : Int)

fn first(p : Point) : Int =
    match p {
        Point(a, b) -> a
    }
```

```console
$ ern build example.ern
example.ern:5:16: a constructor has exactly one positional field
4 |     match p {
5 |         Point(a, b) -> a
  |                ^
  | = help: name the fields, `Point(x = ..., y = ...)`, or match a tuple, `Point(#(..., ...))`
```

### A type parameter written twice (§4.3)

```ernest-rejected
type Pair(a, a) = Pair(a)
```

```console
$ ern build example.ern
example.ern:1:14: type variable a appears twice among the parameters of Pair
1 | type Pair(a, a) = Pair(a)
  |           - first written here
  |              ^
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

### A recursive type named at other than its parameters (§3.9)

```ernest-rejected
type Nest(a) = Flat(a) | Deeper(Nest(List(a)))
```

```console
$ ern build example.ern
example.ern:1:33: Nest is named at List(a) in its own fields, and a type of a recursive group is named in its fields at the declaring type's parameters alone
1 | type Nest(a) = Flat(a) | Deeper(Nest(List(a)))
  |                                 ^^^^^^^^^^^^^
  | = help: write `Nest(a)`, or `List(Nest(a))` to hold it in a List
```

### A recursive type named at its parameters in another order (§3.9)

```ernest-rejected
type Flip(a, b) = End(a) | Turn(Flip(b, a))
```

```console
$ ern build example.ern
example.ern:1:33: Flip is named at (b, a) in its own fields, and a type of a recursive group is named in its fields at the declaring type's parameters, each in its place, (a, b)
1 | type Flip(a, b) = End(a) | Turn(Flip(b, a))
  |                                 ^^^^^^^^^^
  | = help: write `Flip(a, b)`
```

## Declarations (report §4)

### An equality mark outside a foreign function (§4.7)

```ernest-rejected
fn f(xs : List(a=)) : Int = 1
```

```console
$ ern build example.ern
example.ern:1:16: the equality mark is written in a foreign function's parameters alone
1 | fn f(xs : List(a=)) : Int = 1
  |                ^^
  | = help: write a; a has equality where a body compares its values with ==
```

### A foreign function's equality mark written twice (§4.7)

```ernest-rejected
foreign fn member(list : List(a=), element : a=) : Bool =
    "lists:member/2"
```

```console
$ ern build example.ern
example.ern:1:46: a is marked twice
1 | foreign fn member(list : List(a=), element : a=) : Bool =
  |                               -- first here
  |                                              ^^
  | = help: write a= once; it marks every occurrence of a
```

### An equality mark in a foreign function's result type (§4.7)

```ernest-rejected
foreign fn first(list : List(a)) : List(a=) =
    "erlang:hd/1"
```

```console
$ ern build example.ern
example.ern:1:41: a foreign function's result type takes no equality mark
1 | foreign fn first(list : List(a)) : List(a=) =
  |                                         ^^
  | = help: mark a in the parameters, a=
```

### A value declared twice (§4.6)

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

### A function written in two clauses (§4.5)

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

### A member of a type the module does not declare (§4.2)

```ernest-rejected
fn Color.negate(n : Int) : Int = n
```

```console
$ ern build example.ern
example.ern:1:4: Color is not a type declared in this module
1 | fn Color.negate(n : Int) : Int = n
  |    ^^^^^^^^^^^^
```

### A member whose Erlang name the host cannot hold (§11.1)

```ernest-rejected
type Vxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx = Point(x : Int, y : Int) derives compare
```

```console
$ ern build example.ern
example.ern:1:281: the Erlang name of the derived member compare, its type's name and its own joined by `.`, is 256 characters long, and the host's names are at most 255
1 | type Vxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx = Point(x : Int, y : Int) derives compare
  |                                                                                                                                                                                                                                                                                         ^^^^^^^^^^^^^^^
  | = help: shorten the type's name to at most 247 characters
```

### An operator member of the wrong shape (§4.8)

```ernest-rejected
type Money = Money(Int)

fn Money.+(a : Money, b : Int) : Money = a
```

```console
$ ern build example.ern
example.ern:3:23: Money.+ must have the type (Money, Money) -> Money, not (Money, Int) -> Money
2 | 
3 | fn Money.+(a : Money, b : Int) : Money = a
  |                       ^^^^^^^
  | = help: a member named by an operator takes two values of its type and receives nothing
```

### A top-level `let` whose initializer is no value and whose type is not determined (§4.6)

```ernest-rejected
fn hold(value : a) : Unit receiving a =
    receive {
        next -> hold(next)
    }

let inbox = spawn(fn() = hold(None))
```

```console
$ ern build example.ern
example.ern:6:1: the type of inbox, Address(Optional(a)), is not determined, and a top-level `let` whose initializer is no value is not generalized where its type holds an address
5 | 
6 | let inbox = spawn(fn() = hold(None))
  | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: annotate it, `let inbox : Address(Optional(...)) = ...`
```

### A foreign implementation of the wrong arity (§8.4)

```ernest-rejected
foreign fn size(t : Foreign.Term) : Int =
    "erlang:tuple_size/2"
```

```console
$ ern build example.ern
example.ern:2:5: the implementation names arity 2, and size has 1 parameter
1 | foreign fn size(t : Foreign.Term) : Int =
2 |     "erlang:tuple_size/2"
  |     ^^^^^^^^^^^^^^^^^^^^^
```

### A foreign implementation that is no `module:function/arity` (§8.4)

```ernest-rejected
foreign fn size(t : Foreign.Term) : Int =
    "tuple_size"
```

```console
$ ern build example.ern
example.ern:2:5: the implementation of size is not written `module:function/arity`
1 | foreign fn size(t : Foreign.Term) : Int =
2 |     "tuple_size"
  |     ^^^^^^^^^^^^
  | = help: write the host's module and function and the arity 1, as `module:function/1`
```

### A foreign implementation that names a unit (§11.1)

```ernest-rejected
foreign fn twice(n : Int) : Int =
    "ern@util:twice/1"
```

```console
$ ern build example.ern
example.ern:2:5: the implementation names ern@util, a unit of Ernest's, whose functions are named by their position
1 | foreign fn twice(n : Int) : Int =
2 |     "ern@util:twice/1"
  |     ^^^^^^^^^^^^^^^^^^
  | = help: call an Ernest function by its name, and name the host's own module here
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
example.ern:1:6: the parameter pattern does not fit its annotation: expected Int, found #(c, d)
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

### A member's name called (§4.5)

```ernest-rejected
fn later(a : Int, b : Int) : Bool =
    Int.compare(a, b) == Greater
```

```console
$ ern build example.ern
example.ern:2:5: `Int.compare` names a member, which an expression reaches through `compare`
1 | fn later(a : Int, b : Int) : Bool =
2 |     Int.compare(a, b) == Greater
  |     ^^^^^^^^^^^
  | = help: write `compare(a, b)`
```

### A member's name as a value (§4.5)

```ernest-rejected
fn opposites(list : List(Int)) : List(Int) =
    List.map(list, Int.negate)
```

```console
$ ern build example.ern
example.ern:2:20: `Int.negate` names a member, which an expression reaches through prefix `-`
1 | fn opposites(list : List(Int)) : List(Int) =
2 |     List.map(list, Int.negate)
  |                    ^^^^^^^^^^
  | = help: where a function is wanted, write a lambda, `fn(x) = -x`
```

### `Prelude.` before a name deeper than a prelude namespace's (§4.2)

```ernest-rejected
fn f() : Unit = Prelude.Io.println("x")
```

```console
$ ern build example.ern
example.ern:1:17: Prelude.Io.println is written only where the module hides Io
1 | fn f() : Unit = Prelude.Io.println("x")
  |                 ^^^^^^^^^^^^^^^^^^
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
type Outcome = Unknown(Int) | Known

fn reason() : Reason =
    Unknown
```

```console
$ ern build example.ern
example.ern:4:5: the body does not have the declared result type: expected Reason, found (Int) -> Outcome
2 | 
3 | fn reason() : Reason =
  |               ------ result type Reason declared here
4 |     Unknown
  |     ------- `Unknown` here is this module's constructor, and the prelude's is `Prelude.Unknown`
  |     ^^^^^^^
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
    let c = Colors.Red;
    1
}
```

```console
$ ern build example.ern
example.ern:2:13: unknown constructor Colors.Red
1 | fn f() : Int = {
2 |     let c = Colors.Red;
  |             ^^^^^^^^^^
```

### A constructor of a type another module keeps private (§4.2, §11.5)

```ernest-rejected
fn f() : Int = {
    let c = Supervisor.Release;
    1
}
```

```console
$ ern build example.ern
example.ern:2:13: Supervisor.Release is a constructor of Supervisor.WatcherMsg, a type Supervisor keeps private
1 | fn f() : Int = {
2 |     let c = Supervisor.Release;
  |             ^^^^^^^^^^^^^^^^^^
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
Ernest 0.4.0. :help for the commands, :quit to leave.
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
  | = help: export Box, or export it as `export abstract type Box` so that its constructors stay private
```

### A value of a type's namespace that is a member's name (§4.2, §11.5)

```ernest
// main.ern
export type Stack = Stack(items : List(Int))

export fn Stack.compare(left : Stack, right : Stack) : Ordering =
    compare(List.size(left.items), List.size(right.items))
```

```ernest-rejected
// main/stack.ern
export fn compare(left : Int, right : Int) : Ordering = Equal
```

```console
$ ern build main/stack.ern
main/stack.ern:2:8: Main.Stack.compare is a member of the type Stack in the module Main
1 | // main/stack.ern
2 | export fn compare(left : Int, right : Int) : Ordering = Equal
  |        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: this module's compare is Main.Stack.compare too; rename it
```

## Fields and construction (report §3.5, §5.6)

### Empty parentheses after a nullary constructor (§5.6)

```ernest-rejected
fn f() : Optional(Int) = None()
```

```console
$ ern build example.ern
example.ern:1:26: empty parentheses after None
1 | fn f() : Optional(Int) = None()
  |                          ^^^^^^
  | = help: a constructor without fields is written without parentheses, None
```

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
example.ern:1:13: the type whose field x is read is not determined; annotate p
1 | fn f(p) = p.x
  |             ^
```

### A field of a value of a type variable of the signature (§4.9, §11.5)

```ernest-rejected
fn smaller(x : a, y : a) : a needs a.compare =
    if x.compare(y) == Less then x else y
```

```console
$ ern build example.ern
example.ern:2:10: a value of a, a type variable of smaller's signature, has no field compare
1 | fn smaller(x : a, y : a) : a needs a.compare =
2 |     if x.compare(y) == Less then x else y
  |          ^^^^^^^
  | = help: under `needs a.compare`, write `compare(..., ...)`
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
5 |     let q : Point = p;
  |                     - this fixes the value whose x is read as Point
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
example.ern:3:31: Point has no field y
2 | 
3 | fn f() : Point = Point(x = 1, y = 2)
  |                               ^^^^^
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

### `receiving m` on a body that receives nothing (§4.5)

```ernest-rejected
fn k() : Int receiving m = 5
```

```console
$ ern build example.ern
example.ern:1:24: k receives nothing, and `receiving m` names no parameter's mailbox type
1 | fn k() : Int receiving m = 5
  |                        ^
  | = help: write k's type without `receiving`
```

### A module's own name written qualified where nothing hides it (§4.2)

```ernest-rejected
fn helper() : Int = 1

export fn main() : Unit = Io.println(Int.toString(Example.helper()))
```

```console
$ ern build example.ern
example.ern:3:51: Example.helper is written only where a binding hides helper
2 | 
3 | export fn main() : Unit = Io.println(Int.toString(Example.helper()))
  |                                                   ^^^^^^^^^^^^^^
  | = help: nothing here hides it; write helper
```

### A module's own constructor written qualified (§4.2)

```ernest-rejected
type Box = Box(Int)

fn f() : Box = Example.Box(1)
```

```console
$ ern build example.ern
example.ern:3:16: Example.Box is the module's own Box, which no binding hides
2 | 
3 | fn f() : Box = Example.Box(1)
  |                ^^^^^^^^^^^
  | = help: write Box
```

### A fill that lacks a field (§5.6)

```ernest-rejected
type Ops(s, a) = Ops(fromList : (List(a)) -> s, min : (s) -> Optional(a))

let hashed : Ops(Set(Int), Int) = Ops(..Set)
```

```console
$ ern build example.ern
example.ern:3:41: Ops(..Set) lacks min: Set has no min
2 | 
3 | let hashed : Ops(Set(Int), Int) = Ops(..Set)
  |                                         ^^^
```

### A fill from `Prelude.` (§5.6, §4.2)

```ernest-rejected
type Ops(s, a) = Ops(fromList : (List(a)) -> s, toList : (s) -> List(a))

let hashed : Ops(Set(Int), Int) = Ops(..Prelude.Set)
```

```console
$ ern build example.ern
example.ern:3:41: `Prelude.Set` names no namespace: `Prelude.` reaches one of the prelude's names
2 | 
3 | let hashed : Ops(Set(Int), Int) = Ops(..Prelude.Set)
  |                                         ^^^^^^^^^^^
  | = help: write the namespace after `..` as it is, `..Set`
```

### A filled field of another type (§5.6)

```ernest-rejected
type Ops(s) = Ops(size : (s) -> Bool)

let hashed : Ops(Set(Int)) = Ops(..Set)
```

```console
$ ern build example.ern
example.ern:3:36: Ops(..Set) fills size with Set.size: expected (Set(Int)) -> Bool, found (Set(a=)) -> Int
2 | 
3 | let hashed : Ops(Set(Int)) = Ops(..Set)
  |                              --- Ops declares size : (s) -> Bool
  |                                    ^^^
  | = help: the types differ at Bool and Int
```

### A fill whose record type leaves a requirement's variable undetermined (§5.6, §4.9)

```ernest-rejected
type Ops(s, a) = Ops(fromList : (List(a)) -> s)

fn f() : Int = {
    let ops = Ops(..OrderedSet);
    1
}
```

```console
$ ern build example.ern
example.ern:4:21: fromList needs a.compare, and the record's type leaves the variable a undetermined; annotate ops
3 | fn f() : Int = {
4 |     let ops = Ops(..OrderedSet);
  |                     ^^^^^^^^^^
```

### A path where a construction gives a field (§5.6)

```ernest-rejected
type Stats = Stats(indexed : Int, hits : Int)

type Pool = Pool(name : String, stats : Stats)

fn fresh() : Pool =
    Pool(name = "p", stats.indexed = 1)
```

```console
$ ern build example.ern
example.ern:6:27: a path stands in a record update only
5 | fn fresh() : Pool =
6 |     Pool(name = "p", stats.indexed = 1)
  |                           ^
  | = help: write the field's value as a construction, or update a value with `..`
```

### A path in a pattern (§5.6)

```ernest-rejected
type Stats = Stats(indexed : Int, hits : Int)

type Pool = Pool(name : String, stats : Stats)

fn indexed(p : Pool) : Int =
    match p {
        Pool(stats.indexed = n) -> n
    }
```

```console
$ ern build example.ern
example.ern:7:19: a path stands in a record update only, not in a pattern
6 |     match p {
7 |         Pool(stats.indexed = n) -> n
  |                   ^
  | = help: match the field with a constructor pattern of its own
```

### A path in a fill (§5.6)

```ernest-rejected
type Ops(s) = Ops(size : (s) -> Int)

let hashed : Ops(Set(Int)) = Ops(..Set, size.x = 1)
```

```console
$ ern build example.ern
example.ern:3:41: `size.x` is a path, which updates a value, and `..Set` names a namespace
2 | 
3 | let hashed : Ops(Set(Int)) = Ops(..Set, size.x = 1)
  |                                         ^^^^^^^^^^
```

### A path through a type with several constructors (§5.6)

```ernest-rejected
type Shape = Dot | Circle(at : Int)

type Holder = Holder(shape : Shape, size : Int)

fn moved(h : Holder) : Holder =
    Holder(..h, shape.at = 1)
```

```console
$ ern build example.ern
example.ern:6:17: `shape.at` reaches Shape, which has 2 constructors, and a path goes through a type with one
5 | fn moved(h : Holder) : Holder =
6 |     Holder(..h, shape.at = 1)
  |                 ^^^^^^^^^^^^
```

### A path through a type without fields (§5.6)

```ernest-rejected
type Holder = Holder(size : Int)

fn grown(h : Holder) : Holder =
    Holder(..h, size.x = 1)
```

```console
$ ern build example.ern
example.ern:4:17: `size.x` reaches Int, which has no fields
3 | fn grown(h : Holder) : Holder =
4 |     Holder(..h, size.x = 1)
  |                 ^^^^^^^^^^
```

### A path that updates what a field updates (§5.6)

```ernest-rejected
type Stats = Stats(indexed : Int, hits : Int)

type Pool = Pool(name : String, stats : Stats)

fn reset(p : Pool) : Pool =
    Pool(..p, stats = Stats(indexed = 0, hits = 0), stats.hits = 2)
```

```console
$ ern build example.ern
example.ern:6:53: `stats.hits` and `stats` update one field
5 | fn reset(p : Pool) : Pool =
6 |     Pool(..p, stats = Stats(indexed = 0, hits = 0), stats.hits = 2)
  |               ------------------------------------ given here
  |                                                     ^^^^^^^^^^^^^^
  | = help: give the field once, or paths into it that do not overlap
```

### A path given twice (§5.6)

```ernest-rejected
type Stats = Stats(indexed : Int, hits : Int)

type Pool = Pool(name : String, stats : Stats)

fn hit(p : Pool) : Pool =
    Pool(..p, stats.hits = 2, stats.hits = 3)
```

```console
$ ern build example.ern
example.ern:6:31: field stats.hits is given twice
5 | fn hit(p : Pool) : Pool =
6 |     Pool(..p, stats.hits = 2, stats.hits = 3)
  |               -------------- first given here
  |                               ^^^^^^^^^^^^^^
```

### A path through a field whose type is not determined (§5.6)

```ernest-rejected
type Box(a) = Box(inner : a)

fn f(b) =
    Box(..b, inner.x = 1)
```

```console
$ ern build example.ern
example.ern:4:14: the type of inner under `inner.x` is not determined; annotate it
3 | fn f(b) =
4 |     Box(..b, inner.x = 1)
  |              ^^^^^^^^^^^
```

### A record update that gives no field (§5.6)

```ernest-rejected
type Point = Point(x : Int, y : Int)

fn same(p : Point) : Point =
    Point(..p)
```

```console
$ ern build example.ern
example.ern:4:5: a record update gives at least one field after its `..`
3 | fn same(p : Point) : Point =
4 |     Point(..p)
  |     ^^^^^^^^^^
  | = help: give the fields that change; with none, the value after `..` is the record
```

## Operators (report §4.8)

### An operator on operands whose type is not determined (§4.8)

```ernest-rejected
fn f(a, b) = a + b
```

```console
$ ern build example.ern
example.ern:1:14: the operand type of `+` is not determined; annotate a
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
3 |     let n : Int = a;
  |                   - this fixes `+`'s operands as Int
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
  | = help: compare takes two values of its type, returns an Ordering, and receives nothing
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
example.ern:1:18: the operand of `!`: expected Bool, found Int
1 | fn f() : Bool = !1
  |                  ^
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
example.ern:1:30: `==` is not defined on () -> Int, a function type
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
example.ern:3:22: () -> Int, a function type, does not support equality, which same requires of its first argument
2 | 
3 | fn f() : Bool = same(fn() = 1, fn() = 1)
  |                 ---- same : (a=, a=) -> Bool
  |                      ^^^^^^^^
```

### `==` reached through a function a call answers (§3.10, §11.5)

```ernest-rejected
fn equalizer() = fn(x, y) = x == y

fn f() : Bool = equalizer()(fn() = 1, fn() = 1)
```

```console
$ ern build example.ern
example.ern:3:17: () -> Int, a function type, does not support equality, which equalizer requires: equalizer : () -> (a=, a=) -> Bool
2 | 
3 | fn f() : Bool = equalizer()(fn() = 1, fn() = 1)
  |                 ^^^^^^^^^
```

### `==` reached through a later use of a function (§3.10, §11.5)

```ernest-rejected
fn same(a, b) = a == b

fn f() : Bool = {
    let eq = same;
    eq(fn() = 1, fn() = 1)
}
```

```console
$ ern build example.ern
example.ern:4:14: () -> Int, a function type, does not support equality, which same requires: same : (a=, a=) -> Bool
3 | fn f() : Bool = {
4 |     let eq = same;
  |              ^^^^
```

## Requirements and derived members (report §4.9, §3.5)

### A call that needs a member the function does not declare (§4.9)

```ernest-rejected
fn unique(list : List(a)) : List(a) =
    OrderedSet.toList(OrderedSet.fromList(list))
```

```console
$ ern build example.ern
example.ern:2:23: fromList needs a.compare, which unique does not declare
1 | fn unique(list : List(a)) : List(a) =
2 |     OrderedSet.toList(OrderedSet.fromList(list))
  |                       ^^^^^^^^^^^^^^^^^^^
  | = help: add `needs a.compare` to unique's signature
```

### An operator on a type variable no requirement names (§4.8, §4.9)

```ernest-rejected
fn smaller(x : a, y : a) : a =
    if x < y then x else y
```

```console
$ ern build example.ern
example.ern:2:8: `<` needs a.compare, which smaller does not declare
1 | fn smaller(x : a, y : a) : a =
2 |     if x < y then x else y
  |        ^^^^^
  | = help: add `needs a.compare` to smaller's signature
```

### An operator on a type no operand fixes (§3.10, §4.9)

```ernest-rejected
fn later() : Bool = Right(2) < Right(1)
```

```console
$ ern build example.ern
example.ern:1:21: `<` needs a.compare, at a type variable no requirement can name
1 | fn later() : Bool = Right(2) < Right(1)
  |                     ^^^^^^^^^^^^^^^^^^^
  | = help: annotate the value where it is bound, `let value : Either(..., Int) = ...`
```

### A requirement's member named in a body (§4.9, §4.5)

```ernest-rejected
fn smaller(x : a, y : a) : a needs a.compare =
    if a.compare(x, y) == Less then x else y
```

```console
$ ern build example.ern
example.ern:2:8: `a.compare` names a member, which an expression reaches through `compare`
1 | fn smaller(x : a, y : a) : a needs a.compare =
2 |     if a.compare(x, y) == Less then x else y
  |        ^^^^^^^^^
  | = help: write `compare(x, y)`
```

### A top-level `let` that would need a requirement (§4.9)

```ernest-rejected
let build = OrderedSet.fromList
```

```console
$ ern build example.ern
example.ern:1:13: fromList needs a.compare, which a top-level let cannot declare
1 | let build = OrderedSet.fromList
  |             ^^^^^^^^^^^^^^^^^^^
  | = help: declare a `fn` with `needs a.compare`
```

### A known type without the member (§4.9)

```ernest-rejected
fn f(counts : Map(Int, Int)) : Int =
    OrderedSet.size(OrderedSet.fromList([counts]))
```

```console
$ ern build example.ern
example.ern:2:21: fromList needs Map(Int, Int).compare, and Map(Int, Int) has no compare
1 | fn f(counts : Map(Int, Int)) : Int =
2 |     OrderedSet.size(OrderedSet.fromList([counts]))
  |                     ^^^^^^^^^^^^^^^^^^^
  | = help: Map(Int, Int) has no ordering; hold it in a type of your own that declares `compare`
```

### A member of another result type (§4.9)

```ernest-rejected
type Vec = Vec(Float)

fn Vec.+(Vec(a) : Vec, Vec(b) : Vec) : Float =
    a + b

fn total(list : List(a), zero : a) : a needs a.+ =
    List.foldLeft(list, zero, fn(sum, x) = sum + x)

fn f() : Vec =
    total([Vec(1.0)], Vec(0.0))
```

```console
$ ern build example.ern
example.ern:10:5: total needs Vec.+ : (Vec, Vec) -> Vec, and Vec.+ answers Float
 9 | fn f() : Vec =
10 |     total([Vec(1.0)], Vec(0.0))
   |     ^^^^^
   | = help: a function over an operation of another shape takes it as a parameter
```

### A requirement that names no member (§4.9)

```ernest-rejected
fn sum(list : List(a)) : a needs a.zero, a.+ =
    List.foldLeft(list, a.zero, fn(total, x) = total + x)
```

```console
$ ern build example.ern
example.ern:1:34: zero is not a member: a requirement names compare, negate, an operator or show
1 | fn sum(list : List(a)) : a needs a.zero, a.+ =
  |                                  ^^^^^^
```

### A requirement on no type variable of the signature (§4.9)

```ernest-rejected
fn f(x : a) : a needs b.compare =
    x
```

```console
$ ern build example.ern
example.ern:1:23: b is no type variable of the signature
1 | fn f(x : a) : a needs b.compare =
  |                       ^^^^^^^^^
```

### A requirement that names a member twice (§4.9)

```ernest-rejected
fn largest(list : List(a)) : Optional(a) needs a.compare, a.compare =
    List.last(list)
```

```console
$ ern build example.ern
example.ern:1:59: the requirement names a.compare twice
1 | fn largest(list : List(a)) : Optional(a) needs a.compare, a.compare =
  |                                                --------- first named here
  |                                                           ^^^^^^^^^
```

### A requirement on an effect variable (§4.9)

```ernest-rejected
fn f(x : a) : a receiving e needs e.compare =
    x
```

```console
$ ern build example.ern
example.ern:1:35: e is an effect variable, and a requirement names a type variable in a value position
1 | fn f(x : a) : a receiving e needs e.compare =
  |                                   ^^^^^^^^^
```

### A binding named as a type variable of the signature (§4.9)

```ernest-rejected
fn f(a : a) : a needs a.compare =
    a
```

```console
$ ern build example.ern
example.ern:1:6: `a` names a type variable of the signature, and a declaration with a requirement binds no name that is one of its type variables
1 | fn f(a : a) : a needs a.compare =
  |      ^
  | = help: rename the binding
```

### A lambda with a requirement (§4.9)

```ernest-rejected
let f = fn(x : a) : a needs a.compare = x
```

```console
$ ern build example.ern
example.ern:1:23: a lambda declares no requirement
1 | let f = fn(x : a) : a needs a.compare = x
  |                       ^^^^^
  | = help: declare a `fn` with the requirement and pass it
```

### `Io.show` at a type variable no requirement names (Appendix E.1, §4.9)

```ernest-rejected
fn shown(x : a) : String =
    Io.show(x)
```

```console
$ ern build example.ern
example.ern:2:5: Io.show needs a.show, which shown does not declare
1 | fn shown(x : a) : String =
2 |     Io.show(x)
  |     ^^^^^^^
  | = help: add `needs a.show` to shown's signature
```

### `Io.show` at a type not known whole (Appendix E.1, §11.5)

```ernest-rejected
fn f() : String =
    Io.show([])
```

```console
$ ern build example.ern
example.ern:2:5: the type List(a) is not known whole here, and Io.show writes a value by its type
1 | fn f() : String =
2 |     Io.show([])
  |     ^^^^^^^
  | = help: bind the value with an annotation, `let value : List(...) = ...`, and show that; at a type variable of the signature, a requirement `needs a.show` lets it write the value
```

### `Foreign.term` on a type variable (§8.4, Appendix E.12)

```ernest-rejected
fn give(x : a) : Foreign.Term =
    Foreign.term(x)
```

```console
$ ern build example.ern
example.ern:2:5: the type a is not known whole here, and Foreign.term gives foreign code a value by its type
1 | fn give(x : a) : Foreign.Term =
2 |     Foreign.term(x)
  |     ^^^^^^^^^^^^
  | = help: a value of a type variable is given by a `foreign fn` whose parameter is of that variable
```

### A declaration with a requirement as a value at the prompt (§4.9, §11.2)

```console
$ ern shell
Ernest 0.4.0. :help for the commands, :quit to leave.
> OrderedSet.fromList
input 1:1:1: fromList needs a.compare, at a type variable no requirement can name
1 | OrderedSet.fromList
  | ^^^^^^^^^^^^^^^^^^^
  | = help: apply it at a known type, or declare a `fn` with the requirement
```

### A value of a type's previous version at the prompt (§11.2, §8.7)

```console
$ ern shell
Ernest 0.4.0. :help for the commands, :quit to leave.
> Fs.write(Path("counter.ern"), String.toUtf8("export type Msg = Inc(Int)\n"), 1000)
Right(Unit) : Either(Io.Error, Unit)
> :load Counter
Counter, compiled from counter.ern
> let inc = Counter.Inc
inc : (Int) -> Counter.Msg
> Fs.write(Path("counter.ern"), String.toUtf8("export type Msg = Inc(Int) | Reset\n"), 1000)
Right(Unit) : Either(Io.Error, Unit)
> :reload
Counter, compiled again
Counter.Msg changed: the binding inc is of its previous version, Counter$1.Msg
> let m : Counter.Msg = inc(1)
input 6:1:23: the value does not have the declared type: expected Counter.Msg, found Counter$1.Msg
1 | let m : Counter.Msg = inc(1)
  |         ----------- declared Counter.Msg here
  |                       ^^^^^^
  | = help: Counter$1.Msg is of a previous version of Counter, which a reload replaced
```

### A derived compare over a field without one (§3.5)

```ernest-rejected
type Date = Date(year : Int, exact : Bool) derives compare
```

```console
$ ern build example.ern
example.ern:1:38: Date.compare cannot be derived: Bool has no compare
1 | type Date = Date(year : Int, exact : Bool) derives compare
  |                                      ^^^^
  | = help: declare `fn Date.compare` yourself, or hold a field whose type has a compare
```

### A type that derives compare and declares it (§3.5)

```ernest-rejected
type Coin = Coin(Int) derives compare

fn Coin.compare(Coin(a) : Coin, Coin(b) : Coin) : Ordering =
    Int.compare(a, b)
```

```console
$ ern build example.ern
example.ern:1:23: Coin derives compare and declares it too
1 | type Coin = Coin(Int) derives compare
  |                       ^^^^^^^^^^^^^^^
...
3 | fn Coin.compare(Coin(a) : Coin, Coin(b) : Coin) : Ordering =
  | ------------------------------------------------------------ declared here
  | = help: keep the declaration, or `derives compare`
```

### `derives` of what is not compare (§3.5)

```ernest-rejected
type Coin = Coin(Int) derives show
```

```console
$ ern build example.ern
example.ern:1:31: `derives` names compare and nothing else, not identifier `show`
1 | type Coin = Coin(Int) derives show
  |                               ^^^^
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
```

### A call of a callee that is no name (§5.2, §11.5)

```ernest-rejected
fn f() : Int =
    (fn(x : Int) : Int = x)(1, 2)
```

```console
$ ern build example.ern
example.ern:2:5: the callee takes 1 argument, not 2
1 | fn f() : Int =
2 |     (fn(x : Int) : Int = x)(1, 2)
  |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

### A call of a selected field (§5.2, §11.5)

```ernest-rejected
type Ops = Ops(size : (Int) -> Int)

fn f(ops : Ops) : Int =
    ops.size(1, 2)
```

```console
$ ern build example.ern
example.ern:4:5: ops.size takes 1 argument, not 2
3 | fn f(ops : Ops) : Int =
4 |     ops.size(1, 2)
  |     ^^^^^^^^^^^^^^
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

### A body at another type than its uses gave its result (§3.9)

```ernest-rejected
fn main() : Int = {
    let x = h() + 1;
    fn h() = "a";
    x
}
```

```console
$ ern build example.ern
example.ern:3:14: the body does not have the result type h's uses give it: expected Int, found String
1 | fn main() : Int = {
2 |     let x = h() + 1;
  |             --- this use gives h's result as Int
3 |     fn h() = "a";
  |              ^^^
```

### A recursive call at another type than the definition's (§4.5)

```ernest-rejected
fn f(x) = if x then f(1) else 2
```

```console
$ ern build example.ern
example.ern:1:23: the argument of a recursive call does not fit f at its own type: expected Bool, found Int
1 | fn f(x) = if x then f(1) else 2
  |                     - f : (Bool) -> a
  |                       ^
  | = help: declare a second function for the call at another type
```

### A top-level `let` that names itself (§8.5)

```ernest-rejected
let f = fn(x) = if x then f(1) else 2
```

```console
$ ern build example.ern
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
  | = help: `a` stands for every type a caller may choose, not for Int alone
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
  | = help: `a` and `b` stand for types a caller chooses apart, which may differ
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
example.ern:2:9: the pattern does not fit the value inside the sum type: expected Int, found #(c, d)
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
  |                  ------- the block's value has type Optional(a) here
  |                               ------- and here
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
  |                  -------- the block's value has type Either(a, b) here
  |                                -------- and here
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
example.ern:2:9: the pattern does not fit the value: expected Int, found #(c, d)
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

### A function that receives, called in a guard (§5.9)

```ernest-rejected
fn wait() : Bool receiving m =
    receive {
        after 1 -> true
    }

fn f(n : Int) : Int receiving Never =
    match n {
        k when wait() -> k
      | _ -> 0
    }
```

```console
$ ern build example.ern
example.ern:8:16: wait needs a mailbox, and a guard receives nothing
7 |     match n {
8 |         k when wait() -> k
  |                ^^^^^^
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
example.ern:3:9: Some has one positional field; write Some(_) to match any Some
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
  | = help: bind two names and compare them in a guard, `when x == y`
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
fn g() : Unit receiving String =
    receive {
        _ -> Unit
    }

fn f() : Unit receiving Int = g()
```

```console
$ ern build example.ern
example.ern:6:31: g needs mailbox String, and the mailbox here is Int
5 | 
6 | fn f() : Unit receiving Int = g()
  |                         --- f is declared `receiving Int` here
  |                               ^^^
```

### A call of a function that receives, from one that receives nothing (§6.1)

```ernest-rejected
fn g() : Unit receiving String =
    receive {
        _ -> Unit
    }

fn f() : Unit = g()
```

```console
$ ern build example.ern
example.ern:6:17: g needs a mailbox, and f receives nothing
5 | 
6 | fn f() : Unit = g()
  |          ---- `: Unit` without `receiving` declares that f receives nothing
  |                 ^^^
  | = help: give f its mailbox type, `receiving String`
```

### A function that waits where one that receives nothing is expected (§3.9, §6.1)

```ernest-rejected
fn pause(ms : Int) : Unit receiving m =
    receive {
        after ms -> Unit
    }

fn apply(f : (Int) -> Unit, ms : Int) : Unit = f(ms)

fn main() : Unit receiving Never = apply(pause, 10)
```

```console
$ ern build example.ern
example.ern:8:42: the argument does not fit apply: a function that receives where one that receives nothing is needed
7 | 
8 | fn main() : Unit receiving Never = apply(pause, 10)
  |                                    ----- apply : ((Int) -> Unit, Int) -> Unit
  |                                          ^^^^^
```

### `self` in a function that receives nothing (§6.1, §11.5)

```ernest-rejected
fn tell() : Unit = {
    let me = self();
    send(me, 1)
}
```

```console
$ ern build example.ern
example.ern:2:14: self needs a mailbox, and tell receives nothing
1 | fn tell() : Unit = {
  |             ---- `: Unit` without `receiving` declares that tell receives nothing
2 |     let me = self();
  |              ^^^^^^
  | = help: give tell its mailbox type, `receiving Int`
```

### A wrap in a function that receives nothing (§6.9, §11.5)

```ernest-rejected
type Msg = Died(Down)

fn watch(p : Process) : Unit = monitor(p, Died)
```

```console
$ ern build example.ern
example.ern:3:32: monitor needs a mailbox, and watch receives nothing
2 | 
3 | fn watch(p : Process) : Unit = monitor(p, Died)
  |                         ---- `: Unit` without `receiving` declares that watch receives nothing
  |                                ^^^^^^^^^^^^^^^^
  | = help: give watch its mailbox type, `receiving Msg`
```

### `receive` in a function that receives nothing (§6.3)

```ernest-rejected
fn f() : Int =
    receive {
        after 1 -> 1
    }
```

```console
$ ern build example.ern
example.ern:2:5: `receive` needs a mailbox, and f receives nothing
1 | fn f() : Int =
  |          --- `: Int` without `receiving` declares that f receives nothing
2 |     receive {
  |     ^^^^^^^^^
  | = help: give f its mailbox type, `receiving e`
```

### `receive` in a function of mailbox Never (§6.8)

```ernest-rejected
fn f() : Int receiving Never =
    receive {
        n -> n
    }
```

```console
$ ern build example.ern
example.ern:2:5: f is declared with mailbox Never and cannot receive
1 | fn f() : Int receiving Never =
  |                        ----- f is declared `receiving Never` here
2 |     receive {
  |     ^^^^^^^^^
  | = help: only an `after` clause is allowed; give f another mailbox type with `receiving`
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
fn f() : Int receiving Int =
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

fn f(limit : Money) : Int receiving Money =
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
  | = help: receive the message and `match` it
```

### A `receive` guard that calls a function (§6.3)

```ernest-rejected
fn f() : Int receiving String =
    receive {
        text when String.isEmpty(text) -> 1
    }
```

```console
$ ern build example.ern
example.ern:3:19: a `receive` guard combines `true`, `false`, Bool variables, and comparisons with `!`, `&&`, and `||`, and calls nothing
2 |     receive {
3 |         text when String.isEmpty(text) -> 1
  |                   ^^^^^^^^^^^^^^^^^^^^
  | = help: bind what the guard needs that does not come from the message with a `let` before the `receive` and compare that; or receive the message and `match` it, which takes it out of the mailbox
```

### A `receive` guard that compares a computed value (§6.3)

```ernest-rejected
fn f() : Int receiving Int =
    receive {
        n when n + 1 > 2 -> 1
    }
```

```console
$ ern build example.ern
example.ern:3:16: a comparison in a `receive` guard compares variables, top-level lets, literals, and nullary constructors
2 |     receive {
3 |         n when n + 1 > 2 -> 1
  |                ^^^^^
  | = help: receive the message and `match` it
```

## What crosses to another node (report §3.11)

### A service at a message type not known where it is made (§3.11)

```ernest-rejected
fn serviceOf(name : String) : Peer.Service(m) = Peer.service(name)
```

```console
$ ern build example.ern
example.ern:1:49: Peer.service names a service at a message type known whole, and here it is m
1 | fn serviceOf(name : String) : Peer.Service(m) = Peer.service(name)
  |                                                 ^^^^^^^^^^^^
  | = help: annotate the service where it is bound, `let service : Peer.Service(Msg) = Peer.service("name")` (report §3.11)
```

### A service at a type bound to its node (§3.11)

```ernest-rejected
type Msg = Run(() -> Unit)

let service : Peer.Service(Msg) = Peer.service("jobs")
```

```console
$ ern build example.ern
example.ern:3:35: Peer.service names a service at Msg, which is bound to its node, since it holds a function
2 | 
3 | let service : Peer.Service(Msg) = Peer.service("jobs")
  |                                   ^^^^^^^^^^^^
  | = help: keep a function out of Msg; send a value that crosses, which the process acts on (report §3.11)
```

### `Peer.spawn` taken as a value (§3.11)

```ernest-rejected
fn starter() : Unit = {
    let start = Peer.spawn;
    Unit
}
```

```console
$ ern build example.ern
example.ern:2:17: Peer.spawn is called where it is named, so that the compiler sees the function it starts
1 | fn starter() : Unit = {
2 |     let start = Peer.spawn;
  |                 ^^^^^^^^^^
  | = help: call it: `Peer.spawn(name, fn() = ..., ms)` (report §3.11)
```

### A spawn on a peer of a function that came as a value (§3.11)

```ernest-rejected
fn startOn(name : String, f : () -> Unit) : Unit = {
    let _ = Peer.spawn(name, f, 1000);
    Unit
}
```

```console
$ ern build example.ern
example.ern:2:30: Peer.spawn starts f, a function that came as a value, whose captures the compiler does not see
1 | fn startOn(name : String, f : () -> Unit) : Unit = {
2 |     let _ = Peer.spawn(name, f, 1000);
  |                              ^
  | = help: write the lambda at the spawn, bind it with `let`, or declare it with `fn`, in this definition (report §3.11)
```

### A spawn on a peer of a top-level `let` (§3.11)

```ernest-rejected
let job : () -> Unit = fn() = Unit

fn start() : Unit = {
    let _ = Peer.spawn("worker", job, 1000);
    Unit
}
```

```console
$ ern build example.ern
example.ern:4:34: Peer.spawn starts job, a top-level `let`, whose value may hold captures the compiler does not see
3 | fn start() : Unit = {
4 |     let _ = Peer.spawn("worker", job, 1000);
  |                                  ^^^
  | = help: declare it with `fn`, or write a lambda at the spawn (report §3.11)
```

### A spawn on a peer of a function a call answers (§3.11)

```ernest-rejected
fn job() : () -> Unit = fn() = Unit

fn start() : Unit = {
    let _ = Peer.spawn("worker", job(), 1000);
    Unit
}
```

```console
$ ern build example.ern
example.ern:4:34: Peer.spawn starts job(), a function a call answers, whose captures the compiler does not see
3 | fn start() : Unit = {
4 |     let _ = Peer.spawn("worker", job(), 1000);
  |                                  ^^^^^
  | = help: write the lambda at the spawn, bind it with `let`, or declare it with `fn`, in this definition (report §3.11)
```

### A capture whose type holds a type variable (§3.11, §3.9)

```ernest-rejected
fn startWith(name : String, values : List(a)) : Unit = {
    let _ = Peer.spawn(name, fn() = Io.println(Int.toString(List.size(values))),
                       1000);
    Unit
}
```

```console
$ ern build example.ern
example.ern:2:71: the function Peer.spawn starts captures values, whose type List(a) holds a type variable
1 | fn startWith(name : String, values : List(a)) : Unit = {
2 |     let _ = Peer.spawn(name, fn() = Io.println(Int.toString(List.size(values))),
  |                                                                       ^^^^^^
  | = help: capture a value whose type is known whole: compute what the process needs of values before the spawn and capture that (report §3.11)
```

### A capture of a type bound to its node (§3.11)

```ernest-rejected
fn startWith(name : String, describe : (Int) -> String) : Unit = {
    let _ = Peer.spawn(name, fn() = Io.println(describe(1)), 1000);
    Unit
}
```

```console
$ ern build example.ern
example.ern:2:48: the function Peer.spawn starts captures describe, a function, which is bound to its node
1 | fn startWith(name : String, describe : (Int) -> String) : Unit = {
2 |     let _ = Peer.spawn(name, fn() = Io.println(describe(1)), 1000);
  |                                                ^^^^^^^^
  | = help: compute what the process needs of describe before the spawn and capture that, or spawn on this node (report §3.11)
```

### A spawned function that uses a member of the requirement in force (§3.11)

```ernest-rejected
fn startWith(name : String, sample : a) : Unit needs a.show = {
    let _ = Peer.spawn(name, fn() = {
        let shown : a = fault("never");
        Io.println(Io.show(shown))
    }, 1000);
    Unit
}
```

```console
$ ern build example.ern
example.ern:2:30: Peer.spawn starts a function that uses a.show, a member of the requirement in force, which is a function bound to its node
1 | fn startWith(name : String, sample : a) : Unit needs a.show = {
2 |     let _ = Peer.spawn(name, fn() = {
  |                              ^^^^^^^^
  | = help: give the process what it needs as a value it captures, or spawn on this node (report §3.11)
```

### A spawned process whose mailbox type is not known whole (§3.11)

```ernest-rejected
fn idle() : Unit receiving m =
    receive {
        after 1000 -> Unit
    }

fn start() : Either(Io.Error, Address(a)) =
    Peer.spawn("worker", idle, 1000)
```

```console
$ ern build example.ern
example.ern:7:26: Peer.spawn starts a process whose mailbox type a is not known whole here
6 | fn start() : Either(Io.Error, Address(a)) =
7 |     Peer.spawn("worker", idle, 1000)
  |                          ^^^^
  | = help: give the function its mailbox type, `fn() : Unit receiving Msg = ...`: an instance of this definition could make the variable a type bound to its node (report §3.11)
```

### A spawned process whose mailbox type is bound to its node (§3.11)

```ernest-rejected
type Msg = Run(Address(Tcp.SocketMsg))

fn serve() : Unit receiving Msg =
    receive {
        Run(_) -> serve()
    }

fn start() : Unit = {
    let _ = Peer.spawn("worker", serve, 1000);
    Unit
}
```

```console
$ ern build example.ern
example.ern:9:34: Peer.spawn starts a process whose mailbox type Msg is bound to its node, since it holds the address of a socket
8 | fn start() : Unit = {
9 |     let _ = Peer.spawn("worker", serve, 1000);
  |                                  ^^^^^
  | = help: keep the address of a socket on this node and send the process values that cross, or spawn on this node (report §3.11)
```

### A compute whose function answers a value bound to its node (§3.11)

```ernest-rejected
fn adder() : Unit = {
    let _ = Peer.compute(fn() = fn(n : Int) = n + 1, 1000);
    Unit
}
```

```console
$ ern build example.ern
example.ern:2:26: Peer.compute answers a value of type (Int) -> Int, which is bound to its node, since it holds a function
1 | fn adder() : Unit = {
2 |     let _ = Peer.compute(fn() = fn(n : Int) = n + 1, 1000);
  |                          ^^^^^^^^^^^^^^^^^^^^^^^^^^
  | = help: answer a value that crosses, from which this node builds what it needs (report §3.11)
```

### A compute whose function's result type holds a type variable (§3.11, §3.9)

```ernest-rejected
fn empties() : Unit = {
    let _ = Peer.computeAt("worker", fn() = [], 1000);
    Unit
}
```

```console
$ ern build example.ern
example.ern:2:38: Peer.computeAt answers a value of type List(a), which holds a type variable, so whether it crosses is not known here
1 | fn empties() : Unit = {
2 |     let _ = Peer.computeAt("worker", fn() = [], 1000);
  |                                      ^^^^^^^^^
  | = help: give the function its result type, `fn() : List(...) = ...`: the value crosses back to this node, and its type is known whole where the compute is written (report §3.11)
```

### A compute's process whose mailbox type is bound to its node (§3.11)

```ernest-rejected
type Msg = Run(Address(Tcp.SocketMsg))

fn serve() : Int receiving Msg =
    receive {
        Run(_) -> serve()
    }

fn start() : Unit = {
    let _ = Peer.computeAt("worker", serve, 1000);
    Unit
}
```

```console
$ ern build example.ern
example.ern:9:38: Peer.computeAt starts a process whose mailbox type Msg is bound to its node, since it holds the address of a socket
8 | fn start() : Unit = {
9 |     let _ = Peer.computeAt("worker", serve, 1000);
  |                                      ^^^^^
  | = help: keep the address of a socket on this node and send the process values that cross, or run the function on this node, `f()` (report §3.11)
```

### `Peer.compute` taken as a value (§3.11)

```ernest-rejected
fn computer() : Unit = {
    let run = Peer.compute;
    Unit
}
```

```console
$ ern build example.ern
example.ern:2:15: Peer.compute is called where it is named, so that the compiler sees the function it starts
1 | fn computer() : Unit = {
2 |     let run = Peer.compute;
  |               ^^^^^^^^^^^^
  | = help: call it: `Peer.compute(fn() = ..., ms)` (report §3.11)
```

### `Code.running` taken as a value (§3.11)

```ernest-rejected
fn lister() : Unit = {
    let list = Code.running;
    Unit
}
```

```console
$ ern build example.ern
example.ern:2:16: Code.running is called where it is named, so that the compiler sees the declaration it names
1 | fn lister() : Unit = {
2 |     let list = Code.running;
  |                ^^^^^^^^^^^^
  | = help: call it: `Code.running(f)`, `f` a top-level `fn` (report §3.11)
```

### `Code.running` of a local (§3.11)

```ernest-rejected
type Msg = Stop

fn loop() : Unit receiving Msg =
    receive {
        Stop -> Unit
    }

fn stopAll() : Unit = {
    let f = loop;
    List.forEach(Code.running(f), fn(process) = send(process, Stop))
}
```

```console
$ ern build example.ern
example.ern:10:31: Code.running lists the processes that run a declaration, and f is a local, whose function is no declaration
 9 |     let f = loop;
10 |     List.forEach(Code.running(f), fn(process) = send(process, Stop))
   |                               ^
   | = help: name loop itself, `Code.running(loop)` (report §3.11)
```

### `Code.running` of a lambda (§3.11)

```ernest-rejected
fn listed() : Int =
    List.size(Code.running(fn() = Unit))
```

```console
$ ern build example.ern
example.ern:2:28: Code.running lists the processes that run a declaration, and a lambda is no declaration
1 | fn listed() : Int =
2 |     List.size(Code.running(fn() = Unit))
  |                            ^^^^^^^^^^^
  | = help: declare the function with `fn` at the top level and name it (report §3.11)
```

### `Code.running` of a top-level `let` (§3.11)

```ernest-rejected
let loop : () -> Unit = fn() = Unit

fn listed() : Int =
    List.size(Code.running(loop))
```

```console
$ ern build example.ern
example.ern:4:28: Code.running lists the processes that run a declaration, and loop is a top-level `let`, whose value is no declaration
3 | fn listed() : Int =
4 |     List.size(Code.running(loop))
  |                            ^^^^
  | = help: declare loop with `fn` and name it, `Code.running(loop)` (report §3.11)
```

### `Code.running` of a foreign declaration (§3.11)

```ernest-rejected
foreign fn waits() : Unit = "erlang:yield/0"

fn listed() : Int =
    List.size(Code.running(waits))
```

```console
$ ern build example.ern
example.ern:4:28: Code.running lists the processes that run a declaration, and waits is a foreign declaration, which has no hash
3 | fn listed() : Int =
4 |     List.size(Code.running(waits))
  |                            ^^^^^
  | = help: declare a top-level `fn` that calls waits, and name it (report §3.11)
```

### `Code.running` of the prelude's function (§3.11)

```ernest-rejected
fn listed() : Int =
    List.size(Code.running(spawn))
```

```console
$ ern build example.ern
example.ern:2:28: Code.running lists the processes that run a declaration, and spawn is the prelude's, which no module declares
1 | fn listed() : Int =
2 |     List.size(Code.running(spawn))
  |                            ^^^^^
  | = help: name a top-level `fn` of this program whose result type is `Unit` (report §3.11)
```

### `Code.running` of a function whose result type is not `Unit` (§3.11)

```ernest-rejected
fn total() : Int receiving Int =
    receive {
        n -> n
    }

fn listed() : Int =
    List.size(Code.running(total))
```

```console
$ ern build example.ern
example.ern:7:28: Code.running lists the processes that run total, whose result type is Int, not Unit
6 | fn listed() : Int =
7 |     List.size(Code.running(total))
  |                            ^^^^^
  | = help: name the function the processes run, a top-level `fn` whose result type is `Unit` (report §3.11)
```

### `Code.running` of a function whose mailbox type holds a type variable (§3.11)

```ernest-rejected
fn hold(value : a) : Unit receiving List(a) =
    receive {
        _ -> Unit
    }

fn listed() : Int =
    List.size(Code.running(hold))
```

```console
$ ern build example.ern
example.ern:7:28: Code.running lists the processes that run hold, whose mailbox type List(a) holds a type variable
6 | fn listed() : Int =
7 |     List.size(Code.running(hold))
  |                            ^^^^
  | = help: give hold its mailbox type, `fn hold(...) : Unit receiving Msg = ...`: every process listed has it (report §3.11)
```
