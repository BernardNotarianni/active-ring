%%% Copyright (C) Dominic Williams, Nicolas Charpentier
%%% All rights reserved.
%%% See file COPYING.

-module (directory_watcher_test).
-test (exports).
-export ([tests_from_empty/0]).
-export ([tests_from_non_existent/0]).
-export ([tests_with_several/0]).
-export ([bad_symlinks_are_ignored/0]).
-export ([recursive/0]).
-export ([directories_can_be_removed/0]).
-export ([directories_can_be_removed_when_recursive/0]).
-export ([change_from_directory_to_file/0]).
-export ([change_from_directory_to_file_when_recursive/0]).
-export ([change_from_file_to_directory/0]).
-export ([change_from_file_to_directory_when_recursive/0]).
-export ([remove_and_add_in_same_check/0]).
-export ([insensitive_to_cwd/0]).
-export ([can_replace_all_in_same_check/0]).
-export ([can_find_two_at_a_time/0]).
-export([tree/0]).

tests_from_empty () ->
    ok = fixtures: use_tree ([], fun tests_from_empty/2).

tests_from_non_existent () ->
    Dir = fixtures: temporary_pathname (),
    Watcher = spawn_link (directory_watcher, init, [Dir, send_me ()]),
    {directory, Dir, {error, enoent}} = receive_one (),
    Watcher ! check,
    {directory, Dir, {error, enoent}} = receive_one (),
    ok = file: make_dir (Dir),
    Watcher ! check,
    timeout = receive_one (),
    ok = file: del_dir (Dir),
    Watcher ! {self (), stop},
    ok.

tests_with_several () ->
    Tree = [{file, "foo.txt", "Hello"},
	    {file, "bar.txt", "G'day"},
	    {file, "toto.erl", "-module(toto)."}],
    ok = fixtures: use_tree (Tree, fun tests_with_several/2).

bad_symlinks_are_ignored () ->
    ok = fixtures: use_tree ([], fun bad_symlinks_are_ignored/2).

recursive () ->
    ok = fixtures: use_tree (tree (), fun recursive/2).

directories_can_be_removed () ->
    ok = fixtures: use_tree (tree (), fun directories_can_be_removed/2).

directories_can_be_removed_when_recursive () ->
    F = fun directories_can_be_removed_when_recursive/2,
    ok = fixtures: use_tree (tree (), F).

change_from_directory_to_file () ->
    Tree = [{directory, "foo", []}],
    ok = fixtures: use_tree (Tree, fun change_from_directory_to_file/2).

change_from_file_to_directory () ->
    Tree = [{file, "foo", []}],
    ok = fixtures: use_tree (Tree, fun change_from_file_to_directory/2).

change_from_file_to_directory_when_recursive () ->
    F = fun change_from_file_to_directory_when_recursive/2,
    ok = fixtures: use_tree ([{file, "foo", "yo"}], F).

change_from_directory_to_file_when_recursive () ->
    F = fun change_from_directory_to_file_when_recursive/2,
    ok = fixtures: use_tree (tree (), F).

remove_and_add_in_same_check () ->    
    F = fun remove_and_add_in_same_check/2,
    ok = fixtures: use_tree ([{file, "foo", "foo"}], F).

insensitive_to_cwd () ->
    Tree = [{directory, "mydir", []}],
    Fun = fun insensitive_to_cwd/2,
    ok = fixtures: use_tree (Tree, Fun).
    
insensitive_to_cwd (Root, [{directory, Name, _}]) ->
    Dir = filename: join (Root, Name),
    Watcher = spawn_link (directory_watcher, init, [Dir, send_me ()]),
    receive_all (),
    {ok, Cwd} = file: get_cwd (),
    ok = file: set_cwd (Root),
    Watcher ! check,
    true = is_process_alive (Watcher),
    [] = receive_all (),
    ok = file: set_cwd (Cwd),
    ok.

can_replace_all_in_same_check () ->
    Tree = [{file, X, X} || X <- ["foo", "bar", "baz"]],
    F = fun can_replace_all_in_same_check/2,
    ok = fixtures: use_tree (Tree, F).

can_find_two_at_a_time () ->
    F = fun can_find_two_at_a_time/2,
    ok = fixtures: use_tree ([{file, "foo", "foo"}], F).

tree () ->
    Subsub = {directory, "subsubdir",
	      [{file, "subsubfile.sub", "titi"}]},
    Tree = [{file, "foo.txt", "Hello"},
	    {file, "bar.txt", "G'day"},
	    {file, "toto.erl", "-module(toto)."},
	    {directory, "subdir",
	     [{file, "subfile.ext", "toto"},
	      Subsub]}],
    Tree.

