%%% Copyright (C) Dominic Williams, Nicolas Charpentier
%%% All rights reserved.
%%% See file COPYING.
-module (shells).
-export ([stop_node/1]).

stop_node ([Node]) when is_atom (Node) ->
    rpc: call (Node, init, stop, []).

