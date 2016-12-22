----------------------------------------------------------------  
-- Player Targeting Logic
--
-- used by pulldowns to present a list of targetable civilizations (global, team, individuals)
--
-- Installation Steps
-- 1. Call PopulateTargetPull() for the target pulldown (and optional editbox) on initialization/show.
-- 2. Register a event handler wrapper function for PlayerInfoChanged that calls PlayerTarget_OnPlayerInfoChanged().
----------------------------------------------------------------  
include( "SupportFunctions"  );		--TruncateString

----------------------------------------------------------------  
-- Globals
----------------------------------------------------------------  
local NO_PLAYERTARGET_ID = -1;
local CHAT_ICON_GLOBAL:string = "[ICON_Global]";
local CHAT_ICON_TEAM:string = "[ICON_Team]";
local CHAT_ICON_WHISPER:string = "[ICON_Whisper]";

function GetNoPlayerTargetID()
	return NO_PLAYERTARGET_ID;
end


---------------------------------------------------------------- 
-- Pulldown Population
----------------------------------------------------------------  
-- editBoxControl [OPTIONAL] - edit box associated with the player target pulldown.  The editBoxControl's colorset will automatically update to the current player target type colorset.
function PopulateTargetPull(pulldownControl :table, editBoxControl :table, pulldownEntriesTable: table, playerTargetData :table, selfOption :boolean, selectionFunction)
	-- Populations the pulldown with the available player target options.

	-- If still in observer mode, ignore.
	local iLocalPlayerID = GetLocalPlayerID();
	if iLocalPlayerID == NO_PLAYERTARGET_ID then
		return;
	end

	-- blank out the pulldownEntriesTable while keeping our reference to the table passed in.
	for tableID, pulldownEntry in pairs( pulldownEntriesTable ) do
		pulldownEntriesTable[tableID] = nil;
	end
    pulldownControl:ClearEntries();

    -------------------------------------------------------
    -- Add To All Entry
    local controlTable = {};
    pulldownControl:BuildEntry( "InstanceOne", controlTable );
    controlTable.Button:SetVoids( ChatTargetTypes.CHATTARGET_ALL, NO_PLAYERTARGET_ID );
    local textControl = controlTable.Button:GetTextControl();
    textControl:LocalizeAndSetText( "LOC_DIPLO_TO_ALL" );
	if controlTable.ChatIcon ~= nil then controlTable.ChatIcon:SetText(CHAT_ICON_GLOBAL); end
	if controlTable.ChatLabel ~= nil then controlTable.ChatLabel:LocalizeAndSetText("LOC_DIPLO_TO_ALL"); end
	pulldownEntriesTable[ChatTargetTypes.CHATTARGET_ALL] = controlTable;


    -------------------------------------------------------
    -- Add To Team Entry
	local localPlayer = PlayerConfigurations[iLocalPlayerID];
	local localTeam = localPlayer:GetTeam();
	if( localTeam ~= TeamTypes.NO_TEAM and GameConfiguration.GetTeamPlayerCount(localTeam, true) >= 1) then
        local controlTable = {};
        pulldownControl:BuildEntry( "InstanceOne", controlTable );
        controlTable.Button:SetVoids( ChatTargetTypes.CHATTARGET_TEAM, localTeam );
        local textControl = controlTable.Button:GetTextControl();
        textControl:LocalizeAndSetText( "LOC_DIPLO_TO_TEAM" );
		if controlTable.ChatIcon ~= nil then controlTable.ChatIcon:SetText(CHAT_ICON_TEAM); end
		if controlTable.ChatLabel ~= nil then controlTable.ChatLabel:LocalizeAndSetText("LOC_DIPLO_TO_TEAM"); end
		pulldownEntriesTable[ChatTargetTypes.CHATTARGET_TEAM] = controlTable;
	end


    -------------------------------------------------------
    -- Add To Self Entry
	if(selfOption) then
			controlTable = {};
			pulldownControl:BuildEntry( "InstanceOne", controlTable );
			controlTable.Button:SetVoids( ChatTargetTypes.CHATTARGET_PLAYER, iLocalPlayerID );
			textControl = controlTable.Button:GetTextControl();
			textControl:LocalizeAndSetText( "LOC_DIPLO_TO_SELF" );
			pulldownEntriesTable[iLocalPlayerID] = controlTable;
	end


    -------------------------------------------------------
    -- Add To Individual Entries
	local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		local pPlayerCfg:table = PlayerConfigurations[iPlayer];
        if( iPlayer ~= iLocalPlayerID and pPlayerCfg:IsHuman() ) then
			controlTable = {};
			pulldownControl:BuildEntry( "InstanceOne", controlTable );
			controlTable.Button:SetVoids( ChatTargetTypes.CHATTARGET_PLAYER, iPlayer );
			textControl = controlTable.Button:GetTextControl();
			TruncateString( textControl, pulldownControl:GetSizeX()-20, Locale.Lookup("LOC_DIPLO_TO_PLAYER", pPlayerCfg:GetPlayerName()));
			if controlTable.ChatIcon ~= nil then controlTable.ChatIcon:SetText(CHAT_ICON_WHISPER); end
			if controlTable.ChatLabel ~= nil then TruncateString(controlTable.ChatLabel, pulldownControl:GetSizeX()-20, Locale.Lookup("LOC_DIPLO_TO_PLAYER", pPlayerCfg:GetPlayerName())); end
			pulldownEntriesTable[iPlayer] = controlTable;
        end
    end

	pulldownControl:RegisterSelectionCallback(
		function(newTargetType :number, newTargetID :number)
			playerTargetData.targetType = newTargetType;
			playerTargetData.targetID = newTargetID;
			UpdatePlayerTargetPulldown(pulldownControl, playerTargetData);
			if(editBoxControl ~= nil) then
				UpdatePlayerTargetEditBox(editBoxControl, playerTargetData);
			end
			if(selectionFunction ~= nil) then
				selectionFunction(newTargetType, newTargetID);
			end
		end
	);
    
	-- Make sure our player target is still legit.  The target can become invalid due to a player disconnect.
	ValidatePlayerTarget(playerTargetData);

	-- Set pulldown label.
	UpdatePlayerTargetPulldown(pulldownControl, playerTargetData); 

	-- Set edit box color
	if(editBoxControl ~= nil) then
		UpdatePlayerTargetEditBox(editBoxControl, playerTargetData);
	end

    pulldownControl:CalculateInternals();
