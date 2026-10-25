-module(arizona_nova).
-moduledoc """
Arizona on the Nova web framework.

Nova owns the Cowboy listener and its routing; Arizona serves its own routes on
that same listener through `arizona_cowboy`'s mounted mode
(`arizona_cowboy_server:mount/2` and `arizona_cowboy_middleware`). A request an
Arizona route matches is answered by Arizona -- pages, the live WebSocket,
controllers, assets, MCP, dev reload -- and everything else reaches Nova's
router untouched.

## Setup

Put `arizona_cowboy_middleware` in front of Nova's middleware chain, and declare
the Arizona routes in the `arizona_nova` env:

```erlang
[
    {nova, [
        {bootstrap_application, my_app},
        {cowboy_configuration, #{
            port => 8080,
            middleware_handlers => arizona_nova:middlewares()
        }}
    ]},
    {arizona_nova, [
        {routes, [
            {live, ~"/", my_page, #{layouts => [{my_layout, render}]}},
            {ws, ~"/ws", #{}},
            {asset, ~"/assets", {priv_dir, arizona, "static/assets/js"}}
        ]}
    ]}
].
```

and list `arizona_nova` in your application's `applications`. When it starts it
mounts the routes on Nova's bootstrap listener; when it stops (before Nova,
which it depends on) it drains Arizona's live sessions, which reconnect to the
next node.

## Env

- `routes` -- the Arizona route list (required).
- `listener` -- the Nova listener to mount on (default `nova_listener`, the
  bootstrap application's).
- `drain_timeout` -- milliseconds a stop waits for Arizona's sessions and
  requests (default `5000`).
- `compress`, `error_page`, `ws_opts`, `max_content_length` -- as in
  `arizona_cowboy_server`.

Arizona routes do not pass through Nova's plugins and security handlers:
Arizona's own route `middlewares` (the CSRF Origin check among them) apply.
""".

%% --------------------------------------------------------------------
%% API function exports
%% --------------------------------------------------------------------

-export([middlewares/0]).
-export([middlewares/1]).

%% --------------------------------------------------------------------
%% Ignore xref warnings
%% --------------------------------------------------------------------

%% Called from the application's Nova config.
-ignore_xref([middlewares/0]).
-ignore_xref([middlewares/1]).

%% --------------------------------------------------------------------
%% API Functions
%% --------------------------------------------------------------------

-doc """
Nova's default middleware chain with `arizona_cowboy_middleware` in front, for
the `middleware_handlers` key of Nova's `cowboy_configuration`.
""".
-spec middlewares() -> [module()].
middlewares() ->
    middlewares([
        nova_router,
        nova_plugin_handler,
        nova_security_handler,
        nova_handler,
        nova_plugin_handler
    ]).

-doc "`NovaMiddlewares` (a customised Nova chain) with `arizona_cowboy_middleware` in front.".
-spec middlewares(NovaMiddlewares) -> [module()] when
    NovaMiddlewares :: [module()].
middlewares(NovaMiddlewares) ->
    [arizona_cowboy_middleware | NovaMiddlewares].
