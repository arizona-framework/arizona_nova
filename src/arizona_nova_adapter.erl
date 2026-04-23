-module(arizona_nova_adapter).
-moduledoc "Arizona adapter for Nova. Resolves views from registered resolvers.".
-behaviour(arizona_adapter).
-export([resolve_route/3]).

-spec resolve_route(arizona_adapter:path(), arizona_adapter:qs(), term()) ->
    {module(), arizona_adapter:route_opts(), az:request()}.
resolve_route(Path, Qs, #{req := Req}) ->
    ok = arizona_nova_live:compile(),
    arizona_cowboy_adapter:resolve_route(Path, Qs, Req).
