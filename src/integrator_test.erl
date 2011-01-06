%%% Copyright (C) Dominic Williams
%%% All rights reserved.
%%% See file COPYING.

-module (integrator_test).
-test (start_stop).
-test (tests_are_cleared_when_anything_recompiles).
-test (corrected_files_are_recompiled).
-test (slave_node).
-test (slave_node_nonode).
-test (consul_forms).
-test (includers_are_recompiled_when_included_change).
-test (recompiles_when_a_missing_include_is_found).
-test (recompiles_when_an_included_is_lost).
-export ([with_files/2]).
-export ([start_stop/0]).
-export ([tests_are_cleared_when_anything_recompiles/0]).
-export ([slave_node/0]).
-export ([slave_node_nonode/0]).
-export ([with_directories/2]).
-export ([consul_forms/0]).
-export ([consul_forms_test1/0]).
-export ([consul_forms_test2/0]).
-export ([includers_are_recompiled_when_included_change/0]).
-export ([recompiles_when_a_missing_include_is_found/0]).
-export ([corrected_files_are_recompiled/0]).
-export ([recompiles_when_an_included_is_lost/0]).
%% TODO: avoid recompiling when an include is found at startup after a source.

start_stop () ->
    Args = [self ()],
    Integrator = spawn_link (integrator, init, Args),
    true = is_process_alive (Integrator),
    Integrator ! stop,
    stopped = receive_one (),
    false = is_process_alive (Integrator),
    ok.

with_files (Root, Fs) ->
    ok = new_files_are_compiled_and_scanned_for_tests (Root, Fs),
    ok = when_all_compile_tests_are_run_in_separate_node (Root, Fs),
    ok = removed_modules_are_unloaded_and_tests_not_run (Root, Fs),
    ok = new_files_are_counted_before_compile_results_are_reported (Root, Fs),
    ok.

with_directories (Root, Tree) ->
    ok = source_can_include_from_various_places (Root, Tree).

new_files_are_compiled_and_scanned_for_tests (Root, Fs) ->
    Files = lists: sublist (Fs, 4),
    Ps = [filename: join (Root, F) || {file, F, _} <- Files],
    [Compiles, Doesnt, Warnings, Has_tests] = Ps,
    Integrator = spawn_link (integrator, init, [self ()]),
    Integrator ! {{file, ".erl"}, Compiles, found},
    {totals, {1,0,0,0,0,0}} = receive_one (),
    {compile, {compiles, ok, []}} = receive_one (),
    {totals, {1,1,0,0,0,0}} = receive_one (), 
    Integrator ! {{file, ".erl"}, Doesnt, found},
    {totals, {2,1,0,0,0,0}} = receive_one (),
    {compile, {doesnt_compile, error, _}} = receive_one (),
    {totals, {2,1,1,0,0,0}} = receive_one (),
    Integrator ! {{file, ".erl"}, Warnings, found},
    {totals, {3,1,1,0,0,0}} = receive_one (),
    {compile, {warnings, ok, [_]}} = receive_one (),
    {totals, {3,2,1,0,0,0}} = receive_one (),
    Integrator ! {{file, ".erl"}, Has_tests, found},
    {totals, {4,2,1,0,0,0}} = receive_one (),
    {compile, {good_test, ok, []}} = receive_one (),
    {totals, {4,3,1,2,0,0}} = receive_one (),
    Integrator ! stop,
    stopped = receive_one (),
    ok.

tests_are_cleared_when_anything_recompiles () ->
    Tree = [{file, "foo.erl",
	     ["-module (foo).",
	      "-test (exports).",
	      "-export ([myfun/0]).",
	      "myfun () -> ok."]},
	    {file, "bar.erl", "-module (bar)."}],
    fixtures: use_tree (Tree, fun tests_are_cleared_when_anything_recompiles/2).

tests_are_cleared_when_anything_recompiles (Root, Files) ->
    [Foo, Bar] = [filename: join (Root, F) || {file, F, _} <- Files],
    Integrator = spawn_link (integrator, init, [self()]),
    Integrator ! {{file, ".erl"}, Foo, found},
    {totals, {1,0,0,0,0,0}} = receive_one (),
    {compile, {foo, ok, []}} = receive_one (),
    {totals, {1,1,0,1,0,0}} = receive_one (),
    {test, {foo, myfun, 0, pass}} = receive_one (),
    {totals, {1,1,0,1,1,0}} = receive_one (),
    Integrator ! {{file, ".erl"}, Bar, found},
    {totals, {2,1,0,1,0,0}} = receive_one (),
    {compile, {bar, ok, []}} = receive_one (),
    {totals, {2,2,0,1,0,0}} = receive_one (),
    {test, {foo, myfun, 0, pass}} = receive_one (),
    {totals, {2,2,0,1,1,0}} = receive_one (),
    Integrator ! stop,
    stopped = receive_one (),
    ok.

