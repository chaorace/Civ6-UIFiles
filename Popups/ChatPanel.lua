----------------------------------------------------------------  
-- Ingame Chat Panel
----------------------------------------------------------------  
include( "SupportFunctions"  );		--TruncateString
include( "PlayerTargetLogic" );
include( "ChatLogic" );
include( "NetConnectionIconLogic" );

local CHAT_ENTRY_LOG_FADE_TIME :number = 1; -- The fade time for chat entries that had already faded out
											-- when reshown by mousing over the chat log.

local PLAYER_LIST_BG_WIDTH:number = 236;
local PLAYER_LIST_BG_HEIGHT:number = 195;
local PLAYER_ENTRY_HEIGHT:number = 46;
local PLAYER_LIST_BG_PADDING:number = 20;

local m_isDebugging		:boolean= false;	-- set to true to fill with test messages
local m_isExpanded		:boolean= false;	-- Is the chat panel expanded?
local m_ChatInstances	:table	= {};		-- Chat instances on the compressed panel
local m_expandedChatInstances :table = {};	-- Chat instances on the expanded panel	
local m_playerTarget = { targetType = ChatTargetTypes.CHATTARGET_ALL, targetID = GetNoPlayerTargetID() };
local m_chatTargetEntries :table = {};		-- Chat target pulldown entries indexed by playerID for compressed panel.
local m_expandedChatTargetEntries :table = {};		-- Chat target pulldown entries indexed by playerID for compressed panel.

local m_isPlayerListVisible	:boolean= false;	-- Is the player list visible?
local m_playerListEntries = {};
-- See below for g_playerListPullData.

local PlayerConnectedChatStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED_CHAT" );
local PlayerDisconnectedChatStr = Locale.Lookup( "LOC_MP_PLAYER_DISCONNECTED_CHAT" );
local PlayerKickedChatStr = Locale.Lookup( "LOC_MP_PLAYER_KICKED_CHAT" );

------------------------------------------------- 
-- PlayerList Data Functions
-- These have to be defined before g_playerListPullData to work correctly.
-------------------------------------------------
function IsKickPlayerValidPull(iPlayerID :number)
	if(Network.IsHost() and iPlayerID ~= Game.GetLocalPlayer()) then
		return true;
	end
	return false;
end

-------------------------------------------------
-------------------------------------------------
function IsFriendRequestValidPull(iPlayerID :number)
	if(Network.GetTransportType() == TransportType.TRANSPORT_STEAM and iPlayerID ~= Game.GetLocalPlayer()) then
		local playerSteamID = PlayerConfigurations[iPlayerID]:GetNetworkIdentifer();
		local numFriends:number = Steam.GetFriendCount();
		for i:number = 0, numFriends - 1 do
			local friend:table = Steam.GetFriendByIndex(i);
			if friend.ID == playerSteamID then
				return false;
			end
		end
		return true;
	end
	return false;
end

-------------------------------------------------
-------------------------------------------------
local g_playerListPullData = 
{
	{ name = "PLAYERACTION_KICKPLAYER",		tooltip = "PLAYERACTION_KICKPLAYER_TOOLTIP",	playerAction = "PLAYERACTION_KICKPLAYER",		isValidFunction=IsKickPlayerValidPull},
	{ name = "PLAYERACTION_FRIENDREQUEST",	tooltip = "PLAYERACTION_FRIENDREQUEST_TOOLTIP",	playerAction = "PLAYERACTION_FRIENDREQUEST",	isValidFunction=IsFriendRequestValidPull},	
};


