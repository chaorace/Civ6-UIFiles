-- ===========================================================================
--	World Builder Player Editor
-- ===========================================================================

include("InstanceManager");
include("SupportFunctions");
include("TabSupport");

-- ===========================================================================
--	DATA MEMBERS
-- ===========================================================================

local DATA_FIELD_SELECTION						:string = "Selection";

local m_SelectedPlayer = nil;
local m_PlayerEntries      : table = {};
local m_PlayerIndexToEntry : table = {};
local m_CivEntries         : table = {};
local m_LeaderEntries      : table = {};
local m_EraEntries         : table = {};
local m_TechEntries        : table = {};
local m_CivicEntries       : table = {};
local m_CivLevelEntries	   : table = {};
local m_ViewingTab		   : table = {};
local m_tabs				:table;

local m_groupIM				:table = InstanceManager:new("GroupInstance",			"Top",		Controls.Stack);				-- Collapsable
local m_simpleIM			:table = InstanceManager:new("SimpleInstance",			"Top",		Controls.Stack);				-- Non-Collapsable, simple
local m_tabIM			   : table = InstanceManager:new("TabInstance",				"Button",	Controls.TabContainer);

local m_uiGroups			:table = nil;	-- Track the groups on-screen for collapse all action.

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
--
-- ===========================================================================
function AddTabSection( name:string, populateCallback:ifunction )
	local kTab		:table				= m_tabIM:GetInstance();	
	kTab.Button[DATA_FIELD_SELECTION]	= kTab.Selection;

	local callback	:ifunction	= function()
		if m_tabs.prevSelectedControl ~= nil then
			m_tabs.prevSelectedControl[DATA_FIELD_SELECTION]:SetHide(true);
		end
		kTab.Selection:SetHide(false);
		populateCallback();
	end

	kTab.Button:GetTextControl():SetText( Locale.Lookup(name) );
	kTab.Button:SetSizeToText( 40, 20 );
    kTab.Button:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	m_tabs.AddTab( kTab.Button, callback );
end

-- ===========================================================================
--	Instantiate a new collapsable row (group) holder & wire it up.
--	ARGS:	(optional) isCollapsed
--	RETURNS: New group instance
-- ===========================================================================
function NewCollapsibleGroupInstance( isCollapsed:boolean )
	if isCollapsed == nil then
		isCollapsed = false;
	end
	local instance:table = m_groupIM:GetInstance();	
	instance.ContentStack:DestroyAllChildren();
	instance["isCollapsed"]		= isCollapsed;
	instance["CollapsePadding"] = nil;				-- reset any prior collapse padding

	instance.CollapseAnim:SetToBeginning();
	if isCollapsed == false then
		instance.CollapseAnim:SetToEnd();
	end	

	instance.RowHeaderButton:RegisterCallback( Mouse.eLClick, function() OnToggleCollapseGroup(instance); end );			
  	instance.RowHeaderButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	instance.CollapseAnim:RegisterAnimCallback(               function() OnAnimGroupCollapse( instance ); end );

	table.insert( m_uiGroups, instance );

	return instance;
end

-- ===========================================================================
--	Set a group to it's proper collapse/open state
--	Set + - in group row
-- ===========================================================================
function RealizeGroup( instance:table )
	local v :number = (instance["isCollapsed"]==false and instance.RowExpandCheck:GetSizeY() or 0);
	instance.RowExpandCheck:SetTextureOffsetVal(0, v);

	instance.ContentStack:CalculateSize();	
	instance.CollapseScroll:CalculateSize();
	
	local groupHeight	:number = instance.ContentStack:GetSizeY();
	instance.CollapseAnim:SetBeginVal(0, -(groupHeight - instance["CollapsePadding"]));
	instance.CollapseScroll:SetSizeY( groupHeight );				

	instance.Top:ReprocessAnchoring();
end

