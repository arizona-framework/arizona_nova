-module(arizona_nova_test_router).
-moduledoc "**TEST FIXTURE.** The Nova router of the bootstrap application under test.".
-behaviour(nova_router).

-export([routes/1]).
-export([hello/1]).

-spec routes(term()) -> [map()].
routes(_Env) ->
    [
        #{
            prefix => "",
            security => false,
            routes => [{"/nova", fun ?MODULE:hello/1, #{methods => [get]}}]
        }
    ].

-spec hello(cowboy_req:req()) -> {status, 200, map(), binary()}.
hello(_Req) ->
    {status, 200, #{~"content-type" => ~"text/plain"}, ~"nova"}.
