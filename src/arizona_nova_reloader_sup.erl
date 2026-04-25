-module(arizona_nova_reloader_sup).
-moduledoc false.
-behaviour(supervisor).

%% --------------------------------------------------------------------
%% API function exports
%% --------------------------------------------------------------------

-export([start_link/0]).

%% --------------------------------------------------------------------
%% Behaviour (supervisor) exports
%% --------------------------------------------------------------------

-export([init/1]).

%% --------------------------------------------------------------------
%% API function definitions
%% --------------------------------------------------------------------

-spec start_link() -> supervisor:startlink_ret().
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% --------------------------------------------------------------------
%% Behaviour (supervisor) callbacks
%% --------------------------------------------------------------------

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    ReloadUrl = <<(arizona_nova:prefix())/binary, "/reload">>,
    persistent_term:put(arizona_reload_url, ReloadUrl),
    {ok, App} = nova:get_main_app(),
    AppDir = code:lib_dir(App),
    SrcDir = filename:join(AppDir, "src"),
    PrivDir = filename:join(AppDir, "priv"),
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 10
    },
    ChildSpecs = [
        #{
            id => arizona_nova_erl_reloader,
            start =>
                {arizona_watcher, start_link, [
                    SrcDir,
                    #{
                        patterns => ["\\.erl$"],
                        callback => fun arizona_reloader:reload_erl/1
                    }
                ]}
        },
        #{
            id => arizona_nova_css_reloader,
            start =>
                {arizona_watcher, start_link, [
                    PrivDir,
                    #{
                        patterns => ["\\.css$"],
                        callback => fun arizona_reloader:reload_css/1
                    }
                ]}
        },
        #{
            id => arizona_nova_js_reloader,
            start =>
                {arizona_watcher, start_link, [
                    PrivDir,
                    #{
                        patterns => ["\\.js$"],
                        callback => fun(_) -> arizona_reloader:broadcast() end
                    }
                ]}
        }
    ],
    {ok, {SupFlags, ChildSpecs}}.
