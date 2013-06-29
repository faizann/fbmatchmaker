-module(fbmatchmaker_view).
-compile(export_all).
-import(fbmatchmaker_shortcuts, [render_ok/3]).

urls() -> [
      {"^hello/?$", hello},
	  {"register_fbuser/?$",register_fbuser},
	  {"invite_fbuser/?$",invite_fbuser}
    ].

hello('GET', Req,_) ->
    QueryStringData = Req:parse_qs(),
    Username = proplists:get_value("username", QueryStringData, "Anonymous"),
	_L1 = {username, [{firstName, Username}]},
	L = {struct, [{key2, Username}]},
    render_ok(Req, fbmatchmaker_dtl, [{username, mochijson:encode(L)}]);
hello('POST', Req,_) ->
    PostData = Req:parse_post(),
    Username = proplists:get_value("username", PostData, "Anonymous"),
    render_ok(Req, fbmatchmaker_dtl, [{username, Username}]).

%% FB REGISTER USER FUNCTION %%
%% this function registers user with fbid, pushtoken, gameversion, osversion %%
register_fbuser('GET',Req, Redis) ->
	QueryStringData = Req:parse_qs(),
	Fbuser = proplists:get_value("fbid",QueryStringData,"0"),
	Pnstoken = proplists:get_value("pnstoken",QueryStringData,"0"),
	Gameversion = proplists:get_value("gameversion",QueryStringData,"unknown"),
	OS = proplists:get_value("os",QueryStringData,"unknown"),
	L = {struct, [{fbid, Fbuser}, {pnstoken, Pnstoken}, {gameversion, Gameversion}, {os,OS}]},
	case fbmatchmaker_api:register_user(Redis, Fbuser, Pnstoken, Gameversion,OS) of
		success -> 
			L1 = {struct ,[{result, success}]};
		_ ->
			L1 = {struct ,[{result, failure}]}
	end,		
	Req:respond({200,[{"Content-Type", "application/json"}],
				mochijson:encode(L1)}).


invite_fbuser('GET',Req, Redis) ->
	QueryStringData = Req:parse_qs(),
	Fbuser = proplists:get_value("fbid",QueryStringData,"0"),
	Fbpeer = proplists:get_value("peerfbid",QueryStringData,"0"),
	GameType = proplists:get_value("game",QueryStringData,"0"),
	Invitemsg = proplists:get_value("message",QueryStringData,""),
	%% Find other FB user and then send invite notification %%
	case fbmatchmaker_api:invite_user(Redis, Fbpeer,Fbuser,"",Invitemsg,GameType) of
		{ok, _ } -> 
		L = {struct, [{result,success}]},
		Req:respond({200,[{"Content-Type","application/json"}],
						mochijson:encode(L)});
		_ -> 
		L = {struct, [{result,failure}]},
		Req:respond({200,[{"Content-Type","application/json"}],
						mochijson:encode(L)})
	end.
