%% Ernest AST, one record per production of report Appendix A. Every node
%% carries pos :: ern_lexer:pos(). Expressions and patterns carry
%% type = undefined, which the type checker fills in; declarations carry
%% doc and the export flag. The parser builds these untyped.
%%
%% Two rewrites happen in the parser: parentheses produce no node, and
%% `x |> f(a)` becomes the call `f(x, a)` (report §5.7).

-ifndef(ERN_AST_HRL).
-define(ERN_AST_HRL, true).

%%
%% Declarations
%%

%% DeclName: name is an ident or a userop atom; owner is the typename prefix
%% of a type member (`fn Stack.push`), else undefined.

-record(type_decl, {pos, doc, export = false, name, params = [], constructors}).
-record(constructor, {pos, name, fields = none}).
%% fields: none | {positional, Type} | {named, [#field{}]}
-record(field, {pos, name, type}).

-record(abstract_decl, {pos, doc, export = false, type, signatures}).
-record(signature, {pos, name, type}).

-record(fn_decl, {pos, doc, export = false, owner, name, params, ret, effect, body,
                  type}).
%% ret/effect: the annotation; ret = undefined means none, ret given with
%% effect = undefined means pure.
-record(param, {pos, pattern, type}).

-record(let_decl, {pos, doc, export = false, owner, name, ann, body, type}).

-record(foreign_type_decl, {pos, doc, export = false, name, params = []}).
-record(foreign_fn_decl, {pos, doc, export = false, owner, name, params, ret, effect,
                          impl}).

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
%% spec(): {size, Expr} | {unit, integer()} | bits | bytes | int | float
%%       | utf8 | utf16 | utf32 | big | little | native | signed | unsigned
-record(e_block, {pos, stmts, type}).
%% stmts: [#fn_decl{} | #binding{} | Expr], the last an Expr
-record(binding, {pos, pattern, ann, op, expr}).
%% op: '=' | '<-'
-record(e_call, {pos, callee, args, type}).
-record(e_neg, {pos, expr, type}).
-record(e_binop, {pos, op, left, right, type}).
-record(e_lambda, {pos, params, ret, effect, body, type}).
-record(e_if, {pos, condition, then_branch, else_branch, type}).
-record(e_match, {pos, scrutinee, clauses, type}).
-record(clause, {pos, pattern, guard, body}).
-record(e_receive, {pos, clauses, 'after', type}).
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
-record(p_bits, {pos, segments, type}).

-endif.
