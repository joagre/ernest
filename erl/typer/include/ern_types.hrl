%% Semantic types for the Ernest type checker, report §3 and §6.1. These are
%% what inference computes and what the compiler reads off the AST; they are
%% distinct from the syntactic #t_named{}/#t_fn{} records the parser builds.
%%
%%   type() ::
%%       {tvar, id()}                          a unification variable
%%     | {tcon, qualified_name(), [type()]}    a named type applied to arguments
%%     | {ttuple, [type()]}                    #(A, B)
%%     | {tfn, [type()], effect(), type()}     (A, B) -> C with M
%%
%%   effect() :: pure | type()     the mailbox slot of an arrow; a type()
%%                                 here is a mailbox type or a variable
%%
%%   qualified_name() :: [atom()]  ['Int'], ['List'], ['Net', 'Http', 'Request']
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

-record(scheme, {quantified = [], type, names = #{}, requirement = []}).
%% quantified: [{id(), restrictions()}]; a monomorphic type is a scheme with
%% quantified = []; names: #{id() => atom()}, the annotation's names of
%% quantified variables; requirement: a declaration's requirement (report
%% §4.9), [{id(), Member}] over its variables, which travels with its name
%% and no further: it is no part of the type, an instance has none, and a
%% value bound from the declaration has none

%% What a requirement is supplied with (report §4.9), which the checker
%% resolves once the enclosing definition is inferred and records in the
%% typed AST, and the emitter writes as an argument the program does not
%% write:
-record(known_member, {qualified_name, member, supplies = []}).
%% the member of a known type, `Int.compare`, its own requirement supplied
%% in turn (members supplying members)
-record(required_member, {variable, member}).
%% the member the enclosing declaration's requirement names at the type
%% variable, which the declaration was given
-record(shown_type, {type}).
%% `show` at a type known whole, written by its descriptor (Appendix E.1)
-record(pending_member, {span, type, member, need}).
%% before the enclosing definition ends: the member at the type, and what
%% needs it, for the error that names it (report §11.5)

%% What the checker knows about a declared type, from this module or a
%% compiled interface.
-record(type_info, {qualified_name, params = [], param_names = [], constructors = [],
                    abstract = false, foreign = false, reply_carrying = false,
                    equality = []}).
%% params: a type variable for each of the type's parameters, in order, of
%% every kind of type, a declared type's those its constructors' schemes
%% are over; param_names: the names a declaration writes for them, [] for
%% a built-in type
%% equality: for a foreign or built-in type, whether each parameter requires
%% equality, as `k=` declares it (report §4.7, §9.2); [] when none does
%% constructors: [#constructor_info{}]; reply_carrying is computed
%% transitively (report §6.6)

-record(constructor_info, {name, qualified_name, type_qualified_name, fields = none, tag_arity,
                           scheme}).
%% fields: none | positional | {named, [atom()]} in canonical (sorted) order;
%% scheme: the constructor as a value, quantified over the type's parameters:
%% the result type for a nullary constructor, else a pure function from the
%% field types (in canonical order) to the result type

%% The declaration a name refers to, which the checker records in its
%% #e_var{} for the emitter (report §4.2): this module's, member_of a type
%% or undefined, and another module's, in its namespace.
-record(own_declaration, {member_of, name}).
-record(remote_declaration, {namespace, member_of, name}).

%% The compiled interface of a module: what other modules see (report §4.2,
%% §11.1). Produced by the checker, consumed by the checker of a dependent
%% module and by the compiler.
-record(interface, {namespace, types = #{}, values = #{}, lets = [], private_types = #{}}).
%% private_types: the module's private types an exported abstract type's
%% fields name, and those theirs name, #{qualified_name() => #type_info{}}, by
%% which a dependent describes the abstract type's values (report §8.4,
%% §11.1) and which it cannot name (§4.2)
%% lets: the qualified names among `values` that were declared with `let`,
%% which the emitter calls through their getter (report §4.6, §8.5)
%% namespace: qualified_name(); types: #{qualified_name() => #type_info{}};
%% values: #{qualified_name() => #scheme{}} for exported fn, let, and foreign fn

-endif.
