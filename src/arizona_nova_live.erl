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
        ArzReq = arizona_cowboy_req:new(Req),
        StaticBindings = maps:get(bindings, Opts, #{}),
        Middlewares = maps:get(middlewares, Opts, []),
        case arizona_req:apply_middlewares(Middlewares, ArzReq, StaticBindings) of
            {halt, _HaltReq} ->
                %% Middleware already wrote a reply via the raw cowboy req.
                {status, 200};
            {cont, ArzReq1, Bindings1} ->
                render_page(Handler, ArzReq1, Bindings1, Opts)
        end
    end,
    {Path, Fun, #{methods => [get]}}.

render_page(Handler, ArzReq, Bindings, Opts) ->
    RenderOpts = #{
        bindings => Bindings,
        layout => maps:get(layout, Opts, undefined),
        on_mount => maps:get(on_mount, Opts, [])
    },
    Headers = #{<<"content-type">> => <<"text/html">>},
    case arizona_reloader:get_error() of
        undefined ->
            try arizona_render:render_view_to_iolist(Handler, ArzReq, RenderOpts) of
                Page ->
                    {status, 200, Headers, iolist_to_binary(Page)}
            catch
                Class:Reason:Stacktrace ->
                    ErrorInfo = #{
                        class => Class,
                        reason => Reason,
                        stacktrace => Stacktrace,
                        reload_url => reload_url()
                    },
                    Body = render_error_page(Bindings, ErrorInfo),
                    {status, 500, Headers, iolist_to_binary(Body)}
            end;
        #{errors := Errors} ->
            ErrorInfo = #{
                class => error,
                reason => {compile_error, Errors},
                stacktrace => [],
                reload_url => reload_url()
            },
            Body = render_error_page(Bindings, ErrorInfo),
            {status, 500, Headers, iolist_to_binary(Body)}
    end.

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

render_error_page(Bindings, ErrorInfo) ->
    Tmpl = arizona_error_page:render(Bindings#{error_info => ErrorInfo}),
    arizona_render:render_to_iolist(Tmpl).

reload_url() ->
    persistent_term:get(arizona_reload_url, undefined).
