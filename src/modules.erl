%%% Copyright (c) Dominic Williams, Nicolas Charpentier
%%% All rights reserved.
%%% See file COPYING.

-module (modules).
-export ([to_binary/1]).
-export ([to_file_name/2]).
-export ([forms_to_binary/1]).
-export ([compile/2, compile/1]).
-export ([module_name/1]).
-export ([locate/2]).
-export ([includes/1]).
-export ([compile2/1]).

compile2 (File_name) ->
    case compile (File_name, []) of
	{ok, Module, Binary, Warnings} ->
	    {File_name, Module, Tests} = tests: filter_by_attribute (Binary),
	    {File_name, Module, ok, {Binary, Tests, Warnings}};
	{error, Errors, Warnings} ->
	    Module = module_name (File_name),
	    {File_name, Module, error, {Errors, Warnings}}
    end.

to_binary (File_name) ->
    {ok, _, Binary, _} = compile (fun compile: file/2, File_name, []),
    Binary.

to_file_name (Module, Directory) ->
    File_name = atom_to_list (Module) ++ ".erl",
    filename: join (Directory, File_name).
    
forms_to_binary (Forms) ->
    {ok, _, Binary, _} = compile (fun compile: forms/2, Forms, []),
    Binary.

compile (Fun, Parameter, User_options) ->
    Options = [binary, return, warn_unused_import, debug_info | User_options],
    Fun (Parameter, Options).

compile (File, Options) ->
    compile (fun compile: file/2, File, Options).

compile (File) ->
    compile (File, []).

module_name (Filename) ->
    {extension, ".erl"} = {extension, filename: extension (Filename)},
    String = filename: rootname (filename: basename (Filename)),
    list_to_atom (String).

locate ({M, F, A}, Binary) ->
    {ok, {M, Chunks}} = beam_lib: chunks (Binary, [abstract_code, compile_info]),
    [{abstract_code, Code}, {compile_info, Info}] = Chunks,
    {value, {source, Filename}} = lists: keysearch (source, 1, Info),
    {raw_abstract_v1, Forms} = Code,
    Line = locate_line (F, A, Forms),
    {Filename, Line}.

locate_line (Function, Arity, [{function, Line, Function, Arity,  _} | _]) ->
    Line;
locate_line (Function, Arity, [_ | Forms]) ->
    locate_line (Function, Arity, Forms);
locate_line (_, _, []) ->
    unknown.

includes (File) ->
    includes_from_forms (epp_dodger: parse_file (File)).

includes_from_forms ({error, _}=E) ->
    E;
includes_from_forms ({ok, Forms}) ->
    Attributes = [A || {tree, attribute, _, A} <- Forms],
    Includes = [I || {attribute, {atom, _, include}, [I]} <- Attributes],
    [F || {string, _, F} <- Includes].
