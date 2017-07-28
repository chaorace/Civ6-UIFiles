-- ===========================================================================
-- Internet Lobby Screen
-- ===========================================================================
include( "InstanceManager" );	--InstanceManager
include("LobbyTypes");		--MPLobbyTypes
include("SteamUtilities");
include("ButtonUtilities");
include( "Civ6Common" ); -- AutoSizeGridButton


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID :string = "Lobby";


-- ===========================================================================
-- Globals
-- ===========================================================================

--[[ UINETTODO - Hook up game server game settings properties.		
-- Hard coded DLC packages to ignore.
local DlcGuidsToIgnore = {
 "{8871E748-29A4-4910-8C57-8C99E32D0167}",
};
--]]

-- Listing Box Buttons
local m_shellTabIM:table = InstanceManager:new("ShellTab", "TopControl", Controls.ShellTabs);
local g_FriendsIM = InstanceManager:new( "FriendInstance", "RootContainer", Controls.FriendsStack );
local g_GridLinesIM = InstanceManager:new( "HorizontalGridLine", "Control", Controls.GridContainer );
local g_InstanceManager = InstanceManager:new( "ListingButtonInstance", "Button", Controls.ListingStack );
local g_InstanceList = {};
local g_TabInstances = {};	-- indexed by browser mode ID

local LIST_LOBBIES				:number = 0;
local LIST_SERVERS				:number = 1;
local LIST_INVITES				:number = 2;

-- PlayByCloud Specific Browse Modes
local LIST_PUBLIC_GAMES			:number = 0;
local LIST_PERSONAL_GAMES		:number = 1;

local SEARCH_INTERNET			:number = 0;	-- Internet Servers/Lobbies
local SEARCH_LAN				:number = 1;	-- LAN Servers/Lobbies
local SEARCH_FRIENDS			:number = 2;
local SEARCH_FAVORITES			:number = 3;
local SEARCH_HISTORY			:number = 4;

local GAMELISTUPDATE_CLEAR		:number = 1;
local GAMELISTUPDATE_COMPLETE	:number = 2;
local GAMELISTUPDATE_ADD		:number = 3;
local GAMELISTUPDATE_UPDATE		:number = 4;
local GAMELISTUPDATE_REMOVE		:number = 5;
local GAMELISTUPDATE_ERROR		:number = 6;

local GRID_LINE_WIDTH			:number = 1020;
local GRID_LINE_HEIGHT			:number = 30;
local NUM_COLUMNS				:number = 6;
local FRIEND_HEIGHT				:number = 46;
local FRIENDS_BG_WIDTH			:number = 236;
local FRIENDS_BG_HEIGHT			:number = 342;
local FRIENDS_BG_PADDING		:number = 20;

-- GameListRoot Offset and Size (with and without shell tabs)
local GAME_LIST_OFFSET_Y		:number = 52;
local GAME_LIST_TABS_OFFSET_Y	:number = 82;
local GAME_LIST_SIZE_Y			:number = 723;
local GAME_LIST_TABS_SIZE_Y		:number = 693;	
local LIST_PANEL_SIZE_Y			:number = 628;
local LIST_PANEL_TABS_SIZE_Y	:number = 598;
local GAME_GRID_SIZE_Y			:number = 714;
local GAME_GRID_TABS_SIZE_Y		:number = 684;

local m_shouldShowFriends		:boolean = true;
local m_lobbyModeName			:string = MPLobbyTypes.STANDARD_INTERNET;
local m_browserMode				:number = LIST_PERSONAL_GAMES;-- Current PlayByCloud browser mode.

local m_steamFriendActions = 
{
	{ name ="LOC_FRIEND_ACTION_PROFILE",	tooltip = "LOC_FRIEND_ACTION_PROFILE_TT",	action = "profile" },
	{ name ="LOC_FRIEND_ACTION_CHAT",		tooltip = "LOC_FRIEND_ACTION_CHAT_TT",		action = "chat" },	
};

local ColorSet_Default			:string = "ServerText";
local ColorSet_Faded			:string = "ServerTextFaded";
local ColorSet_ModGreen			:string = "ModStatusGreenCS";
local ColorSet_ModYellow		:string = "ModStatusYellowCS";
local ColorSet_ModRed			:string = "ModStatusRedCS";
local ColorString_ModGreen		:string = "[color:ModStatusGreen]";
local ColorString_ModYellow		:string = "[color:ModStatusYellow]";
local ColorString_ModRed		:string = "[color:Civ6Red]";

local DEFAULT_RULE_SET:string = Locale.Lookup("LOC_MULTIPLAYER_STANDARD_GAME");
local DEFAULT_GAME_SPEED:string = Locale.Lookup("LOC_GAMESPEED_STANDARD_NAME");
local gameStartedTooltip:string = Locale.Lookup("LOC_LOBBY_GAME_STARTED_TOOLTIP");
local gameLoadingSaveTooltip:string = Locale.Lookup("LOC_LOBBY_GAME_LOADING_SAVE_TOOLTIP");
local gameYourTurnTooltip:string = Locale.Lookup("LOC_LOBBY_GAME_YOUR_TURN_TOOLTIP");
local playByCloudJoinsDisabled:string = "[color:Civ6Red]You can not join PlayByCloud games while in a debug build.[ENDCOLOR]";
local LOC_LOBBY_MY_GAMES		:string = Locale.Lookup("LOC_LOBBY_MY_GAMES");
local LOC_LOBBY_OPEN_GAMES		:string = Locale.Lookup("LOC_LOBBY_OPEN_GAMES");
													  