-- ===========================================================================
--	Callback
--	Expand or contract a group based on its existing state.
-- ===========================================================================
function OnToggleCollapseGroup( instance:table )
	instance["isCollapsed"] = not instance["isCollapsed"];
	instance.CollapseAnim:Reverse();
	RealizeGroup( instance );
end

-- ===========================================================================
--	Toggle a group expanding / collapsing
--	instance,	A group instance.
-- ===========================================================================
function OnAnimGroupCollapse( instance:table)
		-- Helper
	function lerp(y1:number,y2:number,x:number)
		return y1 + (y2-y1)*x;
	end
	local groupHeight	:number = instance.ContentStack:GetSizeY();
	local collapseHeight:number = instance["CollapsePadding"]~=nil and instance["CollapsePadding"] or 0;
	local startY		:number = instance["isCollapsed"]==true  and groupHeight or collapseHeight;
	local endY			:number = instance["isCollapsed"]==false and groupHeight or collapseHeight;
	local progress		:number = instance.CollapseAnim:GetProgress();
	local sizeY			:number = lerp(startY,endY,progress);

	instance.CollapseAnim:SetSizeY( groupHeight );		
	instance.CollapseScroll:SetSizeY( sizeY );	
	instance.ContentStack:ReprocessAnchoring();	
	instance.Top:ReprocessAnchoring()

	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();			
end


-- ===========================================================================
function SetGroupCollapsePadding( instance:table, amount:number )
	instance["CollapsePadding"] = amount;
end

-- ===========================================================================
function ResetTabForNewPageContent()
	m_uiGroups = {};
	m_ViewingTab = {};
	m_groupIM:ResetInstances();
	m_simpleIM:ResetInstances();
	Controls.Scroll:SetScrollValue( 0 );	
end

-- ===========================================================================
--	Get the index if the CivEntry that matches the civ type.
--  This can also be one of the special keys, such as RANDOM or UNDEFINED
-- ===========================================================================
function GetCivEntryIndexByType(civType)
	for i, civEntry in ipairs(m_CivEntries) do
		if civEntry ~= nil and civEntry.Type == civType then
			return i;
		end
	end

	return 0;
end

-- ===========================================================================
--	Set the default leader for our indexed civ list from a game info entry
-- ===========================================================================
function SetCivDefaultLeader(civLeaderEntry)
	for _, civEntry in ipairs(m_CivEntries) do
		if civEntry ~= nil and civEntry.Type == civLeaderEntry.CivilizationType then
			civEntry.DefaultLeader = civLeaderEntry.LeaderType;
		end
	end
end

-- ===========================================================================
--	Get the index if the LeaderEntry that matches the leader type.
--  This can also be one of the special keys, such as RANDOM or UNDEFINED
-- ===========================================================================
function GetLeaderEntryIndexByType(leaderType)
	for i, leaderEntry in ipairs(m_LeaderEntries) do
		if leaderEntry ~= nil and leaderEntry.Type == leaderType then
			return i;
		end
	end

	return 0;
end

-- ===========================================================================
--	Get the index if the CivLevelEntry that matches the level type.
-- ===========================================================================
function GetCivLevelEntryIndexByType(civLevelType)
	for i, civLevelEntry in ipairs(m_CivLevelEntries) do
		if civLevelEntry ~= nil and civLevelEntry.Type == civLevelType then
			return i;
		end
	end

	return 0;
end

-- ===========================================================================
function UpdateTechTabValues()

	if m_SelectedPlayer ~= nil then

		if (m_ViewingTab.TechInstance ~= nil and m_ViewingTab.TechInstance.TechList ~= nil) then
			for i,techEntry in ipairs(m_TechEntries) do
				local hasTech = WorldBuilder.PlayerManager():PlayerHasTech( m_SelectedPlayer.Index, techEntry.Type.Index );
				m_ViewingTab.TechInstance.TechList:SetEntrySelected( techEntry, hasTech, false );
			end
		end
	end