directories_can_be_removed (Dir, _) ->    
    Watcher = spawn_link (directory_watcher, init, [Dir, send_me ()]),
    receive_all (),
    Subdir = filename: join (Dir, "subdir"),
    fixtures: delete_tree (Subdir), 
    Watcher ! check,
    {directory, Subdir, lost} = receive_one (),
    ok.

directories_can_be_removed_when_recursive (Dir, _) ->    
    Watcher = spawn_link (directory_watcher, init_recursive, [Dir, send_me ()]),
    receive_all (),
    Subdir = filename: join ([Dir, "subdir", "subsubdir"]),
    ok = fixtures: delete_tree (Subdir), 
    Watcher ! check,
    File = filename: join (Subdir, "subsubfile.sub"),
    [{{file, ".sub"}, File, lost}, {directory, Subdir, lost}] = receive_all (),
    ok.

recursive (Dir, _) ->
    Watcher = spawn_link (directory_watcher, init_recursive, [Dir, send_me ()]),
    Subdir = filename: join (Dir, "subdir"),
    Found_subdir = {directory, Subdir, found},
    ok = receive_until_found (Found_subdir),
    Subfile = filename: join (Subdir, "subfile.ext"),
    Found_subfile = {{file, ".ext"}, Subfile, found},
    ok = receive_until_found (Found_subfile),
    Subsubfile = filename: join ([Subdir, "subsubdir", "subsubfile.sub"]),
    Found_subsub = {{file, ".sub"}, Subsubfile, found},
    ok = receive_until_found (Found_subsub),
    ok = file: write_file (Subsubfile, "not titi"),
    Watcher ! check,
    Change_subsub = {{file, ".sub"}, Subsubfile, changed},
    ok = receive_until_found (Change_subsub).    

bad_symlinks_are_ignored (Dir, _) ->
    Watcher = spawn_link (directory_watcher, init, [Dir, send_me ()]),
    Link = filename: join (Dir, "titi.erl"),
    Destination = filename: join (Dir, "nofile"),
    case file: make_symlink (Destination, Link) of
	ok ->
	    Watcher ! check,
	    timeout = receive_one ();
	{error, enotsup} ->
	    ok
    end,
    ok.
    
tests_from_empty (Dir, []) ->
    Watcher = spawn_link (directory_watcher, init, [Dir, send_me ()]),
    timeout = receive_one (),
    
    Filename = filename: join (Dir, "myfile.txt"),
    ok = file: write_file (Filename, list_to_binary ("Hello")),
    Watcher ! check,
    {{file, ".txt"}, Filename, found} = receive_one (),

    Subdir = filename: join (Dir, "mydir"),
    ok = file: make_dir (Subdir),
    Watcher ! check,
    {directory, Subdir, found} = receive_one (),
    
    Subfile = filename: join (Subdir, "mysubfile.txt"),
    ok = file: write_file (Subfile, list_to_binary ("Hello")),
    Watcher ! check,
    timeout = receive_one (),

    ok = file: delete (Subfile),
    ok = file: del_dir (Subdir),
    Watcher ! check,
    {directory, Subdir, lost} = receive_one (),

    rewrite_same_data (Filename),
    Watcher ! check,
    timeout = receive_one (),

    ok = file: write_file (Filename, list_to_binary ("Bye")),
    Watcher ! check,
    {{file, ".txt"}, Filename, changed} = receive_one (),
    
    Watcher ! stop,
    bye = receive_one (),
    false = is_process_alive (Watcher),
    ok.

rewrite_same_data (Filename) ->
    ok = file: write_file (Filename, list_to_binary ("Hello")).

tests_with_several (Dir, Tree) ->
    [Foo, Bar, Toto] = [filename: join (Dir, Name) || {file, Name, _} <- Tree],
    Watcher = spawn_link (directory_watcher, init, [Dir, send_me ()]),
    Finds = [receive_one(), receive_one(), receive_one()],
    [FoundBar, FoundFoo, FoundToto] = lists: keysort (2, Finds),
    {{file, ".txt"}, Bar, found} = FoundBar,
    {{file, ".txt"}, Foo, found} = FoundFoo,
    {{file, ".erl"}, Toto, found} = FoundToto,
    
    ok = file: write_file (Foo, list_to_binary ("Bye")),
    Watcher ! check,
    {{file, ".txt"}, Foo, changed} = receive_one (),
    
    ok = file: write_file (Foo, list_to_binary ("Not yet")),
    ok = file: write_file (Bar, list_to_binary ("Bye")),
    Watcher ! check,
    Changes = [receive_one(), receive_one()],
    [ChangedBar, ChangedFoo] = lists: keysort (2, Changes),
    {{file, ".txt"}, Bar, changed} = ChangedBar,
    {{file, ".txt"}, Foo, changed} = ChangedFoo,
    ok.

