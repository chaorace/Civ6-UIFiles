-- ===========================================================================
--	World Builder Placement
-- ===========================================================================

-- ===========================================================================
--	DATA MEMBERS
-- ===========================================================================
local m_SelectedPlot = nil;
local m_MouseOverPlot = nil;
local m_Mode = nil;
local m_TabButtons             : table = {};
local m_TerrainTypeEntries     : table = {};
local m_FeatureTypeEntries     : table = {};
local m_ContinentTypeEntries   : table = {};
local m_ResourceTypeEntries    : table = {};
local m_ImprovementTypeEntries : table = {};
local m_RouteTypeEntries       : table = {};
local m_PlayerEntries          : table = {};
local m_ScenarioPlayerEntries  : table = {}; -- Scenario players are players that don't have a random civ and can therefore have cities and units
local m_CityEntries            : table = {};
local m_UnitTypeEntries        : table = {};

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function PlacementValid(plotID, mode)

	if mode == nil then
		return false;
	elseif mode.PlacementValid ~= nil then
		return mode.PlacementValid(plotID)
	else
		return true;
	end
end

-- ===========================================================================
function UpdateMouseOverHighlight(plotID, mode, on)

	if not mode.NoMouseOverHighlight then
		local highlight;
		if PlacementValid(plotID, mode) then
			highlight = PlotHighlightTypes.MOVEMENT;
		else
			highlight = PlotHighlightTypes.ATTACK;
		end

		UI.HighlightPlots(highlight, on, { plotID } );
	end
end

-- ===========================================================================
function ClearMode()

	if m_Mode ~= nil then

		if m_MouseOverPlot ~= nil then
			UpdateMouseOverHighlight(m_MouseOverPlot, m_Mode, false);
		end
		
		if m_Mode.OnLeft ~= nil then
			m_Mode.OnLeft();
		end

		m_Mode = nil;
	end
end

-- ===========================================================================
function OnPlacementTypeSelected(mode)

	ClearMode();

	m_Mode = mode;
	Controls.TabControl:SelectTab( mode.Tab );

	if m_MouseOverPlot ~= nil then
		UpdateMouseOverHighlight(m_MouseOverPlot, m_Mode, true);
	end

	if m_Mode.OnEntered ~= nil then
		m_Mode.OnEntered();
	end
end

-- ===========================================================================
function OnPlotSelected(plotID, edge, lbutton)
	
	if not ContextPtr:IsHidden() then
		local mode = Controls.PlacementPullDown:GetSelectedEntry();
		mode.PlacementFunc( plotID, edge, lbutton );
	end
end

-- ===========================================================================
function OnPlotMouseOver(plotID)

	if m_Mode ~= nil then
		if m_MouseOverPlot ~= nil then
			UpdateMouseOverHighlight(m_MouseOverPlot, m_Mode, false);
		end

		if plotID ~= nil then
			UpdateMouseOverHighlight(plotID, m_Mode, true);
		end
	end

	m_MouseOverPlot = plotID;
end

-- ===========================================================================
function OnShow()

	local mode = Controls.PlacementPullDown:GetSelectedEntry();
	OnPlacementTypeSelected( mode );

	if UI.GetInterfaceMode() ~= InterfaceModeTypes.WB_SELECT_PLOT then
		UI.SetInterfaceMode( InterfaceModeTypes.WB_SELECT_PLOT );
	end
end

-- ===========================================================================
function OnHide()
	ClearMode();
end

-- ===========================================================================
function OnLoadGameViewStateDone()

	UpdatePlayerEntries();
	UpdateCityEntries();

	if not ContextPtr:IsHidden() then
		OnShow();
	end
end

-- ===========================================================================
function OnVisibilityPlayerChanged(entry)
	
	if m_Mode ~= nil and m_Mode.Tab == Controls.PlaceVisibility then
		if entry ~= nil then
			WorldBuilder.SetVisibilityPreviewPlayer(entry.PlayerIndex);
		else
			WorldBuilder.ClearVisibilityPreviewPlayer();
		end
	end 
end