-------------------------------------------------
-- OnChat
-------------------------------------------------
function OnChat( fromPlayer, toPlayer, text, eTargetType, playSounds :boolean )
	local pPlayerConfig :table	= PlayerConfigurations[fromPlayer];
	local playerName	:string = pPlayerConfig:GetPlayerName(); 
	
	-- Selecting chat text color based on eTargetType	
	local chatColor :string = "[color:ChatMessage_Global]";
	if(eTargetType == ChatTargetTypes.CHATTARGET_TEAM) then
		chatColor = "[color:ChatMessage_Team]";
	elseif(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER) then
		chatColor = "[color:ChatMessage_Whisper]";  
	end
	
	local chatString	:string = "[color:ChatPlayerName]" .. playerName;

	-- When whispering, include the whisperee's name as well.
	if(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER) then
		local pTargetConfig :table	= PlayerConfigurations[toPlayer];
		if(pTargetConfig ~= nil) then
			local targetName :string = pTargetConfig:GetPlayerName();
			chatString = chatString .. " [" .. targetName .. "]";
		end
	end

	-- When a map pin is sent, parse and build button
	if(string.find(text, "%[pin:%d+,%d+%]")) then
		-- parse the string
		local pinStr = string.sub(text, string.find(text, "%[pin:%d+,%d+%]"));
		local pinPlayerIDStr = string.sub(pinStr, string.find(pinStr, "%d+"));
		local comma = string.find(pinStr, ",");
		local pinIDStr = string.sub(pinStr, string.find(pinStr, "%d+", comma));
		
		local pinPlayerID = tonumber(pinPlayerIDStr);
		local pinID = tonumber(pinIDStr);

		-- Only build button if valid pin
		-- TODO: player can only send own/team pins. ??PEP
		if(GetMapPinConfig(pinPlayerID, pinID) ~= nil) then
			chatString = chatString .. ": [ENDCOLOR]";
			AddMapPinChatEntry(pinPlayerID, pinID, chatString, Controls.ChatEntryStack, m_ChatInstances, Controls.ChatLogPanel);
			AddMapPinChatEntry(pinPlayerID, pinID, chatString, Controls.ExpandedChatEntryStack, m_expandedChatInstances, Controls.ExpandedChatLogPanel);
			return;
		end
	end

	-- Ensure text parsed properly
	text = ParseChatText(text);

	chatString			= chatString .. ": [ENDCOLOR]" .. chatColor .. text .. "[ENDCOLOR]"; 

	AddChatEntry( chatString, Controls.ChatEntryStack, m_ChatInstances, Controls.ChatLogPanel);
	AddChatEntry( chatString, Controls.ExpandedChatEntryStack, m_expandedChatInstances, Controls.ExpandedChatLogPanel);

	if(playSounds and fromPlayer ~= Network.GetLocalPlayerID()) then
		UI.PlaySound("Play_MP_Chat_Message_Received");
	end

	if fromPlayer ~= Network.GetLocalPlayerID() then
		local isHidden
		LuaEvents.ChatPanel_OnChatReceived(fromPlayer, ContextPtr:GetParent():IsHidden());
	end
end

function OnMultiplayerChat( fromPlayer, toPlayer, text, eTargetType )
	OnChat(fromPlayer, toPlayer, text, eTargetType, true);
end


------------------------------------------------- 
-- SendChat
-------------------------------------------------
function SendChat( text )
    if( string.len( text ) > 0 ) then
		-- Parse text for possible chat commands
		local parsedText :string;
		local chatTargetChanged :boolean = false;
		local printHelp :boolean = false;
		parsedText, chatTargetChanged, printHelp = ParseInputChatString(text, m_playerTarget);
		if(chatTargetChanged) then
			ValidatePlayerTarget(m_playerTarget);
			UpdatePlayerTargetPulldown(Controls.ChatPull, m_playerTarget);
			UpdatePlayerTargetEditBox(Controls.ChatEntry, m_playerTarget);
			UpdatePlayerTargetPulldown(Controls.ExpandedChatPull, m_playerTarget);
			UpdatePlayerTargetEditBox(Controls.ExpandedChatEntry, m_playerTarget);
		end

		if(printHelp) then
			ChatPrintHelp(Controls.ChatEntryStack, m_ChatInstances, Controls.ChatLogPanel);
			ChatPrintHelp(Controls.ExpandedChatEntryStack, m_expandedChatInstances, Controls.ExpandedChatLogPanel);
		end

		if(parsedText ~= "") then
			-- m_playerTarget uses PlayerTargetLogic values and needs to be converted 
			local chatTarget :table ={};
			PlayerTargetToChatTarget(m_playerTarget, chatTarget);
			Network.SendChat( parsedText, chatTarget.targetType, chatTarget.targetID );
		end
		UI.PlaySound("Play_MP_Chat_Message_Sent");
    end
    Controls.ChatEntry:ClearString();
	Controls.ExpandedChatEntry:ClearString();
