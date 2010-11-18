%%% Copyright (C) Dominic Williams
%%% All rights reserved.
%%% See file COPYING.

-module (directory_tester).
-export ([init/1, init/2, init/3]).
-export ([run_once/1, run_once/2, run_once/3]).
-export ([read_args/1]).

run_once (Args) ->
    {Directories, Options} = read_args (Args),
    run_once (Directories, Options).

run_once (Directories, All_options) ->
    Slave_args = proplists: get_value (slave, All_options),
    Options = proplists: delete (slave, All_options),
    run_once (Directories, slave (Slave_args), Options).

run_once (Directories, Node, Options) ->
    run (start (Directories, Node, Options)).

init (Args) ->
    {Directories, Options} = read_args (Args),
    init (Directories, Options).

init (Directories, All_options) ->
    Slave_args = proplists: get_value (slave, All_options),
    Options = proplists: delete (slave, All_options),
    init (Directories, slave (Slave_args), Options). 
    
init (Directories, Node, Options) ->
    loop (start (Directories, Node, Options)).

slave (undefined) ->
    {Host, Name} = integrator: slave_node (node ()),
    {ok, Slave} = slave: start_link (Host, Name),
    Slave;
slave (Args) when is_list (Args) ->
    {Host, Name} = integrator: slave_node (node ()),
    {ok, Slave} = slave: start_link (Host, Name, Args),
    Slave.

start (Directories, Node, Options) ->
    Compiler_options = options (compiler, Options),
    Compiler_args = [notify_me (compiler), Directories, Compiler_options],
    Compiler = spawn_link (compiler, init, Compiler_args),
    Tester = spawn_link (tester, init, [notify_me (tester), Node]),
    Compiler ! check,
    Printer = spawn_link (text_printer, init, [standard_io]),
    {Compiler, Tester, Printer}.

read_args (Args) when length (Args) == 1 ->
    [Dirs] = read_path_args (Args),
    {Dirs, []};
read_args (Args) when length (Args) == 2 ->
    [Dirs, Incs] = read_path_args (Args),
    Options = [{compiler, [{i, I} || I <- Incs]}],
    {Dirs, Options};
read_args ([Arg1, Arg2, Slave_args]) ->
    {Dirs, C_options} = read_args ([Arg1, Arg2]),
    {Dirs, [{slave, Slave_args} | C_options]}.

read_path_args (Paths) ->
    Dirs = [string: tokens (P, ":") || P <- Paths],
    Not_dir = [D || D <- lists: concat (Dirs), not filelib: is_dir (D)],
    {not_dir, []} = {not_dir, Not_dir},
    Dirs.

notify_me (Atom) ->
    Parent = self (),
    fun (Event) ->
	    Parent ! {notify, {self (), Atom, Event}}
    end.

loop ({Compiler, Tester, Printer}) ->
    receive
	stop ->
	    Compiler ! {self (), stop},
	    Tester ! {self (), stop};
	{notify, {Compiler, compiler, {{binaries, Bs}, {removed, Rs}}}} ->
	    delete (Rs, Tester),
	    run (Bs, Tester),
	    loop ({Compiler, Tester, Printer});
	{notify, Event} ->
	    Printer ! Event,
	    loop ({Compiler, Tester, Printer})
    after 4000 ->
	    Compiler ! check,
	    loop ({Compiler, Tester, Printer})
    end.

run ({Compiler, Tester, Printer}) ->
    receive
	{notify, {Compiler, compiler, {{binaries, Bs}, {removed, Rs}}}} ->
	    Compiler ! {self (), stop},
	    delete (Rs, Tester),
	    run (Bs, Tester),
	    Tester ! {self (), stop},
	    run ({Compiler, Tester, Printer});
	{notify, Event} ->
	    Printer ! Event,
	    run ({Compiler, Tester, Printer});
	{Tester, bye} ->
	    done;
	{_, bye} ->
	    run ({Compiler, Tester, Printer})
    end.

delete ([], _) ->
    pass;
delete (Removed, Tester) ->
    Tester ! {delete, Removed}.

run ([], _) ->
    pass;
run (Binaries, Tester) ->
    Tester ! {run, Binaries}.

options (Key, List) ->
    lists: concat (proplists: get_all_values (Key, List)).
