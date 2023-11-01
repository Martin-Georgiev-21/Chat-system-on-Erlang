-module(chatserver).
-export([start/1, sv/1, client/2, replace_process/4, update_states/3, update_statespart2/4]).

start(N) ->
	Supervisor = spawn(chatserver, sv, [[]]),
	Supervisor ! {start_links, N}.

sv(StateSV) ->
	process_flag(trap_exit, true),
	receive
		{start_links, N} ->
			io:format("Supervisor Pid: ~p~n", [self()]),
			Proc_list = [spawn_link(chatserver, client, [I, []]) || I <- lists:seq(1,N) ],
		       	io:format("List of clients: ~p~n", [Proc_list]),
			NewState = Proc_list;

		{restart, Pid} ->
			Pid ! {die},
			NewState = StateSV;

		{'EXIT', Pid ,Reason} ->
			{I, ListClient} = Reason,
			RestartedProcess = spawn_link(chatserver, client, [I, ListClient]),
			ListOfClients = replace_process(StateSV, RestartedProcess, Pid, []),
                        io:format("List of clients: ~p~n", [ListOfClients]),
			update_states(ListOfClients, Pid, RestartedProcess),
			NewState = ListOfClients;
			
		Any -> io:format("Any:~p~n", [Any]),	
		       NewState = StateSV
	end,
	sv(NewState).

replace_process([], _ProcPid, _OldPid, FinalList) -> FinalList;

replace_process(ListOfPids, ProcPid, OldPid, FinalList) ->
	[Head | Tail] = ListOfPids,			
	if
		Head == OldPid -> NewFinalList =  lists:append([FinalList, [ProcPid]]);
		true -> NewFinalList =  lists:append([FinalList, [Head]])
	end,
	replace_process(Tail, ProcPid, OldPid, NewFinalList).



update_states([], _OldPid, _NewPid) -> ok;

update_states(ListOfPids, OldPid, NewPid) ->
	[Head | Tail] = ListOfPids,
	Head ! {updating, OldPid, NewPid},
	update_states(Tail, OldPid, NewPid).



update_statespart2([], _OldPid, _NewPid, UpdatedStateList) -> UpdatedStateList;

update_statespart2(StateList, OldPid, NewPid, UpdatedStateList) ->
	[Head | Tail] = StateList,
	{Sender, Msg} = Head,
	if
		Sender == OldPid -> NewUpdatedStateList = lists:append([UpdatedStateList, [{NewPid, Msg}]]);
		true -> NewUpdatedStateList =  lists:append(UpdatedStateList, [Head])
	end,
	update_statespart2(Tail, OldPid, NewPid, NewUpdatedStateList).

	

client(StateC, List) ->
	receive
		{{Pid}, Msg} ->
			io:format("~p got ~p from ~p~n", [self(),  Msg, Pid]), 
			List1 = List ++ [{Pid, Msg}],
			NewState = StateC,
			NewList = List1;
		
		{history} ->
			print_list(List),
			NewState = StateC,
			NewList = List;

		{update, UpdatedList} -> 
			NewList = UpdatedList,
			NewState = StateC;

		{Msg, Pid} ->
			Pid ! {{self()}, Msg},
			NewState = StateC,
			NewList = List;
		
		{updating, OldPid, NewPid} -> 
			NewList = update_statespart2(List, OldPid, NewPid, []),
			NewState = StateC;

		{die} ->
			exit(self(), {StateC, List}),
			NewState = StateC,
			NewList = List;

		Any -> io:format("Any:~p~n", [Any]),
       			NewState = StateC,
 			NewList = List			

	end,
	client(NewState,NewList).

print_list([]) -> ok;

print_list(List) ->
	[Head | Tail] = List,
	io:format("~p~n", [Head]),
	print_list(Tail).
