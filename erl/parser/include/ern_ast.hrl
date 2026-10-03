%% Ernest AST, one record per production of report Appendix A. Every node
%% carries span :: ern_diagnostic:span(), from its first token to the end
%% of its last (report §11.5). Expressions and patterns carry type =
%% undefined, their last field, which the type checker fills in with the
%% type it infers; declarations carry doc and the export flag. The parser
%% builds these untyped.
%%
%% Two rewrites happen in the parser: parentheses produce no node, and
%% `x |> f(a)` becomes the call `f(x, a)` (report §5.7), marked as a pipe's.

-ifndef(ERN_AST_HRL).
-define(ERN_AST_HRL, true).

%%
%% Declarations
%%

%% DeclName: name is an ident or a userop atom; member_of is the typename prefix
%% of a type member (`fn Distance.+`), else undefined.

-record(module_doc, {span, text}). % the module's doc block, first in the list, report §2.2
-record(type_declaration, {span, doc, export = false, name, params = [], constructors,
                           derives}).
%% derives: undefined, or the span of `derives compare`, which gives the type
%% the member compare (report §3.5)
-record(constructor, {span, doc, name, fields = none}).
%% fields: none | {positional, Type} | {named, [#field{}]}
-record(field, {span, doc, name, annotation}).

-record(abstract_declaration, {span, doc, export = false, declaration}).
%% declaration: the #type_declaration{} whose constructors its module keeps
%% (report §4.4)

-record(fn_declaration, {span, doc, export = false, member_of, name, params, result_type, effect,
                         requirement = [], body, scheme}).
%% result_type/effect: the annotation; result_type = undefined means none,
%% result_type given with effect = undefined means pure. requirement: the
%% #member{}s its `needs` names, report §4.9, [] where it has none. scheme:
%% set by the checker.
-record(member, {span, member_of, name, type}).
%% A member a requirement names, Appendix A's Member, `a.compare`:
%% member_of, the type variable's name; name, compare, negate, an operator
%% or show; type, set by the checker: the type variable the name stands for
%% in the signature.
-record(param, {span, pattern, annotation}).
%% annotation: the type written, or undefined where there is none

-record(let_declaration, {span, doc, export = false, name, annotation, body, scheme}).
%% annotation: the type written, or undefined; scheme: set by the checker

-record(foreign_type_declaration, {span, doc, export = false, name, params = [],
                                   equality = []}).
%% equality: for each parameter, whether it is written `k=` and requires equality
%% (report §4.7); [] where it has none
-record(foreign_fn_declaration, {span, doc, export = false, member_of, name, params, result_type,
                                 effect, implementation, implementation_span, scheme}).
%% scheme: set by the checker, as on fn_declaration; implementation_span:
%% where the implementation's string stands, for its diagnostics (report
%% §11.5)

%%
%% Types (syntactic)
%%

-record(t_named, {span, namespace = [], name, args = []}).
-record(t_var, {span, name}).
-record(t_tuple, {span, elements}).
-record(t_fn, {span, params, result_type, effect}).
%% effect = undefined means pure.

%%
%% Expressions
%%

-record(e_literal, {span, kind, value, type}).
%% kind: int | float | char | string | bool
-record(e_var, {span, namespace = [], name, referent, supplies = [], type}).
%% referent, which the checker sets (report §4.2): var, a name bound around
%% it; #own_declaration{}, this module's declaration; #remote_declaration{},
%% another module's, the two of typer/include/ern_types.hrl; {prelude,
%% QualifiedName}. A qualified function, operator, or value: namespace is
%% the name's prefix (report §4.2). supplies, which the checker sets: what the declaration's
%% requirement is supplied with at this use (report §4.9), and Io.show's or
%% Io.debug's descriptor (Appendix E.1), each a supply of ern_types.hrl.
-record(e_constructor, {span, namespace = [], name, base, args = none, type}).
%% base: the Expr of a record update's `..`, or undefined (report §5.6);
%% args: none | {positional, Expr} | {named, [#field_set{}]}
-record(field_set, {span, name, path = [], expr}).
%% path: in a record update, the segments after the name of a path to a
%% field of a field, `stats.indexed` being name stats and path [indexed]
%% (report §5.6); [] elsewhere
-record(e_tuple, {span, elements, type}).
-record(e_list, {span, elements, type}).
-record(e_bitstring, {span, segments, type}).
-record(bit_segment, {span, value, specs = []}).
%% value: an expression or, in a pattern, a pattern; specs: [spec()]
%% spec(): {size, Expr} | {unit, integer()} | bytes | int | float
%%       | utf8 | utf16 | utf32 | big | little | signed | unsigned
-record(e_block, {span, statements, type}).
%% statements: [#fn_declaration{} | #binding{} | Expr], the last an Expr
-record(binding, {span, pattern, annotation, operator, expr}).
%% annotation: the type written, or undefined; operator: '=' | '<-'
-record(e_call, {span, callee, args, pipe = false, returns = true, type}).
%% pipe: true when `x |> e` wrote it; x is the first argument, evaluated
%% before a callee that is not a name (report §5.1); returns: set by the
%% checker, false where the callee never returns, which the reply check
%% reads (report §6.6)
-record(e_selection, {span, expr, field, field_span, type}).
%% expr.field, report §3.5; field_span: where the selector stands, where
%% its errors are reported (report §11.5)
-record(e_negation, {span, expr, member, type}).
%% member, which the checker sets: the supply of the `negate` an operand of
%% a type with members resolves to (report §5.1, §4.9), undefined for Int
%% and Float
-record(e_not, {span, expr, type}).
-record(e_binop, {span, operator, left, right, member, type}).
%% member, which the checker sets: the supply of the member an arithmetic
%% or ordering operator resolves to (report §4.8, §4.9), undefined where the
%% operation is the runtime's own
-record(e_member, {span, member_of, name, supply, type}).
%% Report §4.9, Appendix A: `a.compare`, `a.negate` or `a.+`, the member of
%% the type variable member_of under a requirement; a derived compare
%% (§3.5) names a field's type, a #t_named{}, as member_of. supply: set by
%% the checker
-record(e_lambda, {span, params, result_type, effect, body, type}).
%% result_type/effect: as on fn_declaration
-record(e_if, {span, condition, then_branch, else_branch, type}).
-record(e_match, {span, scrutinee, clauses, type}).
-record(clause, {span, pattern, guard, body}).
%% guard: an expression, or undefined
-record(e_receive, {span, clauses, 'after', type}).
%% 'after': an #after_clause{}, or undefined
-record(after_clause, {span, timeout, body}).

%%
%% Patterns
%%

-record(p_wildcard, {span, type}).
-record(p_var, {span, name, type}).
-record(p_literal, {span, kind, value, type}).
-record(p_constructor, {span, namespace = [], name, args = none, type}).
%% args: none | {positional, Pattern} | {named, [#field_pattern{}]}
-record(field_pattern, {span, name, pattern}).
-record(p_tuple, {span, elements, type}).
-record(p_list, {span, elements, type}).
-record(p_cons, {span, head, tail, type}).
%% name_span is where the name after `as` stands, span where the pattern does
-record(p_as, {span, pattern, name, name_span, type}).
-record(p_or, {span, alternatives, type}). % alternatives of a clause, report §5.9
-record(p_bitstring, {span, segments, type}).

-endif.
