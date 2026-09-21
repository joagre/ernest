%% A diagnostic, report §11.5: what every stage reports and ern_diag renders.
-ifndef(ERN_DIAG_HRL).
-define(ERN_DIAG_HRL, true).

-record(diag, {span, message, labels = [], help, incomplete = false,
               expected = undefined}).
%% span: ern_diag:span(), the primary span; message: string(), the first
%% line; labels: [{ern_diag:span(), string()}], secondary spans the message
%% depends on, each with its label; help: string() | undefined, the one line
%% naming the fix; incomplete: true where more input could finish what was
%% read, which the shell takes another line for (report §11.2) and nothing
%% else reads; expected: what the parser wanted where it stopped,
%% `expression`, `typename`, `pattern`, `declaration` or `{field, Con}`,
%% which completion reads to know what may stand at the cursor (§11.2)
%% and which is `undefined` everywhere else

-endif.
