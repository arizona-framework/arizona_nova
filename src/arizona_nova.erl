-module(arizona_nova).
-moduledoc "Configuration helpers for Arizona Nova integration.".

-export([prefix/0]).

-doc "Get the configured URL prefix. Default: `/arizona`.".
-spec prefix() -> binary().
prefix() ->
    case application:get_env(arizona_nova, prefix, ~"/arizona") of
        Prefix when is_binary(Prefix) -> Prefix;
        Prefix when is_list(Prefix) -> list_to_binary(Prefix)
    end.
