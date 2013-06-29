-module(fbmatchmaker_api_tests).
-include_lib("eunit/include/eunit.hrl").

mnesia_test() ->
	% make lots of fbids and put them in mnesia and check how long it takes to get data out
	ok.
%	?_test(fbinsert_test(10)).

fbinsert_test(Numrecs) ->
	L = [X || X <- [lists:seq(1,Numrecs)]],
	Fblist = lists:map(fun(X) -> string:concat("facebookuser",integer_to_list(X)) end, L),
	Pnstoken = "APA91bENqXZjNMuswK0q__bT2m5DCuQWLtfk8w5opQ5E-SkIvksCRIV3zYBkedascAq8nEFyluWmoSPy6ofgSHXQcL-oWi7eCj5bD6SVGjSkj5G8QFS8aXWpF6l64akmeRKq3vknfpQ8K4PvOa3_1Xsir9574O9GAA",
	Gameversion = "mnesiatest",
	Osid = "android",
	eunit:debugFmt("Inserting ~p records for testing"),
	eunit:debugTime("Inserts took ",lists:map(fun(X) -> fbmatchmaker_api:register_user(X,Pnstoken,Gameversion,Osid) end, Fblist)).
	
