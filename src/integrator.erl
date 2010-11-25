-module (integrator).
-export ([init/1, init/3]).
-export ([slave_node/1]).
-export ([consul_forms/1]).
-import (dict, [new/0, store/3, fetch/2, fold/3, erase/2]).
-record (state, {mux, includes, slave, modules}).

init (Mux) ->
    init (Mux, [], []).

init (Mux, Dirs, Options) ->
    S = #state {mux = Mux, includes = Dirs, slave = slave (), modules = new ()},
    State = options (Options, S),
    idle (State).

options ([{includes, Path} | Options], State) ->
    Includes = State#state.includes ++ Path,
    options (Options, State#state {includes = Includes});
options ([_, Options], State) ->
    options (Options, State);
options ([], State) ->
    State.

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
	{{file, ".erl"}, F, lost} ->
	    removing (F, State);
	{{file, _}, _, _} ->
	    Continuation (State);
	Other ->
	    State#state.mux ! {unexpected, Other},
	    Continuation (State)
    after (Timeout) ->
	    Continuation (State)
    end.

removing (F, State) ->
    case fetch (F, State#state.modules) of
	{ok, M, _, _} ->
	    rpc: call (State#state.slave, code, purge, [M]),
	    rpc: call (State#state.slave, code, delete, [M]),
	    false = rpc: call (State#state.slave, code, is_loaded, [M]);
	_ -> ignore
    end,
    Modules = erase (F, State#state.modules),
    State_with_cleared_tests = clear_tests (State#state {modules = Modules}),
    State#state.mux ! totals (State_with_cleared_tests#state.modules),
    testing (State_with_cleared_tests).
    
compiling (F, State) ->
    Cleared = clear_tests (State),
    #state {mux=Mux, modules=Modules} = Cleared,
    Mux ! totals (Modules),
    All_includes = [modules: 'OTP_include_dir' (F)  | Cleared#state.includes],
    Options = [{i, P} || P <- All_includes],
    Compilation = modules: compile2 (F, Options),
    Compiled = store_compilation (Compilation, Cleared),
    Mux ! totals (Compiled#state.modules),
    testing (Compiled).

slave () ->
    {Host, Name} = integrator: slave_node (node ()),
    {ok, Slave} = slave: start_link (Host, Name),
    Binary = modules: forms_to_binary (consul_forms (consul)),
    Load_args = [consul, "consul.beam", Binary],
    {module, consul} = rpc: call (Slave, code, load_binary, Load_args),
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
    spawn_link (Slave, consul, test, [M, F, self ()]),
    Result =
	receive
	    {test, M, F, pass} ->
		Mux ! {test, {M, F, 0, pass}},
		pass;
	    {test, M, F, {error, {Error, Stack_trace}}} ->
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

consul_forms (Module) ->
%% Abstract forms for following code:
%%
%% -module (Module).
%% -export ([test/3]).
%% test (M, F, Pid) ->
%%    case catch (M: F()) of
%%       {'EXIT', Error} ->
%%          Pid ! {test, M, F, {error, Error}};
%%       _ ->
%%          Pid ! {test, M, F, pass}
%%    end.
    [{attribute,1,module,Module},
     {attribute,2,export,[{test,3}]},
     {function,4,test,3,
      [{clause,4,
	[{var,4,'M'},{var,4,'F'},{var,4,'Pid'}],
	[],
	[{'case',5,
	  {'catch',5,{call,5,{remote,5,{var,5,'M'},{var,5,'F'}},[]}},
	  [{clause,6,
	    [{tuple,6,[{atom,6,'EXIT'},{var,6,'Error'}]}],
	    [],
	    [{op,7,'!',
	      {var,7,'Pid'},
	      {tuple,7,
	       [{atom,7,test},
		{var,7,'M'},
		{var,7,'F'},
		{tuple,7,[{atom,7,error},{var,7,'Error'}]}]}}]},
	   {clause,8,
	    [{var,8,'_'}],
	    [],
	    [{op,9,'!',
	      {var,9,'Pid'},
	      {tuple,9,
	       [{atom,9,test},
		{var,9,'M'},
		{var,9,'F'},
		{atom,9,pass}]}}]}]}]}]}].
