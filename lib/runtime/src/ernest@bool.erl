%% Appendix E.7, namespace Bool, as an Erlang module for MVP 1.
-module('ernest@bool').

-export(['not'/1, toString/1]).

'not'(B) -> not B.
toString(true) -> <<"true">>;
toString(false) -> <<"false">>.
