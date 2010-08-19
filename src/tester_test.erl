%%% Copyright (C) Dominic Williams, Nicolas Charpentier
%%% All rights reserved.
%%% See file COPYING.

-module (tester_test).
-export ([run_all/0]).
-export ([tree/0]).
-test (run_all).

run_all () ->
    Name = list_to_atom (fixtures: unique_string ()),
    {ok, Host} = inet: gethostname (),
    Host_atom = list_to_atom (Host),
    {ok, Node} = slave: start_link (Host_atom, Name),
    ok = run_all (Node),
    ok = slave: stop (Node).

run_all (Node) ->
    Fun = run_fun (Node),
    ok = fixtures: use_tree (tree (), Fun).

run_fun (Node) ->
    fun (Root, _) ->
	    runs_a_test (Node, Root),
	    reruns_a_test_when_given_module (Node, Root),
	    runs_given_tests (Node, Root),
	    runs_given_test_sequence (Node, Root),
	    reloads_corrected_module (Node, Root),
	    deletes_a_module  (Node, Root),
	    deletes_a_test_module  (Node, Root),
	    runs_new_tests_failed_then_successful  (Node, Root),
	    provides_failed_test_and_location (Node, Root),
	    stops (Node, Root),
	    ok
    end.

send (Root, Modules, Tester) ->
    Paths = [modules: to_file_name (M, Root) || M <- Modules],
    Binaries = [modules: to_binary (P) || P <- Paths],
    false = lists: any (fun (M) -> code: is_loaded (M) end, Modules),
    Tester ! {run, Binaries},
    Results = receive_all ([]),
    false = lists: any (fun (M) -> code: is_loaded (M) end, Modules),
    Results.

notify_me () ->
    Self = self (),
    fun (M) -> Self ! M end.

runs_a_test (Node, Root) ->
    Tester = spawn_link (tester, init, [notify_me (), Node]),
    [{2, 0, 0}, {2, 1, 1}, Error, {2, 2, 1}] = send (Root, [eg_test], Tester),
    {badmatch, nok} = dict: fetch (error, Error), 
    [{eg_test, nok, 0} | _] = dict: fetch (stack_trace, Error),
    ok.

reruns_a_test_when_given_module (Node, Root) ->
    Tester = spawn_link (tester, init, [notify_me (), Node]),
    [{1, 0, 0}, Error, {1, 1, 0}] = send (Root, [eg_test_of_code], Tester),
    undef = dict: fetch (error, Error),
    Stack_trace = dict: fetch (stack_trace, Error),
    [{eg_code, ok, []}, {eg_test_of_code, ok, 0} | _] = Stack_trace,
    [{1, 0, 0}, {1, 1, 1}] = send (Root, [eg_code], Tester),
    ok.

runs_given_test_sequence (Node, Root) ->
    Tester = spawn_link (tester, init, [notify_me (), Node]),
    [{2, 0, 0}, {2, 1, 1}, _, {2, 2, 1}] = send (Root, [eg_test], Tester),
    [{2, 0, 0}, _, {2, 1, 0}, {2, 2, 1}] = send (Root, [eg_code], Tester),
    Result = send (Root, [eg_test_of_code], Tester),
    [{3, 0, 0}, {3, 1, 1}, _, {3, 2, 1}, {3, 3, 2}] = Result,
    ok.

runs_given_tests (Node, Root) ->
    Tester = spawn_link (tester, init, [notify_me (), Node]),
    Modules = [eg_test, eg_code, eg_test_of_code],
    Result = send (Root, Modules, Tester),
    [{3, 0, 0}, {3, 1, 1}, _, {3, 2, 1}, {3, 3, 2}] = Result,
    ok.

reloads_corrected_module (Node, _) ->
    Tester = spawn_link (tester, init, [notify_me (), Node]),
    Binary = modules: forms_to_binary (eg_test_form ("nok")),
    Tester ! {run, [Binary]},
    [{1, 0, 0}, Error, {1, 1, 0}] = receive_all ([]),
    Correct_binary = modules: forms_to_binary (eg_test_form ("ok")),
    Tester ! {run, [Correct_binary]},
    [{1, 0, 0}, {1, 1, 1}] = receive_all ([]),
    Tester ! {run, [Binary]},
    [{1, 0, 0}, Error, {1, 1, 0}] = receive_all ([]),
    ok.

