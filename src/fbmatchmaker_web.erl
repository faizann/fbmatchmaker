%% @author Mochi Media <dev@mochimedia.com>
%% @copyright 2010 Mochi Media <dev@mochimedia.com>

%% @doc Web server for fbmatchmaker.

-module(fbmatchmaker_web).
-author("Mochi Media <dev@mochimedia.com>").

-export([start/1, stop/0, loop/3]).

%% External API

start(Options) ->
    {DocRoot, Options1} = get_option(docroot, Options),
    {ok, Redis} = eredis:start_link(),
    Loop = fun (Req) ->
                   ?MODULE:loop(Req, DocRoot,Redis)
           end,
    mochiweb_http:start([{name, ?MODULE}, {loop, Loop} | Options1]).

stop() ->
    mochiweb_http:stop(?MODULE).
% Iterate recursively on our list of {Regexp, Function} tuples
dispatch(_, [], _Redis) -> none;
dispatch(Req, [{Regexp, Function}|T], Redis) -> 
    "/" ++ Path = Req:get(path),
    Method = Req:get(method),
    Match = re:run(Path, Regexp, [global, {capture, all_but_first, list}]),
    case Match of
        {match,[MatchList]} -> 
            % We found a regexp that matches the current URL path
            case length(MatchList) of
                0 -> 
                    % We didn't capture any URL parameters
                    fbmatchmaker_view:Function(Method, Req, Redis);
                Length when Length > 0 -> 
                    % We pass URL parameters we captured to the function
                    Args = lists:append([[Method, Req, Redis], MatchList]),
                    apply(fbmatchmaker_view, Function, Args)
            end;
        _ -> 
            dispatch(Req, T, Redis)
    end.

loop(Req, DocRoot, Redis) ->
    "/" ++ Path = Req:get(path),
    try
%%        case Req:get(method) of
%%            Method when Method =:= 'GET'; Method =:= 'HEAD' ->
%%                case Path of
%%                    _ ->
%%                        Req:serve_file(Path, DocRoot)
%%                end;
%%            'POST' ->
%%                case Path of
%%                    _ ->
%%                        Req:not_found()
%%                end;
%%            _ ->
%%                Req:respond({501, [], []})
%%        end

%% log request to our logger

		log4erl:info(mochiweb,"~p ~p ~p",[Req:get(peer), Req:get(method), Req:get(path)]),
		log4erl:debug(mochiweb,"~p",[Req:dump()]),
		case dispatch(Req,fbmatchmaker_view:urls(),Redis) of
			none ->
				% No request handler found
				case filelib:is_file(filename:join([DocRoot, Path])) of
					true ->
						% If there's a static file, serve it
						Req:serve_file(Path, DocRoot);
					false ->
						Req:not_found()
				end;
			Response ->
				Response
		end
    catch
        Type:What ->
            Report = ["web request failed",
                      {path, Path},
                      {type, Type}, {what, What},
                      {trace, erlang:get_stacktrace()}],
            error_logger:error_report(Report),
	    log4erl:error(Report),
            %% NOTE: mustache templates need \ because they are not awesome.
            Req:respond({500, [{"Content-Type", "text/plain"}],
                         "request failed, sorry\n"})
    end.

%% Internal API

get_option(Option, Options) ->
    {proplists:get_value(Option, Options), proplists:delete(Option, Options)}.

%%
%% Tests
%%
-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

you_should_write_a_test() ->
    ?assertEqual(
       "No, but I will!",
       "Have you written any tests?"),
    ok.

-endif.
