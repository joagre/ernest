%% A diagnostic, report §11.5: what every stage reports and ern_diag renders.
-ifndef(ERN_DIAG_HRL).
-define(ERN_DIAG_HRL, true).

-record(diag, {span, message, labels = [], help}).
%% span: ern_diag:span(), the primary span; message: string(), the first
%% line; labels: [{ern_diag:span(), string()}], secondary spans the message
%% depends on, each with its label; help: string() | undefined, the one line
%% naming the fix

-endif.
