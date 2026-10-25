# arizona_nova

[Arizona](https://github.com/arizona-framework/arizona) on the
[Nova](https://github.com/novaframework/nova) web framework.

Nova owns the Cowboy listener and its routing. Arizona serves its own routes on that same
listener through [`arizona_cowboy`](https://github.com/arizona-framework/arizona_cowboy)'s
mounted mode: a request an Arizona route matches (a live page, the live WebSocket, a controller,
an asset, MCP, dev reload) is answered by Arizona, and everything else reaches Nova's router
untouched.

## Installation

```erlang
{deps, [
    nova,
    arizona,
    arizona_cowboy,
    arizona_nova
]}.
```

and list `arizona_nova` in your application's `applications`.

## Setup

Put Arizona's middleware in front of Nova's chain, and declare the Arizona routes:

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

`arizona_nova:middlewares()` is Nova's default chain with `arizona_cowboy_middleware` in
front; pass your own chain to `arizona_nova:middlewares/1` if you customised it.

When `arizona_nova` starts it mounts the routes on Nova's bootstrap listener. When it stops
(before Nova, which it depends on) it drains Arizona's live sessions, which reconnect to the
next node, and unmounts the routes; Nova keeps serving until its own shutdown.

Arizona routes do not pass through Nova's plugins and security handlers: Arizona's own route
`middlewares` (the CSRF Origin check among them) apply.

## Env

| Key | Default | Description |
| --- | ------- | ----------- |
| `routes` | (required) | The Arizona route list |
| `listener` | `nova_listener` | The Nova listener to mount on (the bootstrap application's) |
| `drain_timeout` | `5000` | Milliseconds a stop waits for Arizona's sessions and requests |
| `compress`, `error_page`, `ws_opts`, `max_content_length` | | As in `arizona_cowboy_server` |

## License

[MIT](LICENSE)