end

---------------------------------------------------------------- 
-- General Scripting
----------------------------------------------------------------  
function ValidatePlayerTarget(playerTargetData :table)
	if(playerTargetData.targetType == ChatTargetTypes.CHATTARGET_ALL) then
		-- global player target is always valid.
		return true;
	elseif(playerTargetData.targetType == ChatTargetTypes.CHATTARGET_TEAM) then
		local iLocalPlayerID :number = GetLocalPlayerID();
		local localPlayer = PlayerConfigurations[iLocalPlayerID];
		local localTeam = localPlayer:GetTeam();
		local targetTeam = playerTargetData.targetID;
		-- Update targetIID if the local player's team has changed
		if(localTeam ~= playerTargetData.targetID) then
			playerTargetData.targetID = localTeam;
		end
	
		if(playerTargetData.targetID ~= TeamTypes.NO_TEAM and GameConfiguration.GetTeamPlayerCount(playerTargetData.targetID, true) >= 1) then
			-- target team needs to have a human player to be valid.
			return true;
		end
	elseif(playerTargetData.targetType == ChatTargetTypes.CHATTARGET_PLAYER) then
		-- player target must be human to be valid.
		local pPlayerCfg:table = PlayerConfigurations[playerTargetData.targetID];
		if( pPlayerCfg ~= nil and pPlayerCfg:IsHuman() ) then
			return true;
		end
	end

	-- invalid player target, revert to default
	playerTargetData.targetType = ChatTargetTypes.CHATTARGET_ALL;
	playerTargetData.targetID = NO_PLAYERTARGET_ID;
end