end
Controls.ChatEntry:RegisterCommitCallback( SendChat );
Controls.ExpandedChatEntry:RegisterCommitCallback( SendChat );


-------------------------------------------------
-- ParseChatText - ensures icon tags parsed properly
-------------------------------------------------
function ParseChatText(text)
	startIdx, endIdx = string.find(string.upper(text), "%[ICON_");
	if(startIdx == nil) then
		return text;
	else
		for i = endIdx + 1, string.len(text) do
			character = string.sub(text, i, i);
			if(character=="]") then
				return string.sub(text, 1, i) .. ParseChatText(string.sub(text,i + 1));
			elseif(character==" ") then
				text = string.gsub(text, " ", "]", 1);
				return string.sub(text, 1, i) .. ParseChatText(string.sub(text, i + 1));
			elseif (character=="[") then
				return string.sub(text, 1, i - 1) .. "]" .. ParseChatText(string.sub(text, i));
			end
		end
		return text.."]";
	end
	return text;
end


-------------------------------------------------
-------------------------------------------------
function OnOpenExpandedPanel()		
    UI.PlaySound("Tech_Tray_Slide_Open");
	m_isExpanded = true;
	Controls.ChatPanel:SetHide(true);
	Controls.ChatPanelBG:SetHide(true);
	Controls.ExpandedChatPanel:SetHide(false);
	Controls.ExpandedChatPanelBG:SetHide(false);
	Controls.PlayerListPanel:SetHide(not m_isPlayerListVisible);
end
Controls.ExpandButton:RegisterCallback(Mouse.eLClick, OnOpenExpandedPanel);

-------------------------------------------------
-------------------------------------------------
function OnCloseExpandedPanel()
    UI.PlaySound("Tech_Tray_Slide_Closed");
	m_isExpanded = false;
	Controls.ChatPanel:SetHide(false);
	Controls.ChatPanelBG:SetHide(false);
	Controls.ExpandedChatPanel:SetHide(true);
	Controls.ExpandedChatPanelBG:SetHide(true);
	Controls.PlayerListPanel:SetHide(true);
end
Controls.ContractButton:RegisterCallback(Mouse.eLClick, OnCloseExpandedPanel);


