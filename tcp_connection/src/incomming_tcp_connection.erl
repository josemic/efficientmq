
-module(incomming_tcp_connection).
-include("incomming_tcp_connection.hrl").
-behaviour(gen_server).

%% API
-export([start_link/4]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define(SERVER, ?MODULE). 

-define(debug, debug). 
-ifdef(debug).
-define(LOG(X), error_logger:info_report("{~p,~p}: ~p~n", [?MODULE,?LINE,X])).
-else.
-define(LOG(X), true).
-endif.

-record(state, {
	 socket::port(),
	 instance::integer(),
	 type::pub|sub|req|rep,
	 manager_pid::pid(),
	 credits::integer()
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
start_link(Socket, Instance, Type, ManagerPID) when is_integer(Instance)->   
    Instance_s = integer_to_list(Instance),
    Ref_s = erlang:ref_to_list(make_ref()),
    Name_s = ?MODULE_STRING ++ "_" ++ Instance_s ++ "_" ++ Ref_s,
    Name = list_to_atom (Name_s),      
    error_logger:info_report("gen_server:start_link Socket:(~p) Instance:(~p) Type:(~p)~n",[[{local, Name},?MODULE,[Socket, Instance, Type],[],self()]]), 
    %% Name may be left away.
    gen_server:start_link({local, Name},?MODULE,[Socket, Instance, Type, ManagerPID],[]).

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
init([Socket, Instance, Type, ManagerPID]) ->
	error_logger:info_msg("tcp_connection has started (~w) on Socket (~w)~n", [self(),Socket]),
	port_manager:process_register(ManagerPID),
	inet:setopts(Socket, [{active,once}, {packet,4}]),
    {ok, #state{socket=Socket, instance=Instance, type=Type, manager_pid=ManagerPID, credits = ?CREDITS},0}.

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
handle_call({send_message, Message}, _From, #state{type=req}=State) ->
	{Reply, NewState} = evaluate_send_message(Message, State), 
    {reply, Reply, NewState};
handle_call({send_message, Message}, _From, #state{type=rep}=State) ->
	{Reply, NewState} = evaluate_send_message(Message, State), 
    {reply, Reply, NewState};
handle_call({send_message, Message}, _From, #state{type=pub}=State) ->
	{Reply, NewState} = evaluate_send_message(Message, State), 
    {reply, Reply, NewState}.
    
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

handle_cast({flowcontrol, Credits}, State) ->
	NewState = State#state{credits = (State#state.credits + Credits)},
	case NewState#state.credits > (?CREDITS / 2) of 
		true ->
			inet:setopts(State#state.socket, [{active,once}, {keepalive,true}, {packet,4}]);
			% error_logger:info_msg("True Credits ~p~n", [NewState#state.credits]); 
		false ->
			inet:setopts(State#state.socket, [{active,false}, {keepalive,true}, {packet,4}])
			% error_logger:info_msg("False Credits ~p~n", [NewState#state.credits]) 
	end,
	{noreply, NewState}.
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

handle_info({tcp, Socket, BytesBin}, #state{type=sub, socket=Socket}=State) ->
	NewState = evaluate_tcp_message(Socket, BytesBin, State),
	{noreply, NewState};
handle_info({tcp, Socket, BytesBin}, #state{type=req, socket=Socket}=State) ->
	NewState = evaluate_tcp_message(Socket, BytesBin, State),
	{noreply, NewState};
handle_info({tcp, Socket, BytesBin}, #state{type=rep, socket=Socket}=State) ->
	NewState = evaluate_tcp_message(Socket, BytesBin, State),
	{noreply, NewState};
handle_info(timeout, State) ->
	{noreply, State};
handle_info({tcp_closed, Socket}, #state{socket=Socket}=State) ->
    gen_tcp:close(Socket),
    error_logger:info_msg("Socket closed: (~w)~n", [Socket]),
    {stop, normal, State};
handle_info({tcp_error, Socket, Reason}, #state{manager_pid=ManagerPID, socket=Socket}=State) ->
    error_logger:info_msg("Socket error:(~w)~n", [Reason]),    
    gen_tcp:close(Socket),
    port_manager:process_unregister(ManagerPID),
    {stop, normal, State}.
%handle_info(_Info, State) ->
%    error_logger:info_msg("tcp_connection (~w) received unhandled Info message (~w) ~n", [self(), _Info]),
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
evaluate_tcp_message(Socket, BytesBin, State) ->
	%?LOG({"Received: ", BytesBin}),
	ok = gen_server:cast(State#state.manager_pid, {forward_message, self(), BytesBin}),
	NewState = State#state{credits = (State#state.credits-1)},
	case NewState#state.credits > (?CREDITS / 2) of 
		true ->
			inet:setopts(Socket, [{active,once}, {keepalive,true}, {packet,4}]);
		false ->
			inet:setopts(Socket, [{active,false}, {keepalive,true}, {packet,4}])
	end,
	%error_logger:info_msg("Credits ~p~n", [NewState#state.credits]), 
	NewState.

evaluate_send_message(Message, State) ->
	Reply = gen_tcp:send(State#state.socket, Message),
	%error_logger:info_msg("{message, ~p~n}", [Message]),
	{Reply, State}.
