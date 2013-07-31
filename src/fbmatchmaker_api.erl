-module(fbmatchmaker_api).
-compile(export_all).
-include_lib("eunit/include/eunit.hrl").
%-include("apns.hrl").
-include("deps/apns/include/localized.hrl").

-define(TEST_CONNECTION, 'test-connection').

%-on_load(init/0).
-record(fbusers, {fbid, pnstoken, gameversion, osid}). %% A simple record/table to store our fbusers list
-record(api_config, {gcmApiKey = "AIzaSyDjRpsMLtWJHmM-Z3SmEHVXAQqMj_W2kA8"}).
-record(apns_msg, {body    = none  :: none | string(),
                    action  = none  :: none | string(),
                    key     = ""    :: string(),
                    args    = []    :: [string()],
                    image   = none  :: none | string()}).       

start() ->
	error_logger:info_msg("Starting fbmatchmaker_api~n"),
	case inets:start() of
		{_,_} -> ok; %% don't care about inets start result
		ok -> ok
	end,	
%	case application:start(mnesia) of
%		{error, Reason} -> error_logger:error_msg("Error in starting mnesia ~p~n",[Reason]),
%		ok; %% return OK anyway
%		ok -> ok
%	end,
%	ok = mnesia:wait_for_tables([fbusers],10000),
	case apns:start() of 
		{ok} -> ok;
		{error,{already_started,_}} -> ok;
		Reason1 -> error_logger:error_msg("Error in starting apns service ~p\n", [Reason1]),
				halt(1)
	end,
	{ok, _Pid} = apns:connect(?TEST_CONNECTION, fun apns_log_error/2, fun apns_log_feedback/1).

%install() ->
%	install([node()]).

%install(Nodes) ->
%	ok = mnesia:create_schema(Nodes),
%	application:start(mnesia),
%	mnesia:create_table(fbusers, 
%			[{attributes, record_info(fields,fbusers)},
%			{index, [#fbusers.pnstoken]},
%			{disc_copies,Nodes},
%			{type, set}]),
%	application:stop(mnesia).

register_user(Redis,Fbid,Pnstoken, Gameversion, Os) ->
	case eredis:q(Redis,["HMSET",Fbid,"pnstoken",Pnstoken,"gameversion",Gameversion,"osid",Os]) of
		{ok,_} -> success;
		{error,Error} -> io:fwrite("Error in redis insert ~p~n", [Error]), failed;
		_ -> failed
	end.	

%register_user(_Redis,Fbid,Pnstoken, Gameversion, Os) ->
%	F = fun() -> 
%		mnesia:write(#fbusers{fbid=Fbid,
%					pnstoken=Pnstoken,
%					gameversion=Gameversion,
%					osid=Os})
%	end,
%	case mnesia:activity(transaction,F) of
%		ok -> success;
%		_ -> failed
%	end.

get_user(Redis,Fbid) ->
	case eredis:q(Redis,["HMGET",Fbid,"pnstoken","gameversion","osid"]) of
		{ok,[Pnstoken,Gameversion,Osid]} -> {ok,#fbusers{fbid=Fbid,
								pnstoken=binary_to_list(Pnstoken),
								gameversion=binary_to_list(Gameversion),
								osid=binary_to_list(Osid)}};
		{error,RedisErr} -> {error,RedisErr};
		_ -> {error,"Unknown error in Redis"}
	end.	



%get_user(Fbid) ->
%	F = fun () -> 
%		mnesia:read({fbusers,Fbid})
%	end,
%	mnesia:activity(transaction,F).


