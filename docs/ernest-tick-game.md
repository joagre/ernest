# Paper Program 3: Tick Game

Written against the Ernest report, September 2026. A multiplayer snake game in the terminal: the world is updated ten times per second, players send directions between ticks, apples appear at random, scores are counted. The aim is to hit local state in pure code, time drift, input faster than ticks, and randomness without `{Random}`.

## Assumptions

`Sys` in the report requires `stdout` and `clock`; keys are the runtime's addition. Assumed:

```
type KeyMsg = Subscribe(Address(Key))
type Key    = Up | Down | Left | Right | Quit

keys : Address(KeyMsg)         // field in the runtime's Sys
```

`Random.next : (Seed) -> (Int, Seed)` is assumed in the prelude, a pure generator.

## The Program

```
// Pure code ------------------------------------------------------

type Dir = N | S | W | E
type Pos = Pos(x : Int, y : Int)

type Player = Player(id : Int, body : List(Pos), dir : Dir, score : Int, alive : Bool)

type World = World(
    w : Int, h : Int,
    players : Map(Int, Player),
    apples : List(Pos),
    seed : Seed,
    tick : Int
)

type Input = Turn(id : Int, dir : Dir) | Leave(Int)

fn move(w : Int, h : Int, Pos(x = x, y = y) : Pos, d : Dir) -> Pos = match d {
    N -> Pos(x = x, y = (y - 1) % h)
  | S -> Pos(x = x, y = (y + 1) % h)
  | W -> Pos(x = (x - 1) % w, y = y)
  | E -> Pos(x = (x + 1) % w, y = y)
}

fn turn(p : Player, d : Dir) -> Player = match (Player.dir(p), d) {
    (N, S) -> p | (S, N) -> p | (W, E) -> p | (E, W) -> p    // no U-turn
  | _      -> Player(..p, dir = d)
}

fn Player.dir(Player(dir = d) : Player) -> Dir = d
fn Player.id(Player(id = i) : Player) -> Int = i

fn applyInput(world : World, input : Input) -> World = {
    let World(players = ps) = world;
    match input {
        Turn(id = id, dir = d) -> match Map.get(ps, id) {
            Some(p) -> World(..world, players = Map.put(ps, id, turn(p, d)))
          | None    -> world
        }
      | Leave(id) -> World(..world, players = Map.delete(ps, id))
    }
}

// One tick: move everyone, eat apples, collide, refill apples.
// Three counters change: score per player, apples left, tick.
fn step(world : World) -> World = {
    let World(w = w, h = h, players = ps, apples = apples, seed = seed, tick = t) = world;
    fn movePlayer((acc, apples), _, p) = match p {
        Player(alive = false) -> (acc, apples)
      | Player(body = head +: rest, dir = d, score = s) -> {
            let next = move(w, h, head, d);
            let ate = List.contains(apples, next);
            let (body, s2) = if ate then (next +: head +: rest, s + 1)
                             else (next +: head +: List.dropLast(rest), s);
            let p2 = Player(..p, body = body, score = s2);
            (Map.put(acc, Player.id(p), p2), List.remove(apples, next))
        }
      | Player(body = []) -> (acc, apples)
    };
    let (ps2, apples2) = Map.foldLeft(ps, (ps, apples), movePlayer);
    let ps3 = Map.map(ps2, fn(p) = collide(ps2, p));
    let (apples3, seed2) = refill(w, h, Map.size(ps3), apples2, seed);
    World(..world, players = ps3, apples = apples3, seed = seed2, tick = t + 1)
}

fn collide(ps : Map(Int, Player), p : Player) -> Player = match p {
    Player(body = head +: _, alive = true) ->
        if List.any(Map.values(ps), fn(q) = List.contains(tailOf(q), head))
        then Player(..p, alive = false) else p
  | _ -> p
}

fn tailOf(Player(body = b) : Player) -> List(Pos) = match b { _ +: rest -> rest | [] -> [] }

fn refill(w : Int, h : Int, want : Int, apples : List(Pos), seed : Seed) -> (List(Pos), Seed) =
    if List.size(apples) >= want then (apples, seed)
    else {
        let (rx, s1) = Random.next(seed);
        let (ry, s2) = Random.next(s1);
        refill(w, h, want, Pos(x = rx % w, y = ry % h) +: apples, s2)
    }

fn render(world : World) -> Text = todo("grid to text, one line per y")

// The game process ------------------------------------------------

type GameMsg = Tick | In(Input)

fn game(out : Address(Line), clock : Address(ClockMsg), world : World) -> () with GameMsg = {
    send(clock, After(ms = 100, to = via(fn(_) = Tick, self())));
    recv {
        Tick -> {
            let world2 = step(drain(world, 64));
            send(out, Line(render(world2)));
            game(out, clock, world2)
        }
    }
}

// Drain the mailbox of input without blocking; at most n per tick.
fn drain(world : World, n : Int) -> World with GameMsg =
    if n == 0 then world
    else recv {
        In(i)   -> drain(applyInput(world, i), n - 1)
      | after 0 -> world
    }

// One process per player: translates keys into Input -------------

fn player(id : Int, game : Address(GameMsg)) -> () with Key = recv {
    Up    -> { send(game, In(Turn(id = id, dir = N))); player(id, game) }
  | Down  -> { send(game, In(Turn(id = id, dir = S))); player(id, game) }
  | Left  -> { send(game, In(Turn(id = id, dir = W))); player(id, game) }
  | Right -> { send(game, In(Turn(id = id, dir = E))); player(id, game) }
  | Quit  -> send(game, In(Leave(id)))
}

fn main(Sys(stdout = out, clock = clock, keys = keys) : Sys) -> () with () = {
    let world0 = World(w = 40, h = 20, players = Map.empty, apples = [], seed = Seed(42), tick = 0);
    let g = spawn(Local, fn() = game(out, clock, addPlayer(world0, 1)));
    let p1 = spawn(Local, fn() = player(1, g));
    send(keys, Subscribe(p1))
}
```

