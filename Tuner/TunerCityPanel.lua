g_PanelHasFocus = false;

-------------------------------------------------------------------------------

g_DistrictPlacement =
{
	DistrictType = -1,
	DistrictTypeName = "",
	ConstructionLevel = 100,

	Place =
	function(plot)
		if (g_PlacementSettings.Player ~= -1 and g_DistrictPlacement.DistrictType ~= -1) then
			local player = Players[g_PlacementSettings.Player];
			if (player ~= nil) then
				local playerCities = player:GetCities();
				local city = playerCities:FindID(g_PlacementSettings.CityID);
				if (city ~= nil) then		
					local pCityBuildQueue = pCity:GetBuildQueue();
					pCityBuildQueue:CreateIncompleteDistrict(g_DistrictPlacement.DistrictType, plot:GetIndex(), g_DistrictPlacement.ConstructionLevel);
				end
			end
		end
	end,
	
	Remove =
	function(plot)
		local pDistrict = CityManager.GetDistrictAt(plot);
		if (pDistrict ~= nil) then
			CityManager.DestroyDistrict(pDistrict);
		end
	end
}

-------------------------------------------------------------------------------

g_BuildingPlacement =
{
	BuildingType = -1,
	BuildingTypeName = "",
	ConstructionLevel = 100,
	
	Place =
	function(plot)
		if (g_PlacementSettings.Player ~= -1 and g_BuildingPlacement.BuildingType ~= -1) then
			local player = Players[g_PlacementSettings.Player];
			if (player ~= nil) then
				local playerCities = player:GetCities();
				local city = playerCities:FindID(g_PlacementSettings.CityID);
				if (city ~= nil) then
					local pCityBuildQueue = pCity:GetBuildQueue();
					pCityBuildQueue:CreateIncompleteBuilding(g_BuildingPlacement.BuildingType, plot:GetIndex(), g_BuildingPlacement.ConstructionLevel);
				end
			end
		end
	end,
	
	Remove =
	function(plot)

	end
}

-------------------------------------------------------------------------------
g_PlacementSettings =
{
	Active = false,
	Player = -1,
	CityID = -1,
	PlacementHandler = g_DistrictPlacement,
}

-------------------------------------------------------------------------------
function GetSelectedCity()
	if (g_PlacementSettings.Player >= 0 and g_PlacementSettings.CityID >= 0) then
		local pPlayer = Players[g_PlacementSettings.Player];
		if pPlayer ~= nil then
			pCity = pPlayer:GetCities():FindID(g_PlacementSettings.CityID);
			return pCity;
		end
	end
	return nil;
end

-------------------------------------------------------------------------------
function GetSelectedPlayer()
	if (g_PlacementSettings.Player >= 0) then
		local pPlayer = Players[g_PlacementSettings.Player];
		return pPlayer;
	end
	return nil;
end

-------------------------------------------------------------------------------
function OnLButtonUp( plotX, plotY )
	if (g_PanelHasFocus == true) then
		local plot = Map.GetPlot( plotX, plotY );

		if (g_PlacementSettings.Active == true and			
			type(g_PlacementSettings) == "table" and
			type(g_PlacementSettings.PlacementHandler) == "table" and
			type(g_PlacementSettings.PlacementHandler.Place) == "function") then
	        
			g_PlacementSettings.PlacementHandler.Place(plot);
		end
	
		-- LuaEvents.TunerExitDebugMode();
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
		end
	
		-- LuaEvents.TunerExitDebugMode();
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

-------------------------------------------------------------------------------
function OnUIDebugModeExited()
	if (g_PanelHasFocus == true) then
		g_PlacementSettings.Active = false;
	end
end

LuaEvents.UIDebugModeExited.Add(OnUIDebugModeExited);
