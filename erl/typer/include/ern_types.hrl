%% Semantic types for the Ernest type checker, report §3 and §6.1. These are
%% what inference computes and what the compiler reads off the AST; they are
%% distinct from the syntactic #t_named{}/#t_fn{} records the parser builds.
%%
%%   type() ::
%%       {tvar, id()}                    a unification variable
%%     | {tcon, qualified_name(), [type()]}  a named type applied to arguments
%%     | {ttuple, [type()]}              #(A, B)
%%     | {tfn, [type()], effect(), type()}  (A, B) -> C with M
%%
%%   effect() :: pure | type()           the mailbox slot of an arrow; a type()
%%                                       here is a mailbox type or a variable
%%
%%   qualified_name() :: [atom()]        ['Int'], ['List'], ['Net', 'Http', 'Request']
%%
%% Every variable has an entry in the checker's variable table keyed by id().
%% Its restrictions are the three inferred restrictions of report §3.9:
%% `equality` (the variable was compared with ==), `process_only` (it may
%% not bind to pure), `not_reply_carrying` (it may not be instantiated to a
%% reply-carrying type). A bound variable's binding lives in the
%% substitution, not in the term, so a type is read through
%% ern_types:resolve/2 before inspection.
%%
%% A scheme quantifies variables together with their restrictions, which is
%% what makes the restrictions travel with a function value (report §3.9).

-ifndef(ERN_TYPES_HRL).
-define(ERN_TYPES_HRL, true).

-record(type_variable, {id, level, restrictions = [], name}).
%% level: the let-nesting depth at creation, for generalization; name: the
%% annotation's name for the variable, if any (report §11.5)

-record(scheme, {quantified = [], type, names = #{}}).
%% quantified: [{id(), restrictions()}]; a monomorphic type is a scheme with
%% quantified = []; names: #{id() => atom()}, the annotation's names of
%% quantified variables

%% What the checker knows about a declared type, from this module or a
%% compiled interface.
-record(type_info, {qualified_name, params = [], constructors = [], abstract = false,
                    signature = [], foreign = false, reply_carrying = false, equality = []}).
%% equality: for a foreign or built-in type, whether each parameter requires
%% equality, as `k=` declares it (report §4.7, §9.2); [] when none does
%% constructors: [#constructor_info{}]; signature: [{name(), #scheme{}}] for
%% an abstract type; reply_carrying is computed transitively (report §6.6)

-record(constructor_info, {name, qualified_name, type_qualified_name, fields = none, tag_arity,
                           scheme}).
%% fields: none | positional | {named, [atom()]} in canonical (sorted) order;
%% scheme: the constructor as a value, quantified over the type's parameters:
%% the result type for a nullary constructor, else a pure function from the
%% field types (in canonical order) to the result type

%% The compiled interface of a module: what other modules see (report §4.2,
%% §11.1). Produced by the checker, consumed by the checker of a dependent
%% module and by the compiler.
-record(interface, {namespace, types = #{}, values = #{}, lets = []}).
%% lets: the qualified names among `values` that were declared with `let`,
%% which the emitter calls through their getter (report §4.6, §8.5)
%% namespace: qualified_name(); types: #{qualified_name() => #type_info{}};
%% values: #{qualified_name() => #scheme{}} for exported fn, let, and foreign fn

-endif.
