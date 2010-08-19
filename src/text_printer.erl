%%% Copyright (C) Dominic Williams
%%% All rights reserved.
%%% See file COPYING.

-module (text_printer).
-export ([init/1]).

init (Device) ->
    wait (Device).

wait (Device) ->
    receive
	{_, compiler, {Total, Done, _}} when Total > Done ->
	    io: put_chars (Device, io_lib: fwrite ("Compiling ~p: ", [Total - Done])),
	    compiling (Device);
	{_, tester, {Total, Done, _}} when Total > Done ->
	    io: put_chars (Device, io_lib: fwrite ("Testing ~p: ", [Total - Done])),
	    testing (Device);
	_ ->
	    wait (Device)
    end.

compiling (Device) ->
    receive
	{_, compiler, {Total, Total, Successful}} ->
	    io: put_chars (Device, [".\n" | end_compile (Successful, Total)]),
	    wait (Device);
	{_, compiler, {_, _, _}} ->
	    io: put_chars (Device, "."),
	    compiling (Device);
	{_, compiler, {Errors, Warnings}} ->
	    io: put_chars (Device, [$\n | [errors (Errors), warnings (Warnings)]]),
	    compiling (Device)
    end.

testing (Device) ->
    receive
	{_, tester, {Total, Total, Successful}} ->
	    io: put_chars (Device, [".\n" | end_tests (Successful, Total)]),
	    wait (Device);
	{_, tester, {_, _, _}} ->
	    io: put_chars (Device, "."),
	    testing (Device);
	{_, tester, Other} ->
	    Error = dict: fetch (error, Other),
	    Stack = dict: fetch (stack_trace, Other),
	    {M, F, A, File, Line} = dict: fetch (location, Other),
	    Output = io_lib: fwrite (
		     "~n~s(~p): failure in {~p, ~p, ~p}~n"
		     "   Error: ~p~n"
		     "   Stack: ~p~n", [File, Line, M, F, A, Error, Stack]),
	    io: put_chars (Device, Output),
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
