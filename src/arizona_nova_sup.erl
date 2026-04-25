-module(arizona_nova_sup).
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
    SupFlags = #{
        strategy => one_for_all,
        intensity => 0,
        period => 1
    },
    ChildSpecs = reloader_sup_child(),
    {ok, {SupFlags, ChildSpecs}}.

%% --------------------------------------------------------------------
%% Internal functions
%% --------------------------------------------------------------------

reloader_sup_child() ->
    case application:get_env(arizona_nova, live_reload, false) of
        true ->
            [
                #{
                    id => arizona_nova_reloader_sup,
                    start => {arizona_nova_reloader_sup, start_link, []},
                    type => supervisor
                }
            ];
        false ->
            []
    end.
