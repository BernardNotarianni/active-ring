-module (integrator_test).
-test (exports).
-export ([start_stop/0]).
-export ([single_file/0]).

start_stop () ->
    Args = [self ()],
    Integrator = spawn_link (integrator, init, Args),
    {totals, {0,0,0,0,0,0}}= receive_one (),
    true = is_process_alive (Integrator),
    Integrator ! stop,
    stopped = receive_one (),
    false = is_process_alive (Integrator),
    ok.

single_file () ->
    Test_data =
	[{"bla",
	  fun (E) -> {mymodule, errors, _} = E end,
	  {1,0,0,0,0,0}},
	 {"-module(mymodule).",
	  fun (E) -> {mymodule, ok} = E end,
	  {1,0,1,0,0,0}}],
    lists: foreach (fun single_file/1, Test_data).
    
single_file ({Content, Test_event, Last_totals}) ->
    fixtures: use_tree (
      [{file, "mymodule.erl", Content}],
      fun (Root, [{file, F, _}]) ->
	      Integrator = spawn_link (integrator, init, [self ()]),
		   {totals, {0,0,0,0,0,0}} = receive_one (),
		   Filename = filename: join (Root, F),
		   Integrator ! {{file, ".erl"}, Filename, found},
		   {totals, {1,1,0,0,0,0}} = receive_one (),
		   {compile, Event} = receive_one (),
		   Test_event (Event),
		   {totals, Last_totals} = receive_one (),
		   Integrator ! stop,
		   ok
	   end).

receive_one () ->
    receive M -> M after 3000 -> timeout end.