corrected_files_are_recompiled () ->
    Tree = [{file, "foo.erl", "foo"}],
    fixtures: use_tree (Tree, fun corrected_files_are_recompiled/2).

corrected_files_are_recompiled (Root, [{file, F, _}]) ->
    Filename = filename: join (Root, F),
    Integrator = spawn_link (integrator, init, [self()]),
    Integrator ! {{file, ".erl"}, Filename, found},
    {totals, {1,0,0,0,0,0}} = receive_one (),
    {compile, {foo, error, _}} = receive_one (),
    {totals, {1,0,1,0,0,0}} = receive_one (),
    Content = list_to_binary ("-module(foo)."),
    ok = file: write_file (Filename, Content),
    Integrator ! {{file, ".erl"}, Filename, changed},
    {totals, {1,0,0,0,0,0}} = receive_one (),
    {compile, {foo, ok, _}} = receive_one (),
    {totals, {1,1,0,0,0,0}} = receive_one (),
    Integrator ! stop,
    stopped = receive_one (),
    ok.

when_all_compile_tests_are_run_in_separate_node (Root, Fs) ->
    Files = lists: sublist (Fs, 5),
    Ps = [filename: join (Root, F) || {file, F, _} <- Files],
    [Compiles, _, Warnings, Has_tests, Tests_other] = Ps,
    Integrator = spawn_link (integrator, init, [self()]),
    lists: foreach (
      fun (F) -> Integrator ! {{file, ".erl"}, F, found} end,
      [Compiles, Warnings, Has_tests, Tests_other]),
    {totals, {1,0,0,0,0,0}} = receive_one (),
    {totals, {2,0,0,0,0,0}} = receive_one (),
    {totals, {3,0,0,0,0,0}} = receive_one (),
    {totals, {4,0,0,0,0,0}} = receive_one (),
    {compile, _} = receive_one (),
    {totals, {4,1,0,_,0,0}} = receive_one (),
    {compile, _} = receive_one (),
    {totals, {4,2,0,_,0,0}} = receive_one (),
    {compile, _} = receive_one (),
    {totals, {4,3,0,_,0,0}} = receive_one (),
    {compile, _} = receive_one (),
    {totals, Totals} = receive_one (),
    {4,4,0,4,0,0} = Totals,
    Expected_to_pass =
	[{good_test, test1}, {good_test, test2}, {tests_other, passes}],
    ok = check_tests (Totals, Expected_to_pass),
    Integrator ! stop,
    stopped = receive_one (),
    ok.

removed_modules_are_unloaded_and_tests_not_run (Root, Fs) ->
    Files = lists: sublist (Fs, 5),
    Ps = [filename: join (Root, F) || {file, F, _} <- Files],
    [Compiles, _, _, Has_tests, Tests_other] = Ps,
    Integrator = spawn_link (integrator, init, [self()]),
    lists: foreach (
      fun (F) -> Integrator ! {{file, ".erl"}, F, found} end,
      [Compiles, Has_tests, Tests_other]),
    ok = receive_until_found ({totals, {3, 3, 0, 4, 3, 1}}),
    Integrator ! {{file, ".erl"}, Compiles, lost},
    {totals, Totals_with_module_removed} = receive_one (),
    {2, 2, 0, 4, 0, 0} = Totals_with_module_removed,
    Expected_to_pass = [{good_test, test1}, {good_test, test2}],
    ok = check_tests (Totals_with_module_removed, Expected_to_pass),
    Integrator ! {{file, ".erl"}, Tests_other, lost},
    {totals, Totals_with_test_removed} = receive_one (),
    {1, 1, 0, 2, 0, 0} = Totals_with_test_removed,
    ok = check_tests (Totals_with_test_removed, Expected_to_pass),
    Integrator ! stop,
    stopped = receive_one (),
    ok.

