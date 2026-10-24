%% Report §2.2: a fenced code block of a doc block's CommonMark, as
%% ern_parser:fenced/1 finds it, which the formatter and `ern test` read
%% too: the first word of its info string, its language, `ernest` for an
%% example; the spaces before its opening fence; its opening line, its
%% content's lines and its closing line as written, the closing none where
%% the text ends first; and its content's lines without up to as many
%% spaces before each as the opening fence had.

-ifndef(ERN_FENCE_HRL).
-define(ERN_FENCE_HRL, true).

-record(fence, {language, indent, opening, lines, closing, content}).

-endif.
