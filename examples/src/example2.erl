

-module(example2).
-export([s3/0, s4/0]).

%%% use case: requester-replier
%%% replier
s3() ->
	Context		= efficientmq:context(),
    Replier     = efficientmq:socket(Context, rep),
    efficientmq:bind(Replier, "tcp://*:1026"),

    {message, Replier_message, _Message1} = efficientmq:receive_message(Replier),
    efficientmq:send_message(Replier_message, <<"Reply">>),

    StartTime = now(),
    Fun3= fun(Replier_msg, _N) ->
		  efficientmq:send_message(Replier_msg, <<"Reply">>)
	  end,  	   
    lib_module:repeat(Fun3, Replier_message, 1000000), 
    error_logger:info_msg("Done in ~p seconds~n!!!", [timer:now_diff(now(), StartTime)/1000000]),
    timer:sleep(10000),
    efficientmq:close(Replier).

%%% requester
s4() ->
	Context		= efficientmq:context(),
	Requester  = efficientmq:socket(Context, req),
    Requester_connection  = efficientmq:connect(Requester, "tcp://localhost:1026"),	

    efficientmq:send_message(Requester_connection, <<"Test by Requester connection">>),
    efficientmq:receive_message(Requester_connection),
    StartTime = now(),
    Fun1 = fun(Receiver, _N) ->
		   efficientmq:receive_message(Receiver)
	   end,
    lib_module:repeat(Fun1, Requester_connection, 1000000),
    error_logger:info_msg("Done in ~p seconds~n!!!", [timer:now_diff(now(), StartTime)/1000000]),
    efficientmq:close(Requester).
