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
                {title, [], [~"Arizona on Nova"]}
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