-- ===========================================================================
function UpdatePlayerEntries()

	m_PlayerEntries = {};
	m_ScenarioPlayerEntries = {};
	
	for i = 0, GameDefines.MAX_PLAYERS-2 do -- Use MAX_PLAYERS-2 to ignore the barbarian player

		local eStatus = WorldBuilder.PlayerManager():GetSlotStatus(i); 
		if eStatus ~= SlotStatus.SS_CLOSED then
			local playerConfig = WorldBuilder.PlayerManager():GetPlayerConfig(i);
			table.insert(m_PlayerEntries, { Text=playerConfig.Name, PlayerIndex=i });
			if playerConfig.Civ ~= nil then
				table.insert(m_ScenarioPlayerEntries, { Text=playerConfig.Name, PlayerIndex=i });
			end
		end
	end
	
	local hasPlayers = m_PlayerEntries[1] ~= nil;
	local hasScenarioPlayers = m_ScenarioPlayerEntries[1] ~= nil;

	Controls.StartPosPullDown:SetEntries( m_PlayerEntries, hasPlayers and 1 or 0 );
	Controls.CityOwnerPullDown:SetEntries( m_ScenarioPlayerEntries, hasScenarioPlayers and 1 or 0 );
	Controls.UnitOwnerPullDown:SetEntries( m_ScenarioPlayerEntries, hasScenarioPlayers and 1 or 0 );
	Controls.VisibilityPullDown:SetEntries( m_ScenarioPlayerEntries, hasScenarioPlayers and 1 or 0 );

	m_TabButtons[Controls.PlaceStartPos]:SetDisabled( not hasPlayers );
	m_TabButtons[Controls.PlaceCity]:SetDisabled( not hasScenarioPlayers );
	m_TabButtons[Controls.PlaceUnit]:SetDisabled( not hasScenarioPlayers );
	m_TabButtons[Controls.PlaceVisibility]:SetDisabled( not hasScenarioPlayers );

	OnVisibilityPlayerChanged(Controls.VisibilityPullDown:GetSelectedEntry());
end

-- ===========================================================================
function UpdateCityEntries()

	m_CityEntries = {};

	for iPlayer = 0, GameDefines.MAX_PLAYERS-1 do
		local player = Players[iPlayer];
		local cities = player:GetCities();
		if cities ~= nil then
			for iCity, city in cities:Members() do
				table.insert(m_CityEntries, { Text=city:GetName(), Player=iPlayer, ID=city:GetID() });
			end
		end
	end

	local hasCities = m_CityEntries[1] ~= nil;
	Controls.OwnerPullDown:SetEntries( m_CityEntries, hasCities and 1 or 0 );
	m_TabButtons[Controls.PlaceOwnership]:SetDisabled( not hasCities );
end

-- ===========================================================================
function PlaceTerrain(plot, edge, bAdd)

	if bAdd then
		local entry = Controls.TerrainPullDown:GetSelectedEntry();
		WorldBuilder.MapManager():SetTerrainType( plot, entry.Type.Index );
	end
end

-- ===========================================================================
function PlaceFeature_Valid(plot)
	local entry = Controls.FeaturePullDown:GetSelectedEntry();
	return WorldBuilder.MapManager():CanPlaceFeature( plot, entry.Type.Index );
end

-- ===========================================================================
function PlaceContinent(plot, edge, bAdd)

	if bAdd then
		local entry = Controls.ContinentPullDown:GetSelectedEntry();
		WorldBuilder.MapManager():SetContinentType( plot, entry.Type.RowId );
	end
end

-- ===========================================================================
function PlaceContinent_Valid(plot)
	local pPlot = Map.GetPlotByIndex(plot);
	return pPlot ~= nil and not pPlot:IsWater();
end

-- ===========================================================================
function PlaceFeature(plot, edge, bAdd)

	if bAdd then
		local entry = Controls.FeaturePullDown:GetSelectedEntry();
		if WorldBuilder.MapManager():CanPlaceFeature( plot, entry.Type.Index ) then
			WorldBuilder.MapManager():SetFeatureType( plot, entry.Type.Index );
		end
	else
		WorldBuilder.MapManager():SetFeatureType( plot, -1 );
	end
