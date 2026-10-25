-module(arizona_nova_app).
-moduledoc false.
-behaviour(application).

%% --------------------------------------------------------------------
%% Behaviour (application) exports
%% --------------------------------------------------------------------

-export([start/2]).
-export([prep_stop/1]).
-export([stop/1]).

%% --------------------------------------------------------------------
%% Macros
%% --------------------------------------------------------------------

-define(DEFAULT_LISTENER, nova_listener).
-define(DRAIN_TIMEOUT, 5000).
-define(MOUNT_OPTS, [routes, compress, error_page, ws_opts, max_content_length]).

%% --------------------------------------------------------------------
%% Behaviour (application) callbacks
%% --------------------------------------------------------------------

-spec start(StartType, StartArgs) -> supervisor:startlink_ret() when
    StartType :: application:start_type(),
    StartArgs :: term().
start(_StartType, _StartArgs) ->
    maybe
        {ok, Sup} ?= arizona_nova_sup:start_link(),
        ok ?= arizona_cowboy_server:mount(listener(), mount_opts()),
        {ok, Sup}
    end.

%% Nova depends on nothing here, so it is still up: the live sessions are told
%% to wind down (and reconnect) while their listener can still close them.
-spec prep_stop(State) -> State when
    State :: term().
prep_stop(State) ->
    Timeout = application:get_env(arizona_nova, drain_timeout, ?DRAIN_TIMEOUT),
    case arizona_cowboy_server:drain(listener(), Timeout) of
        ok -> State;
        {error, not_found} -> State
    end.

-spec stop(State) -> ok when
    State :: term().
stop(_State) ->
    ok.

%% --------------------------------------------------------------------
%% Internal functions
%% --------------------------------------------------------------------

listener() ->
    application:get_env(arizona_nova, listener, ?DEFAULT_LISTENER).

mount_opts() ->
    maps:from_list([
        {Key, Value}
     || Key <- ?MOUNT_OPTS, {ok, Value} <- [application:get_env(arizona_nova, Key)]
    ]).
