-module(ts_root_sup).

-behaviour(supervisor).

%% API
-export([start_link/0, 
	 start_incomming_connection_worker/4, start_connection_acceptor_worker/3, stop_connection_acceptor_worker/1]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

start_incomming_connection_worker(Socket, Instance, Type, ManagerPID) ->
    Instance_s = integer_to_list(Instance),
    Ref_s = erlang:ref_to_list(make_ref()),
    Type_s = atom_to_list(Type),                       
    %% Ref_s makes the instance unique after restart
    %% as instance starts again at 0
    Name_s = ?MODULE_STRING ++ "_" ++ Instance_s  ++ "_" ++ Ref_s ++ "_" ++ Type_s,  
    Name = list_to_atom (Name_s),
    %% the name must be a unique atom
    TCP_incomming_connection_worker = {Name, {incomming_tcp_connection, start_link, [Socket, Instance, Type, ManagerPID]},
    			  temporary, 2000, worker, [incomming_tcp_connection]},
    supervisor:start_child(?SERVER, TCP_incomming_connection_worker).
    
start_connection_acceptor_worker(ManagerPID, Type, PortNr) ->
    Ref_s = erlang:ref_to_list(make_ref()),
    Type_s = atom_to_list(Type),                       
    %% Ref_s makes the instance unique after restart
    Name_s = ?MODULE_STRING ++ "_" ++ "_" ++ Ref_s ++ "_" ++ Type_s,  
    Name = list_to_atom (Name_s),
    %% the name must be a unique atom
    TCP_connection_acceptor_worker = {Name, {connection_acceptor, start_link, [ManagerPID, Type, PortNr]},
    			  temporary, brutal_kill, worker, [connection_acceptor]},
    supervisor:start_child(?SERVER, TCP_connection_acceptor_worker).

stop_connection_acceptor_worker(WorkerPID)->
	exit(WorkerPID, kill).
	%%%supervisor:terminate_child(?SERVER, WorkerPID).



%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%%
%% @spec init(Args) -> {ok, {SupFlags, [ChildSpec]}} |
%%                     ignore |
%%                     {error, Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    RestartStrategy = one_for_one,
    MaxRestarts = 10,
    MaxSecondsBetweenRestarts = 60,

    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

    Context_process = {ts_context_process, {ts_context_process, start_link, []},
		     temporary, brutal_kill, worker, [ts_context_process]},
    {ok, {SupFlags, [Context_process]}}.
%%%===================================================================
%%% Internal functions
%%%===================================================================
