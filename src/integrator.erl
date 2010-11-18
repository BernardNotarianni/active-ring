-module (integrator).
-export ([init/1]).
-export ([slave_node/1]).
-import (dict, [new/0, store/3, fetch/2, fold/3]).
-record (state, {mux, slave, modules}).

init (Mux) ->
    process_flag (trap_exit, true),
    Modules = new (),
    Mux ! totals (Modules),
    idle (#state {mux = Mux, slave = slave (), modules = Modules}).

idle (State) ->
    receive_messages (State, infinity, fun idle/1).

receive_messages (State, Timeout, Continuation) ->
    receive
	stop ->
	    slave: stop (State#state.slave),
	    State#state.mux ! stopped;
	{{file, ".erl"}, F, found} ->
	    Modules = store (F, new, State#state.modules),
	    compiling (F, State#state{modules = Modules});
	{{file, ".erl"}, F, changed} ->
	    Modules = store (F, changed, State#state.modules),
	    compiling (F, State#state{modules = Modules});
	{'EXIT', _, normal} ->
	    Continuation (State);
	{'EXIT', _, Reason} ->
	    exit (Reason);
	Other ->
	    State#state.mux ! {unexpected, Other},
	    Continuation (State)
    after (Timeout) ->
	    Continuation (State)
    end.

compiling (F, State) ->
    #state{mux=Mux, modules=Modules} = State,
    Mux ! totals (Modules),
    State_with_compilation = store_compilation (modules: compile2 (F), State),
    State_with_cleared_tests = clear_tests (State_with_compilation),
    Mux ! totals (State_with_cleared_tests#state.modules),
    testing (State_with_cleared_tests).

slave () ->
    {Host, Name} = integrator: slave_node (node ()),
    {ok, Slave} = slave: start_link (Host, Name),
    Slave.

testing (State) ->
    receive_messages (State, 0, fun real_testing/1).

real_testing (State) ->
    {totals, Ts} = totals (State#state.modules),
    test_if_necessary (Ts, State).

test_if_necessary ({M, C, _, T, P, F}, State) when M == C andalso T > P+F ->
    Next = fold (fun testing/3, State, State#state.modules),
    idle (Next);
test_if_necessary (_ ,State) ->
    idle (State).

testing (_, {ok, _, _, []}, State) ->
    State;
testing (File, {ok, _, _, Tests}, State) ->
    Test = fun (Test, _, St) -> test (File, Test, St) end,
    fold (Test, State, Tests).

test (File, F, State) ->
    #state {slave = Slave, mux = Mux, modules = Modules} = State,
    {ok, M, Binary, Tests} = fetch (File, Modules),
    Pid = spawn_link (Slave, M, F, []),
    Result =
	receive
	    {'EXIT', Pid, normal} ->
		Mux ! {test, {M, F, 0, pass}},
		pass;
	    {'EXIT', Pid, {Error, Stack_trace}} ->
		{File, Line} = modules: locate ({M, F, 0}, Binary),
		Location = {M, F, 0, File, Line},
		List = [{error, Error},
			{stack_trace, Stack_trace},
			{location, Location}],
		Reason = dict: from_list (List),
		Mux ! {test, {M, F, 0, {fail, Reason}}},
		fail
	end,
    Ts = store (F, Result, Tests),
    Module = {ok, M, Binary, Ts},
    Ms = store (File, Module, Modules),
    Mux ! totals (Ms),
    State#state {modules = Ms}.

clear_tests (State) ->
    fold (fun clear_modules/3, State, State#state.modules).

clear_modules (File, {ok, M, Binary, Tests}, State) ->
    Ts = fold (fun clear_tests/3, new (), Tests),
    Module = {ok, M, Binary, Ts},
    Modules = store (File, Module, State#state.modules),
    State#state {modules = Modules};
clear_modules (_, _, State) ->
    State.

clear_tests (F, _, Acc) ->
    store (F, not_run, Acc).

store_compilation ({File, Module, error, Errors}, State) ->
    #state {mux = Mux, modules = Modules} = State,
    Mux ! {compile, {Module, error, Errors}},
    State#state {modules = store (File, error, Modules)};
store_compilation ({File, Module, ok, {Binary, Ts, Ws}}, State) ->
    #state {mux = Mux, slave = Slave, modules = Modules} = State,
    Mux ! {compile, {Module, ok, Ws}},
    Load_args = [Module, File, Binary],
    {module, Module} = rpc: call (Slave, code, load_binary, Load_args),
    Tests = dict: from_list ([{T, not_run} || T <- Ts]),
    State#state {modules = store (File, {ok, Module, Binary, Tests}, Modules)}.

totals (Modules) ->
    Totals = fold (fun totals/3, {0,0,0,0,0,0}, Modules),
    {totals, Totals}.

totals (_, new, {M, C, E, T, P, F}) ->
    {M+1, C, E, T, P, F};
totals (_, changed, {M, C, E, T, P, F}) ->
    {M+1, C, E, T, P, F};
totals (_, error, {M, C, E, T, P, F}) ->
    {M+1, C, E+1, T, P, F};
totals (_, {ok, _, _, Ts}, {M, C, E, T, P, F}) ->
    {Tests, Passes, Fails} = fold (fun test_totals/3, {T, P, F}, Ts),
    {M+1, C+1, E, Tests, Passes, Fails}.

test_totals (_, not_run, {T, P, F}) ->
    {T + 1, P, F};
test_totals (_, pass, {T, P, F}) ->
    {T + 1, P + 1, F};
test_totals (_, fail, {T, P, F}) ->
    {T + 1, P, F + 1}.

slave_node (nonode@nohost) ->
    not_alive;
slave_node (Node) ->
    Node_string = atom_to_list (Node),
    [Name, Host_string] = string: tokens (Node_string, "@"),
    Slave_name_string = Name ++ "_extremeforge_slave",
    Slave_name = list_to_atom (Slave_name_string),
    Host = list_to_atom (Host_string),
    {Host, Slave_name}.

