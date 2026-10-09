%% A definition as the `.erc` records it beside its canonical form (report
%% §8.7, §11.1, Appendix H), which ern_canonical makes and reads.

-ifndef(ERN_CANONICAL_HRL).
-define(ERN_CANONICAL_HRL, true).

-record(definition, {qualified_name, kind, hash, form, group = none}).
%% kind: function, binding or type; hash: the definition's hash, the 32
%% bytes of its SHA-256; form: its canonical form, a reference to a member
%% of its own group by position; group: none, or {GroupHash, Position}
%% where it is a member of a mutually recursive group, whose forms in
%% source order its hash is taken of

-endif.