## What Chafed

**1. Local state: it did not hurt, but it shows where it would have.** `step` changes three things: the players' scores, apples left, tick. Without `{State}` it became a fold with a tuple accumulator `(ps, apples)`, a `Map.map`, and a recursive `refill` that threads the seed. That is three lines more than a mutable version and it reads top to bottom. What would hurt is if `movePlayer` had to update a fourth thing: the tuple becomes a triple, and every `(acc, apples)` in the body changes. With named fields the accumulator could be a type `Step { players, apples }` and `..` would have saved it. Conclusion: `let mut` is not needed; the accumulator as a named type is the answer when the tuple grows past two.

**2. `where` was needed, and did not exist.** `movePlayer` uses `w` and `h` from `step`'s arguments. The first version wrote `where` out of Haskell habit; the specification does not have it. The answer was not to add `where` but to remove the difference: a definition may stand anywhere a binding may stand, in blocks as at top level. The code above does so; `movePlayer` is the first binding in `step`'s block. The first version also wrote `tailOf` with two clauses, Haskell-style; the specification has one clause and `match`, and that is fixed.

**3. `after 0` as draining is the idiom for input between ticks.** `drain` reads everything that arrived since the last tick and stops when the mailbox is empty, without blocking. It is exactly what a game needs. The limit `64` is backpressure in its simplest form: a player who sends a thousand directions per tick gets the first 64 handled and the rest next tick. That is the right behavior and it is three lines.

**4. Time drift.** `After(ms = 100, to = ...)` is sent at the start of the loop, before `step` and `render`, so the next tick is 100 ms after this tick's *start*. That is right. But if `step` takes 120 ms, the next `Tick` is already in the mailbox when the loop reaches `recv`, and the game runs as fast as it can without anyone noticing. `clock` has only relative time. With an absolute time the game could compute tick = start + n × 100 and skip missed ones. Proposal: `ClockMsg` gets `At` beside `After`, and `Now`. These are not three variants of the same thing: relative, absolute, and read.

**5. Randomness as state worked.** `seed` is a field in `World`, `refill` threads it. No `{Random}` was missed. The price is the field and that every function that draws randomness returns the new seed. It is also what makes the game deterministic given a seed, a property that `{Random}` with a handler provides and Ernest provides for free.

**6. `Sys` is fixed.** Keys are not in the report's `Sys`, so the program assumes a field `keys`. That means `Sys` cannot be a fixed list in the report: every runtime has its system processes, and a program that needs one that does not exist should get a type error at `main`, not an empty mailbox. Proposal: `Sys` is the runtime's type, not the report's; the report requires only that `main` takes it and that `stdout` and `clock` exist.

**7. Players as processes or as ids.** The players in the world are data with ids; the player processes are only translators from key to `Input`. The alternative, one process per player owning its snake, would have made `step` a protocol with one message per player per tick and a wait for all replies. That is the design the report leads toward ("state lives in processes") and it is wrong here: the world is a value updated in one step, and one process per player is parallelism nobody asked for. It should be recorded as an example of when a value is right and a process wrong.

**8. What did not chafe.** Named fields with `..` carried the whole program; `Player(..p, dir = d)` is exactly what one wants to write. Positional `Pos` would have been wrong; `Pos(x = 3, y = 4)` reads. `if` was dropped for a day and brought back; the only thing left of the attempt is that the two `if`s in `movePlayer` that changed `body` and `score` on the same condition became one `if` with a tuple, which is better. `recv` as a form made `game` four lines. That `render` is sent as one `Line` per frame is crude but right for a terminal.

**9. Arithmetic on the board.** With `Nat` and no `-`, `move` needed a `pred` with 0 as floor; when `Nat` was dropped for a single `Int`, subtraction came back and `pred` went. For an hour `%` on `Int` did not exist and `wrap` unwrapped `Int.mod`'s `Optional` with 0 as floor; then `/` and `%` returned as the one deliberate exception to the total prelude, faulting on zero. `move` is now four lines of arithmetic, and a board with `w = 0` kills the game process with `Fault("division by zero")`, which is the right fate for it.

## Adopted into the Report

- Definitions as bindings in blocks (finding 2); closes `where`. Adopted.
- `ClockMsg`: `After`, `At`, `Now` (finding 4). Adopted.
- `Sys` is the runtime's type; the report requires `stdout` and `clock` (finding 6). Adopted.
- The value-versus-process criterion (finding 7), under opaque types. Adopted.
- Under Later in the decision log, local state: the accumulator as a named type when the tuple grows (finding 1). `let mut` was not needed. Adopted.
- The code transferred to syntax revision 3 and to the grammar audit: single `Int`, named fields in parentheses, `let`.
