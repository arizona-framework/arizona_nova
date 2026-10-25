-module(example_counter).
-moduledoc """
A live counter: each click is a WebSocket event, and the server answers with a
patch of the one slot that changed.
""".
-include_lib("arizona/include/arizona_stateful.hrl").

-export([mount/1]).
-export([render/1]).
-export([handle_event/3]).

-spec mount(az:bindings()) -> az:mount_ret().
mount(_Bindings) ->
    {#{id => ~"counter", count => 0}, #{}}.

-spec render(az:bindings()) -> az:template().
render(Bindings) ->
    ?html(
        {main, [{id, ?get(id)}], [
            {h1, [], [~"Arizona on Nova"]},
            {p, [], [~"Count: ", ?get(count)]},
            {button, [{az_click, arizona_js:push_event(~"dec")}], [~"-"]},
            {button, [{az_click, arizona_js:push_event(~"inc")}], [~"+"]},
            {p, [], [{a, [{href, ~"/api/time"}], [~"A Nova route"]}]}
        ]}
    ).

-spec handle_event(az:event_name(), az:event_payload(), az:bindings()) ->
    az:handle_event_ret().
handle_event(~"inc", _Payload, #{count := Count} = Bindings) ->
    {Bindings#{count => Count + 1}, #{}, []};
handle_event(~"dec", _Payload, #{count := Count} = Bindings) ->
    {Bindings#{count => Count - 1}, #{}, []}.
