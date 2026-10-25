-module(example_dashboard).
-moduledoc """
Arizona's side: shorten a link, and watch every link's clicks climb live as
people follow them through Nova's `/s/:code` route, in every open tab.
""".
-include_lib("arizona/include/arizona_stateful.hrl").

-export([mount/1]).
-export([render/1]).
-export([handle_event/3]).
-export([handle_info/2]).

-spec mount(az:bindings()) -> az:mount_ret().
mount(_Bindings) ->
    %% Over the socket only: the first render is plain HTML.
    ?connected andalso ?subscribe(example_links:topic()),
    Links = arizona_stream:new(fun(#{code := Code}) -> Code end, example_links:list()),
    {#{id => ~"dashboard", links => Links, error => <<>>}, #{}}.

-spec render(az:bindings()) -> az:template().
render(Bindings) ->
    ?html(
        {main, [{id, ?get(id)}], [
            {header, [], [
                {h1, [], [~"Shorten"]},
                {p, [{class, ~"tag"}], [~"Nova redirects. Arizona counts, live."]}
            ]},
            {form,
                [
                    {class, ~"shorten"},
                    {az_submit, arizona_js:push_event(~"shorten")},
                    az_form_reset
                ],
                [
                    {input, [
                        {name, ~"url"},
                        {type, ~"url"},
                        {required, true},
                        {placeholder, ~"https://example.com/a/long/address"},
                        {'aria-label', ~"URL to shorten"}
                    ]},
                    {button, [{type, ~"submit"}], [~"Shorten"]}
                ]},
            {p, [{class, ~"error"}, {role, ~"alert"}], [?get(error)]},
            {ul, [{class, ~"links"}], [
                ?each(
                    fun(#{code := Code, url := Url, clicks := Clicks}, Key) ->
                        {li, [{az_key, Key}], [
                            {'div', [{class, ~"link"}], [
                                {a, [{href, [~"/s/", Code]}, {target, ~"_blank"}], [~"/s/", Code]},
                                {span, [{class, ~"url"}, {title, Url}], [Url]}
                            ]},
                            {span, [{class, ~"clicks"}], [
                                {strong, [], [Clicks]},
                                case Clicks of
                                    1 -> ~" click";
                                    _ -> ~" clicks"
                                end
                            ]}
                        ]}
                    end,
                    ?get(links)
                )
            ]},
            {footer, [], [
                ~"Every link is also JSON at ",
                {a, [{href, ~"/api/links"}], [~"/api/links"]},
                ~", served by Nova."
            ]}
        ]}
    ).

-spec handle_event(az:event_name(), az:event_payload(), az:bindings()) ->
    az:handle_event_ret().
handle_event(~"shorten", #{~"url" := Url}, Bindings) ->
    %% The new link arrives here like any other, through the broadcast.
    case example_links:shorten(Url) of
        {ok, _Link} -> {Bindings#{error => <<>>}, #{}, []};
        {error, invalid_url} -> {Bindings#{error => ~"That is not an http(s) link."}, #{}, []}
    end.

-spec handle_info(term(), az:bindings()) -> az:handle_info_ret().
handle_info({link_created, Link}, #{links := Links} = Bindings) ->
    {Bindings#{links => arizona_stream:insert(Links, Link, 0)}, #{}, []};
handle_info({link_clicked, Code, Clicks}, #{links := Links} = Bindings) ->
    Link = arizona_stream:get(Links, Code),
    {Bindings#{links => arizona_stream:update(Links, Code, Link#{clicks => Clicks})}, #{}, []}.
