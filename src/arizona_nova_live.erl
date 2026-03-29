-module(arizona_nova_live).

-moduledoc """
Arizona LiveView integration helpers for Nova routes.

## Example

```erlang
-module(my_app_router).
-behaviour(nova_router).
-export([routes/1]).

routes(_Env) ->
    Layout = {my_layout, render},
    [#{prefix => "",
       security => false,
       routes => [
           arizona_nova_live:route("/", my_home_view, #{layout => Layout}),
           arizona_nova_live:route("/modules/:module_id", my_module_view, #{layout => Layout}),
           {"/ws", arizona_nova_ws, #{protocol => ws}},
           {"/assets/[...]", "static/assets"}
       ]}].
```
""".

-export([route/3, compile/0]).

-define(PENDING_KEY, arizona_nova_pending_routes).

-doc "Create a Nova route tuple for a live view and register for WS navigate.".
-spec route(string() | binary(), module(), map()) -> {string(), fun(), map()}.
route(Path, Handler, Opts) ->
    PathBin = iolist_to_binary(Path),
    Pending = persistent_term:get(?PENDING_KEY, []),
    persistent_term:put(?PENDING_KEY, [{live, PathBin, Handler, Opts} | Pending]),
    Fun = fun(Req) ->
        PathBindings = maps:fold(fun(K, V, Acc) ->
            Acc#{binary_to_atom(K) => V}
        end, #{}, maps:get(bindings, Req, #{})),
        QueryParams = maps:from_list(cowboy_req:parse_qs(Req)),
        MergedBindings = maps:merge(PathBindings, QueryParams),
        RenderOpts = #{
            bindings => MergedBindings,
            layout => maps:get(layout, Opts, undefined),
            on_mount => maps:get(on_mount, Opts, [])
        },
        Html = arizona_render:render_to_iolist(Handler, RenderOpts),
        {status, 200, #{<<"content-type">> => <<"text/html">>}, iolist_to_binary(Html)}
    end,
    {Path, Fun, #{methods => [get]}}.

-doc false.
-spec compile() -> ok.
compile() ->
    case persistent_term:get(?PENDING_KEY, []) of
        [] -> ok;
        Pending ->
            persistent_term:erase(?PENDING_KEY),
            ok = arizona_cowboy_router:compile_routes(lists:reverse(Pending))
    end.
