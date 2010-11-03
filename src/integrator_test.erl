-module (integrator_test).
-test (exports).
-export ([start_stop/0]).
-export ([uncompilable_file/0]).

start_stop () ->
    Args = [self ()],
    Integrator = spawn_link (integrator, init, Args),
    {totals,0,0,0,0,0,0}= receive_one (),
    true = is_process_alive (Integrator),
    Integrator ! stop,
    stopped = receive_one (),
    false = is_process_alive (Integrator),
    ok.

uncompilable_file () ->
    Tree = [{file, "uncompilable.erl", "bla"}],
    ok = fixtures: use_tree (Tree, fun uncompilable_file/2).

uncompilable_file (Root, [{file, F, _}]) ->
    Integrator = spawn_link (integrator, init, [self ()]),
    {totals,0,0,0,0,0,0} = receive_one (),
    Filename = filename: join (Root, F),
    Integrator ! {{file, ".erl"}, Filename, found},
    {totals,1,1,0,0,0,0} = receive_one (),
    {errors, {Filename, _}} = receive_one (),
    {totals,1,0,0,0,0,0} = receive_one (),
    Integrator ! stop,
    ok.

receive_one () ->
    receive M -> M after 3000 -> timeout end.

