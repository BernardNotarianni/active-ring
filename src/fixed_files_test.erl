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
       "-test (test).",
       "test () -> ok."]}].

run () ->
    ok = fixtures: use_tree (tree (), fun run/2).

run (Root, Tree) ->
    ok = integrator_test: with_files (Root, Tree),
    ok = modules_test: with_files (Root, Tree).