end

-- ===========================================================================
function PlaceRiver(plot, edge, bAdd)
	WorldBuilder.MapManager():EditRiver(plot, edge, bAdd);
end

-- ===========================================================================
function PlaceCliff(plot, edge, bAdd)
	WorldBuilder.MapManager():EditCliff(plot, edge, bAdd);
end

-- ===========================================================================
function PlaceResource_Valid(plot)
	local entry = Controls.ResourcePullDown:GetSelectedEntry();
	return WorldBuilder.MapManager():CanPlaceResource( plot, entry.Type.Index );
end

-- ===========================================================================
function PlaceResource(plot, edge, bAdd)

	if bAdd then
		local entry = Controls.ResourcePullDown:GetSelectedEntry();
		if WorldBuilder.MapManager():CanPlaceResource( plot, entry.Type.Index ) then
			WorldBuilder.MapManager():SetResourceType( plot, entry.Type.Index, Controls.ResourceAmount:GetText() );
		end
	else
		WorldBuilder.MapManager():SetResourceType( plot, -1 );
	end
end

-- ===========================================================================
function PlaceCity(plot, edge, bAdd)

	if bAdd then
		local playerEntry = Controls.CityOwnerPullDown:GetSelectedEntry();
		if playerEntry ~= nil then
			WorldBuilder.CityManager():Create(playerEntry.PlayerIndex, plot);
		end
	else
		WorldBuilder.CityManager():RemoveAt(plot);
	end
end

-- ===========================================================================
function PlaceUnit(plot, edge, bAdd)

	if bAdd then
		local playerEntry = Controls.UnitOwnerPullDown:GetSelectedEntry();
		local unitEntry = Controls.UnitPullDown:GetSelectedEntry();
		if playerEntry ~= nil and unitEntry ~= nil then
			WorldBuilder.UnitManager():Create(unitEntry.Type.Index, playerEntry.PlayerIndex, plot);
		end
	else
		WorldBuilder.UnitManager():RemoveAt(plot);
	end
end

-- ===========================================================================
function PlaceImprovement(plot, edge, bAdd)

	if bAdd then
		local entry = Controls.ImprovementPullDown:GetSelectedEntry();
		WorldBuilder.MapManager():SetImprovementType( plot, entry.Type.Index, Map.GetPlotByIndex( m_SelectedPlot ):GetOwner() );
	else
		WorldBuilder.MapManager():SetImprovementType( plot, -1 );
	end
end

-- ===========================================================================
function PlaceRoute(plot, edge, bAdd)

	if bAdd then
		local entry = Controls.RoutePullDown:GetSelectedEntry();
		WorldBuilder.MapManager():SetRouteType( plot, entry.Type.Index, Controls.RoutePillagedCheck:IsChecked() );
	else
		WorldBuilder.MapManager():SetRouteType( plot, RouteTypes.NONE );
	end
end

-- ===========================================================================
function PlaceStartPos(plot, edge, bAdd)

	if bAdd then
		local entry = Controls.StartPosPullDown:GetSelectedEntry();
		if entry ~= nil then
			WorldBuilder.PlayerManager():SetPlayerStartingPosition( entry.PlayerIndex, plot );
		end
	else
		local prevStartPosPlayer = WorldBuilder.PlayerManager():GetStartPositionPlayer( plot );
		if prevStartPosPlayer ~= -1 then
			WorldBuilder.PlayerManager():ClearPlayerStartingPosition( prevStartPosPlayer );
		end
	end
end

-- ===========================================================================
function PlaceOwnership(iPlot, edge, bAdd)

	local plot = Map.GetPlotByIndex( iPlot );
	if bAdd then
		local entry = Controls.OwnerPullDown:GetSelectedEntry();
		if entry ~= nil then
			WorldBuilder.CityManager():SetPlotOwner( plot:GetX(), plot:GetY(), entry.PlayerIndex, entry.ID );
		end
	else
		WorldBuilder.CityManager():SetPlotOwner( plot:GetX(), plot:GetY(), false );
	end
end

