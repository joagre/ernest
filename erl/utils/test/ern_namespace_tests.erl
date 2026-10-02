%% ern_namespace maps a path's components to a namespace's segments and back.
-module(ern_namespace_tests).

-include_lib("eunit/include/eunit.hrl").

%% report §11.1: a component is words joined by single `_`, a word a
%% lowercase letter then lowercase letters and digits
component_shape_test() ->
    ?assert(ern_namespace:is_component("http")),
    ?assert(ern_namespace:is_component("httpv2")),
    ?assert(ern_namespace:is_component("ordered_set")),
    ?assert(ern_namespace:is_component("h_t_t_p")),
    ?assertNot(ern_namespace:is_component("Net")),
    ?assertNot(ern_namespace:is_component("9x")),
    %% a word begins with a letter, so `http_2` and `http2` cannot both be Http2
    ?assertNot(ern_namespace:is_component("http_2")),
    %% a `_` stands between two words
    ?assertNot(ern_namespace:is_component("_http")),
    ?assertNot(ern_namespace:is_component("http_")),
    ?assertNot(ern_namespace:is_component("ordered__set")),
    ?assertNot(ern_namespace:is_component("")).

%% report §4.2: the segment is each word with its first letter uppercased
%% and the `_` dropped, and the mapping is one-to-one both ways
segment_and_component_test() ->
    ?assertEqual({ok, "Http"}, ern_namespace:segment("http")),
    ?assertEqual({ok, "Httpv2"}, ern_namespace:segment("httpv2")),
    ?assertEqual({ok, "HttpV2"}, ern_namespace:segment("http_v2")),
    ?assertEqual({ok, "OrderedSet"}, ern_namespace:segment("ordered_set")),
    ?assertEqual({ok, "HTTP"}, ern_namespace:segment("h_t_t_p")),
    ?assertEqual(error, ern_namespace:segment("http_2")),
    ?assertEqual({ok, "http"}, ern_namespace:component("Http")),
    ?assertEqual({ok, "httpv2"}, ern_namespace:component("Httpv2")),
    ?assertEqual({ok, "http_v2"}, ern_namespace:component("HttpV2")),
    ?assertEqual({ok, "ordered_set"}, ern_namespace:component("OrderedSet")),
    ?assertEqual({ok, "h_t_t_p"}, ern_namespace:component("HTTP")),
    ?assertEqual(error, ern_namespace:component("orderedSet")),
    ?assertEqual(error, ern_namespace:component("Ordered_Set")),
    ?assertEqual(error, ern_namespace:component("Http.Parser")),
    ?assertEqual(error, ern_namespace:component("")),
    Components = ["http", "httpv2", "http_v2", "ordered_set", "h_t_t_p", "a1_b2"],
    [?assertEqual({ok, C}, ern_namespace:component(S))
     || C <- Components, {ok, S} <- [ern_namespace:segment(C)]].

%% report §4.2, §11.2: a namespace from a path and the path from a namespace
namespace_and_path_test() ->
    ?assertEqual(['Net', 'HttpClient'], ern_namespace:namespace(["net", "http_client"])),
    ?assertEqual("net/http_client", ern_namespace:module_path(['Net', 'HttpClient'])),
    ?assertEqual("ordered_set", ern_namespace:module_path(['OrderedSet'])),
    ?assertEqual('ern@ordered_set', ern_namespace:erlang_module(['OrderedSet'])),
    ?assertEqual('ern@net@http_client', ern_namespace:erlang_module(['Net', 'HttpClient'])),
    %% the shell's own modules keep their spelling but for the case of a letter
    ?assertEqual('ern@$input1', ern_namespace:erlang_module(['$Input1'])),
    ?assertEqual(['$Input1'], ern_namespace:namespace(["$Input1"])).
