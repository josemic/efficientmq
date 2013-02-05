

-module(efficientmq).
-export([context/0, term/0, socket/2, bind/2, connect/2, send_message/2, receive_message/1]).
-export([close/1]).

context() -> % creates the context
    application:start(sasl),
    application:start(tcp_server), 
    appmon:start(),
    {context, ts_context_process}. % registered context name

term() -> % terminates the context
    application:stop(tcp_server).

socket({context, ContextName}, pub = Type) ->
    {ok, PublisherPID}=gen_server:call(ContextName, {socket, Type}),
    {pub, PublisherPID};
socket({context, ContextName},sub = Type) ->
    {ok, SubscriberPID}=gen_server:call(ContextName, {socket, Type}),
    {sub, SubscriberPID};
socket({context, ContextName},req = Type) ->
    {ok, RequesterPID}=gen_server:call(ContextName, {socket, Type}),
    {req, RequesterPID};
socket({context, ContextName},rep = Type) ->
    {ok, ResponderPID}=gen_server:call(ContextName, {socket, Type}),
    {rep, ResponderPID}.

converStringToHostAndPortNr(BindString)->
    "tcp://" = string:sub_string(BindString, 1, 6),
    HostAndPortString = string:sub_string(BindString, 7),
    {Host, {Port, ""}} = case string:tokens(HostAndPortString, ":") of
			     ["localhost", PortNrString]->
				 {localhost, string:to_integer(PortNrString)};
			     [HostString, PortNrString]->
				 {HostString, string:to_integer(PortNrString)}
			 end,
    {Host, Port}.

bind({pub, PublisherManagerPID}, BindString) ->
    {"*", PortNr} = converStringToHostAndPortNr(BindString),
    gen_server:cast(PublisherManagerPID, {bind, PortNr});
bind({sub, SubscriberManagerPID}, BindString) ->
    {"*", PortNr} = converStringToHostAndPortNr(BindString),
    gen_server:cast(SubscriberManagerPID, {bind, PortNr});
bind({req, RequesterManagerPID}, BindString) ->
    {"*", PortNr} = converStringToHostAndPortNr(BindString),
    gen_server:cast(RequesterManagerPID, {bind, PortNr});
bind({rep, ResponderManagerPID}, BindString) ->
    {"*", PortNr} = converStringToHostAndPortNr(BindString),
    gen_server:cast(ResponderManagerPID, {bind, PortNr}).


connect({pub, PublisherPID}, ConnectString) ->
    {Host, PortNr} = converStringToHostAndPortNr(ConnectString), 
    gen_server:cast(PublisherPID, {connect, PortNr, Host, self()}),
    receive
		{connect_ack, {ok, Outgoing_connnection_PID}} ->
			{connection, Outgoing_connnection_PID}
    end;
connect({sub, SubscriberPID}, ConnectString) ->
    {Host, PortNr} = converStringToHostAndPortNr(ConnectString), 
    gen_server:cast(SubscriberPID, {connect, PortNr, Host, self()}),
    receive
		{connect_ack, {ok, Outgoing_connnection_PID}} ->
			{connection, Outgoing_connnection_PID}
    end;
connect({req, RequesterPID}, ConnectString) ->
    {Host, PortNr} = converStringToHostAndPortNr(ConnectString), 
    gen_server:cast(RequesterPID, {connect, PortNr, Host, self()}),
    receive
		{connect_ack, {ok, Outgoing_connnection_PID}} ->
			{connection, Outgoing_connnection_PID}
    end;
connect({rep, ResponderPID}, ConnectString) ->
    {Host, PortNr} = converStringToHostAndPortNr(ConnectString), 
    gen_server:cast(ResponderPID, {connect, PortNr, Host, self()}),
    receive
		{connect_ack, {ok, Outgoing_connnection_PID}} ->
			{connection, Outgoing_connnection_PID}
    end.
    
%%% Send messages to manager connection acceptors (incoming connections)
send_message({pub, ConnectionPID}, Message) ->
	send_message({connection_proxy, ConnectionPID}, Message);
send_message({manager, ConnectionPID}, Message) ->
	send_message({connection_proxy, ConnectionPID}, Message);
%%% Send messages to connection initiators ....
send_message({connection, ConnectionPID}, Message) ->
	send_message({connection_proxy, ConnectionPID}, Message);
%%% Send messages to connection proxy ....
send_message({connection_proxy, ConnectionPID}, Message) ->
    case gen_server:call(ConnectionPID, {send_message, Message}, infinity) of
	ok ->
	    ok;
	Error ->
	    Error
    end.


%%% assuming the have been bound before
receive_message({sub, ManagerPID}) ->
    receive_message(ManagerPID);
receive_message({req, ManagerPID}) ->
    receive_message(ManagerPID);
receive_message({rep, ManagerPID}) ->
    receive_message(ManagerPID);

%%% Receive messages from connection acceptors ....
receive_message({manager, ManagerPID}) ->
    receive_message(ManagerPID);
receive_message({connection, ConnectionPID}) ->
    receive_message(ConnectionPID);
receive_message({connection_proxy, ConnectionPID}) ->
    receive_message(ConnectionPID);
receive_message(ConnectionPID) ->
    gen_server:cast(ConnectionPID, {receive_msg, self()}),
    receive
		{received_message_ack, ConnectionReplierPID, Message} ->
			{message, {connection_proxy, ConnectionReplierPID}, Message}
    end.



close({connection, ConnectionPID}) ->
	gen_server:cast(ConnectionPID, stop);
close({pub, ManagerPID}) ->
	gen_server:cast(ManagerPID, stop);
close({sub, ManagerPID}) ->
	gen_server:cast(ManagerPID, stop);
close({req, ManagerPID}) ->
	gen_server:cast(ManagerPID, stop);
close({rep, ManagerPID}) ->
	gen_server:cast(ManagerPID, stop).	
