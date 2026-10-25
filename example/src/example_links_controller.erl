-module(example_links_controller).
-moduledoc """
Nova's side: a short link redirects (and is counted), and the links are also
an ordinary JSON API.
""".

-export([follow/1]).
-export([index/1]).

-spec follow(cowboy_req:req()) -> {redirect, binary()} | {status, 404}.
follow(#{bindings := #{~"code" := Code}}) ->
    case example_links:follow(Code) of
        {ok, Url} -> {redirect, Url};
        error -> {status, 404}
    end.

-spec index(cowboy_req:req()) -> {json, [example_links:link()]}.
index(_Req) ->
    {json, example_links:list()}.
