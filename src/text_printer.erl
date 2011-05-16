%%% Copyright (C) Dominic Williams
%%% All rights reserved.
%%% See file COPYING.

-module (text_printer).
-export ([init/2]).

init (Device, GreenBar) ->
    wait (Device, GreenBar).

wait (Device, GreenBar) ->
    receive
	stop ->
	    bye;
	{totals, {M, C, E, _, _, _}} when M > C + E ->
	    io: put_chars (Device, io_lib: fwrite ("Compiling: ", [])),
	    compiling (Device, GreenBar);
	{totals, {M, C, E, T, P, F}} when M == C + E  andalso T > P + F ->
	    N = T - P - F,
	    io: put_chars (Device, io_lib: fwrite ("Testing ~p: ", [N])),
 	    testing (Device, GreenBar);
	_ ->
	    wait (Device, GreenBar)
    end.

compiling (Device, GreenBar) ->
    receive
	{compile, {_, ok, []}} ->
	    io: put_chars (Device, "."),
	    compiling (Device, GreenBar);
	{compile, {_, ok, Warnings}} ->
	    io: put_chars (Device, [$\n | warnings (Warnings)]),
	    compiling (Device, GreenBar);
	{compile, {_, error, {Errors, Warnings}}} ->
	    Cs = [$\n | [errors (Errors), warnings (Warnings)]],
	    io: put_chars (Device, Cs),
	    compiling (Device, GreenBar);
	{totals, {M, C, E, T, P, F}} when M == C + E ->
	    io: put_chars (Device, ["\n" | end_compile (C, M)]),
	    if
		E == 0 andalso T > P + F ->
		    N = T - P - F,
		    Chars = io_lib: fwrite ("Testing ~p: ", [N]),
		    io: put_chars (Device, Chars),
		    testing (Device, GreenBar);
		true ->
		    wait (Device, GreenBar)
	    end;
	_ ->
	    compiling (Device, GreenBar)
    end.

testing (Device, GreenBar) ->
    receive
	{totals, {_, _, _, T, P, F}} when T == P + F ->
	    io: put_chars (Device, ["\n" | end_tests (P, T)]),
	    if
		P == T ->
		    GreenBar ! green;
		true ->
		    GreenBar ! red
	    end,
	    wait (Device, GreenBar);
	{test, {_, _, _, pass}} ->
	    io: put_chars (Device, "."),
	    testing (Device, GreenBar);
	{test, {_, _, _, {fail, Reason}}} ->
	    Error = dict: fetch (error, Reason),
	    Stack = dict: fetch (stack_trace, Reason),
	    {M, F, A, File, Line} = dict: fetch (location, Reason),
	    Output = io_lib: fwrite (
		     "~n~s(~p): failure in {~p, ~p, ~p}~n"
		     "   Error: ~p~n"
		     "   Stack: ~p~n", [File, Line, M, F, A, Error, Stack]),
	    io: put_chars (Device, Output),
	    testing (Device, GreenBar);
	_ ->
	    testing (Device, GreenBar)
    end.

warnings (Ws) -> items (warning, Ws).
errors (Es) -> items (error, Es).

items (Label, [{File, Xs} | Tail]) ->
    Item = [[File, item (Label, X), $\n] || X <- Xs],
    [Item | items (Label, Tail)];
items (_, []) ->
    [].

item (Label, {Line, Stage, Message}) ->
    io_lib: fwrite ("(~p): ~s: ~s.", [Line, Label, Stage: format_error (Message)]).

end_compile (Successful, Total) ->
    Compiled = io_lib: fwrite ("~p/~p successfully compiled.~n", [Successful, Total]),
    [Compiled, cannot_test (Successful, Total)].

cannot_test (Total, Total) ->
    [];
cannot_test (_, _) ->
    "Cannot run tests.\n".

end_tests (Successful, Total) ->
    io_lib: fwrite ("~p/~p successfully tested.~n", [Successful, Total]).
