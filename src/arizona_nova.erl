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
    Layouts = [{my_layout, render}],
    arizona_nova:routes([
        #{prefix => "",
          security => false,
          routes => [
              {live, "/", my_home_view, #{layouts => Layouts}},
              {live, "/modules/:module_id", my_module_view, #{layouts => Layouts}},
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

The same pass collects the Arizona route declarations and compiles
them into the Cowboy dispatch table, so SPA navigate requests can
resolve them without a per-request compile step.
""".
-spec routes([map()]) -> [map()].
routes(RouteMaps) ->
    {Transformed, ArizonaRoutes} =
        lists:mapfoldl(fun transform_route_map/2, [], RouteMaps),
    ok = arizona_cowboy_router:compile_routes(ArizonaRoutes),
    Transformed.

transform_route_map(#{routes := Routes} = M, Acc0) ->
    {NovaRoutes, Acc1} = lists:mapfoldl(fun transform_route/2, Acc0, Routes),
    {M#{routes => NovaRoutes}, Acc1};
transform_route_map(M, Acc) ->
    {M, Acc}.

transform_route({live, Path, Handler, Opts}, Acc) ->
    NovaRoute = arizona_nova_live:route(Path, Handler, Opts),
    PathBin = iolist_to_binary(Path),
    {NovaRoute, [{live, PathBin, Handler, Opts} | Acc]};
transform_route(Route, Acc) ->
    {Route, Acc}.