-------------------------------------------------
-- GetLocalPlayerID
-- Abstracted to a function because player targets are used ingame and pregame (where Game doesn't exist yet). 
-------------------------------------------------
function GetLocalPlayerID()
	local iLocalPlayerID :number = NO_PLAYERTARGET_ID;
	if Network.IsInGameStartedState() then
		iLocalPlayerID = Game.GetLocalPlayer();
	else
		iLocalPlayerID = Network.GetLocalPlayerID();
	end

	return iLocalPlayerID;
end

-------------------------------------------------
-- PlayerTargetToChatTarget
-------------------------------------------------
function PlayerTargetToChatTarget(playerTarget :table, chatTarget :table)
	-- right now, this is a 1:1 relationship
	chatTarget.targetType = playerTarget.targetType;
	chatTarget.targetID = playerTarget.targetID;
end

---------------------------------------------------------------- 
-- Button Events
---------------------------------------------------------------- 
function UpdatePlayerTargetPulldown(pulldownControl :table,  playerTargetData :table)
	local textControl = pulldownControl:GetButton():GetTextControl();

	if( playerTargetData.targetType == ChatTargetTypes.CHATTARGET_TEAM ) then
		TruncateString( textControl, pulldownControl:GetSizeX()-20, Locale.Lookup("LOC_DIPLO_TO_TEAM"));
	elseif( playerTargetData.targetType == ChatTargetTypes.CHATTARGET_ALL ) then
		textControl:LocalizeAndSetText( "LOC_DIPLO_TO_ALL" );
	elseif( playerTargetData.targetType == ChatTargetTypes.CHATTARGET_PLAYER ) then
		local iLocalPlayerID = GetLocalPlayerID();
		if(iLocalPlayerID >= 0 and iLocalPlayerID == playerTargetData.targetID) then
			-- We are targeting ourself, this can totally happen for private map pins
			textControl:LocalizeAndSetText( "LOC_DIPLO_TO_SELF" );
		else
			local pChatPlayerCfg = PlayerConfigurations[playerTargetData.targetID];
			TruncateString( textControl, pulldownControl:GetSizeX()-20, Locale.Lookup("LOC_DIPLO_TO_PLAYER", pChatPlayerCfg:GetPlayerName()));
		end
	end
end

function UpdatePlayerTargetEditBox(editBoxControl :table,  playerTargetData :table)
	if(editBoxControl ~= nil) then
		if( playerTargetData.targetType == ChatTargetTypes.CHATTARGET_TEAM ) then
			editBoxControl:SetColorByName("ChatMessage_Team");
		elseif( playerTargetData.targetType == ChatTargetTypes.CHATTARGET_ALL ) then
			editBoxControl:SetColorByName("ChatMessage_Global");
		elseif( playerTargetData.targetType == ChatTargetTypes.CHATTARGET_PLAYER ) then
			editBoxControl:SetColorByName("ChatMessage_Whisper");
		end
	end
end

---------------------------------------------------------------- 
-- Exteneral Event Handlers
---------------------------------------------------------------- 
function PlayerTarget_OnPlayerInfoChanged( playerID :number, pulldownControl :table, editBoxControl:table, pulldownEntriesTable: table, playerTargetData :table, selfOption :boolean, selectionFunction)
	-- Rebuild chat pulldown if the changed player altered their human status.A player was human if they had a pulldown entry.
	local pPlayerCfg:table = PlayerConfigurations[playerID];
	local rebuildPulldown :boolean = false;
	if(pPlayerCfg ~= nil) then
		local isHuman = pPlayerCfg:IsHuman();
		local inPulldown = pulldownEntriesTable[playerID] ~= nil;
		if(playerID == GetLocalPlayerID()) then
			-- We need to rebuild if we changed teams.
			local teamPulldown = pulldownEntriesTable[ChatTargetTypes.CHATTARGET_TEAM];
			local localTeam = pPlayerCfg:GetTeam();
			if( (localTeam ~= TeamTypes.NO_TEAM and teamPulldown == nil) -- switched to a team from no team.
				or (teamPulldown ~= nil and localTeam ~= teamPulldown.Button:GetVoid2()) ) then -- switched to a different team.
				rebuildPulldown = true;
			end
		elseif(isHuman ~= inPulldown) then
			rebuildPulldown = true;
		end
	end

	if(rebuildPulldown) then
		PopulateTargetPull(pulldownControl, editBoxControl, pulldownEntriesTable, playerTargetData, selfOption, selectionFunction);
	end
end
