
-module(example1).
-export([s1/0, s2/0]).


%%% synchronized publisher-subscriber
%%% synchronized publisher (syncpub.erl)
s1() ->
	Context		= efficientmq:context(),
    Publisher   = efficientmq:socket(Context, pub),
    Replier     = efficientmq:socket(Context, rep),
    efficientmq:bind(Publisher, "tcp://*:1025"),
    efficientmq:bind(Replier, "tcp://*:1026"),

    Fun1 = fun(Receiver, _N) ->
		   {message, Replier_message, _Message1} = efficientmq:receive_message(Receiver),
		   efficientmq:send_message(Replier_message, <<"Reply">>),
		   error_logger:info_msg("Replier_message:~p~n",[Replier_message])
	   end,
    lib_module:repeat(Fun1, Replier, 1),
    error_logger:info_msg("Start sending!!"), 
    StartTime = now(),
    Fun2 = fun(Sender, N) ->
		   BinaryNumberString= list_to_binary(integer_to_list(N)),
		   efficientmq:send_message(Sender, [<<"Test by Publisher">>, BinaryNumberString]),
		   error_logger:info_msg("Sent ~p~n",[N])
	   end,	 	   
    lib_module:repeat(Fun2, Publisher, 1000000), 
    error_logger:info_msg("Done in ~p seconds~n!!!", [timer:now_diff(now(), StartTime)/1000000]),
    %timer:sleep(10000),
    efficientmq:close(Publisher),
    efficientmq:close(Replier).

%%% synchronized subscriber (syncsub.erl)
s2() ->
	Context		= efficientmq:context(),
    Subscriber = efficientmq:socket(Context, sub),
    Requester  = efficientmq:socket(Context, req),
    Subscriber_connection = efficientmq:connect(Subscriber, "tcp://localhost:1025"),
    Requester_connection  = efficientmq:connect(Requester, "tcp://localhost:1026"),	
	%error_logger:info_msg("Requester_connection:~p~n",[Requester_connection]),

    efficientmq:send_message(Requester_connection, <<"Test by Requester connection">>),
    efficientmq:receive_message(Requester_connection),
    
    StartTime = now(),
    Fun1 = fun(Receiver, N) ->
		   efficientmq:receive_message(Receiver),
		   timer:sleep(100),
		   error_logger:info_msg("Received ~p~n",[N])
	   end,
    lib_module:repeat(Fun1, Subscriber_connection, 1000000),
    error_logger:info_msg("Done in ~p seconds~n!!!", [timer:now_diff(now(), StartTime)/1000000]),
    efficientmq:close(Subscriber),
    efficientmq:close(Requester).
