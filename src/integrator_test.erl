-module (integrator_test).
-test (start_stop).
-test (modified_files_are_recompiled).
-export ([with_files/2]).
-export ([start_stop/0]).
-export ([modified_files_are_recompiled/0]).

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
    new_files_are_compiled_and_scanned_for_tests (Root, Fs),
    ok.

new_files_are_compiled_and_scanned_for_tests (Root, Fs) ->
    Ps = [filename: join (Root, F) || {file, F, _} <- Fs],
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
    ok.

receive_one () ->
    receive M -> M after 3000 -> timeout end.
