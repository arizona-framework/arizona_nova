-module(arizona_nova).
-moduledoc """
Configuration helpers for Arizona Nova integration.

## Declaring routes

Use `routes/1` to rewrite `{live, Path, Handler, Opts}` tuples into the
Nova route tuples Arizona expects, without calling `arizona_nova_live`
directly:

```erlang
-module(my_app_router).
-behaviour(nova_router).
-export([routes/1]).

routes(_Env) ->
    Layout = {my_layout, render},
    arizona_nova:routes([
        #{prefix => "",
          security => false,
          routes => [
              {live, "/", my_home_view, #{layout => Layout}},
              {live, "/modules/:module_id", my_module_view, #{layout => Layout}},
              {"/ws", arizona_nova_ws, #{protocol => ws}},
              {"/assets/[...]", "static/assets"}
          ]}
    ]).
```
""".

-export([prefix/0]).
-export([routes/1]).

-doc "Get the configured URL prefix. Default: `/arizona`.".
-spec prefix() -> binary().
prefix() ->
    case application:get_env(arizona_nova, prefix, ~"/arizona") of
        Prefix when is_binary(Prefix) -> Prefix;
        Prefix when is_list(Prefix) -> list_to_binary(Prefix)
    end.

-doc """
Transform a Nova router map list, rewriting any `{live, Path, Handler, Opts}`
entries into the Nova route tuples `arizona_nova_live` produces. Other
route tuples pass through unchanged.
""".
-spec routes([map()]) -> [map()].
routes(RouteMaps) ->
    [transform_route_map(M) || M <- RouteMaps].

transform_route_map(#{routes := Routes} = M) ->
    M#{routes => [transform_route(R) || R <- Routes]};
transform_route_map(M) ->
    M.

transform_route({live, Path, Handler, Opts}) ->
    arizona_nova_live:route(Path, Handler, Opts);
transform_route(Route) ->
    Route.
