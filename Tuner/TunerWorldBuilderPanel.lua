g_PanelHasFocus = false;

g_ShowReferenceMap = false;
g_ReferenceMap = "";

-------------------------------------------------------------------------------
g_UnitPlacement =
{
	UnitType = -1,
	Embarked = false,
	
	Place =
	function(plot)
		if (g_PlacementSettings.Player ~= -1 and g_UnitPlacement.UnitType ~= -1) then
			local player = Players[g_PlacementSettings.Player];
			if (player ~= nil and player:IsInitialized()) then
				WorldBuilder.UnitManager():Create(g_UnitPlacement.UnitType, g_PlacementSettings.Player, plot:GetX(), plot:GetY());
			end
		end
	end,
	
	Remove =
	function(plot)
		local aUnits = Units.GetUnitsInPlot(plot);
		for i, pUnit in ipairs(aUnits) do
			WorldBuilder.UnitManager():Remove(pUnit);
		end
	end
}

-------------------------------------------------------------------------------
g_ResourcePlacement =
{
	ResourceType = -1,
	ResourceAmount = 1,
	
	Place =
	function(plot)
		if (g_ResourcePlacement.ResourceType ~= -1) then
			WorldBuilder.MapManager():SetResourceType(plot, g_ResourcePlacement.ResourceType, g_ResourcePlacement.ResourceAmount);
		end
	end,
	
	Remove =
	function(plot)
		WorldBuilder.MapManager():SetResourceType(plot, -1);
	end
}

-------------------------------------------------------------------------------
g_ImprovementPlacement =
{
	ImprovementType = -1,
	Pillaged = false,
	HalfBuilt = false,
	
	Place =
	function(plot)
		if (g_ImprovementPlacement.ImprovementType ~= -1) then
			if (WorldBuilder.MapManager():SetImprovementType(plot, g_ImprovementPlacement.ImprovementType, g_PlacementSettings.Player)) then
				if (g_ImprovementPlacement.Pillaged) then
					WorldBuilder.MapManager():SetImprovementPillaged(plot, true);
				end
			end
		end
	end,
	
	Remove =
	function(plot)
		WorldBuilder.MapManager():SetImprovementType(plot, -1);
	end
}

-------------------------------------------------------------------------------
g_FeaturePlacement =
{
	FeatureType = -1,
	
	Place =
	function(plot)
		if (g_FeaturePlacement.ImprovementType ~= -1) then
			if (WorldBuilder.MapManager():SetFeatureType(plot, g_FeaturePlacement.FeatureType)) then
			end
		end
	end,
	
	Remove =
	function(plot)
		WorldBuilder.MapManager():SetFeatureType(plot, -1);
	end
}

-------------------------------------------------------------------------------
g_CityPlacement =
{
	Place =
	function(plot)
		if (g_PlacementSettings.Player ~= -1) then
			local player = Players[g_PlacementSettings.Player];
			if (player ~= nil and player:IsInitialized()) then
				WorldBuilder.CityManager():Create(g_PlacementSettings.Player, plot:GetX(), plot:GetY());
			end
		end
	end,
	
	Remove =
	function(plot)
		local pCity = Cities.GetCityInPlot(plot);
		if (pCity ~= nil) then
			WorldBuilder.CityManager():Remove(pCity);
		end
	end
}

-------------------------------------------------------------------------------
g_RoutePlacement =
{
	Type = RouteTypes.NONE,
	Pillaged = false,

	Place =
	function(plot)
		WorldBuilder.MapManager():SetRouteType(plot, g_RoutePlacement.Type, g_RoutePlacement.Pillaged);
	end,
	
	Remove =
	function(plot)
		WorldBuilder.MapManager():SetRouteType(plot, RouteTypes.NONE);
	end
}

