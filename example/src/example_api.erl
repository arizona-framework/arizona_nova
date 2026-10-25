-module(example_api).
-moduledoc "A plain Nova controller, served beside Arizona's live page.".

-export([time/1]).

-spec time(cowboy_req:req()) -> {json, map()}.
time(_Req) ->
    {json, #{~"utc" => list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second)))}}.