-- ===========================================================================
function OnVisibilityToolEntered()
	
	local entry = Controls.VisibilityPullDown:GetSelectedEntry();
	if entry ~= nil then
		WorldBuilder.SetVisibilityPreviewPlayer(entry.PlayerIndex);
	end 
end

-- ===========================================================================
function OnVisibilityToolLeft()
	WorldBuilder.ClearVisibilityPreviewPlayer();
end

-- ===========================================================================
function PlaceVisibility(plot, edge, bAdd)

	local entry = Controls.VisibilityPullDown:GetSelectedEntry();
	if entry ~= nil then
		WorldBuilder.MapManager():SetRevealed(plot, bAdd, entry.PlayerIndex);
	end
end

-- ===========================================================================
local m_ContinentPlots : table = {};

-- ===========================================================================
function OnContinentToolEntered()

	local continentType = Controls.ContinentPullDown:GetSelectedEntry().Type.RowId;
	m_ContinentPlots = WorldBuilder.MapManager():GetContinentPlots(continentType);
	UI.HighlightPlots(PlotHighlightTypes.PLACEMENT, true, m_ContinentPlots);
	LuaEvents.WorldBuilder_ContinentTypeEdited.Add(OnContinentTypeEdited);
end

-- ===========================================================================
function OnContinentToolLeft()
	LuaEvents.WorldBuilder_ContinentTypeEdited.Remove(OnContinentTypeEdited);
	UI.HighlightPlots(PlotHighlightTypes.PLACEMENT, false);
end

-- ===========================================================================
function OnContinentTypeSelected( entry )

	if m_Mode ~= nil and m_Mode.Tab == Controls.PlaceContinent then
		UI.HighlightPlots(PlotHighlightTypes.PLACEMENT, false);
		m_ContinentPlots = WorldBuilder.MapManager():GetContinentPlots(entry.Type.RowId);
		UI.HighlightPlots(PlotHighlightTypes.PLACEMENT, true, m_ContinentPlots);
	end
end

-- ===========================================================================
function OnContinentTypeEdited( plotID, continentType )

	if continentType == Controls.ContinentPullDown:GetSelectedEntry().Type.RowId then
		table.insert(m_ContinentPlots, plotID);
		UI.HighlightPlots(PlotHighlightTypes.PLACEMENT, true, { plotID } );
	else
		for i, v in ipairs(m_ContinentPlots) do
			if v == plotID then
				table.remove(m_ContinentPlots, i);
				UI.HighlightPlots(PlotHighlightTypes.PLACEMENT, false);
				UI.HighlightPlots(PlotHighlightTypes.PLACEMENT, true, m_ContinentPlots);
				break;
			end
		end
	end
end

-- ===========================================================================
--	Placement Modes
-- ===========================================================================
local m_PlacementModes : table =
{
	{ Text="Terrain",         Tab=Controls.PlaceTerrain,      PlacementFunc=PlaceTerrain,     PlacementValid=nil                   },
	{ Text="Features",        Tab=Controls.PlaceFeatures,     PlacementFunc=PlaceFeature,     PlacementValid=PlaceFeature_Valid    },
	{ Text="Continent",       Tab=Controls.PlaceContinent,    PlacementFunc=PlaceContinent,   PlacementValid=PlaceContinent_Valid, OnEntered=OnContinentToolEntered, OnLeft=OnContinentToolLeft, NoMouseOverHighlight=true },
	{ Text="Rivers",          Tab=Controls.PlaceRivers,       PlacementFunc=PlaceRiver,       PlacementValid=nil                   },
	{ Text="Cliffs",          Tab=Controls.PlaceCliffs,       PlacementFunc=PlaceCliff,       PlacementValid=nil                   },
	{ Text="Resources",       Tab=Controls.PlaceResources,    PlacementFunc=PlaceResource,    PlacementValid=PlaceResource_Valid   },
	{ Text="City",            Tab=Controls.PlaceCity,         PlacementFunc=PlaceCity,        PlacementValid=nil                   },
	{ Text="Unit",            Tab=Controls.PlaceUnit,         PlacementFunc=PlaceUnit,        PlacementValid=nil                   },
	{ Text="Improvements",    Tab=Controls.PlaceImprovements, PlacementFunc=PlaceImprovement, PlacementValid=nil                   },
	{ Text="Routes",          Tab=Controls.PlaceRoutes,       PlacementFunc=PlaceRoute,       PlacementValid=nil                   },
	{ Text="Start Position",  Tab=Controls.PlaceStartPos,     PlacementFunc=PlaceStartPos,    PlacementValid=nil                   },
	{ Text="Owner",           Tab=Controls.PlaceOwnership,    PlacementFunc=PlaceOwnership,   PlacementValid=nil                   },
	{ Text="Revealed",        Tab=Controls.PlaceVisibility,   PlacementFunc=PlaceVisibility,  PlacementValid=nil,                  OnEntered=OnVisibilityToolEntered, OnLeft=OnVisibilityToolLeft },
};