g_SelectedServerID = nil;
g_Listings = {};

-- Sort Option Data
-- Contains all possible buttons which alter the listings sort order.
g_SortOptions = {
	{
		Button = Controls.SortbyName,
		Column = "ServerName",
		DefaultDirection = "asc",
		CurrentDirection = "asc",
	},
	{
		Button = Controls.SortbyRuleSet,
		Column = "RuleSet",
		DefaultDirection = "asc",
		CurrentDirection = "asc",
	},
	{
		Button = Controls.SortbyMapName,
		Column = "MapName",
		DefaultDirection = "asc",
		CurrentDirection = nil,
	},
	{
		Button = Controls.SortbyGameSpeed,
		Column = "GameSpeed",
		DefaultDirection = "asc",
		CurrentDirection = nil,
	},
	{
		Button = Controls.SortbyPlayers,
		Column = "MembersSort",
		DefaultDirection = "desc",
		CurrentDirection = nil,
		SortType = "numeric",
	},
	{
		Button = Controls.SortbyModsHosted,
		Column = "DLCSort",
		DefaultDirection = "desc",
		CurrentDirection = nil,
		SortType = "numeric",
	},
};

g_SortFunction = nil;

-------------------------------------------------
-- Helper Functions
-------------------------------------------------
function IsUsingPlayByCloudGameList()
	if (m_lobbyModeName == MPLobbyTypes.PLAYBYCLOUD) then
		return true;
	end 
	return false;
end

function IsUsingInternetGameList()
	if (m_lobbyModeName == MPLobbyTypes.STANDARD_INTERNET 
		or m_lobbyModeName == MPLobbyTypes.PITBOSS_INTERNET
		or m_lobbyModeName == MPLobbyTypes.PITBOSS_LAN) then
		return true;
	else
		return false;
	end
end

function IsUsingPitbossGameList()
	if (m_lobbyModeName == MPLobbyTypes.PITBOSS_INTERNET
		or m_lobbyModeName == MPLobbyTypes.PITBOSS_LAN) then
		return true;
	else
		return false;
	end
end

function IsPlayByCloudJoinsDisabled()
	local joiningDisabled :boolean = IsUsingPlayByCloudGameList() and not UI.IsFinalRelease();
	return joiningDisabled;
end

function SetBrowserMode(browserMode :number)
	m_browserMode = browserMode;
	Matchmaking.SetBrowseMode(m_browserMode);
end

-------------------------------------------------
-- Server Listing Button Handler (Dynamic)
-------------------------------------------------
function ServerListingButtonClick()
	if ( g_InstanceList ~= nil ) then
		for i,v in ipairs( g_InstanceList ) do -- Iterating over the entire list solves some issues with stale information.
			v.Selected:SetHide( true );
		end
	end

	if(IsPlayByCloudJoinsDisabled()) then
		return;
	end

	if g_SelectedServerID and g_SelectedServerID >= 0 then
		local bSuccess, bPending = Network.JoinGame( g_SelectedServerID );
		if(not bSuccess) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_JOIN_FAILED" );
		end
	end
end


-------------------------------------------------
-- Host Game Button Handler
-------------------------------------------------
function OnHostButtonClick()
	LuaEvents.Lobby_RaiseHostGame();
end


-------------------------------------------------
function UpdateRefreshButton()
	if (Matchmaking.IsRefreshingGameList()) then
		Controls.RefreshButton:LocalizeAndSetText("LOC_MULTIPLAYER_STOP_REFRESH_GAME_LIST");
		Controls.RefreshButton:LocalizeAndSetToolTip("LOC_MULTIPLAYER_STOP_REFRESH_GAME_LIST_TT");
	else
		Controls.RefreshButton:LocalizeAndSetText("LOC_MULTIPLAYER_REFRESH_GAME_LIST");
		Controls.RefreshButton:LocalizeAndSetToolTip("LOC_MULTIPLAYER_REFRESH_GAME_LIST_TT");
	end
end

-------------------------------------------------
-- Refresh Game List Button Handler
-------------------------------------------------
function OnRefreshButtonClick()
	if (Matchmaking.IsRefreshingGameList()) then
		Matchmaking.StopRefreshingGameList();
	else
		Matchmaking.RefreshGameList();
	end	
	UpdateRefreshButton();
end

-------------------------------------------------
-- Friends Button Handler
-------------------------------------------------
function OnFriendsButtonClick()
	Controls.FriendsCheck:SetCheck(not Controls.FriendsCheck:IsChecked()); 
	OnFriendsListToggled();
end

-------------------------------------------------
-- Back Button Handler
-------------------------------------------------
function OnBackButtonClick()
	Close();
end


----------------------------------------------------------------        
-- Input Handler
----------------------------------------------------------------        
function OnInputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			Close();
		end
	end
	return true;
end						

-------------------------------------------------
-- Event Handler: MultiplayerGameListClear
-------------------------------------------------
function OnGameListClear()
	if(ContextPtr:IsVisible()) then
		g_SelectedServerID = nil;
		UpdateRefreshButton();
		UpdateGameList();
	end
end

