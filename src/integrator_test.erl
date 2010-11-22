-module (integrator_test).
-test (start_stop).
-test (modified_files_are_recompiled).
-test (slave_node).
-test (slave_node_nonode).
-export ([with_files/2]).
-export ([start_stop/0]).
-export ([modified_files_are_recompiled/0]).
-export ([slave_node/0]).
-export ([slave_node_nonode/0]).
-export ([with_directories/2]).

start_stop () ->
    Args = [self ()],
    Integrator = spawn_link (integrator, init, Args),
    {totals, {0,0,0,0,0,0}}= receive_one (),
    true = is_process_alive (Integrator),
    Integrator ! stop,
    stopped = receive_one (),
    false = is_process_alive (Integrator),
    ok.

with_files (Root, Fs) ->
    ok = new_files_are_compiled_and_scanned_for_tests (Root, Fs),
    ok = when_all_compile_tests_are_run_in_separate_node (Root, Fs),
    ok = removed_modules_are_unloaded_and_tests_not_run (Root, Fs),
    ok.

with_directories (Root, Tree) ->
    ok = source_can_include_from_various_places (Root, Tree).

new_files_are_compiled_and_scanned_for_tests (Root, Fs) ->
    Files = lists: sublist (Fs, 4),
    Ps = [filename: join (Root, F) || {file, F, _} <- Files],
    [Compiles, Doesnt, Warnings, Has_tests] = Ps,
    Integrator = spawn_link (integrator, init, [self ()]),
    {totals, {0,0,0,0,0,0}} = receive_one (),
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

modified_files_are_recompiled () ->
    Tree = [{file, "foo.erl", "foo"}],
    fixtures: use_tree (Tree, fun modified_files_are_recompiled/2).

modified_files_are_recompiled (Root, [{file, F, _}]) ->
    Filename = filename: join (Root, F),
    Integrator = spawn_link (integrator, init, [self()]),
    {totals, {0,0,0,0,0,0}} = receive_one (),
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
    {totals, {0,0,0,0,0,0}} = receive_one (),
    lists: foreach (
      fun (F) -> Integrator ! {{file, ".erl"}, F, found} end,
      [Compiles, Warnings, Has_tests, Tests_other]),
    {totals, {1,0,0,0,0,0}} = receive_one (),
    {compile, _} = receive_one (),
    {totals, {1,1,0,0,0,0}} = receive_one (),
    {totals, {2,1,0,0,0,0}} = receive_one (),
    {compile, _} = receive_one (),
    {totals, {2,2,0,0,0,0}} = receive_one (),
    {totals, {3,2,0,0,0,0}} = receive_one (),
    {compile, _} = receive_one (),
    {totals, {3,3,0,2,0,0}} = receive_one (),
    {totals, {4,3,0,2,0,0}} = receive_one (),
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
    {totals, {0,0,0,0,0,0}} = receive_one (),
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
    {totals, {0,0,0,0,0,0}} = receive_one (),
    Integrator ! {{file, ".hrl"}, Include, found},
    {totals, {0,0,0,0,0,0}} = receive_one (),
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

