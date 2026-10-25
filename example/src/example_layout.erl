-module(example_layout).
-moduledoc "The page shell: loads Arizona's client, which opens the live WebSocket.".
-include_lib("arizona/include/arizona_stateless.hrl").

-export([render/1]).

-spec render(az:bindings()) -> az:template().
render(Bindings) ->
    ?html([
        ~"<!DOCTYPE html>",
        {html, [], [
            {head, [], [
                {meta, [{charset, ~"utf-8"}]},
                {meta, [{name, ~"viewport"}, {content, ~"width=device-width, initial-scale=1"}]},
                {title, [], [~"Shorten · Arizona on Nova"]},
                {style, [], [
                    ~"""
                    :root {
                        color-scheme: light dark;
                        --bg: #f4f1ea; --card: #fffdf8; --ink: #2b2620; --muted: #8a8174;
                        --accent: #c2410c; --ring: #e7e0d4; --bad: #b91c1c;
                    }
                    @media (prefers-color-scheme: dark) {
                        :root {
                            --bg: #17140f; --card: #211d17; --ink: #f1ebe0; --muted: #9c9284;
                            --accent: #fb923c; --ring: #332c23; --bad: #f87171;
                        }
                    }
                    * { box-sizing: border-box; }
                    body {
                        margin: 0; min-height: 100vh; padding: 48px 16px;
                        background: var(--bg); color: var(--ink);
                        font: 16px/1.5 system-ui, sans-serif;
                    }
                    main {
                        width: min(100%, 560px); margin: 0 auto; padding: 32px;
                        background: var(--card); border: 1px solid var(--ring);
                        border-radius: 20px; box-shadow: 0 12px 40px rgb(0 0 0 / 0.08);
                    }
                    h1 { margin: 0; font-size: 1.6rem; letter-spacing: -0.02em; }
                    .tag { margin: 2px 0 24px; color: var(--muted); }
                    .shorten { display: flex; gap: 8px; }
                    input, button { font: inherit; border-radius: 12px; }
                    input {
                        flex: 1; min-width: 0; padding: 12px 14px; color: var(--ink);
                        background: var(--bg); border: 1px solid var(--ring);
                    }
                    input:focus { outline: 2px solid var(--accent); outline-offset: 1px; }
                    button {
                        padding: 12px 18px; border: 0; cursor: pointer; font-weight: 600;
                        background: var(--accent); color: #fff;
                    }
                    button:active { transform: scale(0.97); }
                    .error { min-height: 1.5em; margin: 6px 0 12px; color: var(--bad); font-size: 0.9rem; }
                    .links { list-style: none; margin: 0; padding: 0; }
                    .links li {
                        display: flex; align-items: center; gap: 16px; padding: 14px 0;
                        border-top: 1px solid var(--ring);
                    }
                    .link { flex: 1; min-width: 0; display: grid; }
                    .link a { color: var(--accent); font-weight: 600; text-decoration: none; }
                    .link a:hover { text-decoration: underline; }
                    .url {
                        color: var(--muted); font-size: 0.85rem;
                        overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
                    }
                    .clicks { color: var(--muted); font-size: 0.85rem; white-space: nowrap; }
                    .clicks strong {
                        color: var(--ink); font-size: 1.15rem; font-variant-numeric: tabular-nums;
                    }
                    footer {
                        margin-top: 20px; padding-top: 16px; border-top: 1px solid var(--ring);
                        color: var(--muted); font-size: 0.85rem;
                    }
                    footer a { color: var(--accent); }
                    """
                ]}
            ]},
            {body, [], [
                ?inner_content,
                {script, [{type, ~"module"}], [
                    ~"""
                    import { connect } from '/assets/arizona.min.js';
                    connect('/ws');
                    """
                ]}
            ]}
        ]}
    ]).
