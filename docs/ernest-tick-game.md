# Paper Program 3: Tick Game

Written against the Ernest report, September 2026. A multiplayer snake game in the terminal: the world is updated ten times per second, players send directions between ticks, apples appear at random, scores are counted. The aim is to hit local state in pure code, time drift, input faster than ticks, and randomness in pure code through a threaded seed rather than a hidden source.

## Assumptions

The report requires `Sys.stdout` and `Sys.clock` (§8); keys are the runtime's addition. Assumed:

```
type KeyMsg = Subscribe(Address(Key))
type Key = Up | Down | Left | Right | Quit

Sys.keys : Address(KeyMsg) // additional runtime reference
```

`type Seed = Seed(Int)` and `Random.next : (Seed) -> #(Int, Seed)` are assumed available (a stdlib `Random` module), a pure generator.

## The Program

```
//
// Types
//

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

type GameMsg = Tick | In(Input)

//
// Program
//

fn main() -> Void with Void = {
    let world0 = World(w = 40, h = 20, players = Map.empty, apples = [], seed = Seed(42), tick = 0);
    let g = spawn(Local, fn() = game(addPlayer(world0, 1)));
    let p1 = spawn(Local, fn() = player(1, g));
    send(Sys.keys, Subscribe(p1))
}

//
// Processes
//

fn game(world : World) -> Void with GameMsg = {
    send(Sys.clock, After(ms = 100, to = via(fn(_) = Tick, self())));
    receive {
        Tick -> {
            let world2 = step(drain(world, 64));
            Io.print(render(world2));
            game(world2)
        }
    }
}

// Drain the mailbox of input without blocking; at most n per tick.
fn drain(world : World, n : Int) -> World with GameMsg =
    if n == 0 then world
    else receive {
        In(i) -> drain(applyInput(world, i), n - 1)
      | after 0 -> world
    }

// One process per player: translates keys into Input.
fn player(id : Int, game : Address(GameMsg)) -> Void with Key = receive {
    Up -> { send(game, In(Turn(id = id, dir = N))); player(id, game) }
  | Down -> { send(game, In(Turn(id = id, dir = S))); player(id, game) }
  | Left -> { send(game, In(Turn(id = id, dir = W))); player(id, game) }
  | Right -> { send(game, In(Turn(id = id, dir = E))); player(id, game) }
  | Quit -> send(game, In(Leave(id)))
}

//
// Pure world logic
//

// One tick: move everyone, eat apples, collide, refill apples.
// Three counters change: score per player, apples left, tick.
fn step(world : World) -> World = {
    let World(w = w, h = h, players = ps, apples = apples, seed = seed, tick = t) = world;
    fn movePlayer(#(acc, apples), _, p) = match p {
        Player(alive = false) -> #(acc, apples)
      | Player(body = head :: rest, dir = d, score = s) -> {
            let next = move(w, h, head, d);
            let ate = List.contains(apples, next);
            let #(body, s2) = if ate then #(next :: head :: rest, s + 1)
                             else #(next :: head :: List.dropLast(rest), s);
            let p2 = Player(..p, body = body, score = s2);
            #(Map.put(acc, Player.id(p), p2), List.remove(apples, next))
        }
      | Player(body = []) -> #(acc, apples)
    };
    let #(ps2, apples2) = Map.foldLeft(ps, #(ps, apples), movePlayer);
    let ps3 = Map.map(ps2, fn(_, p) = collide(ps2, p));
    let #(apples3, seed2) = refill(w, h, Map.size(ps3), apples2, seed);
    World(..world, players = ps3, apples = apples3, seed = seed2, tick = t + 1)
}

fn applyInput(world : World, input : Input) -> World = {
    let World(players = ps) = world;
    match input {
        Turn(id = id, dir = d) -> match Map.get(ps, id) {
            Some(p) -> World(..world, players = Map.put(ps, id, turn(p, d)))
          | None -> world
        }
      | Leave(id) -> World(..world, players = Map.remove(ps, id))
    }
}

fn collide(ps : Map(Int, Player), p : Player) -> Player = match p {
    Player(body = head :: _, alive = true) ->
        if List.any(Map.values(ps), fn(q) = List.contains(tailOf(q), head))
        then Player(..p, alive = false) else p
  | _ -> p
}

fn refill(w : Int, h : Int, want : Int, apples : List(Pos), seed : Seed) -> #(List(Pos), Seed) =
    if List.size(apples) >= want then #(apples, seed)
    else {
        let #(rx, s1) = Random.next(seed);
        let #(ry, s2) = Random.next(s1);
        refill(w, h, want, Pos(x = rx % w, y = ry % h) :: apples, s2)
    }

fn addPlayer(world : World, id : Int) -> World = todo("add a player at a random free position")

fn render(world : World) -> String = todo("grid to text, one line per y")

//
// Small helpers
//

fn move(w : Int, h : Int, Pos(x = x, y = y) : Pos, d : Dir) -> Pos = match d {
    N -> Pos(x = x, y = (y - 1) % h)
  | S -> Pos(x = x, y = (y + 1) % h)
  | W -> Pos(x = (x - 1) % w, y = y)
  | E -> Pos(x = (x + 1) % w, y = y)
}

fn turn(p : Player, d : Dir) -> Player = match #(Player.dir(p), d) {
    #(N, S) -> p | #(S, N) -> p | #(W, E) -> p | #(E, W) -> p // no U-turn
  | _ -> Player(..p, dir = d)
}

fn Player.dir(Player(dir = d) : Player) -> Dir = d
fn Player.id(Player(id = i) : Player) -> Int = i

fn tailOf(Player(body = b) : Player) -> List(Pos) = match b { _ :: rest -> rest | [] -> [] }
```