end

-- ===========================================================================
function UpdateCivicsTabValues()

	if m_SelectedPlayer ~= nil then

		if (m_ViewingTab.CivicsInstance ~= nil and m_ViewingTab.CivicsInstance.CivicsList) then
			for i,civicEntry in ipairs(m_CivicEntries) do
				local hasCivic = WorldBuilder.PlayerManager():PlayerHasCivic( m_SelectedPlayer.Index, civicEntry.Type.Index );
				m_ViewingTab.CivicsInstance.CivicsList:SetEntrySelected( civicEntry, hasCivic, false );
			end
		end
	end

end

-- ===========================================================================
--	Handler for when a player is selected.
-- ===========================================================================
function OnPlayerSelected(entry)

	m_SelectedPlayer = entry;
	local playerSelected = entry ~= nil;

	if playerSelected then

		Controls.CivPullDown:SetSelectedIndex( GetCivEntryIndexByType( entry.Civ ), false );
		Controls.LeaderPullDown:SetSelectedIndex( GetLeaderEntryIndexByType( entry.Leader ), false );
		Controls.CivLevelPullDown:SetSelectedIndex( GetCivLevelEntryIndexByType( entry.CivLevel ), false );
		Controls.EraPullDown:SetSelectedIndex( entry.Era+1, false );

		local goldText = Controls.GoldEdit:GetText();
		if goldText == nil or tonumber(goldText) ~= entry.Gold then
			Controls.GoldEdit:SetText( entry.Gold );
		end

		local faithText = Controls.FaithEdit:GetText();
		if faithText == nil or tonumber(faithText) ~= entry.Faith then
			Controls.FaithEdit:SetText( entry.Faith );
		end

		if (m_ViewingTab.Name ~= nil) then

			UpdateTechTabValues();
			UpdateCivicsTabValues();

			if (m_ViewingTab.Name == "Cities") then
				ViewPlayerCitiesPage();				
			end

		end

	end

	Controls.CivPullDown:SetDisabled( not playerSelected );
	Controls.EraPullDown:SetDisabled( not playerSelected );
	Controls.GoldEdit:SetDisabled( not playerSelected );
	Controls.FaithEdit:SetDisabled( not playerSelected );
	if (m_ViewingTab.TechInstance ~= nil and m_ViewingTab.TechInstance.TechList ~= nil) then
		m_ViewingTab.TechInstance.TechList:SetDisabled( not playerSelected );
	end
	if (m_ViewingTab.CivicsInstance ~= nil and m_ViewingTab.CivicsInstance.CivicsList ~= nil) then
		m_ViewingTab.CivicsInstance.CivicsList:SetDisabled( not playerSelected );
	end
	Controls.LeaderPullDown:SetDisabled( entry == nil or not entry.IsFullCiv or entry.Civ == -1 );
end

-- ===========================================================================
function UpdatePlayerEntry(playerEntry)

	local playerConfig = WorldBuilder.PlayerManager():GetPlayerConfig(playerEntry.Index);

	playerEntry.Config = playerConfig;
	playerEntry.Leader = playerConfig.Leader ~= nil and playerConfig.Leader or "UNDEFINED";
	playerEntry.Civ    = playerConfig.Civ ~= nil and playerConfig.Civ or "UNDEFINED";
	playerEntry.CivLevel = playerConfig.CivLevel ~= nil and playerConfig.CivLevel or "UNDEFINED";
	playerEntry.Era    = GameInfo.Eras[ playerConfig.Era ] ~= nil and GameInfo.Eras[ playerConfig.Era ].Index or 0;
	playerEntry.Text   = string.format("%s - %s", playerConfig.IsHuman and "Human" or "AI", Locale.Lookup(playerConfig.Name));
	playerEntry.Gold   = playerConfig.Gold;
	playerEntry.Faith  = playerConfig.Faith;
	playerEntry.IsFullCiv = playerConfig.IsFullCiv;
	
	if playerEntry.Button ~= nil then
		playerEntry.Button:SetText(playerEntry.Text);
	end

	if playerEntry == m_SelectedPlayer then
		OnPlayerSelected(m_SelectedPlayer);
	end
