-module(ts_context_process).

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define(SERVER, ?MODULE). 

-record(state, {}).

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
init([]) ->
    {ok, #state{}}.

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
handle_call({socket, pub = Type}, _From, State) ->
	Ref_s = erlang:ref_to_list(make_ref()),                       
    %% Ref_s makes the instance unique after restart
    Name_s = atom_to_list(port_manager)++ "_" ++ atom_to_list(Type)  ++ "_" ++ Ref_s,  
    CallbackName = list_to_atom (Name_s),
    {ok, PublisherPID}=gen_server:start_link({local, CallbackName}, port_manager, [Type], []),
	Reply = {ok, PublisherPID},
    {reply, Reply, State};
handle_call({socket, sub = Type}, _From, State) ->
	Ref_s = erlang:ref_to_list(make_ref()),                       
    %% Ref_s makes the instance unique after restart
    Name_s = atom_to_list(port_manager)++ "_" ++ atom_to_list(Type)  ++ "_" ++ Ref_s,  
    CallbackName = list_to_atom (Name_s),
	{ok, SubscriberPID} = gen_server:start_link({local, CallbackName}, port_manager,[Type], []),
    Reply = {ok, SubscriberPID},
    {reply, Reply, State};
handle_call({socket, req = Type}, _From, State) ->
	Ref_s = erlang:ref_to_list(make_ref()),                       
    %% Ref_s makes the instance unique after restart
    Name_s = atom_to_list(port_manager)++ "_" ++ atom_to_list(Type)  ++ "_" ++ Ref_s,  
    CallbackName = list_to_atom (Name_s),
    {ok, RequesterPID} = gen_server:start_link({local, CallbackName},port_manager,[Type], []),
    Reply = {ok, RequesterPID},
    {reply, Reply, State};
handle_call({socket, rep = Type}, _From, State) ->
	Ref_s = erlang:ref_to_list(make_ref()),                       
    %% Ref_s makes the instance unique after restart
    Name_s = atom_to_list(port_manager)++ "_" ++ atom_to_list(Type)  ++ "_" ++ Ref_s,   
    CallbackName = list_to_atom (Name_s),
    {ok, ResponderPID} = gen_server:start_link({local, CallbackName},port_manager,[Type], []),
    Reply = {ok, ResponderPID},
    {reply, Reply, State};
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
handle_cast(_Msg, State) ->
    {noreply, State}.

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
terminate(_Reason, _State) ->
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