deletes_a_module (Node, Root) ->
    Tester = spawn_link (tester, init, [notify_me (), Node]),
    [{1, 0, 0}, {1, 1, 1}] = send (Root, [eg_test_of_code], Tester),
    Tester ! {delete,[eg_code]},
    [{1, 0, 0}, Error, {1, 1, 0}] = receive_all ([]),
    undef = dict: fetch (error, Error),
    [{eg_code, ok, []} | _] = dict: fetch (stack_trace, Error),
    [{1, 0, 0}, {1, 1, 1}] = send (Root, [eg_code], Tester),
    ok.

deletes_a_test_module (Node, Root) ->
    Tester = spawn_link (tester, init, [notify_me (), Node]),
    [{1, 0, 0}, {1, 1, 1}] = send (Root, [eg_test_of_code], Tester),
    Tester ! {delete,[eg_test_of_code]},
    [{0, 0, 0}] = receive_all ([]),
    [{1, 0, 0}, {1, 1, 1}] = send (Root, [eg_test_of_code], Tester),
    ok.

runs_new_tests_failed_then_successful (Node, Root) ->
    Tester = spawn_link (tester, init, [notify_me (), Node]),
    Modules = [eg_code, eg_test_of_code_failed],
    Result = send (Root, Modules, Tester),
    [{1, 0, 0}, Error, {1, 1, 0}] = Result,
    {badmatch, bad_eg_code} = dict: fetch (error, Error),
    Result_after_new_test = send (Root, [eg_test_not_exports], Tester),
    [{2, 0, 0}, {2, 1, 1}, Error, {2, 2, 1}] = Result_after_new_test,
    New_run = send (Root, [eg_test_of_code], Tester),
    [{3, 0, 0}, {3, 1, 1}, Error, {3, 2, 1}, {3, 3, 2}] = New_run,
    ok.

provides_failed_test_and_location (Node, Root) ->
    Tester = spawn_link (tester, init, [notify_me (), Node]),
    [{2, 0, 0}, {2, 1, 1}, Error, {2, 2, 1}] = send (Root, [eg_test], Tester),
    Filename = filename: join (Root, "eg_test.erl"),
    {eg_test, nok, 0, Filename, 6} =  dict: fetch (location, Error),
    ok.

stops (Node, Root) ->
    Tester = spawn_link (tester, init, [notify_me (), Node]),
    Modules = [eg_code, eg_test_of_code],
    Paths = [modules: to_file_name (M, Root) || M <- Modules],
    Binaries = [modules: to_binary (P) || P <- Paths],
    Tester ! {run, Binaries},
    Tester ! {self (), stop},
    Results = receive_all ([]),
    [{1, 0, 0}, {1, 1, 1}] = Results,
    ok = receive {Tester, bye} -> ok after 100 -> timeout end.

receive_all (Ms) ->
    receive
	{Run, Run, Passed} ->
	    lists: reverse ([{Run, Run, Passed} | Ms]);
	M ->
	    receive_all ([M | Ms])
    end.

eg_test_form (String) ->
    [{attribute,1,file,{"./eg_test.erl",1}},
     {attribute,1,module,eg_test},
     {attribute,2,export,[{ok,0}]},
     {attribute,3,test,exports},
     {function,4,
      ok,
      0,
      [{clause,4,
	[],
	[],
	[{match,5,
	  {atom,5,ok},
	  {call,5,
	   {atom,5,list_to_atom},
	   [{string,5,String}]}}]}]},
     {eof,7}].

tree () ->
    [{file, "eg_test.erl",
      ["-module (eg_test).",
       "-test (exports).",
       "-export ([ok/0, nok/0]).",
       "ok () ->",
       "    ok = list_to_existing_atom (\"ok\").",
       "nok () ->",
       "    ok = list_to_existing_atom (\"nok\")."]},
     {file, "eg_test_of_code.erl",
      ["-module (eg_test_of_code).",
       "-test (exports).",
       "-export ([ok/0]).",
       "ok () ->",
       "    ok = eg_code: ok ()."]},
     {file, "eg_code.erl",
      ["-module (eg_code).",
       "-export ([ok/0]).",
       "ok () ->",
       "    ok."]},
     {file, "eg_test_of_code_failed.erl",
      ["-module (eg_test_of_code_failed).",
       "-test (exports).",
       "-export ([ok/0]).",
       "",
       "ok () ->",
       "    Result = eg_code: ok (),",
       "    Result = bad_eg_code."]},
     {file, "eg_test_not_exports.erl",
      ["-module (eg_test_not_exports).",
       "-test (ok).",
       "-export ([ok/0, nok/0]).",
       "ok () ->",
       "    ok = list_to_existing_atom (\"ok\").",
       "nok () ->",
       "    ok = list_to_existing_atom (\"nok\")."]}
    ].

