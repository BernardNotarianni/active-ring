%%% Copyright (C) Dominic Williams, Nicolas Charpentier
%%% All rights reserved.
%%% See file COPYING.

-module (tester).
-export ([init/2]).

init (Notify, Node) ->
    process_flag (trap_exit, true),
    With_notify = dict: store (notify, Notify, dict: new ()),
    With_tests = dict: store (tests, dict: new (), With_notify),
    With_binaries = dict: store (binaries, dict: new (), With_tests),
    State = dict: store (node, Node, With_binaries),
    loop (State).

loop (State) ->
    receive
	{delete, Modules} ->
	    test (unload (Modules, State));
	{run, Modules} ->
	    test (load (Modules, State));
	{Pid, stop} ->
	    Pid ! {self (), bye}
    end.

load (Modules, State) ->
    lists: foldl (fun load_aux/2, State, Modules).

load_aux (Binary, State) ->
    {File_name, Module, Tests} = tests: filter_by_attribute (Binary),
    Node = dict: fetch (node, State),
    Load_args = [Module, File_name, Binary],
    {module, Module} = rpc: call (Node, code, load_binary, Load_args),
    Time_stamped_tests = [{Test, new} || Test <- Tests],
    Test_dict = dict: fetch (tests, State),
    New_tests = dict: store (Module, Time_stamped_tests, Test_dict),
    Binaries_dict = dict: fetch (binaries, State),
    New_binaries = dict: store (Module, Binary, Binaries_dict),
    dict: store (binaries, New_binaries, dict: store (tests, New_tests, State)).

test (State) ->
    State_without_pid = stop_running_session (State),
    Test_dict = dict: fetch (tests, State_without_pid),
    {Total, Tests} = flatten (Test_dict),
    Notify = dict: fetch (notify, State_without_pid),
    Notify ({Total, 0, 0}),
    Self = self(),
    Test_session_fun = fun () -> 
			       launch_test (Self, Total, Tests, State_without_pid)
		       end,
    Test_session = spawn (Test_session_fun),
    dict: store (test_session, Test_session, State_without_pid),
    loop (receive {runner_end, New_state} -> New_state end).

stop_running_session (State) ->
    case dict: find (test_session, State) of
	{ok, Session} ->
	    exit(Session, kill),
	    dict: erase (test_session, State);
	_ ->
	    State
    end.

launch_test (Parent, Total, Tests, State) ->
    process_flag (trap_exit, true),
    Run = lists: foldl (test_fun (State, Total), {State,{0, 0}}, Tests),
    {New_state, _} = Run,
    Parent ! {runner_end, New_state}.

unload (Modules, State) ->
    lists: foldl (fun unload_aux/2, State, Modules).

unload_aux (Module, State) ->
    Node = dict: fetch (node, State),
    rpc: call (Node, code, purge, [Module]),
    rpc: call (Node, code, delete, [Module]),
    false = rpc: call (Node, code, is_loaded, [Module]),
    Tests = dict: fetch (tests, State),
    New_tests = dict: erase (Module, Tests),
    Binaries = dict: fetch (binaries, State),
    New_binaries = dict: erase (Module, Binaries),
    dict: store (binaries, New_binaries, dict :store (tests, New_tests, State)).

flatten (Tests) ->
    F = fun (Module, Ts, {Count, List}) ->
		Tests_by_module = [{Module, T, Stamp} || {T, Stamp} <- Ts],
		{Count + length (Ts), [ Tests_by_module | List]}
	end,
    {Total, All} = dict: fold (F, {0, []}, Tests),
    Sorted_tests = lists: sort (fun new_tests_first/2, lists: flatten (All)),
    {Total, Sorted_tests}.

new_tests_first ({_, _ ,new}, {_, _, failed})  ->
    true;
new_tests_first ({_, _ ,failed}, {_, _, new})  ->
    false;
new_tests_first ({_, _ ,new}, _)  ->
    true;
new_tests_first ({_, _, failed}, _) ->
    true;
new_tests_first ({_,_,_},{_,_,new}) ->
    false;
new_tests_first ({_,_,_},{_,_,failed}) ->
    false;
new_tests_first (A,B) ->
    A<B.
    
test_fun (State, Total) ->
    Node = dict: fetch (node, State),
    Notify = dict: fetch (notify, State),
    Binaries = dict: fetch (binaries, State),
    fun (Test_definition, {Tester_state, {Run, Passed}}) ->
	    {Module, Function, Stamp} = Test_definition,
	    Pid = spawn_link (Node, Module, Function, []),
	    {New_passed, New_stamp} =
		receive
		    {'EXIT', Pid, normal} ->
			{Passed + 1, first_test_success (Stamp, now())};
		    {'EXIT', Pid, {Error, Stack_trace}} ->
			Binary = dict: fetch (Module, Binaries),
			MFA = {Module, Function, 0},
			{File, Line} = modules: locate (MFA, Binary),
			Location = {Module, Function, 0, File, Line},
			List = [{error, Error},
				{stack_trace, Stack_trace},
				{location, Location}],
			Reason = dict: from_list (List),
			Notify (Reason),
			{Passed, failed}
		end,
	    New_run = Run + 1,
	    Notify ({Total, New_run, New_passed}),
	    New_state = update_state (Tester_state, Module, Function, New_stamp),
	    {New_state, {New_run, New_passed}}
    end.

first_test_success (Before, Now) when is_atom (Before) ->
    Now;
first_test_success (Stamp, _) ->
    Stamp.

update_state (State, Module, Function, Stamp) ->
    Test_dict = dict: fetch (tests, State),
    Module_tests = dict:fetch (Module, Test_dict),
    Filtered_tests = proplists: delete (Function, Module_tests),
    Updated_tests = [{Function, Stamp} | Filtered_tests],
    New_tests = dict: store (Module, Updated_tests, Test_dict),
    dict: store (tests, New_tests, State).
