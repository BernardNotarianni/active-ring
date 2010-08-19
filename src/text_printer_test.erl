%%% Copyright (C) Dominic Williams
%%% All rights reserved.
%%% See file COPYING.

-module(text_printer_test).
-test (exports).
-export ([compile_output/0]).
-export ([test_output/0]).
-export ([file_deletion/0]).

compile_output () ->
    P = spawn_link (text_printer, init, [self ()]),
    P ! {self (), compiler, {4, 0, 0}},
    <<"Compiling 4: ">> = receive_io_request (P),
    P ! {self (), compiler, {4, 1, 1}},
    <<".">> = receive_io_request (P),
    P ! {self (), compiler, {4, 2, 2}},
    <<".">> = receive_io_request (P),
    P ! {self (), compiler, {[], [warning ()]}},
    <<"\n/dir/file.erl(12): warning: function foo/1 is unused.\n">> = receive_io_request (P),
    P ! {self (), compiler, {4, 3, 3}},
    <<".">> = receive_io_request (P),
    P ! {self (), compiler, {[error ()], []}},
    <<"\n/dir/file2.erl(15): error: syntax error before: '->'.\n">> = receive_io_request (P),
    P ! {self (), compiler, {4, 4, 3}},
    <<".\n3/4 successfully compiled.\nCannot run tests.\n">> = receive_io_request (P),
    P ! {self (), compiler, {4, 3, 2}},
    <<"Compiling 1: ">> = receive_io_request (P),
    P ! {self (), compiler, {4, 4, 4}},
    <<".\n4/4 successfully compiled.\n">> = receive_io_request (P),
    ok.

test_output () ->
    P = spawn_link (text_printer, init, [self ()]),
    P ! {self (), tester, {4, 0, 0}},
    <<"Testing 4: ">> = receive_io_request (P),
    P ! {self (), tester, {4, 1, 1}},
    <<".">> = receive_io_request (P),
    P ! {self (), tester, {4, 2, 2}},
    <<".">> = receive_io_request (P),
    Error = {error, {undef, [{foo, bar, []}, {toto, titi, 0}]}},
    Stack = {stack_trace, [{eg_test, ok, 0}, {test_runner, run, 0}]},
    Locat = {location, {eg_test, ok, 0, "/dir/eg_test.erl", 12}},
    Dict = dict: from_list ([Error, Stack, Locat]),
    P ! {self (), tester, Dict},
    <<"\n/dir/eg_test.erl(12): failure in {eg_test, ok, 0}"
     "\n   Error: {undef,[{foo,bar,[]},{toto,titi,0}]}"
     "\n   Stack: [{eg_test,ok,0},{test_runner,run,0}]\n">> = receive_io_request (P),
    P ! {self (), tester, {4, 3, 2}},
    <<".">> = receive_io_request (P),
    P ! {self (), tester, {4, 4, 3}},
    <<".\n3/4 successfully tested.\n">> = receive_io_request (P),
    ok.

file_deletion () ->
    P = spawn_link (text_printer, init, [self ()]),
    P ! {self (), compiler, {2, 2, 2}},
    timeout = receive_io_request (P),
    P ! {self (), tester, {1, 0, 0}},
    <<"Testing 1: ">> = receive_io_request (P),
    P ! {self (), tester, {1, 1, 1}},
    <<".\n1/1 successfully tested.\n">> = receive_io_request (P),
    ok.

warning () ->
    {"/dir/file.erl", [{12, erl_lint, {unused_function,{foo,1}}}]}.

error () ->
    {"/dir/file2.erl", [{15, erl_parse, ["syntax error before: ",["'->'"]]}]}.
    
receive_io_request (P) ->
    Self = self (),
    receive
	{io_request, P, Self, {put_chars, unicode, Binary}} ->
	    P ! {io_reply, Self, ok},
	    Binary;
	{io_request, P, Self, {put_chars, Binary}} ->
	    P ! {io_reply, Self, ok},
	    Binary;
	M -> M
    after 1000 -> timeout
    end.
			   
	    
    
