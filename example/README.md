# Arizona on Nova: a link shortener

A small Nova application where the two frameworks split the work on one listener:

- **Nova** follows short links. `/s/:code` redirects to the stored URL and counts the visit
  (`src/example_links_controller.erl`), and `/api/links` lists them as JSON. Plain Nova routes
  (`src/example_router.erl`).
- **Arizona** is the dashboard at `/` (`src/example_dashboard.erl`): shorten a URL, and watch
  each link's clicks climb live, in every open tab, the moment someone follows it through Nova.
  No polling: the visit Nova counts is broadcast, and the dashboard patches just that number.

They share a tiny store (`src/example_links.erl`, an ETS table) and Arizona's pubsub. The wiring
is all in `config/sys.config`: Arizona's middleware in front of Nova's chain, and the Arizona
routes in the `arizona_nova` env.

## Run it

From this directory, against the `arizona_nova` checkout around it:

```sh
mkdir -p _checkouts && ln -s ../.. _checkouts/arizona_nova
rebar3 shell
```

and open <http://localhost:8080> (change `port` in `config/sys.config` if 8080 is taken).
Without the `_checkouts` link it runs `arizona_nova`'s `main` instead.

`rebar3 ct` boots it on a free port and drives the whole loop over the wire: a link shortened
on the dashboard, followed through Nova's redirect, and its click arriving back live.
