-module (integrator).
-export ([init/1]).
-import (dict, [new/0, store/3, fold/3]).

init (Channel) ->
    idle (Channel, new ()).

idle (Channel, Modules) ->
    Channel ! totals (Modules),
    receive
	stop ->
	    Channel ! stopped;
	{{file, ".erl"}, F, found} ->
	    compiling (F, Channel, store (F, new, Modules));
	{{file, ".erl"}, F, changed} ->
	    compiling (F, Channel, store (F, changed, Modules));
	Other ->
	    Channel ! {unexpected, Other},
	    idle (Channel, Modules)
    end.

compiling (F, Channel, Modules) ->
    Channel ! totals (Modules),
    Next = store_compilation (modules: compile2 (F), Channel, Modules),
    idle (Channel, Next).

store_compilation ({File, Module, error, Errors}, Channel, Modules) ->
    Channel ! {compile, {Module, error, Errors}},
    store (File, error, Modules);
store_compilation ({File, Module, ok, {Binary, Ts, Ws}}, Channel, Modules) ->
    Channel ! {compile, {Module, ok, Ws}},
    store (File, {ok, Module, Binary, Ts}, Modules).

totals (Modules) ->
    {totals, fold (fun totals/3, {0,0,0,0,0,0}, Modules)}.

totals (_, new, {M, C, E, T, P, F}) ->
    {M+1, C, E, T, P, F};
totals (_, changed, {M, C, E, T, P, F}) ->
    {M+1, C, E, T, P, F};
totals (_, error, {M, C, E, T, P, F}) ->
    {M+1, C, E+1, T, P, F};
totals (_, {ok, _, _, Ts}, {M, C, E, T, P, F}) ->
    {M+1, C+1, E, T + length(Ts), P, F}.
