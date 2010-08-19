%%% Copyright (c) Dominic Williams, Nicolas Charpentier, Virgile Delecolle.
%%% All rights reserved.
%%% See file COPYING.

-module (fixtures_test).
-test (exports).
-export ([temporary_pathname/0]).
-export ([tree_handling/0]).
-export ([use_tree_creates_the_tree_first_and_destroys_it_after/0]).
-export ([use_tree_passes_a_tree_to_a_fun/0]).
-export ([use_tree_destroys_tree_even_if_fun_crashes/0]).
-export ([use_tree_destroys_tree_even_if_trapexit/0]).
-export ([use_tree_destroys_tree_even_if_killed_by_parent_link/0]).
-export ([make_tree_accepts_single_character_content/0]).

temporary_pathname () ->
	Name = fixtures: temporary_pathname (),
	true = is_list (Name),
	{error, enoent} = file: read_file_info (Name),
	Next_name = fixtures: temporary_pathname (),
	false = string: equal (Name, Next_name),
	ok = file: make_dir (Name),
	ok = file: del_dir (Name),
	ok = file: write_file (Next_name, list_to_binary ("Hello world")),
	ok = file: delete (Next_name),
	pass.

tree () ->
    [{file, "test", "Hello world"},
     {file, "test2", ["Goodbye", "world!"]},
     {directory, "testdir",
      [{file, "toto", "Silly"},
       {directory, "testdir2", [{file, "titi", "Very silly"}]}]}].
    
test_tree (Dir) ->
    fun ({Path, Expected}, Count) ->
	    Filename = filename: join ([Dir | Path]),
	    {ok, Content} = file: read_file (Filename),
	    {Count, Expected} = {Count, binary_to_list (Content)},
	    Count + 1
    end.
    
tree_handling () ->
    Tmp_dirname = fixtures: temporary_pathname(),
    Tree = tree (),
    fixtures: make_tree (Tmp_dirname, Tree),
    Test = test_tree (Tmp_dirname),
    Table =
	[{["test"], "Hello world"},
	 {["test2"], "Goodbye\nworld!"},
	 {["testdir", "toto"], "Silly"},
	 {["testdir", "testdir2", "titi"], "Very silly"}],
    lists: foldl (Test, 1, Table),
    fixtures: delete_tree (Tmp_dirname),
    {error, enoent} = file: read_file_info (Tmp_dirname),
    pass.

make_tree_accepts_single_character_content () ->
    Tmp_dirname = fixtures: temporary_pathname(),
    Tree = [{file, "myfile", "a"}],
    ok = fixtures: make_tree (Tmp_dirname, Tree),
    {ok, B} = file: read_file (filename: join (Tmp_dirname, "myfile")),
    "a" = binary_to_list (B),
    fixtures: delete_tree (Tmp_dirname),
    pass.
    
use_tree_passes_a_tree_to_a_fun () ->
    Tmp = fixtures: temporary_pathname (),
    Tree = tree (),
    Ref = make_ref (),
    No_op = fun (D, T) when D == Tmp, T == Tree-> Ref end,
    Ref = fixtures: use_tree (Tmp, Tree, No_op),
    {error,enoent} = file: read_file_info (Tmp),
    pass.

use_tree_creates_the_tree_first_and_destroys_it_after () ->
    Tmp = fixtures: temporary_pathname (),
    Result = fixtures: use_tree (Tmp, tree (), fun keep_real_files/2),
    ["test", "test2", "testdir"] = Result,
    {error,enoent} = file: read_file_info (Tmp),
    pass.

keep_real_files (Dir, Tree) ->
    [X || {_,X,_} <- Tree, filelib: is_file (filename: join (Dir, X))].

use_tree_destroys_tree_even_if_fun_crashes () ->
    Tmp = fixtures: temporary_pathname (),
    Tree = tree (),
    ok =
	try
	    fixtures: use_tree (Tmp, Tree, fun suicide/2),
	    no_crash
	catch
	    _: {suicide, Tmp, Tree} -> ok;
	    C: E -> {unexpected, C, E}
	end,
    {error, enoent} = file: read_file_info (Tmp),
    pass.

spawn_undef (_, _) ->
    spawn_link (blabla, blabla, []),
    receive M -> M end.
	    
use_tree_destroys_tree_even_if_trapexit () ->
    Tmp = fixtures: temporary_pathname (),
    ok =
	try
	    fixtures: use_tree (Tmp, [], fun spawn_undef/2),
	    no_crash
	catch
	    _: {undef, _} -> ok;
	    C:E -> {unexpected, C, E}
	end,
    {error, enoent} = file: read_file_info (Tmp),
    pass.

suicide (Dir, Tree) ->    
    exit ({suicide, Dir, Tree}).
    
use_tree_destroys_tree_even_if_killed_by_parent_link () ->
    Tmp = fixtures: temporary_pathname (),
    Self = self (),
    ok =
	try
	    Long = fun (_, _) -> Self ! tree_built, timer: sleep (5000) end,
	    Use_tree = fun () -> fixtures: use_tree (Tmp, [], Long) end,
	    Impatient = fun () -> spawn_link (Use_tree),
				  receive tree_built -> ok end,
				  throw (stop) end,
	    Pid = spawn (Impatient),
	    receive tree_built -> Pid ! tree_built end,
	    ok
	catch
	    C: E -> {unexpected, C, E}
	end,
    timer: sleep (500),
    {error, enoent} = file: read_file_info (Tmp),
    pass.