-------------------------------------------------
-- Event Handler: MultiplayerGameListComplete
-------------------------------------------------
function OnGameListComplete()
	if(ContextPtr:IsVisible()) then
		UpdateRefreshButton();
	end
end



-------------------------------------------------
-- Event Handler: MultiplayerGameListUpdated
-------------------------------------------------
function OnGameListUpdated(eAction, idLobby, eLobbyType, eSearchType)
	if(ContextPtr:IsVisible()) then
		if (eAction == GAMELISTUPDATE_ADD) then
			local serverTable = Matchmaking.GetGameListEntry(idLobby);		
			if (serverTable ~= nil) then 
				AddServer( serverTable[1] );
				bUpdate = true;
			end
		else
			if (eAction == GAMELISTUPDATE_REMOVE) then
				RemoveServer( idLobby );
				if (g_SelectedServerID == idLobby) then
					g_SelectedServerID = nil;
				end
				bUpdate = true;
			end
		end

		if (bUpdate) then
			SortAndDisplayListings(true);
		end
	end
end

-------------------------------------------------
-- Event Handler: BeforeMultiplayerInviteProcessing
-------------------------------------------------
function OnBeforeMultiplayerInviteProcessing()
	-- We're about to process a game invite.  Get off the popup stack before we accidently break the invite!
	UIManager:DequeuePopup( ContextPtr );
end

-------------------------------------------------
-- Event Handler: ChangeMPLobbyMode
-------------------------------------------------
function OnChangeMPLobbyMode(newLobbyMode)
	print("OnChangeMPLobbyMode: " .. tostring(newLobbyMode));	--debug
	m_lobbyModeName = newLobbyMode;
end

-------------------------------------------------
-------------------------------------------------
function SelectGame( serverID )

	-- Reset the selection state of all the listings.
	if ( g_InstanceList ~= nil ) then
		for i,v in ipairs( g_InstanceList ) do -- Iterating over the entire list solves some issues with stale information.
			v.Selected:SetHide( true );
		end
	end

	local listItem = g_InstanceList[ serverID ];
	if ( serverID ~= nil and listItem ~= nil ) then
		Controls.JoinGameButton:SetDisabled(false);

		listItem.Selected:SetHide(false);
		listItem.Selected:SetToBeginning();
		listItem.Selected:Play();
	else
		Controls.JoinGameButton:SetDisabled(false);
		if listItem ~= nil then
			listItem.Selected:SetHide(true);
		end
	end

	if(IsPlayByCloudJoinsDisabled()) then
		Controls.JoinGameButton:SetDisabled(true);
		Controls.JoinGameButton:SetToolTipString(playByCloudJoinsDisabled);
	end
	
	Controls.BottomButtons:CalculateSize();
	Controls.BottomButtons:ReprocessAnchoring();

	g_SelectedServerID = serverID;
end

