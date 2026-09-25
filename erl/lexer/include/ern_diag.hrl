%% A diagnostic, report §11.5: what every stage reports and ern_diag renders.
-ifndef(ERN_DIAG_HRL).
-define(ERN_DIAG_HRL, true).

-record(diag, {span, message, labels = [], help, incomplete = false,
               expected = undefined, within = undefined}).
%% span: ern_diag:span(), the primary span.
%% message: string(), the first line.
%% labels: [{ern_diag:span(), string()}], the secondary spans the message
%%   depends on, each with its label.
%% help: string() | undefined, the one line naming the fix.
%% incomplete: true where more input could finish what was read; the shell
%%   takes another line for it (report §11.2), and nothing else reads it.
%% expected: what the parser wanted where it stopped, for completion to know
%%   what may stand at the cursor (§11.2): `expression`, `typename`,
%%   `pattern`, `declaration`, `{field, Path, Con}` where a field's name of
%%   constructor Con stands, or `{field_or_value, Path, Con}` or
%%   `{field_or_pattern, Path, Con}` where Con's first argument would stand
%%   and could be either, Path being the qualifier Con is written with;
%%   `undefined` for every other failure.
%% within: the innermost call or constructor the input stops inside, for
%%   `Shift-Tab` (§11.2). For a call `{Path, Name, N}`, N the index of the
%%   argument at the cursor; for a constructor `{Path, Name, At}`, At the
%%   argument's index, `{field, F}` in a named field's value, or `none`
%%   where a field's name stands; `undefined` outside both.

-endif.
