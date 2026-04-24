-module(arizona_nova_live).

-moduledoc """
Arizona LiveView integration helpers for Nova routes.

Prefer declaring routes with `arizona_nova:routes/1` and `{live, ...}`
tuples. See that module's docs for the recommended usage.
""".

-export([route/3]).

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
    ok = arizona_nova_router:append_pending([{live, PathBin, Handler, Opts}]),
    Fun = fun(Req) ->
        Headers = #{<<"content-type">> => <<"text/html">>},
        case arizona_http:render(Handler, Req, Opts) of
            {halt, _RawReq} ->
                %% Middleware already wrote a reply via the raw cowboy req.
                {status, 200};
            {redirect, Status, Location} ->
                {status, Status, #{<<"location">> => Location}, <<>>};
            {ok, Status, Body} ->
                {status, Status, Headers, iolist_to_binary(Body)};
            {error, Status, Body} ->
                {status, Status, Headers, iolist_to_binary(Body)}
        end
    end,
    {Path, Fun, #{methods => [get]}}.
