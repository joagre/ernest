%% Semantic types for the Ernest type checker, report §3 and §6.1. These are
%% what inference computes and what the compiler reads off the AST; they are
%% distinct from the syntactic #t_con{}/#t_fn{} records the parser builds.
%%
%%   type() ::
%%       {tvar, id()}                    a unification variable
%%     | {tcon, qname(), [type()]}       a named type applied to arguments
%%     | {ttuple, [type()]}              #(A, B)
%%     | {tfn, [type()], effect(), type()}  (A, B) -> C with M
%%
%%   effect() :: pure | type()           the mailbox slot of an arrow; a type()
%%                                       here is a mailbox type or a variable
%%
%%   qname() :: [atom()]                 ['Int'], ['List'], ['Net', 'Http', 'Request']
%%
%% Every variable has an entry in the checker's variable table keyed by id().
%% The flags are the three inferred restrictions of report §3.9: `eq` (the
%% variable was compared with ==), `process_only` (it may not bind to pure),
%% `no_reply` (it may not be instantiated to a reply-carrying type). A bound
%% variable's binding lives in the substitution, not in the term, so a type
%% is read through ern_types:resolve/2 before inspection.
%%
%% A scheme quantifies variables together with their flags, which is what
%% makes the restrictions travel with a function value (report §3.9).

-ifndef(ERN_TYPES_HRL).
-define(ERN_TYPES_HRL, true).

-record(tv, {id, level, flags = [], name}).
%% level: the let-nesting depth at creation, for generalization; name: the
%% annotation's name for the variable, if any (report §11.5)

-record(scheme, {vars = [], type, names = #{}}).
%% vars: [{id(), flags()}]; a monomorphic type is a scheme with vars = [];
%% names: #{id() => atom()}, the annotation's names of quantified variables

%% What the checker knows about a declared type, from this module or a
%% compiled interface.
-record(tinfo, {qname, params = [], constructors = [], abstract = false,
                signature = [], foreign = false, reply_carrying = false}).
%% constructors: [#cinfo{}]; signature: [{name(), #scheme{}}] for an abstract
%% type; reply_carrying is computed transitively (report §6.6)

-record(cinfo, {name, qname, type_qname, fields = none, tag_arity, scheme}).
%% fields: none | positional | {named, [atom()]} in canonical (sorted) order;
%% scheme: the constructor as a value, quantified over the type's parameters:
%% the result type for a nullary constructor, else a pure function from the
%% field types (in canonical order) to the result type

%% The compiled interface of a module: what other modules see (report §4.2,
%% §11.1). Produced by the checker, consumed by the checker of a dependent
%% module and by the compiler.
-record(iface, {namespace, types = #{}, values = #{}, lets = []}).
%% lets: the qualified names among `values` that were declared with `let`,
%% which the emitter calls through their getter (report §4.6, §8.5)
%% namespace: qname(); types: #{qname() => #tinfo{}};
%% values: #{qname() => #scheme{}} for exported fn, let, and foreign fn

-endif.
