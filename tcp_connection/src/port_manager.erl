
-module(port_manager).
-include("incomming_tcp_connection.hrl").
-behaviour(gen_server).

%% API
-export([start_link/0, process_register/1, process_unregister/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define(SERVER, ?MODULE). 

-record(state, {type::pub|sub|req|rep,
				direction::incoming|outgoing,
				outgoing_connnection_pid::pid(),
				connection_acceptor_pid::pid(),
				pid_list = []::list(),
				portNr::port(),
				receive_msg_sender_pid = undefined ::pid(),
				queue_read_iterator = '$end_of_table', % ets table index
				queueTableID,  % ets table
				roundrobin_queueID = undefined     ::pid() % pid of the receiving process
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
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

process_register(ManagerPID)->
	 ok = gen_server:call(ManagerPID, register).

process_unregister(ManagerPID)->
	 ok = gen_server:call(ManagerPID, unregister).

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
init([Type]) ->
    {ok, #state{type = Type, pid_list = [], roundrobin_queueID = undefined}}.

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

handle_call({send_message, Message}, _From, #state{type = pub, direction=incoming}=State) ->
	%error_logger:info_msg("pid_list: ~p~n",[State#state.pid_list]),
	Reply = send_multicast_messages(State#state.pid_list, {send_message, Message}), 
    {reply, Reply, State};
handle_call(register, From, #state{type= sub, direction=incoming}=State) ->
	{SenderPID,_} = From,
	{Reply, NewState} = evaluate_registration_message(SenderPID, State),
    {reply, Reply, NewState};
handle_call(register, From, #state{type= pub, direction=incoming}=State) ->
	{SenderPID,_} = From,
	{Reply, NewState} = evaluate_registration_message(SenderPID, State),
    {reply, Reply, NewState};
handle_call(register, From, #state{type= req, direction=incoming, pid_list=[]}=State) ->
	{SenderPID,_} = From,
	{Reply, NewState} = evaluate_registration_message(SenderPID, State),
    {reply, Reply, NewState};
handle_call(register, From, #state{type= rep, direction=incoming, pid_list=[]}=State) ->
	{SenderPID,_} = From,
	{Reply, NewState}  = evaluate_registration_message(SenderPID, State),
    {reply, Reply, NewState};
handle_call(unregister, From, #state{type= sub, direction=incoming}=State) ->
	{SenderPID,_} = From,
	{Reply, NewState}  = evaluate_unregistration_message(SenderPID, State),
    {reply, Reply, NewState};
handle_call(unregister, From, #state{type= pub, direction=incoming}=State) ->
	{SenderPID,_} = From,
	{Reply, NewState}  = evaluate_unregistration_message(SenderPID, State),
    {reply, Reply, NewState};
handle_call(unregister, From, #state{type= req, direction=incoming}=State) ->
	{SenderPID,_} = From,
	{Reply, NewState}  = evaluate_unregistration_message(SenderPID, State),
    {reply, Reply, NewState};
handle_call(unregister, From, #state{type= rep, direction=incoming}=State) ->
	{SenderPID,_} = From,
	{Reply, NewState}  = evaluate_unregistration_message(SenderPID, State),
    {reply, Reply, NewState}.



%handle_call(_Request, _From, State) ->
%   Reply = ok,
%   {reply, Reply, State}.

	

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
handle_cast({connect, PortNr, Host, SenderPID}, State) ->
	error_logger:info_msg("Connecting to Host: ~p and Port: ~p~n", [Host, PortNr]),
	{ok, Outgoing_Connection_PID} = outgoing_tcp_connection:start_link(self(), State#state.type, Host, PortNr),
	NewState = State#state{outgoing_connnection_pid=Outgoing_Connection_PID},
	SenderPID ! {connect_ack, {ok, NewState#state.outgoing_connnection_pid}},
    {noreply, NewState#state{direction=outgoing}};
handle_cast({bind, PortNr}, State) ->
	NewState = State#state{portNr = PortNr},
	QueueTableID = lib_module:create_queuetable(),
	%%%{ok, ConnectionAcceptor_PID} = ts_root_sup:start_connection_acceptor_worker(self(), NewState#state.type, NewState#state.portNr), 
	{ok, ConnectionAcceptor_PID} =connection_acceptor:start_link(self(), NewState#state.type, NewState#state.portNr),
    {noreply, NewState#state{direction=incoming, connection_acceptor_pid = ConnectionAcceptor_PID, queueTableID = QueueTableID}};
handle_cast({receive_msg, SenderPID}, #state{direction=incoming, type=sub}=State) -> 
	NewState =evaluate_receive_message(SenderPID, State),
    {noreply, NewState};
handle_cast({receive_msg, SenderPID}, #state{direction=incoming, type=req}=State) -> 
	NewState =evaluate_receive_message(SenderPID, State),
    {noreply, NewState};
handle_cast({receive_msg, SenderPID}, #state{direction=incoming, type=rep}=State) ->
	NewState =evaluate_receive_message(SenderPID, State),
    {noreply, NewState};
handle_cast({receive_msg, SenderPID}, #state{direction=outgoing, type=sub}=State) ->
    gen_server:cast(State#state.outgoing_connnection_pid, {receive_msg, SenderPID}),
    {noreply, State};
handle_cast({receive_msg, SenderPID}, #state{direction=outgoing, type=req}=State) ->
    gen_server:cast(State#state.outgoing_connnection_pid, {receive_msg, SenderPID}),
    {noreply, State};
handle_cast({receive_msg, SenderPID}, #state{direction=outgoing, type=rep}=State) ->
    gen_server:cast(State#state.outgoing_connnection_pid, {receive_msg, SenderPID}),
    {noreply, State};
handle_cast({forward_message, ReplyerPID, BytesBin}, #state{type = sub, direction=incoming}=State) ->
	NewState = evaluate_forward_message(ReplyerPID, BytesBin, State),
    {noreply, NewState};
handle_cast({forward_message, ReplyerPID, BytesBin}, #state{type = req, direction=incoming}=State) ->
	NewState = evaluate_forward_message(ReplyerPID, BytesBin, State),
    {noreply, NewState};
handle_cast({forward_message, ReplyerPID, BytesBin}, #state{type = rep, direction=incoming}=State) ->
	NewState = evaluate_forward_message(ReplyerPID, BytesBin, State),
    {noreply, NewState};
handle_cast(stop, #state{direction=incoming}=State) ->
    ts_root_sup:stop_connection_acceptor_worker(State#state.connection_acceptor_pid),
    {stop, normal, State};
handle_cast(stop, #state{direction=outgoing}=State) ->
	gen_server:cast(State#state.outgoing_connnection_pid, stop),
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
handle_info(_Info, State) ->
    {noreply, State}.

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
terminate(_Reason, #state{direction=incoming}=State) ->
	%gen_server:cast(State#state.connection_acceptor_pid, stop),
	lib_module:delete_queuetable(State#state.queueTableID),
    ok;
terminate(_Reason, #state{direction=outgoing}=_State) ->
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

send_multicast_messages([], _Message) ->
    ok;

send_multicast_messages([H|T], Message) ->
    %% Handle exception in case the process has already been terminated (race condition)
    ok = gen_server:call(H,Message, infinity),
    %try gen_server:call(H,Message) , error_logger:info_msg("{message, ~p~n}", [Message]) of 
	%Val -> {normal, Val} 
    %catch
	%exit:Reason -> {exit, Reason};
	%throw:Throw -> {throw, Throw};
	%error:Error -> {error, Error}	
    %end,
    send_multicast_messages(T, Message).

evaluate_forward_message(ReplyerPID, BytesBin, State) ->
	QueueIdentifier = ReplyerPID,
	case State#state.receive_msg_sender_pid of
		undefined ->
			NewQueue = lib_module:queue_element(BytesBin, lib_module:get_queue(State#state.queueTableID, QueueIdentifier), ?CREDITS), 
		    lib_module:set_queue(State#state.queueTableID, QueueIdentifier, NewQueue),
		    NewState = State;
		ReceiverPID ->
			%error_logger:info_msg("evaluate_forward_message ReceiverPID~p~n",[ReceiverPID]),
		    ReceiverPID ! {received_message_ack, ReplyerPID, BytesBin},
			gen_server:cast(ReplyerPID, {flowcontrol,1}),	
		    NewState = State#state{receive_msg_sender_pid = undefined}
	end,
	NewState.	

evaluate_receive_message(SenderPID, State)->
	QueueIdentifier = State#state.roundrobin_queueID,
	Res = lib_module:getNextElementInQueueRoundRobin(State#state.queueTableID, QueueIdentifier),
	%error_logger:info_msg("getNextElementInQueueRoundRobin Res:~p~n",[Res]),
	case Res of 
		{all_queues_empty, '$end_of_table'}->
			KeyPID = ets:first(State#state.queueTableID),
			NewState = State#state{receive_msg_sender_pid = SenderPID, roundrobin_queueID = KeyPID}; 
			%error_logger:info_msg("KeyPID:~p~n",[KeyPID]),
			%error_logger:info_msg("ETStable:~p~n",[ets:tab2list(State#state.queueTableID)]);
		{all_queues_empty, KeyPID}->
			case State#state.receive_msg_sender_pid of 
				undefined ->
					%error_logger:info_msg("Storing SenderPID ~p~n",[SenderPID]),
					NewState = State#state{receive_msg_sender_pid = SenderPID, roundrobin_queueID = KeyPID};		
				_Other ->
					error_logger:error_report("Already waiting for message reception Error!!"),
					NewState = State#state{receive_msg_sender_pid = SenderPID, roundrobin_queueID = KeyPID}
			end;
		{queue_element, KeyPID, Queue_element} ->
			ReplyerPID = KeyPID,
		    NewState = State#state{roundrobin_queueID = KeyPID},
		    BytesBin = Queue_element,
		    SenderPID ! {received_message_ack, ReplyerPID, BytesBin},
			gen_server:cast(ReplyerPID, {flowcontrol,1})
			%error_logger:info_msg("KeyPID:~p~n",[KeyPID]),
			%error_logger:info_msg("ETStable:~p~n",[ets:tab2list(State#state.queueTableID)])
	end,
	NewState.

evaluate_registration_message(PID, State)->
	%error_logger:info_msg("evaluate_registration_message~p~n",[PID]),
	NewState = State#state{pid_list = [PID | State#state.pid_list]},
	case NewState#state.roundrobin_queueID == undefined of
		true ->
			NewState1 = NewState#state{roundrobin_queueID = PID};
		_Other ->
			NewState1 = NewState
	end,
	lib_module:set_queue(NewState1#state.queueTableID, PID, lib_module:queue_new()),
	%error_logger:info_msg("ETStable after registration:~p~n",[ets:tab2list(State#state.queueTableID)]),
	{ok, NewState1}.


evaluate_unregistration_message(PID, State)->
	%error_logger:info_msg("evaluate_unregistration_message~p~n",[PID]),
	NewState = State#state{pid_list = lists:delete(PID, State#state.pid_list)},
	lib_module:delete_queuetable_key(State#state.queueTableID , PID),
	case NewState#state.roundrobin_queueID==PID of 
		true ->
			First = ets:first(State#state.queueTableID),
			case (First == '$end_of_table') of
				true ->
					NewState1 = NewState#state{roundrobin_queueID = undefined};
				_OtherFirst ->
					NewState1 = NewState#state{roundrobin_queueID=First}
			end;
		_Other ->
			NewState1 = NewState
	end,
	%error_logger:info_msg("ETStable after unregistration:~p~n",[ets:tab2list(State#state.queueTableID)]),
	{ok, NewState1}.
	

