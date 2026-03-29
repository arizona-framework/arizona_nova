-module(arizona_nova_reload).
-moduledoc "SSE reload endpoint for Nova.".
-export([handle/1]).

-spec handle(cowboy_req:req()) -> {status, 200}.
handle(Req) ->
    Headers = #{
        <<"content-type">> => <<"text/event-stream">>,
        <<"cache-control">> => <<"no-cache">>
    },
    Req1 = cowboy_req:stream_reply(200, Headers, Req),
    ok = arizona_reloader:join(self()),
    sse_loop(Req1).

sse_loop(Req) ->
    receive
        {arizona_reloader, reload} ->
            cowboy_req:stream_body(<<"event: reload\ndata: \n\n">>, nofin, Req),
            sse_loop(Req);
        {arizona_reloader, reload_css} ->
            cowboy_req:stream_body(<<"event: reload_css\ndata: \n\n">>, nofin, Req),
            sse_loop(Req);
        _ ->
            sse_loop(Req)
    end.
