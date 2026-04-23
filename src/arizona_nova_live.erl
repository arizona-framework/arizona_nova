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

-doc """
Create a Nova route tuple for an Arizona view and register for WS navigate.

`Handler` must be an `arizona_view` module (includes `arizona_view.hrl`, exports
`mount/2`). URL path bindings and query params are exposed to mount via the
`az:request()` argument; the route's `bindings` option is passed as static
initial bindings. Route `Opts` may include `layout`, `on_mount`, and
`middlewares`.
""".
-spec route(string() | binary(), module(), map()) -> {string(), fun(), map()}.
route(Path, Handler, Opts) ->
    PathBin = iolist_to_binary(Path),
    Pending = persistent_term:get(?PENDING_KEY, []),
    persistent_term:put(?PENDING_KEY, [{live, PathBin, Handler, Opts} | Pending]),
    Fun = fun(Req) ->
        Headers = #{<<"content-type">> => <<"text/html">>},
        case arizona_http:render(Handler, Req, Opts) of
            {halt, _RawReq} ->
                %% Middleware already wrote a reply via the raw cowboy req.
                {status, 200};
            {ok, Status, Body} ->
                {status, Status, Headers, iolist_to_binary(Body)};
            {error, Status, Body} ->
                {status, Status, Headers, iolist_to_binary(Body)}
        end
    end,
    {Path, Fun, #{methods => [get]}}.

-doc false.
-spec compile() -> ok.
compile() ->
    case persistent_term:get(?PENDING_KEY, []) of
        [] ->
            ok;
        Pending ->
            persistent_term:erase(?PENDING_KEY),
            ok = arizona_cowboy_router:compile_routes(lists:reverse(Pending))
    end.
