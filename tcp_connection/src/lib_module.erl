
-module(lib_module).
%% API
-export([queue_new/0, queue_len/1, queue_element/3, repeat_forever/3, repeat/3]).
-export([create_queuetable/0, delete_queuetable/1, remove_queue/2, get_queue/2, set_queue/3, queue_out/1]).
-export([delete_queuetable_key/2, getNextElementInQueueRoundRobin/2]).

queue_new() ->
    queue:new().

queue_len(Queue) ->
    queue:len(Queue).

queue_element(Element, Queue, MaxLength) ->
    QueueLength = queue:len(Queue), 
    if  
	QueueLength < MaxLength -> 
	    QueueNew = queue:in(Element,Queue);
	true -> 
	    QueueNew1 = queue:in(Element,Queue),
	    {_QueueDump, QueueNew} = queue:split(1, QueueNew1),
	    error_logger:warning_report([{"QueueNew1: ", QueueNew1, " QueueDump: ", _QueueDump}])
    end,
    QueueNew.

queue_out(Queue) ->
	queue:out(Queue).
	
create_queuetable() ->
	QueueTableID = ets:new(queueTable,[ordered_set, private]),
	%error_logger:info_msg("Initial Table: ~p~n",[ets:tab2list(QueueTableID)]),
	QueueTableID.

delete_queuetable(QueueTableID) ->
	ets:delete(QueueTableID).

delete_queuetable_key(QueueTableID, Key) ->
	ets:delete(QueueTableID, Key).
	
remove_queue(TableID, QueueIdentifier)->
	ets:delete(TableID, QueueIdentifier). 
	

get_queue(TableID, QueueIdentifier)->
	Queue = case ets:lookup(TableID, QueueIdentifier) of 
		[] ->
			queue_new();
		[{QueueIdentifier, QueueElement}] ->
			QueueElement
	end,
	Queue.
	
getNextElementInQueueRoundRobin(TableID, StartKey) ->
	case StartKey of 
		'$end_of_table' ->
			case ets:first(TableID) of
				'$end_of_table' -> 
					{all_queues_empty, '$end_of_table'};
				NewStartKey ->
					getNextElementInQueueRoundRobin(TableID, NewStartKey, NewStartKey)
			end;
		_Other ->	
			getNextElementInQueueRoundRobin(TableID, StartKey, StartKey)
	end.
	
getNextElementInQueueRoundRobin(TableID, StartKey, CurrentKey) ->
	case ets:next(TableID, CurrentKey) of
		'$end_of_table' ->
			case ets:first(TableID) of
			'$end_of_table' ->
				case ets:next(TableID, CurrentKey) of
					'$end_of_table' ->
						{all_queues_empty, '$end_of_table'};
					StartKey ->	
						case queue:out(ets:lookup_element(TableID, StartKey,2)) of 
							{empty,{[],[]}} ->
								{all_queues_empty, StartKey};
							{{value, Queue_element}, NewQueue} ->
								ets:insert(TableID,{StartKey, NewQueue}),
								{queue_element, StartKey, Queue_element}
						end;
					NewCurrentKey ->
						case queue:out(ets:lookup_element(TableID, NewCurrentKey,2)) of 
							{empty,{[],[]}} ->
								getNextElementInQueueRoundRobin(TableID, StartKey, NewCurrentKey);
							{{value, Queue_element}, NewQueue} ->
								ets:insert(TableID,{NewCurrentKey, NewQueue}),
								{queue_element, NewCurrentKey, Queue_element}
						end
				end;		
			StartKey ->
				case queue:out(ets:lookup_element(TableID, StartKey,2)) of 
					{empty,{[],[]}} ->
						{all_queues_empty, StartKey};
					{{value, Queue_element}, NewQueue} ->
						ets:insert(TableID,{StartKey, NewQueue}),
						{queue_element, StartKey, Queue_element}
				end;
			NewCurrentKey ->
				case queue:out(ets:lookup_element(TableID, NewCurrentKey,2)) of 
				{empty,{[],[]}} ->
					getNextElementInQueueRoundRobin(TableID, StartKey, NewCurrentKey);
				{{value, Queue_element}, NewQueue} ->
					ets:insert(TableID,{NewCurrentKey, NewQueue}),
					{queue_element, NewCurrentKey, Queue_element}
				end
			end;
		StartKey ->	
			case queue:out(ets:lookup_element(TableID, StartKey,2)) of 
				{empty,{[],[]}} ->
					{all_queues_empty, StartKey};
				{{value, Queue_element}, NewQueue} ->
					ets:insert(TableID,{StartKey, NewQueue}),
					{queue_element, StartKey, Queue_element}
			end;
		NewCurrentKey ->
			case queue:out(ets:lookup_element(TableID, NewCurrentKey,2)) of 
				{empty,{[],[]}} ->
					getNextElementInQueueRoundRobin(TableID, StartKey, NewCurrentKey);
				{{value, Queue_element}, NewQueue} ->
					ets:insert(TableID,{NewCurrentKey, NewQueue}),
					{queue_element, NewCurrentKey, Queue_element}
			end
	end.
				
set_queue(TableID, QueueIdentifier, NewQueue) ->
	ets:insert(TableID, {QueueIdentifier, NewQueue}).
	%error_logger:info_msg("Table: ~p~n",[ets:tab2list(TableID)]).
		
repeat_forever(Fun, X, Y) ->
    repeat_forever(Fun, X, Y, 0).

repeat_forever(Fun, X, Y, N) ->
    Fun(X, Y, N), 
    repeat_forever(Fun, X, Y, N+1).


repeat(_Fun, _X, 0) ->
    ok;

repeat(Fun, X, N) ->
    Fun(X, N), 
    repeat(Fun, X, N-1).
