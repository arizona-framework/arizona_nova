-module(arizona_nova_ws).
-moduledoc """
Nova WebSocket handler for Arizona live connections.

Thin wrapper around `arizona_socket` that translates between
Nova's WebSocket interface and Arizona's transport protocol.
Delegates the upgrade-time handshake (parse `_az_path`/`_az_reconnect`,
resolve the route, run middlewares) to `arizona_ws:prepare/3`.
""".

-export([init/1, websocket_init/1, websocket_handle/2, websocket_info/2]).

-spec init(map()) -> {ok, map()}.
init(#{req := Req} = ControllerData) ->
    QS = cowboy_req:parse_qs(Req),
    case arizona_ws:prepare(QS, arizona_cowboy_req, Req) of
        {halt, HaltReq} ->
            {ok, ControllerData#{halt => arizona_req:raw(HaltReq)}};
        {cont, #{req := ArzReq} = State} ->
            %% Map State.req -> az_req so it doesn't clobber Nova's CD.req
            %% (the raw cowboy req).
            AzState = maps:remove(req, State#{az_req => ArzReq}),
            {ok, maps:merge(ControllerData, AzState)}
    end.

-spec websocket_init(map()) -> {reply, term(), map()} | {ok, map()}.
websocket_init(
    #{
        handler := H,
        bindings := IB,
        on_mount := OM,
        az_req := ArzReq,
        reconnect := R
    } = CD
) ->
    Opts = #{reconnect => R, on_mount => OM},
    to_nova(arizona_socket:init(H, IB, ArzReq, Opts), CD).

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
