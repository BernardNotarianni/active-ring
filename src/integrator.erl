-module (integrator).
-export ([init/1]).
-record (state,
	 {channel,
	  uncompiled = [],
	  bad = [],
	  compiled = [],
	  tests = []}).

init (Channel) ->
    State = #state {channel = Channel},
    idle (State).

idle (State) ->
    totals (State),
    receive
	stop ->
	    State#state.channel ! stopped;
	{{file, ".erl"}, F, found} ->
	    Fs = [F | State#state.uncompiled],
	    compiling (State#state {uncompiled = Fs});
	Other ->
	    State#state.channel ! {unexpected, Other},
	    idle (State)
    end.

compiling (#state {uncompiled = [F | Fs]} = State) ->
    totals (State),
    Next = store_compilation (modules: compile2 (F), State),
    compiling (Next#state {uncompiled = Fs});
compiling (#state {uncompiled = []} = State) ->
    idle (State).

store_compilation ({File, Module, error, Errors}, State) ->
    State#state.channel ! {compile, {Module, error, Errors}},
    State#state {bad = [File | State#state.bad]};
store_compilation ({_, Module, ok, {Binary, Ts, Ws}}, State) ->
    State#state.channel ! {compile, {Module, ok, Ws}},
    Compiled = [Binary | State#state.compiled],
    Tests = [{Module, T} || T <- Ts] ++ State#state.tests,
    State#state {compiled = Compiled, tests = Tests}.

totals (State) ->
    U = length (State#state.uncompiled),
    B = length (State#state.bad),
    C = length (State#state.compiled),
    T = length (State#state.tests),
    Modules = U + B + C,
    State#state.channel ! {totals, {Modules, C, B, T, 0, 0}}.
