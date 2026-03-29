-module(arizona_nova).
-moduledoc """
Public API for Arizona Nova integration.

Provides view resolver registration and configuration helpers.
Apps register their view resolvers at startup so the shared
WebSocket endpoint can route to the correct view module.

## Usage

```erlang
%% In your app's start/2:
arizona_nova:register_views(my_app, fun my_controller:resolve_view/2).
```
""".

-export([prefix/0, register_views/2, resolve_view/2]).

-define(RESOLVER_TABLE, arizona_nova_resolvers).

-doc "Get the configured URL prefix. Default: `/arizona`.".
-spec prefix() -> binary().
prefix() ->
    case application:get_env(arizona_nova, prefix, ~"/arizona") of
        Prefix when is_binary(Prefix) -> Prefix;
        Prefix when is_list(Prefix) -> list_to_binary(Prefix)
    end.

-doc "Register a view resolver for an application.".
-spec register_views(atom(), fun((binary(), term()) -> {module(), arizona_adapter:route_opts()})) ->
    ok.
register_views(App, ResolverFun) when is_atom(App), is_function(ResolverFun, 2) ->
    ets:insert(?RESOLVER_TABLE, {App, ResolverFun}),
    ok.

-doc false.
-spec resolve_view(binary(), term()) -> {module(), arizona_adapter:route_opts()}.
resolve_view(Path, State) ->
    Resolvers = ets:tab2list(?RESOLVER_TABLE),
    try_resolvers(Resolvers, Path, State).

try_resolvers([], Path, _State) ->
    logger:warning(#{msg => ~"No view resolver matched", path => Path}),
    error({no_view_resolver, Path});
try_resolvers([{App, Resolver} | Rest], Path, State) ->
    try
        case Resolver(Path, State) of
            {_Handler, _RouteOpts} = Result ->
                Result;
            Other ->
                logger:warning(#{
                    msg => ~"View resolver returned unexpected format", app => App, result => Other
                }),
                try_resolvers(Rest, Path, State)
        end
    catch
        Class:Reason ->
            logger:warning(#{
                msg => ~"View resolver failed", app => App, class => Class, reason => Reason
            }),
            try_resolvers(Rest, Path, State)
    end.
