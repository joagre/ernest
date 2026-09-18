%% The prelude, report section 9, and the standard library signatures of
%% Appendix E, as data. Types are Ernest source, the standard library's
%% under their namespaces; values are name and type text, parsed by
%% ern_parser:parse_type/1 and converted by the checker.
%% The stdlib entries are here until the stdlib exists as compiled modules
%% with interfaces of their own (implementation plan, Phase 2.4).
-module(ern_prelude).

-export([builtin_types/0, declared_types/0, stdlib_types/0, values/0, process_only/0,
         eq_vars/1]).

%% Types the runtime provides with no Ernest declaration: name and arity.
-spec builtin_types() -> [{atom(), non_neg_integer()}].
builtin_types() ->
    [{'Int', 0}, {'Float', 0}, {'Char', 0}, {'String', 0}, {'Bytes', 0}, {'Bool', 0},
     {'Address', 1}, {'Reply', 1}, {'Never', 0}, {'Foreign', 0},
     {'List', 1}, {'Map', 2}, {'Set', 1}].

%% Report §9.3.
-spec declared_types() -> string().
declared_types() ->
    "type Unit = Unit\n"
    "type Optional(a) = None | Some(a)\n"
    "type Either(e, a) = Left(e) | Right(a)\n"
    "type Ordering = Less | Equal | Greater\n"
    "type Down = Down(reason : Reason, function : String)\n"
    "type Reason = Returned | Killed | ProgramEnd | Fault(String)\n"
    "type ClockMsg = After(ms : Int, to : Address(Unit)) | At(at : Int, to : Address(Unit))"
    " | Now(reply : Reply(Int))\n"
    "type RemoteError = NoRemotePeer | PeerLost\n"
    "type Where = Local | Peer(String)\n".

%% Types the standard library declares, by namespace (Appendix E.13).
-spec stdlib_types() -> [{[atom()], string()}].
stdlib_types() ->
    [{['Random'], "type Seed = Seed(Int)\n"}].

%% Primitives whose effect variables are process-only (report §3.9), and the
%% Io functions, which are built on send.
-spec process_only() -> [[atom()]].
process_only() ->
    [[send], [spawn], ['Address', call], ['Address', callForever], [answer], [monitor],
     [kill], [remote], [parallelRemote],
     ['Io', print], ['Io', println], ['Io', printTo], ['Io', printlnTo]].

%% Type variables that carry the equality constraint (report §3.10): Map
%% keys, Set elements, and the List functions that compare elements.
-spec eq_vars([atom()]) -> [atom()].
eq_vars(['Map' | _]) -> [k];
eq_vars(['Set', map]) -> [a, b];
eq_vars(['Set', filterMap]) -> [a, b];
eq_vars(['Set' | _]) -> [a];
eq_vars(['List', contains]) -> [a];
eq_vars(['List', remove]) -> [a];
eq_vars(_) -> [].

