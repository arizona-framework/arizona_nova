-module(arizona_nova_router).
-moduledoc """
Nova router for Arizona. Registers the shared WebSocket endpoint
and serves arizona static assets (JS, CSS).

Add `arizona_nova` to your app's `nova_apps`:

```erlang
{my_app, [{nova_apps, [arizona_nova]}]}
```

Configure the prefix (default `/arizona`):

```erlang
{arizona_nova, [{prefix, "/arizona"}]}
```
""".

-behaviour(nova_router).

-export([routes/1]).
-export([append_pending/1, drain_pending/0]).

-define(PENDING_KEY, arizona_nova_pending_routes).

-spec routes(term()) -> [map()].
routes(_Env) ->
    Prefix = arizona_nova:prefix(),
    [
        #{
            prefix => Prefix,
            security => false,
            routes => [
                {~"/ws", arizona_nova_ws, #{protocol => ws}},
                {~"/assets/js/:file", fun arizona_nova_static:serve_js/1, #{methods => [get]}}
            ]
        }
    ].

-doc false.
-spec append_pending([term()]) -> ok.
append_pending(Routes) when is_list(Routes) ->
    Pending = persistent_term:get(?PENDING_KEY, []),
    persistent_term:put(?PENDING_KEY, Pending ++ Routes).

-doc false.
-spec drain_pending() -> [term()].
drain_pending() ->
    case persistent_term:get(?PENDING_KEY, []) of
        [] ->
            [];
        Pending ->
            persistent_term:erase(?PENDING_KEY),
            Pending
    end.
