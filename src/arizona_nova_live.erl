-module(arizona_nova_live).

-moduledoc """
Arizona LiveView integration helpers for Nova routes.

Provides `live/1,2,3` to create Nova-compatible route callbacks that
render Arizona views on the initial HTTP request.

## Example

```erlang
-module(my_app_router).
-behaviour(nova_router).
-export([routes/1]).

routes(_Env) ->
    [#{prefix => "",
       security => false,
       routes => [
           {"/", arizona_nova_live:live(my_home_view), #{methods => [get]}},
           {"/counter", arizona_nova_live:live(my_counter_view, #{}, #{count => 0}), #{methods => [get]}},
           {"/ws", arizona_nova_ws, #{protocol => ws}},
           {"/assets/[...]", "static/assets"}
       ]}].
```
""".

-export([live/1, live/2, live/3]).

-doc "Create a Nova route callback that renders an Arizona view.".
-spec live(module()) -> fun((map()) -> {status, 200, map(), binary()}).
live(Handler) ->
    live(Handler, #{}, #{}).

-doc "Create a Nova route callback with route options (layout, on_mount).".
-spec live(module(), map()) -> fun((map()) -> {status, 200, map(), binary()}).
live(Handler, Opts) ->
    live(Handler, Opts, #{}).

-doc "Create a Nova route callback with route options and initial bindings.".
-spec live(module(), map(), map()) -> fun((map()) -> {status, 200, map(), binary()}).
live(Handler, Opts, Bindings) ->
    fun(Req) ->
        PathBindings = cowboy_req:bindings(Req),
        QueryParams = maps:from_list(cowboy_req:parse_qs(Req)),
        MergedBindings = maps:merge(maps:merge(Bindings, PathBindings), QueryParams),
        RenderOpts = #{
            bindings => MergedBindings,
            layout => maps:get(layout, Opts, undefined),
            on_mount => maps:get(on_mount, Opts, [])
        },
        Html = arizona_render:render_to_iolist(Handler, RenderOpts),
        {status, 200, #{<<"content-type">> => <<"text/html">>}, iolist_to_binary(Html)}
    end.
