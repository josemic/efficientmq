

-module(example4).
-export([example_1_proxy/0, example_1_publisher/0, example_1_subscriber/0]).

%%% use case: n-publisher-subscriber-proxy-publisher-m-subscribers 
%%% proxy consisting of xsubscriber and xpublisher

example_1_proxy() ->
	Context		= efficientmq:context(),
    Subscriber = efficientmq:socket(Context, sub),
    Publisher = efficientmq:socket(Context, pub), % actually pub implementation is same as sub
    efficientmq:bind(Subscriber, "tcp://*:1025"),
	efficientmq:bind(Publisher, "tcp://*:1026"),
    StartTime = now(),
    Fun1 = fun(Receiver, Sender, _N) ->
    	{message, _Replier_message, Message} = efficientmq:receive_message(Receiver),
		efficientmq:send_message(Sender, Message)
    	% error_logger:info_msg("Received message: ~p~n", [Message])
	   end,
    lib_module:repeat_forever(Fun1, Subscriber, Publisher), 
    error_logger:info_msg("Done in ~p seconds~n!!!", [timer:now_diff(now(), StartTime)/1000000]).

%%% connection initiator: publisher
example_1_publisher() ->
	Context		= efficientmq:context(),
    Publisher  = efficientmq:socket(Context, pub),
    Publisher_connection = efficientmq:connect(Publisher, "tcp://localhost:1025"),
    StartTime = now(),
    error_logger:info_msg("Start sending!!"), 
    Fun1 = fun(Sender, N) ->
		   BinaryPIDString = list_to_binary(pid_to_list(self())),
		   BinaryNumberString= list_to_binary(integer_to_list(N)),
		   efficientmq:send_message(Sender, [<<"Test by Publisher">>, BinaryPIDString, BinaryNumberString])
	   end,	 	   
    lib_module:repeat(Fun1, Publisher_connection, 1000000),
    error_logger:info_msg("Done in ~p seconds~n!!!", [timer:now_diff(now(), StartTime)/1000000]).  

%%% connection initiator: subscriber
example_1_subscriber() ->
    Context		= efficientmq:context(),
    Subscriber = efficientmq:socket(Context, sub),
    Subscriber_connection = efficientmq:connect(Subscriber, "tcp://localhost:1026"),
	
    StartTime = now(),
    Fun1 = fun(Receiver, _N) ->
    	{message, _Replier_message, _Message1} = efficientmq:receive_message(Receiver)
    	% error_logger:info_msg("Received message: ~p~~n", [Message1])
	   end,
    lib_module:repeat(Fun1, Subscriber_connection, 2000000),
    error_logger:info_msg("Done in ~p seconds~n!!!", [timer:now_diff(now(), StartTime)/1000000]).
