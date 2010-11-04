-module (integrator_test).
-test (start_stop).
-export ([with_files/2]).
-export ([start_stop/0]).

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
    Ps = [filename: join (Root, F) || {file, F, _} <- Fs],
    [Compiles, Doesnt, Warnings, _] = Ps,
    Integrator = spawn_link (integrator, init, [self ()]),
    {totals, {0,0,0,0,0,0}} = receive_one (),
    Integrator ! {{file, ".erl"}, Compiles, found},
    {totals, {1,0,0,0,0,0}} = receive_one (),
    {compile, {compiles, ok}} = receive_one (),
    {totals, {1,1,0,0,0,0}} = receive_one (), 
    Integrator ! {{file, ".erl"}, Doesnt, found},
    {totals, {2,1,0,0,0,0}} = receive_one (),
    {compile, {doesnt_compile, errors, _}} = receive_one (),
    {totals, {2,1,1,0,0,0}} = receive_one (),
    Integrator ! {{file, ".erl"}, Warnings, found},
    {totals, {3,1,1,0,0,0}} = receive_one (),
    {compile, {warnings, warnings, _}} = receive_one (),
    {totals, {3,2,1,0,0,0}} = receive_one (),
    Integrator ! stop,
    ok.

receive_one () ->
    receive M -> M after 3000 -> timeout end.