end

-- ===========================================================================
function UpdatePlayerList()

	m_PlayerEntries = {};
	m_PlayerIndexToEntry = {};

	local selected = 1;
	local entryCount = 0;

	for i = 0, GameDefines.MAX_PLAYERS-2 do -- Use MAX_PLAYERS-2 to ignore the barbarian player

		local eStatus = WorldBuilder.PlayerManager():GetSlotStatus(i); 
		if eStatus ~= SlotStatus.SS_CLOSED then
			local playerEntry = {};
			playerEntry.Index = i;
			UpdatePlayerEntry(playerEntry);
			table.insert(m_PlayerEntries, playerEntry);
			m_PlayerIndexToEntry[i] = playerEntry;
			entryCount = entryCount + 1;

			if m_SelectedPlayer ~= nil and m_SelectedPlayer.Index == playerEntry.Index then
				selected = entryCount;
			end
		end
	end

	if entryCount == 0 then
		selected = 0;
	end

	Controls.PlayerList:SetEntries( m_PlayerEntries, selected );
	OnPlayerSelected( Controls.PlayerList:GetSelectedEntry() );
end

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewPlayerTechsPage()	

	ResetTabForNewPageContent();

	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();
	
	m_ViewingTab.Name = "Techs";
	m_ViewingTab.TechInstance = {};
	ContextPtr:BuildInstanceForControl( "PlayerTechsInstance", m_ViewingTab.TechInstance, instance.Top ) ;	
	
	m_ViewingTab.TechInstance.TechList:SetEntries( m_TechEntries );
	m_ViewingTab.TechInstance.TechList:SetEntrySelectedCallback( OnTechSelected );
	UpdateTechTabValues();

	Controls.Scroll:CalculateSize();
	Controls.Stack:CalculateSize();

	local xOffset, yOffset = Controls.Scroll:GetParentRelativeOffset();
	Controls.Scroll:SetSizeY( Controls.TabsContainer:GetSizeY() - yOffset );

end

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewPlayerCivicsPage()	

	ResetTabForNewPageContent();

	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();
	
	m_ViewingTab.Name = "Civics";
	m_ViewingTab.CivicsInstance = {};
	ContextPtr:BuildInstanceForControl( "PlayerCivicsInstance", m_ViewingTab.CivicsInstance, instance.Top ) ;	
	
	m_ViewingTab.CivicsInstance.CivicsList:SetEntries( m_CivicEntries );
	m_ViewingTab.CivicsInstance.CivicsList:SetEntrySelectedCallback( OnCivicSelected );
	UpdateCivicsTabValues();

	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();

	local xOffset, yOffset = Controls.Scroll:GetParentRelativeOffset();
	Controls.Scroll:SetSizeY( Controls.TabsContainer:GetSizeY() - yOffset );
