-module(arizona_nova_SUITE).
-moduledoc """
Boots Nova with `arizona_nova` in front of its middleware chain and checks that
Arizona and Nova share the listener: Arizona answers its routes (a page, the
live WebSocket, an asset) and Nova answers its own.
""".
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).
-export([init_per_suite/1]).
-export([end_per_suite/1]).

-export([arizona_serves_its_page/1]).
-export([nova_serves_its_routes/1]).
-export([arizona_serves_its_assets/1]).
-export([live_socket_connects/1]).
-export([stopping_drains_arizona_and_leaves_nova_serving/1]).

all() ->
    [
        arizona_serves_its_page,
        nova_serves_its_routes,
        arizona_serves_its_assets,
        live_socket_connects,
        stopping_drains_arizona_and_leaves_nova_serving
    ].

init_per_suite(Config) ->
    Port = pick_port(),
    ok = application:load(nova),
    ok = application:load(arizona_nova),
    ok = application:set_env(nova, bootstrap_application, arizona_nova),
    ok = application:set_env(nova, environment, dev),
    ok = application:set_env(nova, cowboy_configuration, #{
        port => Port,
        middleware_handlers => arizona_nova:middlewares()
    }),
    ok = application:set_env(arizona_nova, router_module, arizona_nova_test_router),
    ok = application:set_env(arizona_nova, routes, [
        {live, ~"/", arizona_nova_test_page, #{}},
        {ws, ~"/ws", #{}},
        {asset, ~"/assets", {priv_dir, arizona, "static/assets/js"}}
    ]),
    {ok, _} = application:ensure_all_started(arizona_nova),
    [{port, Port} | Config].

end_per_suite(Config) when is_list(Config) ->
    ok = application:stop(arizona_nova),
    ok = application:stop(nova),
    ok = application:stop(arizona).

%% --------------------------------------------------------------------
%% Cases
%% --------------------------------------------------------------------

arizona_serves_its_page(Config) ->
    {200, Body} = request(Config, ~"GET", ~"/"),
    ?assertNotEqual(nomatch, binary:match(Body, ~"Arizona on Nova")),
    ?assertNotEqual(nomatch, binary:match(Body, ~"az-view")).

nova_serves_its_routes(Config) ->
    ?assertEqual({200, ~"nova"}, request(Config, ~"GET", ~"/nova")).

arizona_serves_its_assets(Config) ->
    {200, Body} = request(Config, ~"GET", ~"/assets/arizona.min.js"),
    ?assert(byte_size(Body) > 0).

%% The live view mounts over the socket: its first frame is the connect frame.
live_socket_connects(Config) ->
    Sock = ws_connect(Config, ~"/"),
    {text, Frame} = ws_recv(Sock),
    ?assertMatch(#{~"a" := _}, json:decode(Frame)),
    ok = gen_tcp:close(Sock).

%% Stopping arizona_nova (before Nova, which it depends on) drains Arizona's
%% sessions -- a live socket closes 1001, which clients reconnect from -- and
%% unmounts its routes, while Nova keeps serving on the same listener.
stopping_drains_arizona_and_leaves_nova_serving(Config) ->
    Sock = ws_connect(Config, ~"/"),
    {text, _Connect} = ws_recv(Sock),
    ok = application:stop(arizona_nova),
    ?assertMatch({close, 1001}, ws_recv(Sock)),
    ok = gen_tcp:close(Sock),
    ?assertEqual({200, ~"nova"}, request(Config, ~"GET", ~"/nova")),
    ?assertMatch({404, _}, request(Config, ~"GET", ~"/")),
    {ok, _} = application:ensure_all_started(arizona_nova).

%% --------------------------------------------------------------------
%% Helpers
%% --------------------------------------------------------------------

pick_port() ->
    {ok, Listen} = gen_tcp:listen(0, [{reuseaddr, true}]),
    {ok, Port} = inet:port(Listen),
    ok = gen_tcp:close(Listen),
    Port.

connect(Config) ->
    {ok, Sock} = gen_tcp:connect("localhost", proplists:get_value(port, Config), [
        binary, {active, false}
    ]),
    Sock.

request(Config, Method, Path) ->
    Sock = connect(Config),
    ok = gen_tcp:send(Sock, [
        Method,
        ~" ",
        Path,
        ~" HTTP/1.1\r\nhost: localhost\r\nconnection: close\r\n",
        ~"content-length: 0\r\n\r\n"
    ]),
    Response = recv_all(Sock, <<>>),
    ok = gen_tcp:close(Sock),
    [Head, Body] = binary:split(Response, ~"\r\n\r\n"),
    <<"HTTP/1.1 ", Code:3/binary, _/binary>> = Head,
    {binary_to_integer(Code), Body}.

recv_all(Sock, Acc) ->
    case gen_tcp:recv(Sock, 0, 5000) of
        {ok, Data} -> recv_all(Sock, <<Acc/binary, Data/binary>>);
        {error, closed} -> Acc
    end.

%% An upgraded socket for the live view at `Path`, with anything read past the
%% 101 head kept in the process dictionary for `ws_recv/1`.
ws_connect(Config, Path) ->
    Sock = connect(Config),
    ok = gen_tcp:send(Sock, [
        ~"GET /ws?_az_path=",
        Path,
        ~" HTTP/1.1\r\nhost: localhost\r\n",
        ~"upgrade: websocket\r\nconnection: Upgrade\r\nsec-websocket-version: 13\r\n",
        ~"sec-websocket-key: ",
        base64:encode(crypto:strong_rand_bytes(16)),
        ~"\r\n\r\n"
    ]),
    {Head, Rest} = recv_head(Sock, <<>>),
    <<"HTTP/1.1 101", _/binary>> = Head,
    undefined = put({ws_buffer, Sock}, Rest),
    Sock.

recv_head(Sock, Acc) ->
    case binary:split(Acc, ~"\r\n\r\n") of
        [Head, Rest] ->
            {Head, Rest};
        [_Partial] ->
            {ok, Data} = gen_tcp:recv(Sock, 0, 5000),
            recv_head(Sock, <<Acc/binary, Data/binary>>)
    end.

%% One unfragmented, unmasked server frame: text, or a close with its code.
ws_recv(Sock) ->
    Buffer = get({ws_buffer, Sock}),
    case parse_frame(Buffer) of
        {Frame, Rest} ->
            Buffer = put({ws_buffer, Sock}, Rest),
            Frame;
        more ->
            {ok, Data} = gen_tcp:recv(Sock, 0, 5000),
            Buffer = put({ws_buffer, Sock}, <<Buffer/binary, Data/binary>>),
            ws_recv(Sock)
    end.

parse_frame(<<_Fin:1, _Rsv:3, Op:4, 0:1, 126:7, Len:16, Payload:Len/binary, Rest/binary>>) ->
    {frame(Op, Payload), Rest};
parse_frame(<<_Fin:1, _Rsv:3, Op:4, 0:1, 127:7, Len:64, Payload:Len/binary, Rest/binary>>) ->
    {frame(Op, Payload), Rest};
parse_frame(<<_Fin:1, _Rsv:3, Op:4, 0:1, Len:7, Payload:Len/binary, Rest/binary>>) when Len < 126 ->
    {frame(Op, Payload), Rest};
parse_frame(_Incomplete) ->
    more.

frame(1, Payload) -> {text, Payload};
frame(8, <<Code:16, _Reason/binary>>) -> {close, Code}.
