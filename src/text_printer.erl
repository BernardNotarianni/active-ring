%%% Copyright (C) Dominic Williams
%%% All rights reserved.
%%% See file COPYING.

-module (text_printer).
-export ([init/1]).

init (Device) ->
    wait (Device).

wait (Device) ->
    receive
	stop ->
	    bye;
	{totals, {M, C, E, _, _, _}} when M > C + E ->
	    io: put_chars (Device, io_lib: fwrite ("Compiling: ", [])),
	    compiling (Device);
	{totals, {M, C, E, T, P, F}} when M == C + E  andalso T > P + F ->
	    N = T - P - F,
	    io: put_chars (Device, io_lib: fwrite ("Testing ~p: ", [N])),
 	    testing (Device);
	_ ->
	    wait (Device)
    end.

compiling (Device) ->
    receive
	{compile, {_, ok, []}} ->
	    io: put_chars (Device, "."),
	    compiling (Device);
	{compile, {_, ok, Warnings}} ->
	    io: put_chars (Device, [$\n | warnings (Warnings)]),
	    compiling (Device);
	{compile, {_, error, {Errors, Warnings}}} ->
	    Cs = [$\n | [errors (Errors), warnings (Warnings)]],
	    io: put_chars (Device, Cs),
	    compiling (Device);
	{totals, {M, C, E, T, P, F}} when M == C + E ->
	    io: put_chars (Device, ["\n" | end_compile (C, M)]),
	    if
		E == 0 andalso T > P + F ->
		    N = T - P - F,
		    Chars = io_lib: fwrite ("Testing ~p: ", [N]),
		    io: put_chars (Device, Chars),
		    testing (Device);
		true ->
		    wait (Device)
	    end;
	_ ->
	    compiling (Device)
    end.

testing (Device) ->
    receive
	{totals, {_, _, _, T, P, F}} when T == P + F ->
	    io: put_chars (Device, ["\n" | end_tests (P, T)]),
	    wait (Device);
	{test, {_, _, _, pass}} ->
	    io: put_chars (Device, "."),
	    testing (Device);
	{test, {_, _, _, {fail, Reason}}} ->
	    Error = dict: fetch (error, Reason),
	    Stack = dict: fetch (stack_trace, Reason),
	    {M, F, A, File, Line} = dict: fetch (location, Reason),
	    Output = io_lib: fwrite (
		     "~n~s(~p): failure in {~p, ~p, ~p}~n"
		     "   Error: ~p~n"
		     "   Stack: ~p~n", [File, Line, M, F, A, Error, Stack]),
	    io: put_chars (Device, Output),
	    testing (Device);
	_ ->
	    testing (Device)
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