end

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewPlayerCitiesPage()	

	ResetTabForNewPageContent();

	if (m_SelectedPlayer ~= nil) then
	
		m_ViewingTab.Name = "Cities";

		local pPlayer = Players[m_SelectedPlayer.Index];

		local pPlayerCities = pPlayer:GetCities();

		for iCity, pCity in pPlayerCities:Members() do
			-- City

			local instance:table = NewCollapsibleGroupInstance();	
			instance.RowHeaderButton:LocalizeAndSetText( pCity:GetName() );
			instance.Top:SetID("City");

			local pCityBldgs = pCity:GetBuildings();

			-- District
			local pCityDistricts = pCity:GetDistricts();
			for iDistrict, pDistrict in pCityDistricts:Members() do
				local pDistrictType = GameInfo.Districts[ pDistrict:GetType() ];
				if (pDistrictType ~= nil) then
					local pDistrictLineItemInstance:table = {};
					ContextPtr:BuildInstanceForControl("DistrictEntryInstance", pDistrictLineItemInstance, instance.ContentStack );
					pDistrictLineItemInstance.DistrictName:LocalizeAndSetText( pDistrictType.Name );
				end

				-- Buildings
				local districtBuildings = pCityBldgs:GetBuildingsAtLocation( pDistrict:GetLocation() );

				for iBuilding, eBuilding in ipairs(districtBuildings) do
					local pBuildingType = GameInfo.Buildings[ eBuilding ];
					if (pBuildingType ~= nil) then
						local pBuildingLineItemInstance:table = {};
						ContextPtr:BuildInstanceForControl("BuildingEntryInstance", pBuildingLineItemInstance, instance.ContentStack );
						pBuildingLineItemInstance.BuildingName:LocalizeAndSetText( pBuildingType.Name );
					end
				end
			end		

			SetGroupCollapsePadding(instance, 0 );
			RealizeGroup( instance );
				
		end
	
	
		Controls.Stack:CalculateSize();
		Controls.Scroll:CalculateSize();

		local xOffset, yOffset = Controls.Scroll:GetParentRelativeOffset();
		Controls.Scroll:SetSizeY( Controls.TabsContainer:GetSizeY() - yOffset );
	end
end

-- ===========================================================================
function OnShow()

	UpdatePlayerList();
end

-- ===========================================================================
function OnLoadGameViewStateDone()

	if not ContextPtr:IsHidden() then
		OnShow();
	end 

end

-- ===========================================================================
function OnClose()

	ContextPtr:SetHide(true);
end

-- ===========================================================================
function OnPlayerAdded()
	
	UpdatePlayerList();
end

-- ===========================================================================
function OnPlayerRemoved(index)
	
	UpdatePlayerList();
end

-- ===========================================================================
function OnPlayerEdited(index)

	local playerEntry = m_PlayerIndexToEntry[index];
	if playerEntry ~= nil then
		UpdatePlayerEntry(playerEntry);
	end
end

-- ===========================================================================
function OnPlayerTechEdited(player, tech, progress)

	if (m_ViewingTab.TechInstance ~= nil and m_ViewingTab.TechInstance.TechList ~= nil) then
		if m_SelectedPlayer ~= nil and m_SelectedPlayer.Index == player then
			for i,techEntry in ipairs(m_TechEntries) do
				if techEntry.Type.Index == tech then
					local hasTech = WorldBuilder.PlayerManager():PlayerHasTech( player, tech );
					m_ViewingTab.TechInstance.TechList:SetEntrySelected( techEntry, hasTech, false );
					break;
				end
			end
		end
	end
end

-- ===========================================================================
function OnPlayerCivicEdited(player, civic, progress)

	if (m_ViewingTab.CivicsInstance ~= nil and m_ViewingTab.CivicsInstance.CivicsList ~= nil) then
		if m_SelectedPlayer ~= nil and m_SelectedPlayer.Index == player then
			for i,civicEntry in ipairs(m_CivicEntries) do
				if civicEntry.Type.Index == civic then
					local hasCivic = WorldBuilder.PlayerManager():PlayerHasCivic( player, civic );
					m_ViewingTab.CivicsInstance.CivicsList:SetEntrySelected( civicEntry, hasCivic, false );
					break;
				end
			end
		end
	end
end

-- ===========================================================================
function OnAddPlayer()

	local player = WorldBuilder.PlayerManager():AddPlayer(false);
	if player ~= -1 then
		Controls.PlayerList:SetSelectedIndex( player+1, true );
	end
end

-- ===========================================================================
function OnAddAIPlayer()

	local player = WorldBuilder.PlayerManager():AddPlayer(true);
	if player ~= -1 then
		Controls.PlayerList:SetSelectedIndex( player+1, true );
	end
