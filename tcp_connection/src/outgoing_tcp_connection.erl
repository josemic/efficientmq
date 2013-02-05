
-module(outgoing_tcp_connection).

-behaviour(gen_server).

%% API
-export([start_link/4]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define(SERVER, ?MODULE). 
-define(debug, debug). 
-ifdef(debug).
-define(LOG(X), error_logger:error_msg("{~p,~p}: ~p~n", [?MODULE,?LINE,X])).
-else.
-define(LOG(X), true).
-endif.

-record(state, {
	manager_pid::pid(),
	port_nr::port(),
	host::localhost|string(),
	type::pub|sub|req|rep,
	socket::port(),
	queue, % queue_new
	max_length::integer(), % max queue length
	high_watermark::integer,
	receive_msg_sender_pid::pid()
	}).


%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(ManagerPID, Type, Host, PortNr) ->
    Ref_s = erlang:ref_to_list(make_ref()),                       
    %% Ref_s makes the instance unique after restart
    Name_s = ?MODULE_STRING ++ "_" ++ Ref_s,  
    Name = list_to_atom (Name_s),
    gen_server:start_link({local, Name}, ?MODULE, [ManagerPID, Type, Host, PortNr], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([ManagerPID, Type, Host, PortNr]) ->
	error_logger:info_report([{"Connecting to Host: ", Host, " and Port: ", PortNr}]),
	{ok, Socket} = continually_connect(Host, PortNr),
    {ok, #state{manager_pid = ManagerPID, type=Type, host = Host, port_nr = PortNr, socket= Socket, queue=lib_module:queue_new(), high_watermark = 1000}, 0}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call({send_message, Message}, _From, State) ->
	Reply = gen_tcp:send(State#state.socket, Message),
    {reply, Reply, State}.
%handle_call(_Request, _From, State) ->
%    Reply = ok,
%    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({receive_msg, SenderPID}, #state{type=sub}=State) ->
	NewState = evaluate_receive_message(SenderPID, State),
    {noreply, NewState};
handle_cast({receive_msg, SenderPID}, #state{type=req}=State) ->
	NewState = evaluate_receive_message(SenderPID, State),
	{noreply, NewState}; 
handle_cast({receive_msg, SenderPID}, #state{type=rep}=State) ->
	NewState = evaluate_receive_message(SenderPID, State),
    {noreply, NewState};
handle_cast(stop, State) ->
	gen_server:cast(State#state.manager_pid, stop),
    {stop, normal, State}.
        
%handle_cast(_Msg, State) ->
%    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(timeout, #state{socket=Socket}=State) ->
	inet:setopts(Socket, [{active,once}, {keepalive,true}, {packet,4}]),
	{noreply, State};
handle_info({tcp, Socket, BytesBin}, #state{type=sub, socket=Socket}=State) ->
	NewState = evaluate_tcp_message(BytesBin, State),
	{noreply, NewState};
handle_info({tcp, Socket, BytesBin}, #state{type=req, socket=Socket}=State) ->
	NewState = evaluate_tcp_message(BytesBin, State),
	{noreply, NewState};
handle_info({tcp, Socket, BytesBin}, #state{type=rep, socket=Socket}=State) ->
	NewState = evaluate_tcp_message(BytesBin, State),
	{noreply, NewState};
handle_info({tcp_closed, Socket}, #state{socket=Socket}=State) ->
    gen_tcp:close(Socket),
    error_logger:info_msg("Socket closed: (~w)~n", [Socket]),
    {stop, normal, State};
handle_info({tcp_error, Socket, Reason}, #state{socket=Socket}=State) ->
    error_logger:info_msg("Socket error:(~w)~n", [Reason]),    
    gen_tcp:close(Socket),
    {stop, normal, State}.	
%handle_info(_Info, State) ->
%    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, State) ->
	gen_tcp:close(State#state.socket),
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================


continually_connect(Host, PortNr) ->
		case gen_tcp:connect(Host, PortNr, [binary, {active, once}, {reuseaddr,true}, {packet,4}, {nodelay,true}, {exit_on_close,false}]) of
			{ok, Socket} ->
				error_logger:info_msg("Connected!!!~n", []),
				{ok, Socket};
			{error,econnrefused} ->
				timer:sleep(100),
				continually_connect(Host, PortNr)
		end.
		
evaluate_receive_message(SenderPID, State)->
	%error_logger:info_msg("Receive message request ~p~n",[State#state.queue]),
	case queue:out(State#state.queue) of
		{empty,{[],[]}} ->
			case State#state.receive_msg_sender_pid of 
				undefined ->
					NewState = State#state{receive_msg_sender_pid = SenderPID};		
			_Other ->
			    error_logger:error_report("Already waiting for message reception Error!!"),
			    NewState = State
		    end;
		{{value, Queue_element}, Queue} ->
		    BytesBin = Queue_element,
		    NewState = State#state{queue = Queue},
		    SenderPID ! {received_message_ack, self(), BytesBin}
	end,
	evaluate_queue_flowcontrol(NewState),	
	NewState.
	
evaluate_tcp_message(BytesBin, State) ->
    % error_logger:info_msg("Received: ~p, receive_msg_sender_pid: ~p~n", [BytesBin, State#state.receive_msg_sender_pid]),
    case State#state.receive_msg_sender_pid of
		undefined ->
			QueueNew = lib_module:queue_element(BytesBin, State#state.queue, State#state.max_length),
		    NewState = State#state{queue = QueueNew};
		SenderPID ->
			SenderPID ! {received_message_ack, self(), BytesBin},
			NewState = State#state{receive_msg_sender_pid = undefined}
	end,
	%error_logger:info_msg("QueueState: ~p~n", [NewState#state.queue]),
	evaluate_queue_flowcontrol(NewState),
	NewState.

evaluate_queue_flowcontrol(State) ->
	case lib_module:queue_len(State#state.queue) < State#state.high_watermark of
	true ->
	    %% get one message from TCP, if available
		inet:setopts(State#state.socket, [{active,once}, {keepalive,true}, {packet,4}]); % active,once -> use flow control
	    %%inet:setopts(Socket, [{active,true}, {keepalive,true}, {packet,4}]); % active,once -> use flow control
	false ->
	    inet:setopts(State#state.socket, [{active,false}, {keepalive,true}, {packet,4}]), % active,once -> use flow control
	    %% queue is filled, do not get one message from TCP
	    ok
    end.
