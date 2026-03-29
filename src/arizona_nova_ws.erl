-module(arizona_nova_ws).
-moduledoc """
Nova WebSocket handler for Arizona live connections.

Thin wrapper around `arizona_socket` that translates between
Nova's WebSocket interface and Arizona's transport protocol.
""".

-export([init/1, websocket_init/1, websocket_handle/2, websocket_info/2]).

-spec init(map()) -> {ok, map()}.
init(#{req := Req} = ControllerData) ->
    QS = cowboy_req:parse_qs(Req),
    Path = proplists:get_value(<<"path">>, QS, <<"/">>),
    Reconnect = proplists:get_value(<<"reconnect">>, QS, <<"0">>) =:= <<"1">>,
    Params =
        case proplists:get_value(<<"params">>, QS) of
            undefined -> #{};
            JSON -> json:decode(JSON)
        end,
    {Handler, RouteOpts} = arizona_nova_adapter:resolve_route(Path, ControllerData),
    IB = maps:merge(maps:get(bindings, RouteOpts, #{}), Params),
    OnMount = maps:get(on_mount, RouteOpts, []),
    {ok, ControllerData#{
        handler => Handler,
        bindings => IB,
        on_mount => OnMount,
        reconnect => Reconnect
    }}.

-spec websocket_init(map()) -> {reply, term(), map()} | {ok, map()}.
websocket_init(#{handler := H, bindings := IB, on_mount := OM, reconnect := R} = CD) ->
    Opts = #{reconnect => R, on_mount => OM, adapter => arizona_nova_adapter, adapter_state => CD},
    to_nova(arizona_socket:init(H, IB, Opts), CD).

-spec websocket_handle(term(), map()) -> {reply, term(), map()} | {ok, map()}.
websocket_handle({text, Data}, #{socket := Sock} = CD) ->
    to_nova(arizona_socket:handle_in(Data, Sock), CD);
websocket_handle(_Frame, CD) ->
    {ok, CD}.

-spec websocket_info(term(), map()) -> {reply, term(), map()} | {ok, map()}.
websocket_info(Msg, #{socket := Sock} = CD) ->
    to_nova(arizona_socket:handle_info(Msg, Sock), CD).

%%----------------------------------------------------------------------
%% Internal
%%----------------------------------------------------------------------

to_nova({ok, Sock}, CD) ->
    {ok, CD#{socket => Sock}};
to_nova({reply, Data, Sock}, CD) ->
    {reply, {text, Data}, CD#{socket => Sock}};
to_nova({close, Code, Reason, _Sock}, CD) ->
    {reply, {close, Code, Reason}, CD}.
