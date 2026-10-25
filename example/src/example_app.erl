-module(example_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).

-spec start(application:start_type(), term()) -> supervisor:startlink_ret().
start(_StartType, _StartArgs) ->
    example_sup:start_link().

-spec stop(term()) -> ok.
stop(_State) ->
    ok.