------------------------------------------------- 
-- Map Pin Chat Buttons
-------------------------------------------------
function AddMapPinChatEntry(pinPlayerID :number, pinID :number, playerName :string, chatEntryStack :table, chatInstances :table, chatLogPanel :table)
	local BUTTON_TEXT_PADDING:number = 12;
	local CHAT_ENTRY_LIMIT:number = 1000;
	local instance = {};
	ContextPtr:BuildInstanceForControl("MapPinChatEntry", instance, chatEntryStack);

	-- limit chat log
	local newChatEntry = { ChatControl = instance; };
	table.insert( chatInstances, newChatEntry );
	local numChatInstances:number = table.count(chatInstances);
	if( numChatInstances > CHAT_ENTRY_LIMIT) then
		chatEntryStack:ReleaseChild( chatInstances[ 1 ].ChatControl.ChatRoot );
		table.remove( chatInstances, 1 );
	end

	instance.PlayerString:SetText(playerName);
	local mapPinCfg = GetMapPinConfig(pinPlayerID, pinID);
	if(mapPinCfg:GetName() ~= nil) then
		instance.MapPinButton:SetText(mapPinCfg:GetName());
	else
		instance.MapPinButton:SetText(Locale.Lookup("LOC_MAP_PIN_DEFAULT_NAME", mapPinCfg:GetID()));
	end
	instance.MapPinButton:SetOffsetVal(instance.PlayerString:GetSizeX(), 0);
	instance.MapPinButton:SetSizeX(instance.MapPinButton:GetTextControl():GetSizeX()+BUTTON_TEXT_PADDING);

	local hexX :number = mapPinCfg:GetHexX();
	local hexY :number = mapPinCfg:GetHexY();
	instance.MapPinButton:RegisterCallback(Mouse.eLClick,
		function()
			UI.LookAtPlot(hexX, hexY);		
		end
	);

	chatEntryStack:CalculateSize();
	chatEntryStack:ReprocessAnchoring();
	chatLogPanel:CalculateInternalSize();
	chatLogPanel:ReprocessAnchoring();
end

-------------------------------------------------
-------------------------------------------------
function OnSendPinToChat(playerID, pinID)
	local mapPinStr :string = "[pin:" .. playerID .. "," .. pinID .. "]";
	SendChat(mapPinStr);
end

------------------------------------------------- 
------------------------------------------------- 
function GetMapPinConfig(iPlayerID :number, mapPinID :number)
	local playerCfg :table = PlayerConfigurations[iPlayerID];
	if(playerCfg ~= nil) then
		local playerMapPins :table = playerCfg:GetMapPins();
		if(playerMapPins ~= nil) then
			return playerMapPins[mapPinID];
		end
	end
	return nil;
end

------------------------------------------------- 
-- PlayerList Scripting
-------------------------------------------------
function TogglePlayerListPanel()
	m_isPlayerListVisible = not m_isPlayerListVisible;
	Controls.ShowPlayerListCheck:SetCheck(m_isPlayerListVisible);
	Controls.PlayerListPanel:SetHide(not m_isPlayerListVisible);
	if(m_isPlayerListVisible) then
		UI.PlaySound("Tech_Tray_Slide_Open");
	else
		UI.PlaySound("Tech_Tray_Slide_Closed");
	end
end
Controls.ShowPlayerListCheck:RegisterCallback(Mouse.eLClick, TogglePlayerListPanel);
Controls.ShowPlayerListButton:RegisterCallback(Mouse.eLClick, TogglePlayerListPanel);

-------------------------------------------------
-------------------------------------------------
function UpdatePlayerEntry(iPlayerID :number)

	local playerEntry:table = m_playerListEntries[iPlayerID];
	if(playerEntry == nil) then
		playerEntry = {};
		ContextPtr:BuildInstanceForControl( "PlayerListEntry", playerEntry, Controls.PlayerListStack);
		m_playerListEntries[iPlayerID] = playerEntry;
	end

	local pPlayerConfig = PlayerConfigurations[iPlayerID];
	if(playerEntry ~= nil and pPlayerConfig ~= nil) then

		playerEntry.PlayerName:SetText(pPlayerConfig:GetSlotName()); 
		
		UpdateNetConnectionIcon(iPlayerID, playerEntry.ConnectionIcon);
		UpdateNetConnectionLabel(iPlayerID, playerEntry.ConnectionLabel);
		
		local numEntries:number = PopulatePlayerPull(iPlayerID, playerEntry.PlayerListPull, g_playerListPullData);
		playerEntry.PlayerListPull:SetDisabled(numEntries == 0 or iPlayerID == Game.GetLocalPlayer());

		if iPlayerID == Network.GetHostPlayerID() then
			local connectionText:string = playerEntry.ConnectionLabel:GetText();
			connectionText = "[ICON_Host] " .. connectionText;
			playerEntry.ConnectionLabel:SetText(connectionText);
		end
	end