new_files_are_counted_before_compile_results_are_reported (Root, Fs) ->
    Files = lists: sublist (Fs, 4),
    Ps = [filename: join (Root, F) || {file, F, _} <- Files],
    [Compiles, _, Warnings, Has_tests] = Ps,
    Integrator = spawn_link (integrator, init, [self()]),
    lists: foreach (
      fun (F) -> Integrator ! {{file, ".erl"}, F, found} end,
      [Compiles, Warnings, Has_tests]),
    ok = receive_until_found ({totals, {3, 0, 0, 0, 0, 0}}),
    ok = receive_until_found ({totals, {3, 3, 0, 2, 0, 0}}),
    ok = receive_until_found ({totals, {3, 3, 0, 2, 2, 0}}),
    Integrator ! stop,
    stopped = receive_one (),
    ok.
    
check_tests ({C, C, 0, Total, Pass, Fail}, _) when Total == Pass + Fail ->
    ok;
check_tests ({C, C, 0, Total, Pass, Fail}, Expected_to_pass) ->
    Expected_totals =
	case receive_one () of
	    {test, {M, F, 0, pass}} ->
		Trace = {expected_to_pass, M, F},
		Expected = lists: member ({M, F}, Expected_to_pass),
		{Trace, true} = {Trace, Expected},
		{C, C, 0, Total, Pass+1, Fail};
	    {test, {M, F, 0, {fail, Reason}}} ->
		Trace = {expected_to_fail, M, F},
		Expected = not lists: member ({M, F}, Expected_to_pass),
		{Trace, true} = {Trace, Expected},
		_ = dict: fetch (error, Reason),
		{M, F, 0, _, _} = dict: fetch (location, Reason),
		_ = dict: fetch (stack_trace, Reason),
		{C, C, 0, Total, Pass, Fail+1}
	end,
    {totals, Totals} = receive_one (),
    {Expected_totals, Expected_totals} = {Expected_totals, Totals},
    check_tests (Totals, Expected_to_pass).

source_can_include_from_various_places (Root, _) ->
    Project = filename: join (Root, "project"),
    Third = filename: join (Root, "3rdparty"),
    Include = filename: join ([Project, "app1", "include", "inc.hrl"]),
    Source1 = filename: join ([Project, "app1", "src", "my1.erl"]),
    Source2 = filename: join ([Project, "app2", "src", "my2.erl"]),
    Tests = filename: join ([Project, "tests", "tests.erl"]),
    Options = [{includes, [Third]}],
    Integrator = spawn_link (integrator, init, [self(), [Project], Options]),
    Integrator ! {{file, ".hrl"}, Include, found},
    Integrator ! {{file, ".erl"}, Source1, found},
    {totals, {1,0,0,0,0,0}} = receive_one (),
    {compile, {my1, ok, []}} = receive_one (),
    {totals, {1,1,0,0,0,0}} = receive_one (),
    Integrator ! {{file, ".erl"}, Source2, found},
    {totals, {2,1,0,0,0,0}} = receive_one (),
    {compile, {my2, ok, []}} = receive_one (),
    {totals, {2,2,0,0,0,0}} = receive_one (),
    Integrator ! {{file, ".erl"}, Tests, found},
    {totals, {3,2,0,0,0,0}} = receive_one (),
    {compile, {tests, ok, []}} = receive_one (),
    {totals, {3,3,0,6,0,0}=Totals} = receive_one (),
    Ts = [mydef1, mydef2, def1, def2, appdef, third],
    Expected_to_pass = [{tests, T} || T <- Ts],
    check_tests (Totals, Expected_to_pass),
    Integrator ! stop,
    stopped = receive_one (),
    ok.

includers_are_recompiled_when_included_change () ->
    Files = [{file, "my.erl",
	      ["-module (my).",
	       "-export ([run/0, test/0]).",
	       "-test (test).",
	       "-include (\"my.hrl\").",
	       "run () -> ?mydef.",
	       "test () -> hello = my: run ()."]},
	     {file, "my.hrl", 
	      "-define (mydef, goodbye)."}],
    ok = fixtures: use_tree (Files, fun includers/2).

