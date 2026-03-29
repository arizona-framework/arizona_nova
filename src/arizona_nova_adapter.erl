-module(arizona_nova_adapter).
-moduledoc "Arizona adapter for Nova. Resolves views from registered resolvers.".
-behaviour(arizona_adapter).
-export([resolve_route/2]).

-spec resolve_route(arizona_adapter:path(), term()) -> {module(), arizona_adapter:route_opts()}.
resolve_route(Path, State) ->
    arizona_nova:resolve_view(Path, State).