end

-------------------------------------------------
-------------------------------------------------
function OnPlayerListPull(iPlayerID :number, iPlayerListDataID :number)
	local playerListData = g_playerListPullData[iPlayerListDataID];
	if(playerListData ~= nil) then
		if(playerListData.playerAction == "PLAYERACTION_KICKPLAYER") then
			UIManager:PushModal(Controls.ConfirmKick, true);	
			local pPlayerConfig = PlayerConfigurations[iPlayerID];
			if(pPlayerConfig ~= nil) then
				local playerName = pPlayerConfig:GetPlayerName();
				LuaEvents.SetKickPlayer(iPlayerID, playerName);
			end
		elseif(playerListData.playerAction == "PLAYERACTION_FRIENDREQUEST") then
			Steam.ActivateGameOverlayToFriendRequest(iPlayerID);
		end
	end
end

-------------------------------------------------
-------------------------------------------------
function PopulatePlayerPull(iPlayerID :number, pullDown :table, playerListPullData :table)
	pullDown:ClearEntries();
	local numEntries:number = 0;

	for i, pair in ipairs(playerListPullData) do
		if(pair.isValidFunction == nil or pair.isValidFunction(iPlayerID)) then
			local controlTable:table = {};
			pullDown:BuildEntry( "InstanceOne", controlTable );
				
			controlTable.Button:LocalizeAndSetText( pair.name );
			controlTable.Button:LocalizeAndSetToolTip( pair.tooltip );
			controlTable.Button:SetVoids( iPlayerID, i);	
			numEntries = numEntries + 1;
		end
	end

	pullDown:CalculateInternals();
	pullDown:RegisterSelectionCallback( OnPlayerListPull );
	return numEntries;
end

-------------------------------------------------
-------------------------------------------------
function BuildPlayerList()
	m_playerListEntries = {};
	Controls.PlayerListStack:DestroyAllChildren();

	-- Call GetplayerEntry on each human player to initially create the entries.
	local numPlayers:number = 0;
	local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		local pPlayerConfig = PlayerConfigurations[iPlayer];
		if(pPlayerConfig ~= nil and pPlayerConfig:IsHuman() and not Network.IsPlayerKicked(iPlayer)) then
			UpdatePlayerEntry(iPlayer);
			numPlayers = numPlayers + 1;
		end
	end

	local inviteButtonContainer:table = nil;
	if Network.GetTransportType() == TransportType.TRANSPORT_STEAM then
		inviteButtonContainer = {};
		ContextPtr:BuildInstanceForControl("InvitePlayerListEntry", inviteButtonContainer, Controls.PlayerListStack);
		inviteButtonContainer.InviteButton:RegisterCallback(Mouse.eLClick, OnInviteButton);
	end

	Controls.PlayerListStack:CalculateSize();
	Controls.PlayerListStack:ReprocessAnchoring();
	Controls.PlayerListScroll:CalculateInternalSize();
	Controls.PlayerListScroll:ReprocessAnchoring();

	if Controls.PlayerListScroll:GetScrollBar():IsHidden() then
		if inviteButtonContainer ~= nil then
			Controls.PlayerListBackground:SetSizeVal(PLAYER_LIST_BG_WIDTH, numPlayers * PLAYER_ENTRY_HEIGHT + PLAYER_LIST_BG_PADDING + inviteButtonContainer.InviteButton:GetSizeY());
		else
			Controls.PlayerListBackground:SetSizeVal(PLAYER_LIST_BG_WIDTH, numPlayers * PLAYER_ENTRY_HEIGHT + PLAYER_LIST_BG_PADDING);
		end
	else
		Controls.PlayerListBackground:SetSizeVal(PLAYER_LIST_BG_WIDTH + 10, PLAYER_LIST_BG_HEIGHT);
	end
end

