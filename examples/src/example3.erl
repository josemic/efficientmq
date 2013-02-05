

-module(example3).
-export([s5/0, s6/0]).

%%% use case: publisher-xsubscriber 
%%% connection acceptor: xsubscriber

s5() ->
	Context		= efficientmq:context(),
    XSubscriber = efficientmq:socket(Context, sub),
    efficientmq:bind(XSubscriber, "tcp://*:1025"),

    StartTime = now(),
    Fun1 = fun(Receiver, _N) ->
			{message, _Replier_message, _Message1} = efficientmq:receive_message(Receiver)
			%error_logger:info_msg("Received message: ~p~~n", [Message1])
	   end,
    lib_module:repeat(Fun1, XSubscriber, 2000000),
    error_logger:info_msg("Done in ~p seconds~n!!!", [timer:now_diff(now(), StartTime)/1000000]),
    efficientmq:close(XSubscriber).

%%% connection initiator: publisher
s6() ->
	Context		= efficientmq:context(),
    Publisher  = efficientmq:socket(Context, pub),
    Publisher_connection = efficientmq:connect(Publisher, "tcp://localhost:1025"),
    timer:sleep(1000), % wait 1 second to connect from subscribers
    error_logger:info_msg("Start sending!!"), 
    StartTime = now(),
    Fun1 = fun(Sender, N) ->
		   BinaryPIDString = list_to_binary(pid_to_list(self())),
		   BinaryNumberString= list_to_binary(integer_to_list(N)),
		   efficientmq:send_message(Sender, [<<"Test by Publisher">>, BinaryPIDString, BinaryNumberString])
	   end,	 	   
    lib_module:repeat(Fun1, Publisher_connection, 1000000), 
    error_logger:info_msg("Done in ~p seconds~n!!!", [timer:now_diff(now(), StartTime)/1000000]),
    timer:sleep(10000).
    %%efficientmq:close(Publisher).
