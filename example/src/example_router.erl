-module(example_router).
-moduledoc """
Nova's routes: following a short link and the JSON API. Arizona's (the live
dashboard, its WebSocket and the client script) are in the `arizona_nova` env;
a request none of those matches reaches this router as in any Nova application.
""".
-behaviour(nova_router).

-export([routes/1]).

-spec routes(atom()) -> [map()].
routes(_Env) ->
    [
        #{
            prefix => "",
            security => false,
            routes => [
                {"/s/:code", fun example_links_controller:follow/1, #{methods => [get]}},
                {"/api/links", fun example_links_controller:index/1, #{methods => [get]}}
            ]
        }
    ].
