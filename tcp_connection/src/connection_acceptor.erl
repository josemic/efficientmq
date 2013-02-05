%%%-------------------------------------------------------------------
%%% @author michael <michael@donald>
%%% @copyright (C) 2013, michael
%%% @doc
%%%
%%% @end
%%% Created : 19 Jan 2013 by michael <michael@donald>
%%%-------------------------------------------------------------------
-module(connection_acceptor).

-behaviour(gen_server).

%% API
-export([start_link/3]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define(SERVER, ?MODULE). 


-record(state, {manager_pid::pid(),
		type::atom(), 
		port::port(), 
		listensocket::port(),
		count::integer()
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
start_link(ParentPID, Type, Port) ->
    Ref_s = erlang:ref_to_list(make_ref()),                       
    %% Ref_s makes the instance unique after restart
    Name_s = ?MODULE_STRING ++ "_" ++ Ref_s,  
    Name = list_to_atom (Name_s),
    gen_server:start_link({local, Name}, ?MODULE, [ParentPID, Type, Port], []).

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
init([ManagerPID, Type, Port]) ->
    {ok, ListenSocket} = gen_tcp:listen(Port, [binary, {active, false}, {reuseaddr,true}, {packet,4}, {nodelay,true}, {exit_on_close,false}]),
    {ok, #state{manager_pid=ManagerPID, type=Type, port=Port, count=0, listensocket = ListenSocket}, 0}.

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
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

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
handle_cast(stop, State) ->
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
handle_info(timeout, #state{listensocket=ListenSocket, count=Count} = State) ->
	error_logger:info_msg("Wait connect: ~p, ListenSocket ~p~n",[Count, ListenSocket]),
    MaxNumberOfConcurrentConnections =100000,
    {ok,NewState} = wait_for_accept_loop(ListenSocket, MaxNumberOfConcurrentConnections, 0, State),
    {noreply, NewState}.
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
	Result = gen_tcp:close(State#state.listensocket),
	error_logger:info_msg("connection_acceptor: socket closed", [State#state.listensocket, Result]),
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

wait_for_accept_loop(_ListenSocket, 0, _Instance, State) ->
    {ok,State};
wait_for_accept_loop(ListenSocket, MaxNumberOfConcurrentConnections, Instance, State) ->
    {ok,Socket} = gen_tcp:accept(ListenSocket),
    Connection_Result = ts_root_sup:start_incomming_connection_worker(Socket, Instance, State#state.type, State#state.manager_pid),
    error_logger:info_msg("ts_root_sup:start_incomming_connection_worker: Root_Sup_PID(~p), Socket(~p), Instance(~p), Result(~p)~n", [ts_root_sup, Socket, Instance, Connection_Result]),
    {ok, Connection_PID} = Connection_Result,
    gen_tcp:controlling_process(Socket, Connection_PID),		   
    NewState = State#state{count = State#state.count+1},
    wait_for_accept_loop(ListenSocket, MaxNumberOfConcurrentConnections-1, Instance+1, NewState).
