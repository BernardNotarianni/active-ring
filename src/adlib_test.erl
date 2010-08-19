%%% Copyright (C) 2009 Dominic Williams
%%% All rights reserved.
%%% See file COPYING.

-module(adlib_test).
-test (exports).
-export ([dict_compare_empty/0]).
-export ([dict_compare_empty_with_non_empty/0]).
-export ([dict_compare/0]).

dict_compare_empty () ->
    Empty = dict: new (),
    Result = adlib: compare_dict (Empty, Empty),
    Keys = [new, lost, changed, same],
    [Empty, Empty, Empty, Empty] = [dict: fetch (Key, Result) || Key <- Keys],
    ok.

dict_compare_empty_with_non_empty () ->
    Empty = dict: new (),
    Non_empty = dict: store (mykey, myvalue, Empty),
    Keys = [new, lost, changed, same],
    Result1 = adlib: compare_dict (Non_empty, Empty),
    [Non_empty, Empty, Empty, Empty] = [dict: fetch (Key, Result1) || Key <- Keys],
    Result2 = adlib: compare_dict (Empty, Non_empty),
    [Empty, Non_empty, Empty, Empty] = [dict: fetch (Key, Result2) || Key <- Keys],
    ok.
    
dict_compare () ->
    Original_list = [{a,a},{b,b},{c,c},{d,d},{e,e},{f,f}],
    Modified_list = [{a,b},{b,b},{d,d},{e,f},{g,g},{h,h}],
    Original = dict: from_list (Original_list),
    Modified = dict: from_list (Modified_list),
    Result = adlib: compare_dict (Modified, Original),
    Keys = [new, lost, changed, same],
    [New, Lost, Changed, Same] = [dict: fetch (Key, Result) || Key <- Keys],
    Expected_new = dict: from_list ([{g,g},{h,h}]),
    Expected_lost = dict: from_list ([{c,c},{f,f}]),
    Expected_changed = dict: from_list ([{a,{b,a}},{e,{f,e}}]),
    Expected_same = dict: from_list ([{b,b},{d,d}]),
    {new, Expected_new} = {new, New},
    {lost, Expected_lost} = {lost, Lost},
    {changed, Expected_changed} = {changed, Changed},
    {same, Expected_same} = {same, Same}.
    
