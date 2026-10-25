-module(example_links).
-moduledoc """
The link store both frameworks share: Nova's controllers follow a link and
list them, Arizona's dashboard shortens them, and every change is broadcast on
`topic/0`, so each open dashboard updates live.

An ETS table owned by this process; a real application would use a database.
""".
-behaviour(gen_server).

-export([start_link/0]).
-export([shorten/1]).
-export([follow/1]).
-export([list/0]).
-export([topic/0]).
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).

-define(TABLE, ?MODULE).
%% No look-alikes (0/O, 1/l/I), so a code read aloud or retyped still works.
-define(CODE_CHARS, ~"abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789").

-type link() :: #{code := binary(), url := binary(), clicks := non_neg_integer()}.
-export_type([link/0]).

-spec start_link() -> gen_server:start_ret().
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-doc "Stores `Url` under a fresh short code. Only absolute http(s) URLs.".
-spec shorten(Url) -> {ok, link()} | {error, invalid_url} when
    Url :: binary().
shorten(Url) ->
    case uri_string:parse(string:trim(Url)) of
        #{scheme := Scheme, host := Host} = Parsed when
            (Scheme =:= ~"http" orelse Scheme =:= ~"https"), Host =/= <<>>
        ->
            Link = #{code => code(), url => uri_string:recompose(Parsed), clicks => 0},
            true = ets:insert(?TABLE, row(Link, erlang:system_time(microsecond))),
            ok = arizona_pubsub:broadcast(topic(), {link_created, Link}),
            {ok, Link};
        _NotAWebUrl ->
            {error, invalid_url}
    end.

-doc "Counts a visit to `Code` and gives the URL to redirect to.".
-spec follow(Code) -> {ok, Url} | error when
    Code :: binary(),
    Url :: binary().
follow(Code) ->
    case ets:lookup(?TABLE, Code) of
        [{Code, Url, _Clicks, _At}] ->
            Clicks = ets:update_counter(?TABLE, Code, {3, 1}),
            ok = arizona_pubsub:broadcast(topic(), {link_clicked, Code, Clicks}),
            {ok, Url};
        [] ->
            error
    end.

-doc "Every link, newest first.".
-spec list() -> [link()].
list() ->
    Rows = lists:reverse(lists:keysort(4, ets:tab2list(?TABLE))),
    [#{code => Code, url => Url, clicks => Clicks} || {Code, Url, Clicks, _At} <- Rows].

-doc "Where link changes are broadcast.".
-spec topic() -> {?MODULE, changes}.
topic() ->
    {?MODULE, changes}.

-spec init([]) -> {ok, undefined}.
init([]) ->
    ?TABLE = ets:new(?TABLE, [named_table, public, set, {write_concurrency, true}]),
    %% One link, so the dashboard has something to show the first time.
    Seed = #{
        code => ~"arizona", url => ~"https://github.com/arizona-framework/arizona", clicks => 0
    },
    true = ets:insert(?TABLE, row(Seed, 0)),
    {ok, undefined}.

-spec handle_call(term(), gen_server:from(), undefined) -> {reply, ok, undefined}.
handle_call(_Request, _From, State) ->
    {reply, ok, State}.

-spec handle_cast(term(), undefined) -> {noreply, undefined}.
handle_cast(_Request, State) ->
    {noreply, State}.

row(#{code := Code, url := Url, clicks := Clicks}, At) ->
    {Code, Url, Clicks, At}.

code() ->
    Code = <<
        <<(binary:at(?CODE_CHARS, rand:uniform(byte_size(?CODE_CHARS)) - 1))>>
     || _ <- lists:seq(1, 6)
    >>,
    case ets:member(?TABLE, Code) of
        false -> Code;
        true -> code()
    end.
