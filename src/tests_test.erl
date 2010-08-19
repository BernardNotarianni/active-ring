%%% Copyright (C) Dominic Williams, Nicolas Charpentier
%%% All rights reserved.
%%% See file COPYING.

-module (tests_test).
-export ([filter_by_attribute/0]).
-test (exports).

filter_by_attribute () ->
    non_tests_returns_empty_list(),
    test_exports_returns_list_of_tests_from_unloaded_binary (),
    test_non_exports_also (),
    ok.

non_tests_returns_empty_list () ->
    Tree = [{file, "my_code.erl",
	     ["-module (my_code).",
	      "-export ([ok/0]).",
	      "ok () ->",
	      "ok."]}],
    Fun = fun non_tests_returns_empty_list/2,
    ok = fixtures: use_tree (Tree, Fun).

non_tests_returns_empty_list (Dir, [{file, Name, _}]) ->
    Path = filename: join (Dir, Name),
    Binary = modules: to_binary (Path),
    {_, my_code, []} = tests: filter_by_attribute (Binary),
    ok.

test_exports_returns_list_of_tests_from_unloaded_binary () ->
    Tree = [{file, "my_tests.erl",
	     ["-module (my_tests).",
	      "-test (exports).",
	      "-export ([ok/0, nok/0]).",
	      "ok () ->",
	      "    ok = list_to_existing_atom (\"ok\").",
	      "nok () ->",
	      "    ok = list_to_existing_atom (\"nok\")."]}],
    Fun = fun test_exports_returns_list_of_tests_from_unloaded_binary/2,
    ok = fixtures: use_tree (Tree, Fun).

test_exports_returns_list_of_tests_from_unloaded_binary (Dir, [{_, Name, _}]) ->
    Path = filename: join (Dir, Name),
    Binary = modules: to_binary (Path),
    false = code: is_loaded (my_tests),
    {_, my_tests, [ok, nok]} = tests: filter_by_attribute (Binary),
    false = code: is_loaded (my_tests),
    ok.

test_non_exports_also () ->
    Tree = [{file, "my_test_not_exports.erl",
	     ["-module (my_test_not_exports).",
	      "-test (ok).",
	      "-export ([ok/0, nok/0]).",
	      "",
	      "ok () ->",
	      "    ok = list_to_existing_atom (\"ok\").",
	      "",
	      "nok () ->",
	      "    ok = list_to_existing_atom (\"nok\")."]}],
    Fun = fun test_non_exports_also/2,
    ok = fixtures: use_tree (Tree, Fun).

test_non_exports_also (Dir, [{file, Name, _}]) ->
    Path = filename: join (Dir, Name),
    Binary = modules: to_binary (Path),
    false = code: is_loaded (my_test_not_exports),
    {_, my_test_not_exports, [ok]} = tests: filter_by_attribute (Binary),
    false = code: is_loaded (my_test_not_exports),
    ok.
