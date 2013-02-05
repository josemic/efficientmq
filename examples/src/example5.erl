

-module(example5).
-export([s6/0, s7/0, s8/0, s9/0, s10/0, s11/0]).


%%% requester-replier
%%% replier
s6() ->
	Context		= efficientmq:context(),
    Replier     = efficientmq:socket(Context, rep),
    efficientmq:bind(Replier, "tcp://*:1026"),
	efficientmq:receive_message(Replier),
	efficientmq:receive_message(Replier),
	efficientmq:receive_message(Replier),
	efficientmq:receive_message(Replier),
	efficientmq:receive_message(Replier),
	Replier.

%%% requester
s7() ->
	Context		= efficientmq:context(),
    Requester  = efficientmq:socket(Context, req),
    Requester_connection  = efficientmq:connect(Requester, "tcp://localhost:1026"),	
    efficientmq:send_message(Requester_connection, <<"Test 1 by Requester connection">>),
    efficientmq:send_message(Requester_connection, <<"Test 2 by Requester connection">>),
    efficientmq:send_message(Requester_connection, <<"Test 3 by Requester connection">>),
    efficientmq:send_message(Requester_connection, <<"Test 4 by Requester connection">>),
    efficientmq:send_message(Requester_connection, <<"Test 5 by Requester connection">>),
    Requester_connection.

%%% subscriber-publisher
%%% subscriber
s8() ->
	Context		= efficientmq:context(),
    Subscriber     = efficientmq:socket(Context, sub),
    efficientmq:bind(Subscriber, "tcp://*:1026"),
    StartTime = now(),
    Fun1 = fun(Receiver, _N) ->
		   efficientmq:receive_message(Receiver)
		   %error_logger:info_msg("Received: ~p, N:~p ~n",[A, N])
	   end,
    lib_module:repeat(Fun1, Subscriber, 2000000),
    error_logger:info_msg("Done in ~p seconds~n!!!", [timer:now_diff(now(), StartTime)/1000000]),
	efficientmq:close(Subscriber).

%%% publisher
s9() ->
	Context		= efficientmq:context(),
    Publisher  = efficientmq:socket(Context, pub),
    Publisher_connection  = efficientmq:connect(Publisher, "tcp://localhost:1026"),	
    error_logger:info_msg("Start sending!!"), 
    StartTime = now(),
    Fun2 = fun(Sender, N) ->
		   BinaryNumberString= list_to_binary(integer_to_list(N)),
		   efficientmq:send_message(Sender, [<<"Test by Publisher">>, BinaryNumberString])
	   end,	 	   
    lib_module:repeat(Fun2, Publisher_connection, 1000000), 
    error_logger:info_msg("Done in ~p seconds~n!!!", [timer:now_diff(now(), StartTime)/1000000]),
    efficientmq:close(Publisher_connection).
    
%%% requester-responder
%%% responder
s10() ->
	Context		= efficientmq:context(),
    Replier     = efficientmq:socket(Context, rep),
    efficientmq:bind(Replier, "tcp://*:1026"),
    StartTime = now(),
    Fun1 = fun(Receiver, _N) ->
		   efficientmq:receive_message(Receiver)
		   %error_logger:info_msg("Received: ~p, N:~p ~n",[A, N])
	   end,
    lib_module:repeat(Fun1, Replier, 1000000),
    error_logger:info_msg("Done in ~p seconds~n!!!", [timer:now_diff(now(), StartTime)/1000000]),
	efficientmq:close(Replier).

%%% requester
s11() ->
	Context		= efficientmq:context(),
    Requester   = efficientmq:socket(Context, req),
    Requester_connection  = efficientmq:connect(Requester, "tcp://localhost:1026"),	
    error_logger:info_msg("Start sending!!"), 
    StartTime = now(),
    Fun2 = fun(Sender, N) ->
		   BinaryNumberString= list_to_binary(integer_to_list(N)),
		   efficientmq:send_message(Sender, [<<"Test by Publisher">>, BinaryNumberString])
	   end,	 	   
    lib_module:repeat(Fun2, Requester_connection, 1000000), 
    error_logger:info_msg("Done in ~p seconds~n!!!", [timer:now_diff(now(), StartTime)/1000000]),
    efficientmq:close(Requester_connection).