-------------------------------------------------
-- OnInviteButton
-------------------------------------------------
function OnInviteButton()
	Steam.ActivateInviteOverlay();
end

------------------------------------------------- 
-- External Event Handlers
-------------------------------------------------
function OnMultplayerPlayerConnected( playerID )
	if(GameConfiguration.IsNetworkMultiplayer()) then
		OnChat( playerID, -1, PlayerConnectedChatStr, false );
		UI.PlaySound("Play_MP_Player_Connect");
		BuildPlayerList();
	end
end

-------------------------------------------------
-------------------------------------------------

function OnMultiplayerPrePlayerDisconnected( playerID )
	if(GameConfiguration.IsNetworkMultiplayer()) then
		if(Network.IsPlayerKicked(playerID)) then
			OnChat( playerID, -1, PlayerKickedChatStr, false );
		else
	   		OnChat( playerID, -1, PlayerDisconnectedChatStr, false );
		end
		UI.PlaySound("Play_MP_Player_Disconnect");
		BuildPlayerList();
	end
end

-------------------------------------------------
-------------------------------------------------
function OnChatPanelPlayerInfoChanged(playerID :number)
	PlayerTarget_OnPlayerInfoChanged( playerID, Controls.ChatPull, Controls.ChatEntry, m_chatTargetEntries, m_playerTarget, false);
	PlayerTarget_OnPlayerInfoChanged( playerID, Controls.ExpandedChatPull, Controls.ExpandedChatEntry, m_expandedChatTargetEntries, m_playerTarget, false);
	BuildPlayerList(); -- Player connection status might have changed.
end

-------------------------------------------------
-------------------------------------------------
function OnMultiplayerPingTimesChanged()
	for playerID, playerEntry in pairs( m_playerListEntries ) do
		UpdateNetConnectionIcon(playerID, playerEntry.ConnectionIcon);
	end
end

-------------------------------------------------
-------------------------------------------------
function OnMultiplayerSnapshotProcessed(playerID :number)
	if(ContextPtr:IsHidden() == false) then
		UpdatePlayerEntry(playerID);
	end
end

-------------------------------------------------
-- ShowHideHandler
-------------------------------------------------
function ShowHideHandler( bIsHide, bIsInit )
	if(not bIsHide) then 
		PopulateTargetPull(Controls.ChatPull, Controls.ChatEntry, m_chatTargetEntries, m_playerTarget, false, OnCollapsedChatPulldownChanged);
		PopulateTargetPull(Controls.ExpandedChatPull, Controls.ExpandedChatEntry, m_expandedChatTargetEntries, m_playerTarget, false, OnExpandedChatPulldownChanged);
		LuaEvents.ChatPanel_OnShown();
	end	
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

function OnCollapsedChatPulldownChanged(newTargetType :number, newTargetID :number, tooltipText:string)
	ChangeChatIcon(Controls.ChatIcon, newTargetType);
	local textControl:table = Controls.ChatPull:GetButton():GetTextControl();
	if tooltipText == nil then
		local text:string = textControl:GetText();
		Controls.ChatPull:SetToolTipString(text);
		OnExpandedChatPulldownChanged(newTargetType, newTargetID, text);
	else
		Controls.ChatPull:SetToolTipString(tooltipText);
	end
end
function OnExpandedChatPulldownChanged(newTargetType :number, newTargetID :number, tooltipText:string)
	ChangeChatIcon(Controls.ExpandedChatIcon, newTargetType);
	local textControl:table = Controls.ExpandedChatPull:GetButton():GetTextControl();
	if tooltipText == nil then
		local text:string = textControl:GetText();
		Controls.ExpandedChatPull:SetToolTipString(text);
		OnCollapsedChatPulldownChanged(newTargetType, newTargetID, text);
	else
		Controls.ExpandedChatPull:SetToolTipString(tooltipText);
	end
end

