%%% Copyright (C) Dominic Williams
%%% All rights reserved.
%%% See file COPYING.

-module (compiler_test).
-test (exports).
-export ([compiles_and_reports_progress_warnings_and_errors/0]).
-export ([provides_binaries_when_all_compiled/0]).
-export ([recompiles_minimally_after_change/0]).
-export ([stops/0]).
-export ([can_start_empty_and_add_files/0]).
-export ([notifies_removed_files/0]).
-export ([notifies_removed_files_even_if_never_compiled/0]).
-export ([provides_all_binaries_not_just_latest_when_all_compiled/0]).
-export ([can_be_given_include_directories/0]).
-export ([discovers_hrl_files_and_includes_their_path/0]).
%% -export ([recompiles_includers/0]).
-export ([adds_root_to_include_path/0]).
-export ([reset_includes_none/0]).
-export ([reset_includes_found/0]).
-export ([can_be_given_several_directories/0]).
-include_lib("stdlib/include/ms_transform.hrl").

compiles_and_reports_progress_warnings_and_errors () ->
    F = fun compiles_and_reports_progress_warnings_and_errors/2,
    ok = fixtures: use_tree (tester_test:tree (), F).
    
compiles_and_reports_progress_warnings_and_errors (Root, _) ->
    Compiler = spawn_link (compiler, init, [notify_me (), [Root]]),
    Compiler ! check,
    Ms = receive_all (),
    Compiler ! stop,
    ok = check (Ms, unknown).

stops () ->
    ok = fixtures: use_tree ([], fun stops/2).

stops (Root, _) ->
    Compiler = spawn_link (compiler, init, [notify_me (), [Root]]),
    Compiler ! check,
    receive_all (),
    Compiler ! {self (), stop},
    ok = receive {Compiler, bye} -> ok after 500 -> timeout end,
    false = is_process_alive (Compiler),
    ok.
    
provides_binaries_when_all_compiled () ->
    F = fun provides_binaries_when_all_compiled/2,
    ok = fixtures: use_tree (good_erl_tree (), F).

recompiles_minimally_after_change () ->
    F = fun recompiles_minimally_after_change/2,
    ok = fixtures: use_tree (good_erl_tree (), F).

provides_all_binaries_not_just_latest_when_all_compiled () ->
    F = fun provides_all_binaries_not_just_latest_when_all_compiled/2,
    ok = fixtures: use_tree (bad_erl_tree (), F).

can_start_empty_and_add_files () ->
    F = fun can_start_empty_and_add_files/2,
    ok = fixtures: use_tree ([], F).

notifies_removed_files () ->
    F = fun notifies_removed_files/2,
    ok = fixtures: use_tree (good_erl_tree (), F).

notifies_removed_files_even_if_never_compiled () ->
    F = fun notifies_removed_files_even_if_never_compiled/2,
    Tree = [{file, "hello.erl", "rubbish"}],
    ok = fixtures: use_tree (Tree, F).

can_be_given_several_directories () ->
    Tree = [{directory, "src1", good_erl_tree ()},
	    {directory, "src2", [{file, "yo.erl", "-module(yo)."}]}],
    ok = fixtures: use_tree (Tree, fun can_be_given_several_directories/2).

can_be_given_several_directories (Root, _) ->
    Dirs = [filename: join (Root, D) || D <- ["src1", "src2"]],
    Compiler = spawn_link (compiler, init, [notify_me (), Dirs]),
    Compiler ! check,
    Ms = receive_all (),
    Compiler ! stop,
    [{3, 0, 0}, _, _, {3, 3, 3}, {{binaries, _}, _}] = Ms,
    ok.
    
can_be_given_include_directories () ->
    Src = "-module(inc).\n-include(\"inc.hrl\").",
    Inc = "-define(yo,\"YO\").",
    Tree = [{directory, "include", [{file, "inc.hrl", Inc}]},
	    {directory, "src", [{file, "inc.erl", Src}]}],
    ok = fixtures: use_tree (Tree, fun include_no_directory/2),
    ok = fixtures: use_tree (Tree, fun include_with_directory/2).