end

-- ===========================================================================
function OnRemovePlayer()

	if m_SelectedPlayer ~= nil then
		WorldBuilder.PlayerManager():UninitializePlayer(m_SelectedPlayer.Index);
	end
end

-- ===========================================================================
function OnCivSelected(entry)

	if m_SelectedPlayer ~= nil then
		WorldBuilder.PlayerManager():SetPlayerLeader(m_SelectedPlayer.Index, entry.DefaultLeader, entry.Type, m_SelectedPlayer.CivLevel);
	end
end

-- ===========================================================================
function OnLeaderSelected(entry)

	if m_SelectedPlayer ~= nil then
		WorldBuilder.PlayerManager():SetPlayerLeader(m_SelectedPlayer.Index, entry.Type, m_SelectedPlayer.Civ, m_SelectedPlayer.CivLevel);
	end
end

-- ===========================================================================
function OnCivLevelSelected(entry)

	if m_SelectedPlayer ~= nil then
		WorldBuilder.PlayerManager():SetPlayerLeader(m_SelectedPlayer.Index, m_SelectedPlayer.Leader, m_SelectedPlayer.Civ, entry.Type);
	end
end

-- ===========================================================================
function OnEraSelected(entry)

	if m_SelectedPlayer ~= nil then
		WorldBuilder.PlayerManager():SetPlayerEra(m_SelectedPlayer.Index, entry.Type.Index);
	end
end

-- ===========================================================================
function OnTechSelected(entry, selected)

	if m_SelectedPlayer ~= nil then
		local progress = selected and 100 or -1;
		WorldBuilder.PlayerManager():SetPlayerHasTech(m_SelectedPlayer.Index, entry.Type.Index, progress);
	end
end

-- ===========================================================================
function OnCivicSelected(entry, selected)

	if m_SelectedPlayer ~= nil then
		local progress = selected and 100 or -1;
		WorldBuilder.PlayerManager():SetPlayerHasCivic(m_SelectedPlayer.Index, entry.Type.Index, progress);
	end
end

-- ===========================================================================
function OnGoldEdited()

	local text = Controls.GoldEdit:GetText();
	if m_SelectedPlayer ~= nil and text ~= nil then
		local gold = tonumber(text);
		if gold ~= m_SelectedPlayer.Gold then
			WorldBuilder.PlayerManager():SetPlayerGold(m_SelectedPlayer.Index, gold);
		end
	end
end

-- ===========================================================================
function OnFaithEdited()

	local text = Controls.FaithEdit:GetText();
	if m_SelectedPlayer ~= nil and text ~= nil then
		local faith = tonumber(text);
		if faith ~= m_SelectedPlayer.Faith then
			WorldBuilder.PlayerManager():SetPlayerFaith(m_SelectedPlayer.Index, faith);
		end
	end
end

