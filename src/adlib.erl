%%% Copyright (C) Dominic Williams
%%% All rights reserved.
%%% See file COPYING.

-module (adlib).
-export ([compare_dict/2]).

compare_dict (Modified, Original) ->
    Init_fun = fun (Key, Dict) -> dict: store (Key, dict: new (), Dict) end,
    Init = lists: foldl (Init_fun, dict: new (), [lost, changed, same]),
    {Intermediate, New} = dict: fold (fun compare_dict/3, {Init, Modified}, Original),
    dict: store (new, New, Intermediate).

compare_dict (Key, Value, {Result, Modified}) ->
    compare_dict (dict: find (Key, Modified), Key, Value, Result, Modified).

compare_dict (error, Key, Value, Result, Modified) ->
    Lost = dict: store (Key, Value, dict: fetch (lost, Result)),
    {dict: store (lost, Lost, Result), Modified};
compare_dict ({ok, Value}, Key, Value, Result, Modified) ->
    Same = dict: store (Key, Value, dict: fetch (same, Result)),
    {dict: store (same, Same, Result), dict: erase (Key, Modified)};
compare_dict ({ok, New_value}, Key, Value, Result, Modified) ->
    Changed = dict: store (Key, {New_value, Value}, dict: fetch (changed, Result)),
    {dict: store (changed, Changed, Result), dict: erase (Key, Modified)}.