-------------------------------------------------------------------------------
g_RiverPlacement =
{
	Place =
	function(plot, edge)
		WorldBuilder.MapManager():EditRiver(plot, edge, true);
	end,
	
	Remove =
	function(plot, edge)
		WorldBuilder.MapManager():EditRiver(plot, edge, false);
	end
}

-------------------------------------------------------------------------------
g_CliffPlacement =
{
	Place =
	function(plot, edge)
		WorldBuilder.MapManager():EditCliff(plot, edge, true);
	end,
	
	Remove =
	function(plot, edge)
		WorldBuilder.MapManager():EditCliff(plot, edge, false);
	end
}

-------------------------------------------------------------------------------
g_TerrainPlacement =
{
	AddType = -1,
	EraseType = -1,
	
	Place =
	function(plot)
		if (g_TerrainPlacement.AddType ~= -1) then
			WorldBuilder.MapManager():SetTerrainType(plot, g_TerrainPlacement.AddType);
		end
	end,
	
	Remove =
	function(plot)
		if (g_TerrainPlacement.EraseType ~= -1) then
			WorldBuilder.MapManager():SetTerrainType(plot, g_TerrainPlacement.EraseType);
		end
	end
}

-------------------------------------------------------------------------------
g_StartingPlotPlacement =
{	
	Place =
	function(plot)
		if (g_PlacementSettings.Player ~= -1) then
			WorldBuilder.PlayerManager():SetPlayerStartingPosition(g_PlacementSettings.Player, plot:GetX(), plot:GetY());
		end
	end,
	
	Remove =
	function(plot)
		if (g_PlacementSettings.Player ~= -1) then
			WorldBuilder.PlayerManager():ClearStartingPosition(plot:GetX(), plot:GetY());
		end
	end
}

-------------------------------------------------------------------------------
g_PlacementSettings =
{
	Active = false,
	Player = -1,
	PlacementHandler = g_UnitPlacement,
}

-------------------------------------------------------------------------------
function GetSelectedPlayer()

	if (g_PlacementSettings.Player ~= -1 and PlayerManager.IsValid(g_PlacementSettings.Player)) then
		return Players[g_PlacementSettings.Player];
	end

	return nil;
end

-------------------------------------------------------------------------------
function OnLButtonUp( plotX, plotY, worldX, worldY, worldZ, edge )
	if (g_PanelHasFocus == true) then
		local plot = Map.GetPlot( plotX, plotY );

		if (g_PlacementSettings.Active == true and			
			type(g_PlacementSettings) == "table" and
			type(g_PlacementSettings.PlacementHandler) == "table" and
			type(g_PlacementSettings.PlacementHandler.Place) == "function") then
	        
			g_PlacementSettings.PlacementHandler.Place(plot, edge);
			return; -- Do not change auto-exit the debug mode
		end
	
		LuaEvents.TunerExitDebugMode();
	end
	return;
end

LuaEvents.TunerMapLButtonUp.Add(OnLButtonUp);

-------------------------------------------------------------------------------
function OnRButtonDown( plotX, plotY, worldX, worldY, worldZ, edge )
	if (g_PanelHasFocus == true) then
		local plot = Map.GetPlot( plotX, plotY );

		if (g_PlacementSettings.Active == true and			
			type(g_PlacementSettings) == "table" and
			type(g_PlacementSettings.PlacementHandler) == "table" and
			type(g_PlacementSettings.PlacementHandler.Remove) == "function") then
	        
			g_PlacementSettings.PlacementHandler.Remove(plot, edge);
			return; -- Do not change auto-exit the debug mode
		end
	
		LuaEvents.TunerExitDebugMode();
	end
	return;
end

LuaEvents.TunerMapRButtonDown.Add(OnRButtonDown);

-------------------------------------------------------------------------------
function OnUIDebugModeEntered()
	if (g_PanelHasFocus == true) then
		g_PlacementSettings.Active = true;
	end
end

LuaEvents.UIDebugModeEntered.Add(OnUIDebugModeEntered);
