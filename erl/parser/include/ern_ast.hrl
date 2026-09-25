%% Ernest AST, one record per production of report Appendix A. Every node
%% carries pos :: ern_diag:span(), from its first token to the end of its
%% last (report §11.5). Expressions and patterns carry type = undefined,
%% their last field, which the type checker fills in; declarations carry
%% doc and the export flag. The parser builds these untyped.
%%
%% Two rewrites happen in the parser: parentheses produce no node, and
%% `x |> f(a)` becomes the call `f(x, a)` (report §5.7), marked as a pipe's.

-ifndef(ERN_AST_HRL).
-define(ERN_AST_HRL, true).

%%
%% Declarations
%%

%% DeclName: name is an ident or a userop atom; owner is the typename prefix
%% of a type member (`fn Stack.push`), else undefined.

-record(module_doc, {pos, text}). % the module's doc block, first in the list, report §2.2
-record(type_decl, {pos, doc, export = false, name, params = [], constructors}).
-record(constructor, {pos, doc, name, fields = none}).
%% fields: none | {positional, Type} | {named, [#field{}]}
-record(field, {pos, doc, name, type}).

-record(abstract_decl, {pos, doc, export = false, type}).
%% type: the #type_decl{} whose constructors its module keeps (report §4.4)

-record(fn_decl, {pos, doc, export = false, owner, name, params, ret, effect, body,
                  type}).
%% ret/effect: the annotation; ret = undefined means none, ret given with
%% effect = undefined means pure. type: the scheme, set by the checker.
-record(param, {pos, pattern, type}).
%% type: the annotation, or undefined where there is none

-record(let_decl, {pos, doc, export = false, owner, name, ann, body, type}).
%% ann: the annotation, or undefined; type: the scheme, set by the checker

-record(foreign_type_decl, {pos, doc, export = false, name, params = [], eq = []}).
%% eq: the parameters written `k=`, which require equality (report §4.7)
-record(foreign_fn_decl, {pos, doc, export = false, owner, name, params, ret, effect,
                          impl, type}).
%% type: the scheme, set by the checker, as on fn_decl

%%
%% Types (syntactic)
%%

-record(t_con, {pos, path = [], name, args = []}).
-record(t_var, {pos, name}).
-record(t_tuple, {pos, elems}).
-record(t_fn, {pos, params, ret, effect}).
%% effect = undefined means pure.

%%
%% Expressions
%%

-record(e_lit, {pos, kind, value, type}).
%% kind: int | float | char | string | bool
-record(e_var, {pos, path = [], name, type}).
%% a qualified function, operator, or value: path is the typename prefix
-record(e_con, {pos, path = [], name, args = none, type}).
%% args: none | {positional, Expr} | {named, Base | undefined, [#field_set{}]}
-record(field_set, {pos, name, expr}).
-record(e_tuple, {pos, elems, type}).
-record(e_list, {pos, elems, type}).
-record(e_bits, {pos, segments, type}).
-record(bit_seg, {pos, value, specs = []}).
%% value: an expression or, in a pattern, a pattern; specs: [spec()]
%% spec(): {size, Expr} | {unit, integer()} | bytes | int | float
%%       | utf8 | utf16 | utf32 | big | little | signed | unsigned
-record(e_block, {pos, stmts, type}).
%% stmts: [#fn_decl{} | #binding{} | Expr], the last an Expr
-record(binding, {pos, pattern, ann, op, expr}).
%% ann: the annotation, or undefined; op: '=' | '<-'
-record(e_call, {pos, callee, args, pipe = false, type}).
%% pipe: true when `x |> e` wrote it; x is the first argument, evaluated
%% before a callee that is not a name (report §5.1)
-record(e_select, {pos, expr, field, type}).
%% expr.field, report §3.5
-record(e_neg, {pos, expr, type}).
-record(e_not, {pos, expr, type}).
-record(e_binop, {pos, op, left, right, type}).
-record(e_lambda, {pos, params, ret, effect, body, type}).
%% ret/effect: as on fn_decl
-record(e_if, {pos, condition, then_branch, else_branch, type}).
-record(e_match, {pos, scrutinee, clauses, type}).
-record(clause, {pos, pattern, guard, body}).
%% guard: an expression, or undefined
-record(e_receive, {pos, clauses, 'after', type}).
%% 'after': an #after_clause{}, or undefined
-record(after_clause, {pos, timeout, body}).

%%
%% Patterns
%%

-record(p_wild, {pos, type}).
-record(p_var, {pos, name, type}).
-record(p_lit, {pos, kind, value, type}).
-record(p_con, {pos, path = [], name, args = none, type}).
%% args: none | {positional, Pattern} | {named, [#field_pat{}]}
-record(field_pat, {pos, name, pattern}).
-record(p_tuple, {pos, elems, type}).
-record(p_list, {pos, elems, type}).
-record(p_cons, {pos, head, tail, type}).
-record(p_as, {pos, pattern, name, type}).
-record(p_or, {pos, alts, type}). % alternatives of a clause, report §5.9
-record(p_bits, {pos, segments, type}).

-endif.