includers (Root, Files) ->
    [Module, Include] = [filename: join (Root, F) || {file, F, _} <- Files],
    Integrator = spawn_link (integrator, init, [self (), [Root], []]),
    Integrator ! {{file, ".erl"}, Module, found},
    Integrator ! {{file, ".hrl"}, Include, found},
    {totals, {1,0,0,0,0,0}} = receive_one (),
    {compile, {my, ok, []}} = receive_one (),
    {totals, {1,1,0,1,0,0}=Totals} = receive_one (),
    check_tests (Totals, []),
    Binary = list_to_binary ("-define (mydef, hello)."),
    ok = file: write_file (Include, Binary),
    Integrator ! {{file, ".hrl"}, Include, changed},
    {totals, {1,0,0,0,0,0}} = receive_one (),
    {compile, {my, ok, []}} = receive_one (),
    {totals, {1,1,0,1,0,0}=Totals} = receive_one (),
    check_tests (Totals, [{my, test}]),
    Integrator ! stop,
    stopped = receive_one (),
    ok.

recompiles_when_a_missing_include_is_found () ->
    Files = [{file, "my.erl",
	      ["-module (my).",
	       "-include (\"my.hrl\").",
	       "-export ([foo/0]).", 
	       "foo () -> ?mydef."]}],
    ok = fixtures: use_tree (Files, fun recompiles_when_a_missing_include_is_found/2).

recompiles_when_a_missing_include_is_found (Root, [{file, File, _}]) ->
    Module = filename: join (Root, File),
    Integrator = spawn_link (integrator, init, [self (), [Root], []]),
    Integrator ! {{file, ".erl"}, Module, found},
    {totals, {1,0,0,0,0,0}} = receive_one (),
    {compile, {my, error, _}} = receive_one (),
    {totals, {1,0,1,0,0,0}} = receive_one (),
    Binary = list_to_binary ("-define (mydef, hello)."),
    Include = filename: join (Root, "my.hrl"),
    ok = file: write_file (Include, Binary),
    Integrator ! {{file, ".hrl"}, Include, found},
    {totals, {1,0,0,0,0,0}} = receive_one (),
    {compile, {my, ok, []}} = receive_one (),
    {totals, {1,1,0,0,0,0}} = receive_one (),
    Integrator ! stop,
    stopped = receive_one (),
    ok.

recompiles_when_an_included_is_lost () ->
    Files = [{file, "my.erl",
	      ["-module (my).",
	       "-export ([run/0]).",
	       "-include (\"my.hrl\").",
	       "run () -> ?mydef."]},
	     {file, "my.hrl", 
	      "-define (mydef, goodbye)."}],
    ok = fixtures: use_tree (Files, fun recompiles_when_an_included_is_lost/2).

recompiles_when_an_included_is_lost (Root, Files) ->
    [Module, Include] = [filename: join (Root, F) || {file, F, _} <- Files],
    Integrator = spawn_link (integrator, init, [self (), [Root], []]),
    Integrator ! {{file, ".erl"}, Module, found},
    Integrator ! {{file, ".hrl"}, Include, found},
    {totals, {1,0,0,0,0,0}} = receive_one (),
    {compile, {my, ok, []}} = receive_one (),
    {totals, {1,1,0,0,0,0}} = receive_one (),
    ok = file: delete (Include),
    Integrator ! {{file, ".hrl"}, Include, lost},
    {totals, {1,0,0,0,0,0}} = receive_one (),
    {compile, {my, error, _}} = receive_one (),
    {totals, {1,0,1,0,0,0}} = receive_one (),
    Integrator ! stop,
    stopped = receive_one (),
    ok.
    
    

receive_one () ->
    receive M -> M after 3000 -> timeout end.

receive_until_found (M) ->
    receive M -> ok;
	    _ -> receive_until_found (M)
    after 10000 ->
	    timeout
    end.

slave_node () ->
    Result = integrator: slave_node (mynode@myhost),
    {myhost, mynode_extremeforge_slave} = Result.

slave_node_nonode () ->
    not_alive = integrator: slave_node (nonode@nohost).

consul_forms_test1 () ->
    ok.

consul_forms_test2 () ->
    yohoho: and_a_bottle_of_rhum ().

consul_forms () ->
    Binary = modules: forms_to_binary (integrator: consul_forms (myconsul)),
    {module, myconsul} = code: load_binary (myconsul, "myconsul.beam", Binary),
    try
	Result1 = {test, ?MODULE, consul_forms_test1, pass},
	Result1 = myconsul: test (?MODULE, consul_forms_test1, self ()),
	Result1 = receive_one (),
	Result2 = myconsul: test (?MODULE, consul_forms_test2, self ()),
	{test, ?MODULE, consul_forms_test2, {error, _}} = Result2,
	Result2 = receive_one ()
    after
	code: purge (myconsul),
      code: delete (myconsul)
    end,
    ok.
