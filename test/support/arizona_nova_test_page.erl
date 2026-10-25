-module(arizona_nova_test_page).
-moduledoc "**TEST FIXTURE.** A live view served by Arizona on Nova's listener.".
-include_lib("arizona/include/arizona_stateful.hrl").
-export([mount/1, render/1]).

-spec mount(az:bindings()) -> az:mount_ret().
mount(_Bindings) ->
    {#{id => ~"nova_page", title => ~"Arizona on Nova"}, #{}}.

-spec render(az:bindings()) -> az:template().
render(Bindings) ->
    ?html({'div', [{id, ?get(id)}], [?get(title)]}).
