g_PanelHasFocus = false;
-------------------------------------------------------------------------------

g_UnitPlacement =
{
	UnitType = -1,
	Embarked = false,
	
	Place =
	function(plot)
		if (g_PlacementSettings.Player ~= -1 and g_UnitPlacement.UnitType ~= -1) then
			local player = Players[g_PlacementSettings.Player];
			if (player ~= nil) then
				local playerUnits = player:GetUnits();

				local unit = playerUnits:Create(g_UnitPlacement.UnitType, plot:GetX(), plot:GetY());
--				if (g_UnitPlacement.Embarked) then
--					unit:Embark();
--				end
			end
		end
	end,
	
	Remove =
	function(plot)
		local aUnits = Units.GetUnitsInPlot(plot);
		for i, pUnit in ipairs(aUnits) do
			Players[pUnit:GetOwner()]:GetUnits():Destroy(pUnit);
		end
		local tradeLayerID = 1;
		aUnits = Units.GetUnitsInPlotLayerID(plot, tradeLayerID);
		for i, pUnit in ipairs(aUnits) do
			Players[pUnit:GetOwner()]:GetUnits():Destroy(pUnit);
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
			ResourceBuilder.SetResourceType(plot, g_ResourcePlacement.ResourceType, g_ResourcePlacement.ResourceAmount);
		end
	end,
	
	Remove =
	function(plot)
		ResourceBuilder.SetResourceType(plot, -1);
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
		if (g_ImprovementPlacement.ImprovementType ~= -1 and g_PlacementSettings.Player ~= -1) then
			ImprovementBuilder.SetImprovementType(plot, g_ImprovementPlacement.ImprovementType, g_PlacementSettings.Player);
			if (g_ImprovementPlacement.Pillaged) then
				ImprovementBuilder.SetImprovementPillaged(plot, true);
			end
		end
	end,
	
	Remove =
	function(plot)
		ImprovementBuilder.SetImprovementType(plot, -1);
	end
}

-------------------------------------------------------------------------------
g_FeaturePlacement =
{
	FeatureType = -1,
	
	Place =
	function(plot)
		if (g_FeaturePlacement.FeatureType ~= -1) then
			TerrainBuilder.SetFeatureType(plot, g_FeaturePlacement.FeatureType);
		end
	end,
	
	Remove =
	function(plot)
		TerrainBuilder.SetFeatureType(plot, -1);
	end
}

-------------------------------------------------------------------------------
g_CityPlacement =
{
	Place =
	function(plot)
		if (g_PlacementSettings.Player ~= -1) then
			local player = Players[g_PlacementSettings.Player];
			if (player ~= nil) then
				local playerCities = player:GetCities();
				local city = playerCities:Create(plot:GetX(), plot:GetY());
			end
		end
	end,
	
	Remove =
	function(plot)
		local pCity = Cities.GetCityInPlot(plot);
		if (pCity ~= nil) then
			Players[pCity:GetOwner()]:GetCities():Destroy(pCity);
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
		if (g_PlacementSettings.Player ~= -1) then
			local player = Players[g_PlacementSettings.Player];
			if (player ~= nil) then
				RouteBuilder.SetRouteType(plot, g_RoutePlacement.Type);
				if (g_RoutePlacement.Pillaged == true) then
					RouteBuilder.SetRoutePillaged(plot, true);
				end
			end
		end
	end,
	
	Remove =
	function(plot)
		RouteBuilder.SetRouteType(plot, RouteTypes.NONE);
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
			TerrainBuilder.SetTerrainType(plot, g_TerrainPlacement.AddType);
		end
	end,
	
	Remove =
	function(plot)
		if (g_TerrainPlacement.EraseType ~= -1) then
			TerrainBuilder.SetTerrainType(plot, g_TerrainPlacement.EraseType);
		end
	end
}

-------------------------------------------------------------------------------

g_GreatPersonPlacement =
{
	UnitType = -1,
	
	Place =
	function(plot)
		if (g_PlacementSettings.Player ~= -1 and g_GreatPersonPlacement.UnitType ~= -1) then
			local player = Players[g_PlacementSettings.Player];
			if (player ~= nil) then
				 Game.GetGreatPeople():CreatePerson(player:GetID(), g_GreatPersonPlacement.UnitType, plot:GetX(), plot:GetY());
			end
		end
	end,
	
	Remove =
	function(plot)
		local aUnits = Units.GetUnitsInPlot(plot);
		for i, pUnit in ipairs(aUnits) do
			Players[pUnit:GetOwner()]:GetUnits():Destroy(pUnit);
		end
		local tradeLayerID = 1;
		aUnits = Units.GetUnitsInPlotLayerID(plot, tradeLayerID);
		for i, pUnit in ipairs(aUnits) do
			Players[pUnit:GetOwner()]:GetUnits():Destroy(pUnit);
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
function OnLButtonUp( plotX, plotY )
	if (g_PanelHasFocus == true) then
		local plot = Map.GetPlot( plotX, plotY );

		if (g_PlacementSettings.Active == true and			
			type(g_PlacementSettings) == "table" and
			type(g_PlacementSettings.PlacementHandler) == "table" and
			type(g_PlacementSettings.PlacementHandler.Place) == "function") then
	        
			g_PlacementSettings.PlacementHandler.Place(plot);
			return; -- Do not change auto-exit the debug mode
		end
	
		LuaEvents.TunerExitDebugMode();
	end
	return;
end

LuaEvents.TunerMapLButtonUp.Add(OnLButtonUp);

-------------------------------------------------------------------------------
function OnRButtonDown( plotX, plotY )
	if (g_PanelHasFocus == true) then
		local plot = Map.GetPlot( plotX, plotY );

		if (g_PlacementSettings.Active == true and			
			type(g_PlacementSettings) == "table" and
			type(g_PlacementSettings.PlacementHandler) == "table" and
			type(g_PlacementSettings.PlacementHandler.Remove) == "function") then
	        
			g_PlacementSettings.PlacementHandler.Remove(plot);
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