receive_one () ->
    receive {directory_watcher, _, Event} -> Event
    after 500 -> timeout
    end.

receive_until_found (Event) ->
    receive {directory_watcher, _, Event} -> ok
    after 500 -> timeout
    end.

receive_all () ->
    lists: reverse (receive_all ([])).

receive_all (Acc) ->
    receive {directory_watcher, _, Event} ->
	    receive_all ([Event | Acc])
    after 500 ->
	    Acc
    end.

change_from_directory_to_file (Root, [{directory, Name, []}]) ->
    Watcher = spawn_link (directory_watcher, init, [Root, send_me ()]),
    receive_all (),
    Path = filename: join (Root, Name),
    ok = file: del_dir (Path),
    ok = file: write_file (Path, list_to_binary ("hello")),
    Watcher ! check,
    [{directory, Path, lost}, {{file, ""}, Path, found}] = receive_all (),
    ok.

change_from_file_to_directory (Root, [{file, Name, []}]) ->
    Watcher = spawn_link (directory_watcher, init, [Root, send_me ()]),
    receive_all (),
    Path = filename: join (Root, Name),
    ok = file: delete (Path),
    ok = file: make_dir (Path),
    Watcher ! check,
    [{{file, ""}, Path, lost}, {directory, Path, found}] = receive_all (),
    ok.

change_from_file_to_directory_when_recursive (Root, [{file, Name, _}]) ->
    Watcher = spawn_link (directory_watcher, init_recursive, [Root, send_me ()]),
    receive_all (),
    Path = filename: join (Root, Name),
    file: delete (Path),
    ok = file: make_dir (Path),
    Watcher ! check,
    [{{file, ""}, Path, lost}, {directory, Path, found}] = receive_all (),
    New_file = filename: join (Path, "new.txt"),
    ok = file: write_file (New_file, list_to_binary ("new")),
    Watcher ! check,
    [{{file, ".txt"}, New_file, found}] = receive_all (),
    ok.

change_from_directory_to_file_when_recursive (Root, _) ->
    Watcher = spawn_link (directory_watcher, init_recursive, [Root, send_me ()]),
    receive_all (),
    Subdir = filename: join ([Root, "subdir", "subsubdir"]),
    ok = fixtures: delete_tree (Subdir),
    ok = file: write_file (Subdir, list_to_binary ("now a file")),
    Watcher ! check,
    [{{file, ".sub"}, _, lost},
     {directory, Subdir, lost},
     {{file, ""}, Subdir, found}] = receive_all (),
    ok.

remove_and_add_in_same_check (Root, _) ->
    Watcher = spawn_link (directory_watcher, init_recursive, [Root, send_me ()]),
    receive_all (),
    [Foo, Bar] = [filename: join (Root, X) || X <- ["foo", "bar"]],
    ok = file: delete (Foo),
    ok = file: write_file (Bar, list_to_binary ("bar")),
    Watcher ! check,
    [{{file, ""}, Bar, found},
     {{file, ""}, Foo, lost}] = receive_all (),
    ok.
    
can_replace_all_in_same_check (Root, Tree) ->
    Watcher = spawn_link (directory_watcher, init, [Root, send_me ()]),
    receive_all (),
    Replace = fun ({file, F, _}) ->
		     Old = filename: join (Root, F),
		     ok = file: delete (Old),
		      New = filename: join (Root, F ++ F),
		      ok = file: write_file (New, "hello")
	     end,
    ok = lists: foreach (Replace, Tree),
    Watcher ! check,
    Lost_files = [filename: join (Root, X) || {file, X, _} <- Tree],
    Found_files = [filename: join (Root, X++X) || {file, X, _} <- Tree],
    Lost = [{{file, ""}, X, lost} || X <- Lost_files],
    Found = [{{file, ""}, X, found} || X <- Found_files],
    Expected = lists: sort (Lost ++ Found),
    Received = lists: sort (receive_all ()),
    {Expected, Expected} = {Expected, Received},
    ok.

can_find_two_at_a_time (Root, _) ->
    Watcher = spawn_link (directory_watcher, init, [Root, send_me ()]),
    receive_all (),
    [Bar, Baz] = [filename: join (Root, X) || X <- ["bar", "baz"]],
    ok = file: write_file (Bar, "bar"),
    ok = file: write_file (Baz, "baz"),
    Watcher ! check,
    Found = [{{file, ""}, X, found} || X <- [Bar, Baz]],
    Expected = lists: sort (Found),
    Received = lists: sort (receive_all ()),
    {Expected, Expected} = {Expected, Received},
    ok.

send_me () ->
    Self = self (),
    fun (E) ->
	    Self ! {directory_watcher, self (), E}
    end.