%% Qualified name and type text.
-spec values() -> [{[atom()], string()}].
values() ->
    [%% §9.4 built-in functions
     {[self], "() -> Address(m) with m"},
     {[send], "(Address(a), a) -> Unit with m"},
     {[spawn], "(Where, () -> Unit with n) -> Address(n) with m"},
     %% §9.5 process functions
     {[via], "((a) -> b, Address(b)) -> Address(a)"},
     {['Address', call], "(Address(m), (Reply(a)) -> m, Int) -> Optional(a) with n"},
     {['Address', callForever], "(Address(m), (Reply(a)) -> m) -> a with n"},
     {[answer], "(Reply(a), a) -> Unit with m"},
     {[remote], "(() -> a) -> Either(RemoteError, a) with m"},
     {[parallelRemote], "(List(() -> a)) -> List(Either(RemoteError, a)) with m"},
     {[monitor], "(Address(a), (Down) -> m) -> Unit with m"},
     {[kill], "(Address(a)) -> Unit with m"},
     %% §9.6 operations required by the language
     {['Int', '+'], "(Int, Int) -> Int"},
     {['Int', '-'], "(Int, Int) -> Int"},
     {['Int', '*'], "(Int, Int) -> Int"},
     {['Int', '/'], "(Int, Int) -> Int"},
     {['Int', '%'], "(Int, Int) -> Int"},
     {['Int', negate], "(Int) -> Int"},
     {['Float', '+'], "(Float, Float) -> Float"},
     {['Float', '-'], "(Float, Float) -> Float"},
     {['Float', '*'], "(Float, Float) -> Float"},
     {['Float', '/'], "(Float, Float) -> Float"},
     {['Float', negate], "(Float) -> Float"},
     {['String', '<>'], "(String, String) -> String"},
     {['List', '<>'], "(List(a), List(a)) -> List(a)"},
     {['Bytes', '<>'], "(Bytes, Bytes) -> Bytes"},
     {['Int', 'div'], "(Int, Int) -> Optional(Int)"},
     {['Int', 'mod'], "(Int, Int) -> Optional(Int)"},
     {['Int', compare], "(Int, Int) -> Ordering"},
     {['Float', compare], "(Float, Float) -> Ordering"},
     {['String', compare], "(String, String) -> Ordering"},
     {['Char', compare], "(Char, Char) -> Ordering"},
     {[todo], "(String) -> a"},
     %% §9.7 system references
     {['Sys', stdout], "Address(String)"},
     {['Sys', clock], "Address(ClockMsg)"},
     %% Appendix E.1 Io
     {['Io', print], "(String) -> Unit with m"},
     {['Io', println], "(String) -> Unit with m"},
     {['Io', printTo], "(String, Address(String)) -> Unit with m"},
     {['Io', printlnTo], "(String, Address(String)) -> Unit with m"},
     %% E.2 List
     {['List', size], "(List(a)) -> Int"},
     {['List', isEmpty], "(List(a)) -> Bool"},
     {['List', get], "(List(a), Int) -> Optional(a)"},
     {['List', last], "(List(a)) -> Optional(a)"},
     {['List', reverse], "(List(a)) -> List(a)"},
     {['List', take], "(List(a), Int) -> List(a)"},
     {['List', drop], "(List(a), Int) -> List(a)"},
     {['List', dropLast], "(List(a)) -> List(a)"},
     {['List', contains], "(List(a), a) -> Bool"},
     {['List', find], "(List(a), (a) -> Bool with e) -> Optional(a) with e"},
     {['List', any], "(List(a), (a) -> Bool with e) -> Bool with e"},
     {['List', all], "(List(a), (a) -> Bool with e) -> Bool with e"},
     {['List', map], "(List(a), (a) -> b with e) -> List(b) with e"},
     {['List', filter], "(List(a), (a) -> Bool with e) -> List(a) with e"},
     {['List', filterMap], "(List(a), (a) -> Optional(b) with e) -> List(b) with e"},
     {['List', foldLeft], "(List(a), b, (b, a) -> b with e) -> b with e"},
     {['List', foreach], "(List(a), (a) -> Unit with e) -> Unit with e"},
     {['List', span], "(List(a), (a) -> Bool with e) -> #(List(a), List(a)) with e"},
     {['List', sort], "(List(a), (a, a) -> Ordering with e) -> List(a) with e"},
     {['List', remove], "(List(a), a) -> List(a)"},
     {['List', zip], "(List(a), List(b)) -> List(#(a, b))"},
     {['List', flatMap], "(List(a), (a) -> List(b) with e) -> List(b) with e"},
     {['List', range], "(Int, Int) -> List(Int)"},
     %% E.3 Map
     {['Map', empty], "Map(k, v)"},
     {['Map', size], "(Map(k, v)) -> Int"},
     {['Map', isEmpty], "(Map(k, v)) -> Bool"},
     {['Map', contains], "(Map(k, v), k) -> Bool"},
     {['Map', get], "(Map(k, v), k) -> Optional(v)"},
     {['Map', put], "(Map(k, v), k, v) -> Map(k, v)"},
     {['Map', remove], "(Map(k, v), k) -> Map(k, v)"},
     {['Map', keys], "(Map(k, v)) -> List(k)"},
     {['Map', values], "(Map(k, v)) -> List(v)"},
     {['Map', map], "(Map(k, v), (k, v) -> w with e) -> Map(k, w) with e"},
     {['Map', filter], "(Map(k, v), (k, v) -> Bool with e) -> Map(k, v) with e"},
     {['Map', filterMap], "(Map(k, v), (k, v) -> Optional(w) with e) -> Map(k, w) with e"},
     {['Map', foreach], "(Map(k, v), (k, v) -> Unit with e) -> Unit with e"},
     {['Map', foldLeft], "(Map(k, v), b, (b, k, v) -> b with e) -> b with e"},
     {['Map', any], "(Map(k, v), (k, v) -> Bool with e) -> Bool with e"},
     {['Map', all], "(Map(k, v), (k, v) -> Bool with e) -> Bool with e"},
     {['Map', find], "(Map(k, v), (k, v) -> Bool with e) -> Optional(#(k, v)) with e"},
     {['Map', fromList], "(List(#(k, v))) -> Map(k, v)"},
     {['Map', toList], "(Map(k, v)) -> List(#(k, v))"},
     %% E.4 Set
     {['Set', empty], "Set(a)"},
     {['Set', size], "(Set(a)) -> Int"},
     {['Set', isEmpty], "(Set(a)) -> Bool"},
     {['Set', contains], "(Set(a), a) -> Bool"},
     {['Set', put], "(Set(a), a) -> Set(a)"},
     {['Set', remove], "(Set(a), a) -> Set(a)"},
     {['Set', union], "(Set(a), Set(a)) -> Set(a)"},
     {['Set', intersect], "(Set(a), Set(a)) -> Set(a)"},
     {['Set', difference], "(Set(a), Set(a)) -> Set(a)"},
     {['Set', fromList], "(List(a)) -> Set(a)"},
     {['Set', toList], "(Set(a)) -> List(a)"},
     {['Set', map], "(Set(a), (a) -> b with e) -> Set(b) with e"},
     {['Set', filter], "(Set(a), (a) -> Bool with e) -> Set(a) with e"},
     {['Set', filterMap], "(Set(a), (a) -> Optional(b) with e) -> Set(b) with e"},
     {['Set', foreach], "(Set(a), (a) -> Unit with e) -> Unit with e"},
     {['Set', foldLeft], "(Set(a), b, (b, a) -> b with e) -> b with e"},
     {['Set', any], "(Set(a), (a) -> Bool with e) -> Bool with e"},
     {['Set', all], "(Set(a), (a) -> Bool with e) -> Bool with e"},
     {['Set', find], "(Set(a), (a) -> Bool with e) -> Optional(a) with e"},
     %% E.5 String
     {['String', size], "(String) -> Int"},
     {['String', isEmpty], "(String) -> Bool"},
     {['String', contains], "(String, String) -> Bool"},
     {['String', trim], "(String) -> String"},
     {['String', toLower], "(String) -> String"},
     {['String', toUpper], "(String) -> String"},
     {['String', toInt], "(String) -> Optional(Int)"},
     {['String', toFloat], "(String) -> Optional(Float)"},
     {['String', toBool], "(String) -> Optional(Bool)"},
     {['String', toList], "(String) -> List(Char)"},
     {['String', fromList], "(List(Char)) -> String"},
     {['String', fromUtf8], "(Bytes) -> Optional(String)"},
     {['String', toUtf8], "(String) -> Bytes"},
     {['String', lines], "(String) -> List(String)"},
     {['String', split], "(String, String) -> List(String)"},
     {['String', join], "(List(String), String) -> String"},
     {['String', any], "(String, (Char) -> Bool with e) -> Bool with e"},
     {['String', all], "(String, (Char) -> Bool with e) -> Bool with e"},
     %% E.6 Char
     {['Char', isDigit], "(Char) -> Bool"},
     {['Char', isAlpha], "(Char) -> Bool"},
     {['Char', isSpace], "(Char) -> Bool"},
     {['Char', toString], "(Char) -> String"},
     {['Char', toInt], "(Char) -> Int"},
     {['Char', fromInt], "(Int) -> Optional(Char)"},
     %% E.7 Bool
     {['Bool', 'not'], "(Bool) -> Bool"},
     {['Bool', toString], "(Bool) -> String"},
     %% E.8 Int
     {['Int', abs], "(Int) -> Int"},
     {['Int', min], "(Int, Int) -> Int"},
     {['Int', max], "(Int, Int) -> Int"},
     {['Int', bitAnd], "(Int, Int) -> Int"},
     {['Int', bitOr], "(Int, Int) -> Int"},
     {['Int', bitXor], "(Int, Int) -> Int"},
     {['Int', bitNot], "(Int) -> Int"},
     {['Int', shiftLeft], "(Int, Int) -> Int"},
     {['Int', shiftRight], "(Int, Int) -> Int"},
     {['Int', toString], "(Int) -> String"},
     {['Int', toFloat], "(Int) -> Float"},
     %% E.9 Float
     {['Float', abs], "(Float) -> Float"},
     {['Float', min], "(Float, Float) -> Float"},
     {['Float', max], "(Float, Float) -> Float"},
     {['Float', toString], "(Float) -> String"},
     {['Float', round], "(Float) -> Int"},
     {['Float', floor], "(Float) -> Int"},
     {['Float', ceil], "(Float) -> Int"},
     %% E.10 Optional
     {['Optional', isSome], "(Optional(a)) -> Bool"},
     {['Optional', isNone], "(Optional(a)) -> Bool"},
     {['Optional', withDefault], "(Optional(a), a) -> a"},
     {['Optional', map], "(Optional(a), (a) -> b with e) -> Optional(b) with e"},
     {['Optional', andThen], "(Optional(a), (a) -> Optional(b) with e) -> Optional(b) with e"},
     %% E.11 Either
     {['Either', isLeft], "(Either(e, a)) -> Bool"},
     {['Either', isRight], "(Either(e, a)) -> Bool"},
     {['Either', withDefault], "(Either(e, a), a) -> a"},
     {['Either', map], "(Either(e, a), (a) -> b with x) -> Either(e, b) with x"},
     {['Either', mapLeft], "(Either(e, a), (e) -> f with x) -> Either(f, a) with x"},
     {['Either', andThen], "(Either(e, a), (a) -> Either(e, b) with x) -> Either(e, b) with x"},
     {['Either', toOptional], "(Either(e, a)) -> Optional(a)"},
     {['Either', fromOptional], "(Optional(a), e) -> Either(e, a)"},
     %% E.12 Foreign
     {['Foreign', toInt], "(Foreign) -> Optional(Int)"},
     {['Foreign', toFloat], "(Foreign) -> Optional(Float)"},
     {['Foreign', toString], "(Foreign) -> Optional(String)"},
     {['Foreign', toBool], "(Foreign) -> Optional(Bool)"},
     {['Foreign', toList], "(Foreign) -> Optional(List(Foreign))"},
     %% E.13 Random
     {['Random', next], "(Random.Seed, Int) -> #(Int, Random.Seed)"}].
