-module(arizona_nova_app).
-moduledoc false.
-behaviour(application).

%% --------------------------------------------------------------------
%% Behaviour (application) exports
%% --------------------------------------------------------------------

-export([start/2]).
-export([stop/1]).

%% --------------------------------------------------------------------
%% Behaviour (application) callbacks
%% --------------------------------------------------------------------

-spec start(StartType, StartArgs) -> {ok, Pid} | {error, term()} when
    StartType :: application:start_type(),
    StartArgs :: term(),
    Pid :: pid().
start(_StartType, _StartArgs) ->
    ok = maybe_setup_live_reload(),
    arizona_nova_sup:start_link().

maybe_setup_live_reload() ->
    case application:get_env(arizona_nova, live_reload, false) of
        true ->
            ReloadUrl = <<(arizona_nova:prefix())/binary, "/reload">>,
            persistent_term:put(arizona_reload_url, ReloadUrl),
            {ok, App} = nova:get_main_app(),
            AppDir = code:lib_dir(App),
            SrcDir = filename:join(AppDir, "src"),
            PrivDir = filename:join(AppDir, "priv"),
            {ok, _} = arizona_watcher:watch(SrcDir, #{
                patterns => ["\\.erl$"],
                callback => fun arizona_reloader:reload_erl/1
            }),
            {ok, _} = arizona_watcher:watch(PrivDir, #{
                patterns => ["\\.css$"],
                callback => fun arizona_reloader:reload_css/1
            }),
            {ok, _} = arizona_watcher:watch(PrivDir, #{
                patterns => ["\\.js$"],
                callback => fun(_) -> arizona_reloader:broadcast() end
            }),
            ok;
        false ->
            ok
    end.

-spec stop(State) -> ok when
    State :: term().
stop(_State) ->
    ok.
