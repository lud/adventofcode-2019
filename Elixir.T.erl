-file("lib/t.ex", 1).

-module('Elixir.T').

-compile([no_auto_import]).

-export(['__info__'/1,test/1]).

-spec '__info__'(attributes | compile | functions | macros | md5 |
                 module | deprecated) ->
                    any().

'__info__'(module) ->
    'Elixir.T';
'__info__'(functions) ->
    [{test, 1}];
'__info__'(macros) ->
    [];
'__info__'(Key = attributes) ->
    erlang:get_module_info('Elixir.T', Key);
'__info__'(Key = compile) ->
    erlang:get_module_info('Elixir.T', Key);
'__info__'(Key = md5) ->
    erlang:get_module_info('Elixir.T', Key);
'__info__'(deprecated) ->
    [].

test(_thing@1) ->
    _thing@1:tt(hello).

