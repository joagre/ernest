%% The primitive behind Uri.parse (report Appendix G.12). The host's
%% `uri_string:parse/1` reads RFC 3986's URI reference into a map that holds
%% a key only where the text writes its component, a term no Ernest type
%% describes; so the host's function is called here, and its map written as
%% `Uri.Reference`'s. The check of each `%`, which the host does not make,
%% is Ernest's, before the call.
-module(ern_uri).

-export([parse/1]).

-type optional(Value) :: {'Some', Value} | 'None'.
-type authority() :: {'Authority', optional(binary()), binary(), optional(non_neg_integer())}.
-type uri_reference() :: {'Reference', optional(binary()), optional(authority()), binary(),
                          optional(binary()), optional(binary())}.

%% Appendix G.12: the components the text writes, or None. The host answers
%% `{error, invalid_uri, Rest}` for a text it refuses. It raises on bytes
%% that are not UTF-8, which no `String` holds, and a probe of every code
%% point in each component found no other raise. A text with an
%% authority has a `host`, empty where the authority is, and `userinfo` and
%% `port` beside it where it writes them, the port `undefined` where it is
%% empty.
-spec parse(binary()) -> optional(uri_reference()).
parse(Text) ->
    case uri_string:parse(Text) of
        {error, _, _} ->
            'None';
        #{path := Path} = Components ->
            {'Some', {'Reference', optional(scheme, Components), authority(Components), Path,
                      optional(query, Components), optional(fragment, Components)}}
    end.

authority(#{host := Host} = Components) ->
    Port = case Components of
               #{port := Number} when is_integer(Number) -> {'Some', Number};
               _ -> 'None'
           end,
    {'Some', {'Authority', optional(userinfo, Components), Host, Port}};
authority(_) ->
    'None'.

optional(Key, Components) ->
    case Components of
        #{Key := Value} -> {'Some', Value};
        _ -> 'None'
    end.
