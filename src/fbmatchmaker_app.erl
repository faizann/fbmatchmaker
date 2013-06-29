%% @author Mochi Media <dev@mochimedia.com>
%% @copyright fbmatchmaker Mochi Media <dev@mochimedia.com>

%% @doc Callbacks for the fbmatchmaker application.

-module(fbmatchmaker_app).
-author("Mochi Media <dev@mochimedia.com>").

-behaviour(application).
-export([start/2,stop/1]).


%% @spec start(_Type, _StartArgs) -> ServerRet
%% @doc application start callback for fbmatchmaker.
start(_Type, _StartArgs) ->
    fbmatchmaker_deps:ensure(),
    fbmatchmaker_sup:start_link().

%% @spec stop(_State) -> ServerRet
%% @doc application stop callback for fbmatchmaker.
stop(_State) ->
    ok.
