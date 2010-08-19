%%% Copyright (c) Dominic Williams, Nicolas Charpentier, Virgile Delecolle,
%%% Fabrice Nourisson, Jacques Couvreur.
%%% All rights reserved.
%%% See file COPYING.

-module (fixtures).
-export ([temporary_pathname/0]).
-export ([make_tree/2, delete_tree/1]).
-export ([use_tree/3]).
-export ([use_tree/2]).
-export ([unique_string/0]).
-include_lib ("kernel/include/file.hrl").

make_tree (Root, Tree) ->
    ok = file: make_dir (Root),
    populate (Root, Tree).

delete_tree (Root) ->
    depopulate (Root),
    ok = file: del_dir (Root).

temporary_pathname () ->
    Roots = [os: getenv (X) || X <- ["TMP", "TEMP", "HOME"], os: getenv (X) /= false],
    Root = hd ([X || X <- Roots, filelib: is_dir (X) == true]),
    Pathname = filename: join (Root, unique_string ()),
    {error, enoent} = file:read_file_info (Pathname),
    Pathname.

unique_string () ->
    Node = atom_to_list (node ()),
    [Name, Host] = string: tokens (Node, "@"),
    [Mega, Sec, Micro] = [integer_to_list (X) || X <- tuple_to_list (now ())],
    Name ++ "_at_" ++ Host ++ "_" ++ Mega ++ "_" ++ Sec ++ "_" ++ Micro.

populate (Directory, [{file, Name, Content} | Tail]) ->
    ok = file: write_file (filename: join (Directory, Name), normalise (Content)),
    populate (Directory, Tail);
populate (Directory, [{directory, Name, Content} | Tail]) ->
    Pathname = filename: join (Directory, Name),
    ok = file: make_dir (Pathname),
    populate (Pathname, Content),
    populate (Directory, Tail);
populate (_, []) ->
    ok.

normalise ([String]) when is_list (String) ->
    String;
normalise ([H | T]) when is_list (H) ->
    %% Inserts newlines when list of strings...
    normalise ([string: concat (H, string: concat ("\n", hd (T))) | tl (T)]);
normalise (String) when is_list (String) ->
    String.

depopulate (Directory) ->
    {ok, Filename_list} = file: list_dir (Directory),
    Delete = fun (Filename) ->
		     Pathname = filename: join (Directory, Filename),
		     {ok, File_info} = file: read_link_info (Pathname),
		     case File_info#file_info.type of
			 directory ->
			     delete_tree (Pathname);
			 regular ->
			     ok = file: delete (Pathname);
			 symlink ->
			     ok = file: delete (Pathname)
		     end
	     end,
    lists: foreach (Delete, Filename_list).

use_tree (Tree, Fun) ->
    use_tree (temporary_pathname (), Tree, Fun).

use_tree (Dir, Tree, Fun) ->
    Self = self (),
    Pid = spawn_link (fun() -> safe_call (Self, Dir, Tree, Fun) end),
    receive
	{Pid, {'EXIT', Error}} -> exit (Error);
	{Pid, Result} -> Result
    end.

safe_call (Parent, Dir, Tree, Fun) ->
    process_flag (trap_exit, true),
    Self = self (),
    make_tree (Dir, Tree),
    Pid = spawn_link (fun () -> Self ! {self (), Fun (Dir, Tree)} end),
    receive M -> delete_tree (Dir) end,
    case M of
	{Pid, Result} -> Parent ! {Self, Result};
	{'EXIT', Pid, Error} -> Parent ! {Self, {'EXIT', Error}};
	_ -> ignore
    end.
