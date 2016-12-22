
function DefaultSteamFriendsSortFunction(a:table,b:table)
	if not a.PlayingCiv and b.PlayingCiv then
		return false;
	elseif a.PlayingCiv and not b.PlayingCiv then
		return true;
	end
	return false;
	end

function FlippedSteamFriendsSortFunction(a:table,b:table)
	if a.PlayingCiv and not b.PlayingCiv then
		return false;
	elseif not a.PlayingCiv and b.PlayingCiv then
		return true;
	end
	return false;
end

function GetSteamFriendsList(sortFunction:ifunction)
	
	local friends:table = {};
	local numFriends:number = Steam.GetFriendCount();
	for i:number = 0, numFriends - 1 do
		local friend:table = Steam.GetFriendByIndex(i);
		if friend.IsOnline then
			friend.RichPresence = Locale.Lookup(Steam.GetRichPresence(friend.ID, "civPresence"));
			friend.PlayingCiv = friend.RichPresence ~= nil and friend.RichPresence ~= "";
			table.insert(friends, friend);
		end
	end

	if sortFunction then
		table.sort(friends, sortFunction);
	else
		table.sort(friends, DefaultSteamFriendsSortFunction);
	end

	return friends;
end

function OnFriendPulldownCallback(friendID:string, actionType:string)
	if actionType == "profile" then
		Steam.ActivateGameOverlayToUser(friendID);
	elseif actionType == "chat" then
		Steam.ActivateGameOverlayToChat(friendID);
	elseif actionType == "invite" then
		Steam.InviteUserToGame(friendID);
	end
end

function PopulateFriendsInstance(instance:table, friendData:table, friendActions:table, pulldownClickedCallback:ifunction)
	local friendID:string = friendData.ID;
	local friendStatus:string = friendData.PlayingCiv and friendData.RichPresence or "LOC_PRESENCE_ONLINE";
	instance.PlayerName:SetText(friendData.PlayerName);
	instance.PlayerStatus:SetText(Locale.Lookup(friendStatus));
	instance.OnlineIndicator:SetHide(not friendData.PlayingCiv);

	instance.FriendPulldown:ClearEntries();
	if friendActions ~= nil then
		for _, action in ipairs(friendActions) do
			controlTable = {};
			local actionType:string = action.action;
			instance.FriendPulldown:BuildEntry("InstanceOne", controlTable);
			controlTable.Button:LocalizeAndSetText(action.name);
			controlTable.Button:LocalizeAndSetToolTip(action.tooltip);
			controlTable.Button:RegisterCallback(Mouse.eLClick, function() 
				OnFriendPulldownCallback(friendID, actionType);
				if pulldownClickedCallback ~= nil then
					pulldownClickedCallback(friendID, actionType);
				end
			end);
		end
		
		instance.FriendPulldown:CalculateInternals();
	end
end