-------------------------------------------------
-------------------------------------------------
function AddServer(serverEntry)

	-- Check if server is already in the listings.
	for _,listServer in ipairs(g_Listings) do
		if(serverEntry.serverID == listServer.ServerID) then
			return;
		end
	end

	local rulesetName;
	
	-- Try to look up bundled text.
	if(serverEntry.RuleSetName) then
		rulesetName = Locale.Lookup(serverEntry.RuleSetName);
	end


	-- Fall-back to unknown.
	if(rulesetName == nil or #rulesetName == 0) then
		rulesetName = Locale.Lookup("LOC_MULTIPLAYER_UNKNOWN");
	end


	-- Try to look up bundled text.
	local gameSpeedName;
	if(serverEntry.GameSpeedName) then
		gameSpeedName = Locale.Lookup(serverEntry.GameSpeedName);
	end

	local mapName = Locale.Lookup(serverEntry.MapName);


	-- TODO: This needs to be modified to not reference GameInfo.
	-- GameInfo should only be used in-game.
	-- The map size name should instead be included as part of the server data.
	local mapSizeName = serverEntry.MapSizeName;
	if(mapSizeName == nil) then
		local mapSizeInfo = GameInfo.Maps[serverEntry.MapSize];
		if(mapSizeInfo) then
			mapSizeName = Locale.Lookup(mapSizeInfo.Name);
		end
	end

	if(mapSizeName == nil) then
		mapSizeName = Locale.Lookup("LOC_MULTIPLAYER_UNKNOWN_MAP_SIZE");
	end

	-- Fall-back to unknown.
	if(gameSpeedName == nil or #gameSpeedName == 0) then
		gameSpeedName = Locale.Lookup("LOC_MULTIPLAYER_UNKNOWN");
	end
	
	local listing = {
		Initialized = serverEntry.Initialized,
		ServerID = serverEntry.serverID,
		ServerName = serverEntry.serverName,
		MembersLabelCaption = serverEntry.numPlayers .. "/" .. serverEntry.maxPlayers,
		MembersLabelToolTip = ParseServerPlayers(serverEntry.Players),
		MembersSort = serverEntry.numPlayers,
		MapName = mapName,
		MapSize = serverEntry.MapSize,
		RuleSet = serverEntry.RuleSet,
		RuleSetName = rulesetName,
		GameSpeed = serverEntry.GameSpeed,
		GameSpeedName = gameSpeedName,
		EnabledMods = serverEntry.EnabledMods,
		MapSizeName = mapSizeName,
		GameStarted = serverEntry.GameStarted,
		SavedGame = serverEntry.SavedGame
	};

	if(m_lobbyModeName == MPLobbyTypes.PLAYBYCLOUD and m_browserMode == LIST_PERSONAL_GAMES) then
		listing.YourTurn = Network.CheckServerForYourTurn(listing.ServerID);
	end
				
	-- Don't add servers that have an invalid Initialized value.  
	-- Steam lobbies briefly don't have meta data between getting created and getting their meta data from the game host.
	if(listing.Initialized ~= nil and listing.Initialized ~= FireWireTypes.FIREWIRE_INVALID_ID) then
		table.insert(g_Listings, listing);
	end
end

-------------------------------------------------
-------------------------------------------------
function RemoveServer(serverID) 

	local index = nil;
	repeat
		index = nil;
		for i,v in ipairs(g_Listings) do
			if(v.ServerID == serverID) then
				index = i;
				break;
			end
		end
		if(index ~= nil) then
			table.remove(g_Listings, index);
		end
	until(index == nil);
	
end

function ParseServerPlayers(playerList)
	-- replace comma separation with new lines.
	parsedPlayers = string.gsub(playerList, ", ", "[NEWLINE]"); 
	-- remove the unique network id that is post-script to each player's name. Example : "razorace@5868795"
	return string.gsub(parsedPlayers, "@(.-)%[NEWLINE%]", "[NEWLINE]");
end

-------------------------------------------------
-------------------------------------------------
function UpdateGameList() 

	g_Listings = {};
	g_SelectedServerID = nil;
	Controls.JoinGameButton:SetDisabled(true);
	
	-- Get the Current Server List
	local serverTable = Matchmaking.GetGameList();
		
	-- Display Each Server
	if serverTable then
		for i,v in ipairs( serverTable ) do
			AddServer( v );
		end
	end
	--[[
	for i=1,100 do 
		AddServer({
			serverID = i,
			serverName = "Server Name " .. i,
			numPlayers = i,
			maxPlayers = i,
			Players = "",
			MembersSort = i,
			MapName = "Map Name " .. i,
			MapSize = "MAPSIZE_STANDARD",
			RuleSet = "Rule Set " .. i,
			GameSpeed = "Game Speed " .. i,
			EnabledMods = "Mods " .. i
		});
	end
	--]]
	
	SortAndDisplayListings(true);
	SetupGridLines(table.count(g_Listings));
end

-------------------------------------------------
-------------------------------------------------
function UpdateFriendsList()

	if ContextPtr:IsHidden() then return; end

	g_FriendsIM:ResetInstances();

	local friends : table;
	if (Steam ~= nil) then
		friends = GetSteamFriendsList(FlippedSteamFriendsSortFunction);
	else
		friends = {};
	end

	if table.count(friends) == 0 then
		Controls.Friends:SetHide(true);
		return;
	end
	Controls.Friends:SetHide(not m_shouldShowFriends);

	-- DEBUG
	--for i = 1, 9 do
	-- /DEBUG
	for _, friend in pairs(friends) do
		local instance:table = g_FriendsIM:GetInstance();
		PopulateFriendsInstance(instance, friend, m_steamFriendActions);
	end
	-- DEBUG
	--end
	-- /DEBUG

	Controls.FriendsStack:CalculateSize();
	Controls.FriendsStack:ReprocessAnchoring();
	Controls.FriendsScrollPanel:CalculateSize();
	Controls.FriendsScrollPanel:ReprocessAnchoring();
	Controls.FriendsScrollPanel:GetScrollBar():SetAndCall(0);

	if Controls.FriendsScrollPanel:GetScrollBar():IsHidden() then
		Controls.FriendsBackground:SetSizeVal(FRIENDS_BG_WIDTH, table.count(friends) * FRIEND_HEIGHT + FRIENDS_BG_PADDING);
	else
		Controls.FriendsBackground:SetSizeVal(FRIENDS_BG_WIDTH + 10, FRIENDS_BG_HEIGHT);
	end
end

-- ===========================================================================
function SortAndDisplayListings(resetSelection:boolean)

	table.sort(g_Listings, g_SortFunction);

	g_InstanceManager:ResetInstances();
	g_InstanceList = {};
	
	for _, listing in ipairs(g_Listings) do
		local controlTable = g_InstanceManager:GetInstance();
		local serverID = listing.ServerID;
		local textColor = ColorSet_Default;
		local rowTooltip = "";
		local gameName = listing.ServerName;
		g_InstanceList[serverID] = controlTable;

		-- Row color and tooltip is determined by game state.
		if(listing.SavedGame == 1) then
			textColor = ColorSet_Faded;
			rowTooltip = gameLoadingSaveTooltip;
		elseif(listing.GameStarted == 1) then
			textColor = ColorSet_Faded;
			rowTooltip = gameStartedTooltip;
		end

		-- PlayByCloud Only - If it is your turn in this game, provide some UI feedback.
		if(listing.YourTurn ~= nil and listing.YourTurn == true) then
			if(rowTooltip ~= "") then
				rowTooltip = rowTooltip .. "[NEWLINE][NEWLINE]";
			end
			rowTooltip = rowTooltip .. gameYourTurnTooltip;

			gameName = Locale.Lookup("LOC_LOBBY_GAME_NAME_YOUR_TURN", gameName);
		end
		
		if(IsPlayByCloudJoinsDisabled()) then
			if(rowTooltip ~= "") then
				rowTooltip = rowTooltip .. "[NEWLINE][NEWLINE]";
			end
			rowTooltip = rowTooltip .. playByCloudJoinsDisabled;
		end
		
		controlTable.ServerNameLabel:SetText(gameName);
		controlTable.ServerNameLabel:SetColorByName(textColor);
		controlTable.ServerNameLabel:SetToolTipString(rowTooltip);
		controlTable.MembersLabel:SetText( listing.MembersLabelCaption);
		controlTable.MembersLabel:SetToolTipString(listing.MembersLabelToolTip);
		controlTable.MembersLabel:SetColorByName(textColor);

		-- RuleSet Info
		if (listing.RuleSetName) then
			controlTable.RuleSetBoxLabel:SetText(listing.RuleSetName);
		else
			controlTable.RuleSetBoxLabel:LocalizeAndSetText("LOC_MULTIPLAYER_UNKNOWN");
		end
		controlTable.RuleSetBoxLabel:SetColorByName(textColor);
		controlTable.RuleSetBoxLabel:SetToolTipString(rowTooltip);
		
		-- Map Type info	
		controlTable.ServerMapTypeLabel:LocalizeAndSetText(listing.MapName);
		controlTable.ServerMapTypeLabel:LocalizeAndSetToolTip(listing.MapSizeName);
		controlTable.ServerMapTypeLabel:SetColorByName(textColor);
		controlTable.ServerMapTypeLabel:SetToolTipString(rowTooltip);

		-- Game Speed
		if (listing.GameSpeedName) then
			controlTable.GameSpeedLabel:SetText(listing.GameSpeedName);
		else
			controlTable.GameSpeedLabel:LocalizeAndSetText("LOC_MULTIPLAYER_UNKNOWN");
		end
		controlTable.GameSpeedLabel:SetColorByName(textColor);
		controlTable.GameSpeedLabel:SetToolTipString(rowTooltip);

		-- Mod Info
		local hasMods = listing.EnabledMods ~= nil;
		local hasOfficialMods = false;
		local hasCommunityMods = false;
		if(hasMods) then
			
			local needsDownload = false;
			local officialModNames = {};
			local communityModNames = {};
				
			local mods = Modding.GetModsFromConfigurationString(listing.EnabledMods);
			if(mods) then
				for i,v in ipairs(mods) do
					
					local modIcon:string = nil;

					-- Check if mod is installed
					if(Modding.GetModHandle(v.ModId)) then
						modIcon = Modding.IsJoinGameAllowed(v.ModId) and "[ICON_CheckSuccess]" or "[ICON_CheckFail]";
					-- Mod isn't installed but is downloadable from Steam.
					elseif(v.SubscriptionId and #v.SubscriptionId > 0) then
						needsDownload = true;
						modIcon = "[ICON_DownloadContent]";
					-- Mod isn't installed and is not downloadable from Steam.
					else
						modIcon = "[ICON_CheckFail]";
					end
					
					if(Modding.IsModOfficial(v.ModId)) then
						table.insert(officialModNames, {v.Name, modIcon});
					else
						table.insert(communityModNames, {v.Name, modIcon});
					end
				end
			end

			SortAndColorizeMods(officialModNames);
			SortAndColorizeMods(communityModNames);

			if #officialModNames > 0 then
				hasOfficialMods = true;
				local ToolTipPrefix = Locale.Lookup("LOC_MULTIPLAYER_LOBBY_MODS_OFFICIAL") .. "[NEWLINE][NEWLINE]";
				controlTable.ModsOfficial:SetToolTipString(ToolTipPrefix .. table.concat(officialModNames, "[NEWLINE]"));
				controlTable.ModsOfficial:SetTexture(needsDownload and "OfficialContent_MissingIcon" or "OfficialContent_Owned");
			end

			if #communityModNames > 0 then
				hasCommunityMods = true;
				local ToolTipPrefix = Locale.Lookup("LOC_MULTIPLAYER_LOBBY_MODS_COMMUNITY") .. "[NEWLINE][NEWLINE]";
				controlTable.ModsCommunity:SetToolTipString(ToolTipPrefix .. table.concat(communityModNames, "[NEWLINE]"));
				controlTable.ModsCommunity:SetTexture(needsDownload and "CommunityContent_Missing" or "CommunityContent_Owned");
			end
		end

		controlTable.ModsOfficial:SetHide(not hasOfficialMods);
		controlTable.ModsCommunity:SetHide(not hasCommunityMods);

		-- Enable the Button's Event Handler
		local selectAndJoinGame:ifunction = function() g_SelectedServerID = serverID; ServerListingButtonClick(); end
		controlTable.Button:SetVoid1( serverID ); -- List ID
		controlTable.Button:RegisterCallback( Mouse.eLClick, SelectGame );
		controlTable.Button:RegisterCallback( Mouse.eLDblClick, selectAndJoinGame );

		if resetSelection then
			controlTable.Selected:SetHide( true );
		end
	end
	
	Controls.ListingScrollPanel:CalculateInternalSize();

	local listWidth:number = Controls.ListingScrollPanel:GetScrollBar():IsHidden() and 1024 or 1004;
	Controls.ListingScrollPanel:SetSizeX(listWidth);

	-- Adjust horizontal grid lines
	listWidth = listWidth - 5;
	for _, instance in ipairs(g_GridLinesIM.m_AllocatedInstances) do
		instance.Control:SetEndX(listWidth);
	end

	-- Adjust vertical grid lines
	Controls.ListingStack:CalculateSize();
	Controls.ListingStack:ReprocessAnchoring();
	local gridLineHeight:number = math.max(Controls.ListingStack:GetSizeY(), Controls.ListingScrollPanel:GetSizeY());
	for i = 1, NUM_COLUMNS do
		Controls["GridLine_" .. i]:SetEndY(gridLineHeight);
	end
	
	Controls.GridContainer:SetSizeY(gridLineHeight);
end

function SortAndColorizeMods(modNames)
	if #modNames > 0 then
		-- Sort mods.
		table.sort(modNames, function(a,b) return Locale.Compare(a[1], b[1]) == -1; end);

		-- Colorize.
		for i,v in ipairs(modNames) do
			if(v[2]) then
				modNames[i] = v[2] .. " " .. v[1];
			else
				modNames[i] = v[1];
			end
		end
	end
end

-- ===========================================================================
--	Leave the Lobby
-- ===========================================================================
function Close()
	Network.LeaveGame();
	UIManager:DequeuePopup( ContextPtr );
	
	-- Reset the selection state of all the listings.
	if ( g_InstanceList ~= nil ) then
		for i,v in ipairs( g_InstanceList ) do -- Iterating over the entire list solves some issues with stale information.
			v.Selected:SetHide( true );
		end
	end
end


-------------------------------------------------
-------------------------------------------------
function AdjustScreenSize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	local hideLogo = true;
	if(screenY >= Controls.MainWindow:GetSizeY() + Controls.LogoContainer:GetSizeY()+ Controls.LogoContainer:GetOffsetY()) then
		hideLogo = false;
	end
	Controls.LogoContainer:SetHide(hideLogo);
	Controls.MainGrid:ReprocessAnchoring();

	Controls.ListingScrollPanel:CalculateInternalSize();
	Controls.FriendsButton:SetSizeX(Controls.FriendsCheck:GetSizeX() + 20);
end


-------------------------------------------------
-------------------------------------------------
function OnUpdateUI( type )
	if( type == SystemUpdateUI.ScreenResize ) then
		AdjustScreenSize();
	end
end

-------------------------------------------------
-- Event Handler: MultiplayerGameLaunched
-------------------------------------------------
function OnGameLaunched()
	--UIManager:DequeuePopup( ContextPtr );
end


-------------------------------------------------
-- Event Handler: Load Game Button Handler
-------------------------------------------------
function OnLoadButtonClick()
	local serverType = ServerTypeForMPLobbyType(m_lobbyModeName);
	local gameMode = GameModeTypeForMPLobbyType(m_lobbyModeName);
	-- Load game screen needs valid ServerType and GameMode.
	LuaEvents.HostGame_SetLoadGameServerType(serverType);
	GameConfiguration.SetToDefaults(gameMode);
	UIManager:QueuePopup(Controls.LoadGameMenu, PopupPriority.Current);	
	--LuaEvents.Lobby_ShowLoadScreen();
end

function OnJoinCodeCommit(joinCodeString)
	if(IsJoiningDisabled()) then
		UI.DataError("PlayByCloud joining is disabled.");
		return;
	end

	if(joinCodeString ~= nil and joinCodeString ~= "") then
		local bSuccess, bPending = Network.JoinGameByJoinCode(joinCodeString);
		if(not bSuccess) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_JOIN_FAILED" );
		end
	end
end

-- ===========================================================================
-- Sorting Support
-- ===========================================================================
function AlphabeticalSortFunction(field, direction, secondarySort)
	if(direction == "asc") then
		return function(a,b)
			print("Sorting " .. field);
			local va = (a ~= nil and a[field] ~= nil) and a[field] or "";
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or "";
			
			if(secondarySort ~= nil and va == vb) then
				return secondarySort(a,b);
			else
				return Locale.Compare(va, vb) == -1;
			end
		end
	elseif(direction == "desc") then
		return function(a,b)
			print("Sorting " .. field);
			local va = (a ~= nil and a[field] ~= nil) and a[field] or "";
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or "";
			
			if(secondarySort ~= nil and va == vb) then
				return secondarySort(a,b);
			else
				return Locale.Compare(va, vb) == 1;
			end
		end
	end
end

-- ===========================================================================
function NumericSortFunction(field, direction, secondarySort)
	if(direction == "asc") then
		return function(a,b)
			print("Sorting " .. field);
			local va = (a ~= nil and a[field] ~= nil) and a[field] or -1;
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or -1;
			
			if(secondarySort ~= nil and tonumber(va) == tonumber(vb)) then
				return secondarySort(a,b);
			else
				return tonumber(va) < tonumber(vb);
			end
		end
	elseif(direction == "desc") then
		return function(a,b)
			print("Sorting " .. field);
			local va = (a ~= nil and a[field] ~= nil) and a[field] or -1;
			local vb = (b ~= nil and b[field] ~= nil) and b[field] or -1;

			if(secondarySort ~= nil and tonumber(va) == tonumber(vb)) then
				return secondarySort(a,b);
			else
				return tonumber(vb) < tonumber(va);
			end
		end
	end
end

-- ===========================================================================
function GetSortFunction(sortOptions)
	local orderBy = nil;
	for i,v in ipairs(sortOptions) do
		if(v.CurrentDirection ~= nil) then
			local secondarySort = nil;
			if(v.SecondaryColumn ~= nil) then
				if(v.SecondarySortType == "numeric") then
					secondarySort = NumericSortFunction(v.SecondaryColumn, v.SecondaryDirection)
				else
					secondarySort = AlphabeticalSortFunction(v.SecondaryColumn, v.SecondaryDirection);
				end
			end
		
			if(v.SortType == "numeric") then
				return NumericSortFunction(v.Column, v.CurrentDirection, secondarySort);
			else
				return AlphabeticalSortFunction(v.Column, v.CurrentDirection, secondarySort);
			end
		end
	end
	
	return nil;
end

-- Updates the sort option structure
function UpdateSortOptionState(sortOptions, selectedOption)
	-- Current behavior is to only have 1 sort option enabled at a time 
	-- though the rest of the structure is built to support multiple in the future.
	-- If a sort option was selected that wasn't already selected, use the default 
	-- direction.  Otherwise, toggle to the other direction.
	for i,v in ipairs(sortOptions) do
		if(v == selectedOption) then
			if(v.CurrentDirection == nil) then			
				v.CurrentDirection = v.DefaultDirection;
			else
				if(v.CurrentDirection == "asc") then
					v.CurrentDirection = "desc";
				else
					v.CurrentDirection = "asc";
				end
			end
		else
			v.CurrentDirection = nil;
		end
	end
end

-- ===========================================================================
-- Registers the sort option controls click events
-- ===========================================================================
function RegisterSortOptions()
	for i,v in ipairs(g_SortOptions) do
		if(v.Button ~= nil) then
			v.Button:RegisterCallback(Mouse.eLClick, function() SortOptionSelected(v); end);
		end
	end

	g_SortFunction = GetSortFunction(g_SortOptions);
end

-- ===========================================================================
-- Callback for when sort options are selected.
-- ===========================================================================
function SortOptionSelected(option)
	local sortOptions = g_SortOptions;
	UpdateSortOptionState(sortOptions, option);
	g_SortFunction = GetSortFunction(sortOptions);
	
	SortAndDisplayListings(false);
end

-- ===========================================================================
function SetupGridLines(numServers:number)
	local nextY:number = GRID_LINE_HEIGHT;
	local gridSize:number = Controls.GridContainer:GetSizeY();
	local numLines:number = math.max(numServers, gridSize / GRID_LINE_HEIGHT);
	g_GridLinesIM:ResetInstances();
	for i:number = 1, numLines do
		g_GridLinesIM:GetInstance().Control:SetOffsetY(nextY);
		nextY = nextY + GRID_LINE_HEIGHT;
	end
end

-- ===========================================================================
function OnShow()
	-- You should not be in a network session when showing the lobby screen because the lobby screen
	-- reconfigures the network system's lobby object.  This will corrupt your network lobby object.
	if Network.IsInSession() then
		UI.DataError("Showing lobby but currently in a game.  This could corrupt your lobby.  @assign bolson");
	end
	
	-- Initialize network lobby for lobby mode.
	Matchmaking.InitLobby(LobbyTypeForMPLobbyType(m_lobbyModeName));

	-- Set default game list filter.
	-- PLAYBYCLOUD uses Matchmaking.SetBrowseMode().
	-- Steam Lobby (Internet) uses Matchmaking.SetGameListType().
	if (m_lobbyModeName == MPLobbyTypes.PLAYBYCLOUD) then
		SetBrowserMode(LIST_PERSONAL_GAMES);
	elseif (m_lobbyModeName == MPLobbyTypes.PITBOSS_INTERNET) then
		Matchmaking.SetGameListType( LIST_SERVERS, SEARCH_INTERNET );
	elseif (m_lobbyModeName == MPLobbyTypes.PITBOSS_LAN) then 
		Matchmaking.SetGameListType( LIST_SERVERS, SEARCH_LAN );
	else
		Matchmaking.SetGameListType( LIST_LOBBIES, SEARCH_INTERNET );
	end

	RealizeShellTabs();

	UpdateGameList();
	Matchmaking.RefreshGameList();
	UpdateRefreshButton();
		
	if IsUsingPlayByCloudGameList() then
		Controls.TitleLabel:LocalizeAndSetText("LOC_MULTIPLAYER_CLOUD_LOBBY");
	elseif IsUsingPitbossGameList() then
		Controls.TitleLabel:LocalizeAndSetText("LOC_MULTIPLAYER_PITBOSS_LOBBY");
	elseif IsUsingInternetGameList() then
		Controls.TitleLabel:LocalizeAndSetText("LOC_MULTIPLAYER_INTERNET_LOBBY");
	else
		Controls.TitleLabel:LocalizeAndSetText("LOC_MULTIPLAYER_LAN_LOBBY");
	end

	UpdateFriendsList();

	if (Steam ~= nil) then
		Steam.SetRichPresence("civPresence", "LOC_PRESENCE_IN_SHELL");
	end
end

-- ===========================================================================
function OnHide()
	g_InstanceManager:ResetInstances();
	g_InstanceList = {};
	g_Listings = {};
end


-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues( RELOAD_CACHE_ID );
	end
end

-- ===========================================================================
function OnShutdown()
	-- Cache values for hotloading...
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden());
end

-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	if context == RELOAD_CACHE_ID and contextTable["isHidden"] == false then
		UIManager:QueuePopup( ContextPtr, PopupPriority.Current );
	end	
end

function OnFriendsListToggled()
	m_shouldShowFriends = Controls.FriendsCheck:IsChecked();
	Controls.Friends:SetHide(not m_shouldShowFriends);
	UpdateFriendsList();
end

function OnBrowserModeClicked(browserMode :number)
	SetBrowserMode(browserMode); 

	-- Updated selected state
	FilterTabsSetSelected(g_TabInstances[browserMode]);

	Matchmaking.RefreshGameList();
	UpdateRefreshButton();
end

function FilterTabsSetSelected(shellTabControl :table)
	for i,v in ipairs( g_TabInstances ) do
		local isSelected = shellTabControl == v;
		v.Selected:SetHide(not isSelected);
	end
end

function AddShellTab(browserModeType :number, locText :string)
	local newTab:table = m_shellTabIM:GetInstance();
	newTab.Button:SetText(locText);
	newTab.SelectedButton:SetText(locText);
	newTab.Button:SetVoid1(browserModeType);
	newTab.Button:RegisterCallback( Mouse.eLClick, OnBrowserModeClicked );

	AutoSizeGridButton(newTab.Button,250,32,10,"H");
	AutoSizeGridButton(newTab.SelectedButton,250,32,20,"H");
	newTab.TopControl:SetSizeX(newTab.Button:GetSizeX());
	g_TabInstances[browserModeType] = newTab;
end

function RealizeShellTabs()
	m_shellTabIM:ResetInstances();
	g_TabInstances = {};

	if(IsUsingPlayByCloudGameList()) then
		Controls.JoinCodeRoot:SetHide(false);
		
		Controls.GameListRoot:SetOffsetY(GAME_LIST_TABS_OFFSET_Y);
		Controls.GameListRoot:SetSizeY(GAME_LIST_TABS_SIZE_Y);
		Controls.ListingScrollPanel:SetSizeY(LIST_PANEL_TABS_SIZE_Y);
		Controls.GameListGrid:SetSizeY(GAME_GRID_TABS_SIZE_Y);

		AddShellTab(LIST_PERSONAL_GAMES, LOC_LOBBY_MY_GAMES);
		AddShellTab(LIST_PUBLIC_GAMES, LOC_LOBBY_OPEN_GAMES);

		-- Set the current browser mode tab as selected.
		FilterTabsSetSelected(g_TabInstances[m_browserMode]); 
	else
		Controls.JoinCodeRoot:SetHide(true);

		Controls.GameListRoot:SetOffsetY(GAME_LIST_OFFSET_Y);
		Controls.GameListRoot:SetSizeY(GAME_LIST_SIZE_Y);
		Controls.ListingScrollPanel:SetSizeY(LIST_PANEL_SIZE_Y);
		Controls.GameListGrid:SetSizeY(GAME_GRID_TABS_SIZE_Y);
	end

	Controls.ShellTabs:CalculateSize();
	Controls.ShellTabs:ReprocessAnchoring();
end

-- ===========================================================================
--	Initialize screen
-- ===========================================================================
function Initialize()
	
	-- Setup initial grid lines, grid is refreshed anytime servers are updated
	SetupGridLines(0);

	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	ContextPtr:SetInputHandler(OnInputHandler);
	ContextPtr:SetShowHandler(OnShow);
	ContextPtr:SetHideHandler(OnHide);

	Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBackButtonClick );
	Controls.HostButton:RegisterCallback( Mouse.eLClick, OnHostButtonClick );
	Controls.JoinGameButton:RegisterCallback( Mouse.eLClick, ServerListingButtonClick );		-- set up join game callback
	Controls.LoadGameButton:RegisterCallback( Mouse.eLClick, OnLoadButtonClick );
	Controls.RefreshButton:RegisterCallback( Mouse.eLClick, OnRefreshButtonClick );
	Controls.FriendsButton:RegisterCallback( Mouse.eLClick, OnFriendsButtonClick );
	Controls.FriendsCheck:RegisterCheckHandler( OnFriendsListToggled );
	Controls.JoinCodeEditBox:RegisterCommitCallback( OnJoinCodeCommit );
	
	Events.SteamFriendsStatusUpdated.Add( UpdateFriendsList );
	Events.SteamFriendsPresenceUpdated.Add( UpdateFriendsList );
	Events.MultiplayerGameLaunched.Add( OnGameLaunched );
	Events.MultiplayerGameListClear.Add( OnGameListClear );
	Events.MultiplayerGameListComplete.Add( OnGameListComplete );
	Events.MultiplayerGameListUpdated.Add( OnGameListUpdated );
	Events.BeforeMultiplayerInviteProcessing.Add( OnBeforeMultiplayerInviteProcessing );
	Events.SystemUpdateUI.Add( OnUpdateUI );
	
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	LuaEvents.ChangeMPLobbyMode.Add( OnChangeMPLobbyMode );
	
	ResizeButtonToText(Controls.RefreshButton);
	ResizeButtonToText(Controls.BackButton);
	RegisterSortOptions();
	AdjustScreenSize();
end
Initialize();

