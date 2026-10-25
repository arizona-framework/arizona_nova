# Arizona on Nova: example

A Nova application that serves an Arizona live page beside its own routes, on Nova's one
listener:

- `/` is Arizona: a live counter (`src/example_counter.erl`) in a layout that loads Arizona's
  client (`src/example_layout.erl`). Each click is a WebSocket event the server answers with a
  patch of the slot that changed.
- `/api/time` is Nova: a plain controller (`src/example_api.erl`) from Nova's router
  (`src/example_router.erl`).

The wiring is all in `config/sys.config`: Arizona's middleware in front of Nova's chain, and the
Arizona routes in the `arizona_nova` env.

## Run it

From this directory, against the `arizona_nova` checkout around it:

```sh
mkdir -p _checkouts && ln -s ../.. _checkouts/arizona_nova
rebar3 shell
```

and open <http://localhost:8080> (change `port` in `config/sys.config` if 8080 is taken).
Without the `_checkouts` link it runs `arizona_nova`'s `main` instead.

`rebar3 ct` boots it on a free port and drives the page, a click and the Nova route over the
wire.
