-module (directory_tester_test).
-test (exports).
-export ([read_args/0]).

read_args () ->
    Tree = [{directory, "toto", []},
	    {directory, "titi", []}],
    fixtures: use_tree (Tree, fun read_args_dirs/2),
    fixtures: use_tree (Tree, fun read_args_paths/2),
    fixtures: use_tree (Tree, fun read_args_with_slave/2).

read_args_dirs (Dir, _) ->
    [Toto, Titi] = [filename: join (Dir, T) || T <- ["toto", "titi"]],
    Tests = [{[Toto], {[Toto], []}},
	     {[Toto, Titi], {[Toto], [{compiler, [{i, Titi}]}]}}],
    lists: foldl (fun read_args_test/2, 1, Tests).

read_args_paths (Dir, _) ->
    [Toto, Titi] = [filename: join (Dir, T) || T <- ["toto", "titi"]],
    Titi_toto = Titi ++ ":" ++ Toto,
    Tests = [{[Titi_toto],
	      {[Titi, Toto], []}},
	     {[Titi_toto, Titi_toto],
	      {[Titi, Toto], [{compiler, [{i, Titi}, {i, Toto}]}]}}],
    lists: foldl (fun read_args_test/2, 1, Tests).

read_args_with_slave (Dir, _) ->
    [Toto, Titi] = [filename: join (Dir, T) || T <- ["toto", "titi"]],
    Slave_args = "-pa /foo/bar -mnesia_dir /var/mnesia",
    Args = [Toto, Titi, Slave_args],
    {[Toto], Options} = directory_tester: read_args (Args),
    [{i, Titi}] = proplists: get_value (compiler, Options),
    Slave_args = proplists: get_value (slave, Options).

read_args_test ({In, Out}, Count) ->
    {Count, In, Out} = {Count, In, directory_tester: read_args (In)},
    Count + 1.
