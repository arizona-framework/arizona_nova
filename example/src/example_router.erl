-module(example_router).
-moduledoc """
Nova's routes for the example. Arizona's (the live page, its WebSocket and the
client script) are in the `arizona_nova` env instead; a request none of those
matches reaches this router as in any Nova application.
""".
-behaviour(nova_router).

-export([routes/1]).

-spec routes(atom()) -> [map()].
routes(_Env) ->
    [
        #{
            prefix => "",
            security => false,
            routes => [{"/api/time", fun example_api:time/1, #{methods => [get]}}]
        }
    ].
