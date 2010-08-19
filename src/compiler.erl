%%% Copyright (C) Dominic Williams
%%% All rights reserved.
%%% See file COPYING.

-module (compiler).
-export ([init/2]).
-export ([init/3]).
-export ([reset_includes/2]).

init (Notify, Dirs) ->
    init (Notify, Dirs, []).

init (Notify, Dirs, Options) ->
    Watchers = lists: foldl (fun watcher/2, [], Dirs),
    Includes = [{i, D} || D <- Dirs],
    State = {dict: new (), dict: new (), [], [], Includes ++ Options},
    loop (Notify, Watchers, State).

watcher (Dir, Acc) ->
    Args = [Dir, notify_me ()],
    Watcher = spawn_link (directory_watcher, init_recursive, Args),
    [Watcher | Acc].
    
loop (Notify, Watchers, State) ->
    receive
	check ->
	    [W ! check || W <- Watchers],
	    {Modules, Includes, Binaries, Removed, Options} = State,
	    Received = receive_files (Modules, Includes),
	    {New_modules, New_includes} = Received,
	    New_options = reset_includes (New_includes, Options),
	    New_state = {New_modules, New_includes, Binaries,
			 Removed, New_options},
	    Last_state =
		if
		    New_modules /= Modules ->
			compile (Notify, New_state);
		    true ->
			New_state
		end,
	    loop (Notify, Watchers, Last_state);
	{Pid, stop} ->
	    Pid ! {self (), bye}
    end.

receive_files (Modules, Includes) ->
%%	    Includes = sets: from_list ([D || {i, D} <- Options]),
    receive
	{watcher, {{file, ".erl"}, File, Event}} ->
	    receive_files (dict: store (File, Event, Modules), Includes);
	{watcher, {{file, ".hrl"}, File, Event}} ->
	    receive_files (Modules, dict: store (File, Event, Includes));
	{watcher, _} ->
	    receive_files (Modules, Includes)
    after 500 ->
	    {Modules, Includes}
    end.

compile (Notify, State) ->
    {Modules, _, _, _, _} = State,
    Notify (totals (Modules)),
    Process = process_fun (Notify),
    Processed = dict: fold (Process, State, Modules),
    notify_end (Notify, Processed).

reset_includes (Dict, Options) ->
    dict: fold (fun reset_includes/3, Options, Dict).

reset_includes (File, found, Options) ->
    Is_include = fun ({i, _}) -> true; (_) -> false end,
    {Includes, Other} = lists: partition (Is_include, Options),
    Dirs = sets: from_list ([D || {i, D} <- Includes]),
    Dir = filename: dirname (File),
    New_dirs = sets: add_element (Dir, Dirs),
    New_includes = [{i, D} || D <- sets: to_list (New_dirs)],
    Other ++ New_includes;
reset_includes (_, _, Options) ->
    Options.

process_fun (Notify) ->
    fun (File, Event, Acc) when Event == found; Event == changed ->
	    {Modules, Includes, Binaries, Removed, Options} = Acc,
	    Result = modules: compile (File, Options),
	    notify_result (Result, Notify),
	    New_modules = dict: store (File, Result, Modules),
	    Notify (totals (New_modules)),
	    New_binaries = binaries (Result, Binaries),
	    {New_modules, Includes, New_binaries, Removed, Options};
	(File, Event, Acc) when Event == lost ->
	    {Modules, Includes, Binaries, Removed, Options} = Acc,
	    New_modules = dict: erase (File, Modules),
	    New_removed = [modules: module_name (File) | Removed],
	    {New_modules, Includes, Binaries, New_removed, Options};
	(_, _, Acc) ->
	    Acc
    end.

notify_me () ->
    Self = self (),
    fun (E) -> Self ! {watcher, E} end.
	    
totals (Modules) ->
    dict: fold (fun count/3, {0, 0, 0}, Modules).

count (_, lost, Acc) ->
    Acc;
count (_, {ok, _, _, _}, {Total, Compiled, Successful}) ->
    {Total + 1, Compiled + 1, Successful + 1};
count (_, {error, _, _}, {Total, Compiled, Successful}) ->
    {Total + 1, Compiled + 1, Successful};
count (_, _, {Total, Compiled, Successful}) ->
    {Total + 1, Compiled, Successful}.
    
notify_result ({ok, _, _, []}, _) ->
    pass;
notify_result ({ok, _, _, Warnings}, Notify) ->
    Notify ({[], Warnings});
notify_result ({error, Errors, Warnings},Notify) ->
    Notify ({Errors, Warnings}).

binaries ({ok, _, B, _}, Bs) ->
    [B | Bs];
binaries ({error, _, _}, Bs) ->
    Bs.

notify_end (Notify, State) ->
    {Modules, _,  _, _, _} = State,
    notify_end (Notify, totals (Modules), State).

notify_end (Notify, {N, N, N}, {Modules, Includes, Binaries, Removed, Options}) ->
    Notify ({{binaries, Binaries}, {removed, Removed}}),
    {Modules, Includes, [], [], Options};
notify_end (_, _, State) ->
    State.