-- ===========================================================================
--	Init
-- ===========================================================================
function OnInit()

	-- Title
	Controls.ModalScreenTitle:SetText( Locale.ToUpper("Player Editor") );

	-- PlayerList
	Controls.PlayerList:SetEntrySelectedCallback( OnPlayerSelected );

	-- EraPullDown
	for type in GameInfo.Eras() do
		table.insert(m_EraEntries, { Text=type.Name, Type=type });
	end
	Controls.EraPullDown:SetEntries( m_EraEntries, 1 );
	Controls.EraPullDown:SetEntrySelectedCallback( OnEraSelected );

	-- CivLevelPullDown
	for type in GameInfo.CivilizationLevels() do
		local name = type.Name ~= nil and type.Name or type.CivilizationLevelType;
		table.insert(m_CivLevelEntries, { Text=name, Type=type.CivilizationLevelType });
	end
	Controls.CivLevelPullDown:SetEntries( m_CivLevelEntries, 1 );
	Controls.CivLevelPullDown:SetEntrySelectedCallback( OnCivLevelSelected );

	-- CivPullDown

	-- Intialize the m_CivEntries table.  This must use a simple index for the key, the pull down control will access it directly.
	-- The first two entries are special
	table.insert(m_CivEntries, { Text="Random", Type="RANDOM", DefaultLeader="RANDOM" });
	table.insert(m_CivEntries, { Text="Any", Type="UNDEFINED", DefaultLeader="UNDEFINED" });
	-- Fill in the civs
	for type in GameInfo.Civilizations() do
		table.insert(m_CivEntries, { Text=type.Name, Type=type.CivilizationType, DefaultLeader=-1 });
	end
	Controls.CivPullDown:SetEntries( m_CivEntries, 1 );
	Controls.CivPullDown:SetEntrySelectedCallback( OnCivSelected );

	-- Set default leaders
	for entry in GameInfo.CivilizationLeaders() do
		local civ = GameInfo.Civilizations[entry.CivilizationType];
		if civ ~= nil then
			SetCivDefaultLeader(entry);
		end
	end

	-- LeaderPullDown
	table.insert(m_LeaderEntries, { Text="Random", Type="RANDOM" });
	table.insert(m_LeaderEntries, { Text="Any", Type="UNDEFINED" });
	for type in GameInfo.Leaders() do
		table.insert(m_LeaderEntries, { Text=type.Name, Type=type.LeaderType });
	end
	Controls.LeaderPullDown:SetEntries( m_LeaderEntries, 1 );
	Controls.LeaderPullDown:SetEntrySelectedCallback( OnLeaderSelected );
	m_LeaderEntries[1].Button:SetDisabled(true); -- We never want the user to manually select the random leader entry

	-- TechList
	for type in GameInfo.Technologies() do
		table.insert(m_TechEntries, { Text=type.Name, Type=type });
	end

	-- CivicsList
	for type in GameInfo.Civics() do
		table.insert(m_CivicEntries, { Text=type.Name, Type=type });
	end

	m_tabs = CreateTabs( Controls.TabContainer, 42, 34, 0xFF331D05 );
	AddTabSection( "LOC_WORLDBUILDER_TAB_TECHS",		ViewPlayerTechsPage );
	AddTabSection( "LOC_WORLDBUILDER_TAB_CIVICS",		ViewPlayerCivicsPage );
	AddTabSection( "LOC_WORLDBUILDER_TAB_CITIES",		ViewPlayerCitiesPage );
	

	m_tabs.SameSizedTabs(50);
	m_tabs.CenterAlignTabs(-10);		

	-- Gold/Faith
	Controls.GoldEdit:RegisterStringChangedCallback( OnGoldEdited );
	Controls.FaithEdit:RegisterStringChangedCallback( OnFaithEdited );

	-- Add/Remove Players
	Controls.NewPlayerButton:RegisterCallback( Mouse.eLClick, OnAddPlayer );
	Controls.NewAIPlayerButton:RegisterCallback( Mouse.eLClick, OnAddAIPlayer );
	Controls.RemovePlayerButton:RegisterCallback( Mouse.eLClick, OnRemovePlayer );

	-- Register for events
	ContextPtr:SetShowHandler( OnShow );
	Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone );
	Controls.ModalScreenClose:RegisterCallback( Mouse.eLClick, OnClose );
	LuaEvents.WorldBuilder_PlayerAdded.Add( OnPlayerAdded );
	LuaEvents.WorldBuilder_PlayerRemoved.Add( OnPlayerRemoved );
	LuaEvents.WorldBuilder_PlayerEdited.Add( OnPlayerEdited );
	LuaEvents.WorldBuilder_PlayerTechEdited.Add( OnPlayerTechEdited );
	LuaEvents.WorldBuilder_PlayerCivicEdited.Add( OnPlayerCivicEdited );

end
ContextPtr:SetInitHandler( OnInit );