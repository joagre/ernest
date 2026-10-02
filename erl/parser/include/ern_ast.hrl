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

%% DeclName: name is an ident or a userop atom; owner is the typename prefix
%% of a type member (`fn Distance.+`), else undefined.

-record(module_doc, {span, text}). % the module's doc block, first in the list, report §2.2
-record(type_declaration, {span, doc, export = false, name, params = [], constructors}).
-record(constructor, {span, doc, name, fields = none}).
%% fields: none | {positional, Type} | {named, [#field{}]}
-record(field, {span, doc, name, annotation}).

-record(abstract_declaration, {span, doc, export = false, declaration}).
%% declaration: the #type_declaration{} whose constructors its module keeps
%% (report §4.4)

-record(fn_declaration, {span, doc, export = false, owner, name, params, result_type, effect,
                         body, scheme}).
%% result_type/effect: the annotation; result_type = undefined means none,
%% result_type given with effect = undefined means pure. scheme: set by the
%% checker.
-record(param, {span, pattern, annotation}).
%% annotation: the type written, or undefined where there is none

-record(let_declaration, {span, doc, export = false, name, annotation, body, scheme}).
%% annotation: the type written, or undefined; scheme: set by the checker

-record(foreign_type_declaration, {span, doc, export = false, name, params = [],
                                   equality = []}).
%% equality: the parameters written `k=`, which require equality (report §4.7)
-record(foreign_fn_declaration, {span, doc, export = false, owner, name, params, result_type,
                                 effect, implementation, implementation_span, scheme}).
%% scheme: set by the checker, as on fn_declaration; implementation_span:
%% where the implementation's string stands, for its diagnostics (report
%% §11.5)

%%
%% Types (syntactic)
%%

-record(t_named, {span, path = [], name, args = []}).
-record(t_var, {span, name}).
-record(t_tuple, {span, elements}).
-record(t_fn, {span, params, result_type, effect}).
%% effect = undefined means pure.

%%
%% Expressions
%%

-record(e_literal, {span, kind, value, type}).
%% kind: int | float | char | string | bool
-record(e_var, {span, path = [], name, referent, type}).
%% referent, which the checker sets (report §4.2): var, a name bound around
%% it; #own_declaration{}, this module's declaration; #remote_declaration{},
%% another module's, the two of typer/include/ern_types.hrl; {prelude,
%% QualifiedName}. A qualified function, operator, or value: path is the
%% typename prefix.
-record(e_constructor, {span, path = [], name, args = none, type}).
%% args: none | {positional, Expr} | {named, Base | undefined, [#field_set{}]}
-record(field_set, {span, name, expr}).
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
%% before a callee that is not a name (report §5.1)
-record(e_selection, {span, expr, field, field_span, type}).
%% expr.field, report §3.5; field_span: where the selector stands, where
%% its errors are reported (report §11.5)
-record(e_negation, {span, expr, type}).
-record(e_not, {span, expr, type}).
-record(e_binop, {span, operator, left, right, type}).
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
-record(p_constructor, {span, path = [], name, args = none, type}).
%% args: none | {positional, Pattern} | {named, [#field_pattern{}]}
-record(field_pattern, {span, name, pattern}).
-record(p_tuple, {span, elements, type}).
-record(p_list, {span, elements, type}).
-record(p_cons, {span, head, tail, type}).
%% name_span is where the name after `as` stands, span where the pattern does
-record(p_as, {span, pattern, name, type, name_span}).
-record(p_or, {span, alternatives, type}). % alternatives of a clause, report §5.9
-record(p_bitstring, {span, segments, type}).

-endif.