invite_user(Redis, Fbid,_Hostfbid, _Hostfbname, Message, Gametype) ->
	case get_user(Redis,Fbid) of
		{error,Err} -> {error, {not_found, Fbid}};
		{ok,Peer1} -> 
			Apiconfig = #api_config{},
			io:format("ApiKey ~p fbid ~p\n",[Apiconfig#api_config.gcmApiKey,Peer1#fbusers.fbid]),
			case Peer1#fbusers.osid of
				"ios" ->
					%% Send ApplePushNotification
					io:format("Going to send ApplePushNotification for ~p\n", [Fbid]),
					apns_send_message(Peer1#fbusers.pnstoken,Message,Gametype);
				"android" ->
%					%% Send GoogleCloudMessage
					do_gcm_msg(Apiconfig#api_config.gcmApiKey, Peer1#fbusers.pnstoken,Message,Gametype)
			end		
	end.


%invite_user(_Redis, Fbid,_Hostfbid, _Hostfbname, Message, Gametype) ->
%	Peer = get_user(Fbid),
%	case Peer of
%		[] -> {error, {not_found, Fbid}};
%		[Peer1] -> 
%			Apiconfig = #api_config{},
%			io:format("ApiKey ~p fbid ~p\n",[Apiconfig#api_config.gcmApiKey,Peer1#fbusers.fbid]),
%			case Peer1#fbusers.osid of
%				"ios" ->
%					%% Send ApplePushNotification
%					io:format("Going to send ApplePushNotification for ~p\n", [Fbid]),
%					apns_send_message(Peer1#fbusers.pnstoken,Message,Gametype);
%				"android" ->
%					%% Send GoogleCloudMessage
%					do_gcm_msg(Apiconfig#api_config.gcmApiKey, Peer1#fbusers.pnstoken,Message,Gametype)
%			end		
%	end.

%% APNS functions
apns_send_message(Pnstoken,Message,Gametype) ->
	case apns:send_message(?TEST_CONNECTION,Pnstoken,#loc_alert{action="ACCEPT",
								   body = Message
								   }
								,0
								,"chime"
								,120
								,[{<<"game">>, list_to_binary(Gametype)}]) of
		ok -> {ok,invitation_sent};
		Other -> Other
	end.
	
apns_log_error(MsgId, Status) ->
  error_logger:error_msg("Error on msg ~p: ~p~n", [MsgId, Status]).
    
apns_log_feedback(Token) ->
  error_logger:warning_msg("Device with token ~p removed the app~n", [Token]).

do_gcm_msg(ApiKey,Pnstoken,Message,Game) ->
	case send_gcm_msg(ApiKey,Pnstoken,Message,Game) of
		{ok, Result} ->
			Result1 = destruct(Result),
					io:format("~p\n",[Result1]),
%%					io:format("result is ~p\n", [check_gcm_success(Result1)]),
			case check_gcm_success(Result1) of
				success -> {ok,invitation_sent};
				_ -> {error, invitation_error}
			end;	
		{error,_Reason} ->
%%					io:format("~p\n",[Reason]),
			{error,unknown_failure}
	end.	
check_gcm_success([]) ->
	failed;
check_gcm_success([H|T]) ->
%%	io:format("Comparing ~p\n", [H]),
	case H of
		{"success",1} -> success;
		_ -> check_gcm_success(T)
	end.

send_gcm_msg(ApiKey, Pnstoken, Message, Game) ->
	Baseurl = "http://android.googleapis.com/gcm/send",
	ApiKey1 = string:concat("key=",ApiKey),
	%% Create Json struct
	Body = lists:flatten(mochijson:encode({struct, [{registration_ids,{array, [Pnstoken]}},
			{data,{struct, [{message,Message},{game,Game}]}}, 
%			{"data",{struct,[{message,Message},{game,Game}]}}, 
			{time_to_live,3600},
			{collapse_key,game_invite}]})),
%%	Body1 = lists:flatten(mochijson:encode(Body)),		
%%	io:format("Sending with json ~p\nApiKey ~p\nMessage ~p\nGame ~p\n",[Body1,ApiKey1,Message,Game]),
	try httpc:request(post, {Baseurl,[{"Authorization",ApiKey1}],"application/json",Body},[],[]) of
		{ok, {{_,200,_},_,RespBody}} ->
			io:format("Response body ~p\n",[RespBody]),
			{ok, mochijson:decode(RespBody)};
		{error, Reason } ->
			{error, Reason};
		{ok, {{StatusLine,_,_},_,RespBody}} ->
			{error, {StatusLine, RespBody}};
		BigError -> {error, BigError}
	catch
		Throw -> {error, caught, Throw}
	end.		

%% @doc Flatten {struct, [term()]} to [term()] recursively.
destruct({struct, L}) ->
	destruct(L);
destruct({array, L}) ->
	destruct(L);
destruct([H | T]) ->
	[destruct(H) | destruct(T)];
destruct({K, V}) ->
	{K, destruct(V)};
destruct(Term) ->
	Term.



