-module (fixed_files_test).
-test (run).
-export ([run/0]).

tree () ->
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
       "test2 () -> ok."]}].

run () ->
    ok = fixtures: use_tree (tree (), fun run/2).

run (Root, Tree) ->
    ok = modules_test: with_files (Root, Tree),
    ok = integrator_test: with_files (Root, Tree).
