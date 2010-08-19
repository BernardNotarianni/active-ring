%%% Copyright (c) Dominic Williams, Nicolas Charpentier
%%% All rights reserved.
%%% See file COPYING.

-module (tests).
-export ([filter_by_attribute/1]).

filter_by_attribute (Binary) ->
    {ok, Chunks} = beam_lib: chunks (Binary, [attributes, compile_info]),
    {Module, [{attributes, Attributes}, {compile_info, Info}]} = Chunks,
    {value, {source, Filename}} = lists: keysearch (source, 1, Info),
    Declarations = lists: flatten ([T || {test, T} <- Attributes]),
    Tests = filter (Binary, Declarations, []),
    {Filename, Module, Tests}.

filter (Binary, [exports | Tail], Acc) ->
    {ok, Chunks} = beam_lib: chunks (Binary, [exports]),
    {_, [{exports, Exports}]} = Chunks,
    Tests = lists: foldl (fun testable_export/2, [], Exports),
    filter (Binary, Tail, [Tests | Acc]);
filter (Binary, [Test | Tail], Acc) ->
    filter (Binary, Tail, [Test | Acc]);
filter (_, [], Acc) ->
    lists: flatten (Acc).

testable_export ({module_info, _}, Fs) -> Fs;
testable_export ({F, 0}, Fs) -> [F | Fs];
testable_export (_, Fs) -> Fs.