adds_root_to_include_path () ->
    Tree =
	[{directory, "include",
	  [{file, "eg_include.hrl", "-define(eg_macro,ok)."}]},
	 {directory, "src",
	  [{file, "eg_code_with_include.erl",
	    ["-module (eg_code_with_include).",
	     "-test (ok).",
	     "-export ([ok/0]).",
	     "-include (\"include/eg_include.hrl\").",
	     "ok () ->",
	     "    ok = ?eg_macro."]}]}],
    ok = fixtures: use_tree (Tree, fun adds_root_to_include_path/2).    

adds_root_to_include_path (Root, _) ->
    Compiler = spawn_link (compiler, init, [notify_me (), [Root]]),
    Compiler ! check,
    Ms = receive_all (),
    Compiler ! stop,
    [{1, 0, 0}, {1, 1, 1}, {{binaries, _}, _}] = Ms,
    ok.

discovers_hrl_files_and_includes_their_path () ->
    Tree = [{directory, "include",
	     [{file, "eg_include.hrl", "-define(eg_macro,ok)."}]},
	    {directory, "src",
	     [{file, "eg_code_with_include.erl",
	       ["-module (eg_code_with_include).",
		"-test (ok).",
		"-export ([ok/0]).",
		"-include (\"eg_include.hrl\").",
		"ok () ->",
		"    ok = ?eg_macro."]}]}],
    ok = fixtures: use_tree (Tree, fun discovers_hrl/2).    

discovers_hrl (Root, _) ->
    Compiler = spawn_link (compiler, init, [notify_me (), [Root]]),
    Compiler ! check,
    Ms = receive_all (),
    Compiler ! stop,
    [{1, 0, 0}, {1, 1, 1}, _] = Ms,
    ok.

provides_binaries_when_all_compiled (Root, _) ->
    Compiler = spawn_link (compiler, init, [notify_me (), [Root]]),
    Compiler ! check,
    Ms = receive_all (),
    Compiler ! stop,
    ok = check (Ms, unknown),
    {{binaries, Bs}, _} = lists: last (Ms),
    Chunks = [ beam_lib: chunks (B, [exports]) || B <- Bs],
    Modules = [M || {ok, {M, [{exports, [_, _, {run, 0}]}]}} <- Chunks],
    [gdbye, hello] = lists: sort (Modules),
    ok.

provides_all_binaries_not_just_latest_when_all_compiled (Root, [_, File]) ->
    Compiler = spawn_link (compiler, init, [notify_me (), [Root]]),
    Compiler ! check,
    [{2, 0, 0}, _, _, {2, 2, 1}] = receive_all (),
    {file, Filename, _} = File,
    Bin = list_to_binary ("-module(gdbye). -export([run/0]). run()->gdbye."),
    ok = file: write_file (filename: join (Root, Filename), Bin),
    Compiler ! check,
    [{2, 1, 1}, {2, 2, 2}, {{binaries, [_, _]}, _}] = receive_all (),
    ok.

recompiles_minimally_after_change (Root, _) ->
    Compiler = spawn_link (compiler, init, [notify_me (), [Root]]),
    Compiler ! check,
    receive_all (),
    File = filename: join (Root, "hello.erl"),
    Code = "-module(hello). -export([run/0]). run()->hello_howdy.",
    Bin = list_to_binary (Code),
    ok = file: write_file (File, Bin),
    Compiler ! check,
    [{2, 1, 1}, {2, 2, 2}, {{binaries, [B]}, _}] = receive_all (),
    Compiler ! stop,
    {ok, {hello, _}} = beam_lib: chunks (B, [exports]),
    ok.

can_start_empty_and_add_files (Root, []) ->
    Compiler = spawn_link (compiler, init, [notify_me (), [Root]]),
    Compiler ! check,
    [timeout] = receive_all (),
    File = filename: join (Root, "hello.erl"),
    Bin = list_to_binary ("-module(hello). -export([run/0]). run()->hello."),
    ok = file: write_file (File, Bin),
    Compiler ! check,
    [{1, 0, 0}, {1, 1, 1}, {{binaries, [_]}, _}] = receive_all (),
    Compiler ! stop,
    ok.

notifies_removed_files (Root, [F, _]) ->
    Compiler = spawn_link (compiler, init, [notify_me (), [Root]]),
    Compiler ! check,
    receive_all (),
    {file, File, _} = F,
    ok = file: delete (filename: join (Root, File)),
    Compiler ! check,
    [{1, 1, 1}, {{binaries, []}, {removed, [hello]}}] = receive_all (),
    Compiler ! {self (), stop},
    ok.