function ChangeChatIcon(iconControl:table, targetType:number)
	if(targetType == ChatTargetTypes.CHATTARGET_ALL) then
		iconControl:SetText("[ICON_Global]");
	elseif(targetType == ChatTargetTypes.CHATTARGET_TEAM) then
		iconControl:SetText("[ICON_Team]");
	else
		iconControl:SetText("[ICON_Whisper]");
	end
end

-------------------------------------------------
-------------------------------------------------
function InputHandler( pInputStruct)
	local uiMsg = pInputStruct:GetMessageType();
	if(uiMsg == KeyEvents.KeyUp) then
		local chatHasFocus:boolean = Controls.ChatEntry:HasFocus();
		local expandedChatHasFocus:boolean = Controls.ExpandedChatEntry:HasFocus();
		return chatHasFocus or expandedChatHasFocus;
	end
	return false;
end

function AdjustScreenSize()
	Controls.ShowPlayerListButton:SetSizeX(Controls.ShowPlayerListCheck:GetSizeX() + 20);
end

-------------------------------------------------
-------------------------------------------------
function OnUpdateUI( type )
	if( type == SystemUpdateUI.ScreenResize ) then
		AdjustScreenSize();
	end
end

-- ===========================================================================
function Initialize()
	BuildPlayerList();

	Events.SystemUpdateUI.Add( OnUpdateUI );
	-- When player info is changed, this pulldown needs to know so it can update itself if it becomes invalid.
	Events.PlayerInfoChanged.Add(OnChatPanelPlayerInfoChanged);
	Events.MultiplayerPlayerConnected.Add( OnMultplayerPlayerConnected );
	Events.MultiplayerPrePlayerDisconnected.Add( OnMultiplayerPrePlayerDisconnected );
	-- Update net connection icons whenever pings have changed.
	Events.MultiplayerPingTimesChanged.Add(OnMultiplayerPingTimesChanged);
	Events.MultiplayerSnapshotProcessed.Add(OnMultiplayerSnapshotProcessed);
	Events.MultiplayerChat.Add( OnMultiplayerChat );

	LuaEvents.MapPinPopup_SendPinToChat.Add(OnSendPinToChat);

	if ( m_isDebugging ) then
		for i=1,20,1 do
			Network.SendChat( "Test message #"..tostring(i), -1, -1 );
		end
	end	

	ChatPrintHelpHint(Controls.ChatEntryStack, m_ChatInstances, Controls.ChatLogPanel);
	ChatPrintHelpHint(Controls.ExpandedChatEntryStack, m_expandedChatInstances, Controls.ExpandedChatLogPanel);

	-- Keep both scroll panels in-sync
	Controls.ChatLogPanel:RegisterScrollCallback(function(control:table, percent:number)
		if Controls.ExpandedChatLogPanel:GetScrollValue() ~= percent then
			Controls.ExpandedChatLogPanel:SetScrollValue(percent);
		end
	end);
	Controls.ExpandedChatLogPanel:RegisterScrollCallback(function(control:table, percent:number)
		if Controls.ChatLogPanel:GetScrollValue() ~= percent then
			Controls.ChatLogPanel:SetScrollValue(percent);
		end
	end);

	-- Keep both edit boxes in-sync
	Controls.ChatEntry:RegisterStringChangedCallback(function()
		if Controls.ExpandedChatEntry:GetText() ~= Controls.ChatEntry:GetText() then
			Controls.ExpandedChatEntry:SetText(Controls.ChatEntry:GetText());
		end
	end);
	Controls.ExpandedChatEntry:RegisterStringChangedCallback(function()
		if Controls.ChatEntry:GetText() ~= Controls.ExpandedChatEntry:GetText() then
			Controls.ChatEntry:SetText(Controls.ExpandedChatEntry:GetText());
		end
	end);

	ContextPtr:SetInputHandler(InputHandler, true);
	AdjustScreenSize();
end
Initialize()
