%%% Copyright (C) Dominic Williams
%%% All rights reserved.
%%% See file COPYING.

-module (directory_watcher).
-export ([init/2]).
-export ([init_recursive/2]).
-include_lib ("kernel/include/file.hrl").

init (Directory, F) ->
    D = filename: absname (Directory),
    check (D, F, dict: new ()).

init_recursive (Directory, F) ->
    D = filename: absname (Directory),
    Self = self (),
    Watcher = spawn_link (?MODULE, init, [D, send (Self)]),
    loop_recursive (D, F, [Watcher]).

check (Directory, F, State) ->
    New_state = list_dir (Directory, F),
    compare (F, State, New_state),
    loop (Directory, F, New_state).

list_dir (Directory, F) ->
    list_dir (Directory, F, file: list_dir (Directory)).

list_dir (Directory, _, {ok, Filenames}) ->
    Paths = [filename: join (Directory, F) || F <- Filenames],
    read_state (Paths);
list_dir (Directory, F, Error) ->
    F ({directory, Directory, Error}),
    dict: new ().

read_state (Filenames) ->
    lists: foldl (fun read_state/2, dict: new (), Filenames).

read_state (File_name, State) ->
    case file: read_file_info (File_name) of
	{ok, Info} ->
	    Value = value (Info#file_info.type, File_name),
	    dict: store (File_name, Value, State);
	_ ->
	    State
    end.

value (regular, Filename) ->
    {ok, Content} = file: read_file (Filename),
    {regular, erlang: md5 (Content)};
value (directory, _) ->
    directory.

loop (Directory, F, Filenames) ->
    receive
	check ->
	    check (Directory, F, Filenames);
	stop ->
	    F (bye)
    end.

loop_recursive (Directory, F, Watchers) ->
    receive
	{?MODULE, _, {directory, Dir, found}=Event} ->
	    Self = self (),
	    Watcher = spawn_link (?MODULE, init, [Dir, send (Self)]),
	    F (Event),
	    loop_recursive (Directory, F, [Watcher | Watchers]);
	{?MODULE, Watcher, {directory, _, {error, _}}} ->
	    Watcher ! stop,
	    loop_recursive (Directory, F, Watchers -- [Watcher]);
	{?MODULE, _, bye} ->
	    loop_recursive (Directory, F, Watchers);
	{?MODULE, _, Event} ->
	    F (Event),
	    loop_recursive (Directory, F, Watchers);
	check ->
	    lists: foreach (fun (P) -> P ! check end, Watchers),
	    loop_recursive (Directory, F, Watchers);
	stop ->
	    F (bye)
    end.

compare (F, Original, Modified) ->
    Compared = adlib: compare_dict (Modified, Original),
    dict: fold (fun notify_new/3, F, dict: fetch (new, Compared)),
    dict: fold (fun notify_lost/3, F, dict: fetch (lost, Compared)),
    dict: fold (fun notify_changed/3, F, dict: fetch (changed, Compared)),
    done.
    
notify_new (File_name, _, Fun) ->
    report_found (Fun, File_name),
    Fun.

report_found (F, Filename) ->
    F ({type (Filename), Filename, found}).

notify_lost (File_name, Value, Fun) ->
    report_lost (Fun, {File_name, Value}),
    Fun.

report_lost (F, {Filename, directory}) ->
    F ({directory, Filename, lost});
report_lost (F, {Filename, {regular, _}}) ->
    F ({{file, filename: extension (Filename)}, Filename, lost}).

notify_changed (File_name, {{regular, _}, {regular, _}}, Fun) ->
    report_changed (Fun, File_name),
    Fun;
notify_changed (File_name, {_, Original}, Fun) ->
    report_lost (Fun, {File_name, Original}),
    report_found (Fun, File_name),
    Fun.

report_changed (F, Filename) ->
    F ({type (Filename), Filename, changed}).
    
type (Path) ->
    type (file: read_file_info (Path), Path).

type ({ok, #file_info{type=directory}}, _) ->
    directory;
type ({ok, #file_info{type=regular}}, Path) ->
    {file, filename: extension (Path)}.

send (Pid) ->
    fun (Event) ->
	    Pid ! {?MODULE, self (), Event}
    end.