notifies_removed_files_even_if_never_compiled (Root, [F]) ->
    Compiler = spawn_link (compiler, init, [notify_me (), [Root]]),
    Compiler ! check,
    [{1, 0, 0}, {_, _}, {1, 1, 0}] = receive_all (),
    {file, File, _} = F,
    Filename = filename: join (Root, File),
    Module = modules: module_name (Filename),
    ok = file: delete (Filename),
    Compiler ! check,
    [{0, 0, 0}, {{binaries, []}, {removed, [Module]}}] = receive_all (),
    Compiler ! {self (), stop},
    ok.

include_no_directory (Root, _) ->
    Src = filename: join (Root, "src"),
    Compiler = spawn_link (compiler, init, [notify_me (), [Src]]),
    Compiler ! check,
    [{1, 0, 0}, {_, _}, {1, 1, 0}] = receive_all (),
    Compiler ! {self (), stop},
    ok.

include_with_directory (Root, _) ->
    Src = filename: join (Root, "src"),
    Inc = filename: join (Root, "include"),
    Compiler = spawn_link (compiler, init, [notify_me (), [Src], [{i, Inc}]]),
    Compiler ! check,
    [{1, 0, 0}, {1, 1, 1}, {{binaries, _}, _}] = receive_all (),
    Compiler ! {self (), stop},
    ok.
    
check ([{Total, 0, 0} | _] = Xs, unknown) ->
    check (Xs, Total);
check ([{Total, M1, N1}, {Total, M2, N2} = X | Xs], Total)
  when M2 == M1+1, N2 == N1 + 1 ->
    check ([X | Xs], Total);
check ([{Total, M1, N1}, {[], _}, {Total, M2, N2} = X | Xs], Total)
  when M2 == M1+1, N2 == N1 + 1 ->
    check ([X | Xs], Total);
check ([{Total, M1, N1}, {_, _}, {Total, M2, N2} = X | Xs], Total)
  when M2 == M1+1, N2 == N1 ->
    check ([X | Xs], Total);
check ([{Total, Total, N}], Total) when N < Total ->
    ok;
check ([{Total, Total, Total}, {{binaries, _}, {removed, _}}], Total) ->
    ok.

good_erl_tree () ->
    [{file, "hello.erl", "-module(hello). -export([run/0]). run()->hello."},
     {file, "gdbye.erl", "-module(gdbye). -export([run/0]). run()->gdbye."}].

bad_erl_tree () ->
    [{file, "hello.erl", "-module(hello). -export([run/0]). run()->hello."},
     {file, "gdbye.erl", "-module(gdbye) -export([run/0]) run()->gdbye"}].

notify_me () ->
    Self = self (),
    fun (M) -> Self ! M end.

receive_all () ->
    receive_all ([]).

receive_all (Ms) ->
    receive
	{Total, Total, Total} = Ts ->
	    receive {{binaries, _}, {removed, _}} = Bs ->
		    lists: reverse ([Bs, Ts | Ms])
	    end;
	{Total, Total, _} = Ts ->
	    lists: reverse ([Ts | Ms]);
	M ->
	    receive_all ([M | Ms])
    after 2000 -> lists: reverse ([timeout | Ms])
    end.

reset_includes_none () ->
    [debug, bla] = compiler: reset_includes (dict: new (), [debug, bla]).

reset_includes_found () ->
    Found = [{"/dir/file.hrl", found}, {"/dir/subdir/file2.hrl", found}],
    New = dict: from_list (Found),
    Options = [debug, bla],
    Expected = [debug, bla, {i, "/dir/subdir"}, {i, "/dir"}],
    Expected = compiler: reset_includes (New, Options).

%% recompiles_includers () ->
%%     Tree = modules_test: includes_tree (),
%%     ok = fixtures: use_tree (Tree, fun recompiles_includers/2).

%% recompiles_includers (Root, _) ->
%%     Compiler = spawn_link (compiler, init, [notify_me (), [Root]]),
%%     Compiler ! check,
%%     [{3, 0, 0}, _, _, {3, 3, 3}, _] = receive_all (),
%%     Include = filename: join (Root, "eg_include.hrl"),
%%     Define = "-define(eg_macro, ko)",
%%     ok = file: write_file (Include, Define),
%%     Compiler ! check,
%%     [{3, 2, 2}, {3, 3, 3}, {{binaries, _}, _}] = receive_all (),
%%     ok.
