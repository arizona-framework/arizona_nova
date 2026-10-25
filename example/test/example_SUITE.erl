-module(example_SUITE).
-moduledoc """
Boots the example (config/sys.config) and drives it over the wire: Arizona's
live page and a click on it, and Nova's own route, on the one listener.
""".
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).
-export([init_per_suite/1]).
-export([end_per_suite/1]).

-export([serves_the_live_page/1]).
-export([serves_the_nova_route/1]).
-export([a_click_updates_the_count/1]).

all() ->
    [serves_the_live_page, serves_the_nova_route, a_click_updates_the_count].

%% config/sys.config, with a free port: 8080 may well be taken on the machine.
init_per_suite(Config) ->
    {ok, Cowboy} = application:get_env(nova, cowboy_configuration),
    Port = pick_port(),
    ok = application:set_env(nova, cowboy_configuration, Cowboy#{port => Port}),
    {ok, _} = application:ensure_all_started(example),
    ok = persistent_term:put(example_port, Port),
    Config.

end_per_suite(Config) when is_list(Config) ->
    ok = application:stop(example),
    ok = application:stop(arizona_nova),
    ok = application:stop(nova).

serves_the_live_page(Config) when is_list(Config) ->
    {200, Body} = request(~"/"),
    ?assertNotEqual(nomatch, binary:match(Body, ~"Count: ")),
    ?assertNotEqual(nomatch, binary:match(Body, ~"/assets/arizona.min.js")).

serves_the_nova_route(Config) when is_list(Config) ->
    {200, Body} = request(~"/api/time"),
    #{~"utc" := Utc} = json:decode(Body),
    ?assertMatch(<<_:19/binary, "Z">>, Utc).

%% The live view mounts over the socket; an `inc` event comes back as a patch
%% carrying the new count.
a_click_updates_the_count(Config) when is_list(Config) ->
    Sock = ws_connect(~"/"),
    {text, Connect} = ws_recv(Sock),
    ?assertMatch(#{~"a" := _}, json:decode(Connect)),
    ok = ws_send(Sock, json:encode([~"counter", ~"inc", #{}])),
    {text, Patch} = ws_recv(Sock),
    ?assertNotEqual(nomatch, binary:match(Patch, ~"1")),
    ok = gen_tcp:close(Sock).

%% --------------------------------------------------------------------
%% Helpers: one HTTP/1.1 request, and a minimal WebSocket client.
%% --------------------------------------------------------------------

pick_port() ->
    {ok, Listen} = gen_tcp:listen(0, [{reuseaddr, true}]),
    {ok, Port} = inet:port(Listen),
    ok = gen_tcp:close(Listen),
    Port.

connect() ->
    {ok, Sock} = gen_tcp:connect("localhost", persistent_term:get(example_port), [
        binary, {active, false}
    ]),
    Sock.

request(Path) ->
    Sock = connect(),
    ok = gen_tcp:send(Sock, [
        ~"GET ", Path, ~" HTTP/1.1\r\nhost: localhost\r\nconnection: close\r\n\r\n"
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

ws_connect(Path) ->
    Sock = connect(),
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

%% A client frame must be masked.
ws_send(Sock, Payload) ->
    Data = iolist_to_binary(Payload),
    Mask = crypto:strong_rand_bytes(4),
    Len = byte_size(Data),
    Header =
        if
            Len < 126 -> <<1:1, 0:3, 1:4, 1:1, Len:7>>;
            true -> <<1:1, 0:3, 1:4, 1:1, 126:7, Len:16>>
        end,
    gen_tcp:send(Sock, [Header, Mask, mask(Data, Mask)]).

mask(Data, Mask) ->
    <<<<(B bxor binary:at(Mask, I rem 4))>> || {I, B} <- lists:enumerate(0, binary_to_list(Data))>>.

%% One unfragmented server frame (servers do not mask).
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

parse_frame(<<_:4, Op:4, 0:1, 126:7, Len:16, Payload:Len/binary, Rest/binary>>) ->
    {{frame_type(Op), Payload}, Rest};
parse_frame(<<_:4, Op:4, 0:1, 127:7, Len:64, Payload:Len/binary, Rest/binary>>) ->
    {{frame_type(Op), Payload}, Rest};
parse_frame(<<_:4, Op:4, 0:1, Len:7, Payload:Len/binary, Rest/binary>>) when Len < 126 ->
    {{frame_type(Op), Payload}, Rest};
parse_frame(_Incomplete) ->
    more.

frame_type(1) -> text;
frame_type(8) -> close.
