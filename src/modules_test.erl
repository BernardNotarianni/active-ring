%%% Copyright (C) Dominic Williams
%%% All rights reserved.
%%% See file COPYING.

-module (modules_test).
-test (module_name).
-test (locate).
-test (includes).
-test ('OTP_include_dir').
-test (normalise_filename).
-test (member_of_includes).
-export ([module_name/0]).
-export ([locate/0]).
-export ([includes_tree/0]).
-export ([includes/0]).
-export ([with_files/2]).
-export (['OTP_include_dir'/0]).
-export ([member_of_includes/0]).
-export ([normalise_filename/0]).

module_name () ->
    hello = modules: module_name ("hello.erl"),
    hello = modules: module_name ("bla/hello.erl").
    
locate () ->
    ok = fixtures: use_tree (tree (), fun locate/2).

tree () ->
    [{file, "eg_code.erl",
      ["-module (eg_code).",
       "-export ([ok/0]).",
       "ok () ->",
       "    ok.",
       "yo () ->",
       "    yo."]}].

locate (Root, _) ->
    File = filename: join (Root, "eg_code.erl"),
    Binary = modules: to_binary (File),
    {File, 3} = modules: locate ({eg_code, ok, 0}, Binary),
    ok.

includes_tree () ->
    [{file, "eg_include.hrl", "-define(eg_macro,ok)."},
     {file, "eg_code_with_include.erl",
      ["-module (eg_code_with_include).",
       "-export ([ok/0]).",
       "-include (\"eg_include.hrl\").",
       "ok () -> ?eg_macro."]},
     {file, "eg_code_no_include.erl",
      ["-module (eg_code_no_include).",
       "-export ([ok/0]).",
       "ok () -> ok."]},
     {directory, "dir",
      [{file, "eg_include_in_dir.hrl", "-define(eg_macro2,nok)."}]},
     {file, "eg_code_include_with_path.erl",
      ["-module (eg_code_include_with_path).",
       "-include (\"dir/eg_include_in_dir.xxx\").",
       "-export ([ok/0]).",
       "ok () -> ok."]}].

includes () ->
    ok = fixtures: use_tree (includes_tree (), fun includes/2).

includes (Root, _) ->
    Without = filename: join (Root, "eg_code_no_include.erl"),
    [] = modules: includes (Without),
    With = filename: join (Root, "eg_code_with_include.erl"),
    ["eg_include.hrl"] = modules: includes (With),
    With_path = filename: join (Root, "eg_code_include_with_path.erl"),
    ["dir/eg_include_in_dir.xxx"] = modules: includes (With_path),
    ok.

with_files (Root, Fs) ->
    Ps = [filename: join (Root, F) || {file, F, _} <- lists: sublist (Fs, 4)],
    [Compiles, Doesnt, Warnings, Tests] = Ps,
    {Compiles, compiles, ok, {Bin1, [], []}} = modules: compile (Compiles, []),
    {Compiles, 3} = modules: locate ({compiles, ok, 0}, Bin1),
    {Doesnt, doesnt_compile, error, {_, _}} = modules: compile (Doesnt, []),
    {Warnings, warnings, ok, {Bin2, [], Ws}} = modules: compile (Warnings, []),
    {Warnings, 4} = modules: locate ({warnings, unused, 0}, Bin2),
    [{Warnings, [{4, erl_lint, {unused_function, _}}]}] = Ws,
    {Tests, good_test, ok, {_, Ts, _}} = modules: compile (Tests, []),
    [test2, test1] = Ts,
    ok.
    
'OTP_include_dir' () ->
    File = filename: join (["app", "src", "foo.erl"]),
    Include = filename: join ("app", "include"),
    Include = modules: 'OTP_include_dir' (File).

normalise_filename () ->
    "/tmp/toto/foo" = modules: normalise_filename ("/tmp/toto/foo"),
    "/tmp/foo" = modules: normalise_filename ("/tmp/toto/../foo"), 
    "/foo" = modules: normalise_filename ("/tmp/toto/../../foo"),
    "/tmp/foo" = modules: normalise_filename ("/tmp/./foo").
   
member_of_includes () ->
    Tests =
	[{"/tmp/proj/toto.hrl",
	  "/tmp/proj/toto.erl",
	  ["toto.hrl"],
	  true},
	 {"/tmp/proj/toto.hrl",
	  "/other/toto.erl",
	  ["titi.xxx", "toto.hrl"],
	 false},
	 {"/tmp/app/include/myinclude.hrl",
	  "/tmp/app/src/foo.erl",
	  ["myinclude.hrl"],
	  true},
	 {"/tmp/app/include/myinclude.hrl",
	  "/tmp/app/src/foo.erl",
	  ["../include/myinclude.hrl"],
	  true},
	 {"/tmp/app/include/myinclude.hrl",
	  "/tmp/app/src/foo.erl",
	  ["../../app/include/myinclude.hrl"],
	  true}],
    Test = fun ({F, S, Is, Expected}, Count) ->
		   Result = modules: member_of_includes (F, S, Is),
		   {Count, Expected} = {Count, Result},
		   Count + 1
	   end,
    lists: foldl (Test, 1, Tests),
    ok.
    
