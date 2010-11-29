%%% Copyright (C) Dominic Williams
%%% All rights reserved.
%%% See file COPYING.

-module (fixed_files_test).
-test (exports).
-export ([flat_files_run/0]).
-export ([tree_run/0]).

flat_files () ->
    [{file, "compiles.erl",
      ["-module (compiles).",
       "-export ([ok/0]).",
       "ok () -> ok."]},
     {file, "doesnt_compile.erl",
      "rubbish"},
     {file, "warnings.erl",
      ["-module (warnings).",
       "-export ([ok/0]).",
       "ok () -> ok.",
       "unused () -> unused."]},
     {file, "good_test.erl",
      ["-module (good_test).",
       "-test (exports).",
       "-export ([test1/0, test2/0]).",
       "test1 () -> ok.",
       "test2 () -> ok."]},
     {file, "tests_other.erl",
      ["-module (tests_other).",
       "-test (exports).",
       "-export ([passes/0, fails/0]).",
       "passes () -> ok = compiles: ok ().",
       "fails () -> nok = warnings: ok ()."]}].

flat_files_run () ->
    ok = fixtures: use_tree (flat_files (), fun flat_files_run/2).

flat_files_run (Root, Tree) ->
    ok = modules_test: with_files (Root, Tree),
    ok = integrator_test: with_files (Root, Tree).

tree () ->
    [{directory, "project",
      [{directory, "app1",
	[{directory, "src",
	  [{file, "my1.erl",
	    ["-module (my1).",
	     "-export ([myfun1/0, myfun2/0, myfun3/0]).",
	     "-include (\"myinc.hrl\").",
	     "-include (\"app2/include/inc.hrl\").",
	     "myfun1 () -> ?mydef.",
	     "myfun2 () -> ?def.",
	     "myfun3 () -> ?appdef."]},
	  {file, "myinc.hrl",
	   ["-define (mydef, mydef1)."]}]},
	 {directory, "include",
	  [{file, "inc.hrl",
	    ["-define (def, def1)."]}]}]},
       {directory, "app2",
	[{directory, "src",
	  [{file, "my2.erl",
	    ["-module (my2).",
	     "-export ([myfun1/0, myfun2/0, myfun3/0]).",
	     "-include (\"myinc.hrl\").",
	     "-include (\"inc.hrl\").",
	     "-include (\"3rd_inc.hrl\").",
	     "myfun1 () -> ?mydef.",
	     "myfun2 () -> ?def.",
	     "myfun3 () -> ?third."]},
	  {file, "myinc.hrl",
	   ["-define (mydef, mydef2)."]}]},
	 {directory, "include",
	  [{file, "inc.hrl",
	    ["-define (def, def2).",
	     "-define (appdef, appdef)."]}]}]},
       {directory, "tests",
	[{file, "tests.erl",
	  ["-module (tests).",
	   "-test (exports).",
	   "-export ([mydef1/0, mydef2/0, def1/0, def2/0]).",
	   "-export ([appdef/0, third/0]).",
	   "mydef1 () -> mydef1 = my1: myfun1 ().",
	   "mydef2 () -> mydef2 = my2: myfun1 ().",
	   "def1 () -> def2 = my1: myfun2 ().",
	   "def2 () -> def2 = my2: myfun2 ().",
	   "appdef () -> appdef = my1: myfun3 ().",
	   "third () -> third = my2: myfun3 ()."]}]}]},
     {directory, "3rdparty",
      [{file, "3rd_inc.hrl",
	["-define (third, third)."]}]}].

tree_run () ->
    ok = fixtures: use_tree (tree (), fun tree_run/2).

tree_run (Root, Tree) ->
    ok = integrator_test: with_directories (Root, Tree).
