%% @author Mochi Media <dev@mochimedia.com>
%% @copyright 2010 Mochi Media <dev@mochimedia.com>

%% @doc fbmatchmaker.

-module(fbmatchmaker).
-author("Mochi Media <dev@mochimedia.com>").
-export([start/0, stop/0]).

ensure_started(App) ->
    case application:start(App) of
        ok ->
            ok;
        {error, {already_started, App}} ->
            ok
    end.


%% @spec start() -> ok
%% @doc Start the fbmatchmaker server.
start() ->
    error_logger:info_msg("Starting fbmatchmaker ~n"),
    fbmatchmaker_deps:ensure(),
    ensure_started(crypto),
    ensure_started(inets),
    fbmatchmaker_api:start(),
%    fbmatchmaker_api:install([]), % installation has to be done manually
    application:start(fbmatchmaker).


%% @spec stop() -> ok
%% @doc Stop the fbmatchmaker server.
stop() ->
    application:stop(fbmatchmaker).