-- ===========================================================================
--	Init
-- ===========================================================================
function OnInit()

	-- PlacementPullDown
	Controls.PlacementPullDown:SetEntries( m_PlacementModes, 1 );
	Controls.PlacementPullDown:SetEntrySelectedCallback( OnPlacementTypeSelected );

	-- Track Tab Buttons
	for i,tabEntry in ipairs(m_PlacementModes) do
		m_TabButtons[tabEntry.Tab] = tabEntry.Button;
	end

	-- TerrainPullDown
	for type in GameInfo.Terrains() do
		table.insert(m_TerrainTypeEntries, { Text=type.Name, Type=type });
	end
	Controls.TerrainPullDown:SetEntries( m_TerrainTypeEntries, 1 );

	-- FeaturePullDown
	for type in GameInfo.Features() do
		table.insert(m_FeatureTypeEntries, { Text=type.Name, Type=type });
	end
	Controls.FeaturePullDown:SetEntries( m_FeatureTypeEntries, 1 );

	-- ContinentPullDown
	for type in GameInfo.Continents() do
		table.insert(m_ContinentTypeEntries, { Text=type.Description, Type=type });
	end
	Controls.ContinentPullDown:SetEntries( m_ContinentTypeEntries, 1 );
	Controls.ContinentPullDown:SetEntrySelectedCallback( OnContinentTypeSelected );

	-- ResourcePullDown
	for type in GameInfo.Resources() do
		table.insert(m_ResourceTypeEntries, { Text=type.Name, Type=type });
	end
	Controls.ResourcePullDown:SetEntries( m_ResourceTypeEntries, 1 );

	-- UnitPullDown
	for type in GameInfo.Units() do
		table.insert(m_UnitTypeEntries, { Text=type.Name, Type=type });
	end
	Controls.UnitPullDown:SetEntries( m_UnitTypeEntries, 1 );

	-- ImprovementPullDown
	for type in GameInfo.Improvements() do
		table.insert(m_ImprovementTypeEntries, { Text=type.Name, Type=type });
	end
	Controls.ImprovementPullDown:SetEntries( m_ImprovementTypeEntries, 1 );

	-- RoutePullDown
	for type in GameInfo.Routes() do
		table.insert(m_RouteTypeEntries, { Text=type.Name, Type=type });
	end
	Controls.RoutePullDown:SetEntries( m_RouteTypeEntries, 1 );

	-- VisibilityPullDown
	Controls.VisibilityPullDown:SetEntrySelectedCallback( OnVisibilityPlayerChanged );

	-- Register for events
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetHideHandler( OnHide );
	Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone );
	LuaEvents.WorldInput_WBSelectPlot.Add( OnPlotSelected );
	LuaEvents.WorldInput_WBMouseOverPlot.Add( OnPlotMouseOver );

	Events.CityAddedToMap.Add( UpdateCityEntries );
	Events.CityRemovedFromMap.Add( UpdateCityEntries );

	LuaEvents.WorldBuilder_PlayerAdded.Add( UpdatePlayerEntries );
	LuaEvents.WorldBuilder_PlayerRemoved.Add( UpdatePlayerEntries );
	LuaEvents.WorldBuilder_PlayerEdited.Add( UpdatePlayerEntries );

end
ContextPtr:SetInitHandler( OnInit );