-module (integrator).
-export ([init/1]).
-record (state, {channel, uncompiled = [], bad = []}).

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
    case modules: compile (F) of
	{error, Errors, _} ->
	    State#state.channel ! {errors, {F, Errors}},
	    Bad = [F | State#state.bad],
	    compiling (State#state {uncompiled = Fs, bad = Bad})
    end;
compiling (#state {uncompiled = []} = State) ->
    idle (State).
	    
totals (State) ->
    U = length (State#state.uncompiled),
    B = length (State#state.bad),
    Total = U + B,
    State#state.channel ! {totals, Total, U, 0, 0, 0, 0}.
