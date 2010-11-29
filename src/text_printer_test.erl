%%% Copyright (C) Dominic Williams
%%% All rights reserved.
%%% See file COPYING.

-module(text_printer_test).
-test (exports).
-export ([compile_output_no_tests/0]).
-export ([test_output/0]).
-export ([file_deletion/0]).
-export ([compile_output_with_tests/0]).

compile_output_no_tests () ->
    P = spawn_link (text_printer, init, [self ()]),
    P ! {totals, {4, 0, 0, 0, 0, 0}},
    <<"Compiling: ">> = receive_io_request (P),
    P ! {compile, {mymodule, ok, []}},
    <<".">> = receive_io_request (P),
    P ! {totals, {4, 1, 0, 0, 0, 0}},
    P ! {compile, {file, ok, [warning ()]}},
    W = receive_io_request (P),
    <<"\n/dir/file.erl(12): warning: function foo/1 is unused.\n">> = W,
    P ! {totals, {4, 2, 0, 0, 0, 0}},
    P ! {compile, {other, ok, []}},
    <<".">> = receive_io_request (P),
    P ! {totals, {4, 3, 0, 0, 0, 0}},
    P ! {compile, {file2, error, {[error ()], []}}},
    E = receive_io_request (P),
    <<"\n/dir/file2.erl(15): error: syntax error before: '->'.\n">> = E,
    P ! {totals, {4, 3, 1, 0, 0, 0}},
    S = receive_io_request (P),
    <<"\n3/4 successfully compiled.\nCannot run tests.\n">> = S,
    P ! {totals, {4, 3, 0, 0, 0, 0}},
    <<"Compiling: ">> = receive_io_request (P),
    P ! {compile, {file2, ok, []}},
    <<".">> = receive_io_request (P),
    P ! {totals, {4, 4, 0, 0, 0, 0}},
    <<"\n4/4 successfully compiled.\n">> = receive_io_request (P),
    {timeout, timeout} = {timeout, receive_io_request (P)},
    ok.

compile_output_with_tests () ->
    P = spawn_link (text_printer, init, [self ()]),
    P ! {totals, {2, 0, 0, 0, 0, 0}},
    <<"Compiling: ">> = receive_io_request (P),
    P ! {compile, {mytests, ok, []}},
    <<".">> = receive_io_request (P),
    P ! {totals, {2, 1, 0, 3, 0, 0}},
    P ! {compile, {mymodule, error, {[error ()], []}}},
    E = receive_io_request (P),
    <<"\n/dir/file2.erl(15): error: syntax error before: '->'.\n">> = E,
    P ! {totals, {2, 1, 1, 3, 0, 0}},
    S = receive_io_request (P),
    <<"\n1/2 successfully compiled.\nCannot run tests.\n">> = S,
    {timeout, timeout} = {timeout, receive_io_request (P)},
    ok.

test_output () ->
    P = spawn_link (text_printer, init, [self ()]),
    P ! {totals, {1, 0, 0, 0, 0, 0}},
    <<"Compiling: ">> = receive_io_request (P),
    P ! {compile, {mymodule, ok, []}},
    <<".">> = receive_io_request (P),
    P ! {totals, {1, 1, 0, 2, 0, 0}},
    <<"\n1/1 successfully compiled.\n">> = receive_io_request (P),
    <<"Testing 2: ">> = receive_io_request (P),
    P ! {test, {mymodule, test1, 0, pass}},
    {dot, <<".">>} = {dot, receive_io_request (P)},
    P ! {totals, {1, 1, 0, 2, 1, 0}},
    Error = {error, {undef, [{foo, bar, []}, {toto, titi, 0}]}},
    Stack = {stack_trace, [{eg_test, ok, 0}, {test_runner, run, 0}]},
    Locat = {location, {eg_test, ok, 0, "/dir/eg_test.erl", 12}},
    Dict = dict: from_list ([Error, Stack, Locat]),
    P ! {test, {mymodule, test2, 0, {fail, Dict}}},
    E = receive_io_request (P),
    <<"\n/dir/eg_test.erl(12): failure in {eg_test, ok, 0}"
     "\n   Error: {undef,[{foo,bar,[]},{toto,titi,0}]}"
     "\n   Stack: [{eg_test,ok,0},{test_runner,run,0}]\n">> = E,
    P ! {totals, {1, 1, 0, 2, 1, 1}},
    <<"\n1/2 successfully tested.\n">> = receive_io_request (P),
    ok.

file_deletion () ->
    P = spawn_link (text_printer, init, [self ()]),
    P ! {totals, {2, 0, 0, 0, 0, 0}},
    <<"Compiling: ">> = receive_io_request (P),
    P ! {compile, {mymodule, ok, []}},
    <<".">> = receive_io_request (P),
    P ! {totals, {2, 1, 0, 0, 0, 0}},
    P ! {totals, {2, 1, 0, 0, 0, 0}},
    P ! {compile, {mytests, ok, []}},
    <<".">> = receive_io_request (P),
    P ! {totals, {2, 2, 0, 1, 0, 0}},
    <<"\n2/2 successfully compiled.\n">> = receive_io_request (P),
    <<"Testing 1: ">> = receive_io_request (P),
    P ! {test, {mytests, test, 0, pass}},
    <<".">> = receive_io_request (P),
    P ! {totals, {2, 2, 0, 1, 1, 0}},
    <<"\n1/1 successfully tested.\n">> = receive_io_request (P),
    P ! {totals, {1, 1, 0, 1, 0, 0}},
    <<"Testing 1: ">> = receive_io_request (P),
    P ! {test, {mytests, test, 0, pass}},
    <<".">> = receive_io_request (P),
    P ! {totals, {1, 1, 0, 1, 1, 0}},
    <<"\n1/1 successfully tested.\n">> = receive_io_request (P),
    timeout = receive_io_request (P),
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
			   
	    
    
