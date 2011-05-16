%%% Copyright (C) Olivier Pizzato, Bernard Notarianni
%%% All rights reserved.
%%% See file COPYING.

-module(green_bar).
-export([create/0]).
-include_lib("wx/include/wx.hrl").

create() ->
     spawn_link(fun raise_and_loop/0).

raise_and_loop()->
  wx:new(),
  Frame = wxFrame:new(wx:null(), -1, "Active Ring", [{size, {800, 50}}]),
  put(frame, Frame),
  wxWindow:show(Frame),
  loop().

loop() ->
  receive
      red ->
	  color(255,0,0),
	  loop();
      green ->
	  color(56,177,26),
	  loop();
      neutral ->
	  color(179,171,110),
	  loop();
    {R,G,B} ->
	  color(R,G,B),
	  loop();
      stop ->
	  exit("stopped")
  end.

color(R,G,B) ->
    Frame = get(frame),
    wxWindow:setBackgroundColour(Frame, {R,G,B}),
    wxWindow:refresh(Frame).
