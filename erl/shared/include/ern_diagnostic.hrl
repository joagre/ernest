%% A diagnostic, report §11.5: what every stage reports and ern_diagnostic renders.
-ifndef(ERN_DIAGNOSTIC_HRL).
-define(ERN_DIAGNOSTIC_HRL, true).

-record(diagnostic, {span, message, labels = [], help, incomplete = false,
                     expected = undefined, within = undefined, unknown_namespace = undefined,
                     unknown_name = undefined}).
%% span: ern_diagnostic:span(), the primary span.
%% message: string(), the first line.
%% labels: [{ern_diagnostic:span(), string()}], the secondary spans the message
%%   depends on, each with its label.
%% help: string() | undefined, the one line naming the fix.
%% incomplete: true where more input could finish what was read; the shell
%%   takes another line for it (report §11.2), and nothing else reads it.
%% expected: what the parser wanted where it stopped, for completion to know
%%   what may stand at the cursor (§11.2): `expression`, `typename`,
%%   `pattern`, `declaration`, or an #expected_field{}; `undefined` for
%%   every other failure.
%% within: the innermost call or constructor the input stops inside, an
%%   #enclosing{}, for `Shift-Tab` (§11.2); `undefined` outside both.
%% unknown_namespace: the namespace of a qualified name that names nothing
%%   in scope, for the shell to name the `:load` that would put it there
%%   (§11.2), and nothing else reads it; `undefined` for every other failure.
%% unknown_name: an unqualified name that names nothing, for the shell to say
%%   when a reload forgot it (§11.2), and nothing else reads it; `undefined`
%%   for every other failure.

%% Where a constructor's field's name stands, kind `field`; or where its
%% first argument would stand and could be a field's name or a value,
%% `field_or_value`, or a field's name or a pattern, `field_or_pattern`.
%% namespace is the one the constructor is written with (report §4.2),
%% and constructor_name the name it is written with.
-record(expected_field, {kind, namespace, constructor_name, segments = []}).
%% segments: in a record update, the segments of a path typed before the
%% cursor, whose last the fields completed are the type's reached (§5.6)

%% A call or a constructor the input stops inside, by the namespace and
%% the name written. argument: for a call, the index of the argument at the
%% cursor; for a constructor, that index, `{field, F}` in a named field's
%% value, or `none` where a field's name stands.
-record(enclosing, {namespace, name, argument}).

-endif.
