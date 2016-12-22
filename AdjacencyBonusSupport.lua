-- ===========================================================================
--	Functions related to finding the yield bonuses (district) plots are given
--	due to some attribute of an adjacent plot.
-- ==========================================================================
include( "Civ6Common" );		-- GetYieldString()
include( "MapEnums" );


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local START_INDEX	:number = GameInfo.Yields["YIELD_FOOD"].Index;
local END_INDEX		:number = GameInfo.Yields["YIELD_FAITH"].Index;


local m_DistrictsWithAdjacencyBonuses	:table = {};
for row in GameInfo.District_Adjacencies() do
	local districtIndex = GameInfo.Districts[row.DistrictType].Index;
	if (districtIndex ~= nil) then
		m_DistrictsWithAdjacencyBonuses[districtIndex] = true;
	end
end

-- ===========================================================================
--	Obtain the artdef string name that shows an adjacency icon for a plot type.
--	RETURNS: Artdef string name for an icon to display between hexes
-- ===========================================================================
function GetAdjacentIconArtdefName( targetDistrictType:string, plot:table, pkCity:table, direction:number )

	local eDistrict = GameInfo.Districts[targetDistrictType].Index;
	local eType = -1;
	local iSubType = -1;
	eType, iSubType = plot:GetAdjacencyBonusType(Game:GetLocalPlayer(), pkCity:GetID(), eDistrict, direction);

	if eType == AdjacencyBonusTypes.NO_ADJACENCY then
		return "";
	elseif eType == AdjacencyBonusTypes.ADJACENCY_DISTRICT then
		return "Districts_Generic_District";
	elseif eType == AdjacencyBonusTypes.ADJACENCY_FEATURE then
		if iSubType == g_FEATURE_JUNGLE then
			return "Terrain_Jungle";
		elseif iSubType == g_FEATURE_FOREST then
			return "Terrain_Forest";
		end
	elseif eType == AdjacencyBonusTypes.ADJACENCY_IMPROVEMENT then
		if iSubType == 1 then
			return "Improvements_Farm";
		elseif iSubType == 2 then
			return "Improvement_Mine";
		elseif iSubType == 3 then
			return "Improvement_Quarry";
		end
	elseif eType == AdjacencyBonusTypes.ADJACENCY_NATURAL_WONDER then
		return "Wonders_Natural_Wonder";
	elseif eType == AdjacencyBonusTypes.ADJACENCY_RESOURCE then
		return "Terrain_Generic_Resource";
	elseif eType == AdjacencyBonusTypes.ADJACENCY_RIVER then
		return "Terrain_River";
	elseif eType == AdjacencyBonusTypes.ADJACENCY_SEA_RESOURCE then
		return "Terrain_Sea";
	elseif eType == AdjacencyBonusTypes.ADJACENCY_TERRAIN then
		if iSubType == g_TERRAIN_TYPE_TUNDRA or iSubType == g_TERRAIN_TYPE_TUNDRA_HILLS then
			return "Terrain_Tundra";
		elseif iSubType == g_TERRAIN_TYPE_DESERT or iSubType == g_TERRAIN_TYPE_DESERT_HILLS then
			return "Terrain_Desert";
		else
			return "Terrain_Mountain";
		end
	elseif eType == AdjacencyBonusTypes.ADJACENCY_WONDER then
		return "Generic_Wonder";
	end
	
	return "";	-- None (or error)
end

-- ===========================================================================
--	RETURNS: true or false, indicating whether this placement option should be 
--	shown when the player can purchase the plot.
-- ===========================================================================
function IsShownIfPlotPurchaseable(eDistrict:number, pkCity:table, plot:table)
	local yieldBonus:string = GetAdjacentYieldBonusString(eDistrict, pkCity, plot);

	-- If we would get a bonus for placing here, then show it as an option
	if (yieldBonus ~= nil and yieldBonus ~= "") then
		return true;
	end

	-- If there are no adjacency bonuses for this district type (and so no bonuses to be had), then show it as an option
	if (m_DistrictsWithAdjacencyBonuses[eDistrict] == nil or m_DistrictsWithAdjacencyBonuses[eDistrict] == false) then
		return true;
	end

	return false;
end

-- ===========================================================================
--	RETURNS: "" if no bonus or...
--		1. Text with the bonuses for a district if added to the given plot,
--		2. parameter is a tooltip with detailed bonus informatin
--		3. NIL if can be used or a string explaining what needs to be done for plot to be usable.
-- ===========================================================================
function GetAdjacentYieldBonusString( eDistrict:number, pkCity:table, plot:table )

	local tooltipText	:string = "";
	local totalBonuses	:string = "";
	local requiredText	:string = "";
	local isFirstEntry	:boolean = true;	
	local iconString:string = "";
	
	-- Special handling for Neighborhoods
	if (GameInfo.Districts[eDistrict].OnePerCity == false) then

		tooltipText, requiredText = plot:GetAdjacencyBonusTooltip(Game:GetLocalPlayer(), pkCity:GetID(), eDistrict, 0);
		-- Ensure required text is NIL if none was returned.
		if requiredText ~= nil and string.len(requiredText) < 1 then
			requiredText = nil;
		end

		local iAppeal = plot:GetAppeal();
		local iBaseHousing = GameInfo.Districts[eDistrict].Housing;

		-- Default is Mbanza case (no appeal change)
		iconString = "+" .. tostring(iBaseHousing);

		for row in GameInfo.AppealHousingChanges() do
			if (row.DistrictType == GameInfo.Districts[eDistrict].DistrictType) then
				local iMinimumValue = row.MinimumValue;
				local iAppealChange = row.AppealChange;
				local szDescription = row.Description;
				if (iAppeal >= iMinimumValue) then
					iconString = "+" .. tostring(iBaseHousing + iAppealChange);
					tooltipText = Locale.Lookup("LOC_DISTRICT_ZONE_NEIGHBORHOOD_TOOLTIP", iBaseHousing + iAppealChange, szDescription);
					break;
				end
			end
		end
		iconString = iconString .. " [ICON_Housing]";

	-- Normal handling for all other districts
	else
		-- Check each neighbor if it matches criteria with the adjacency rules
		local iBonus = 0;
		local iBonusYield = -1;
		for iI = START_INDEX, END_INDEX do
			iBonus = plot:GetAdjacencyYield(Game:GetLocalPlayer(), pkCity:GetID(), eDistrict, iI); 
			if (iBonus > 0) then
				iBonusYield = iI;
				break;
			end
		end
			
		if iBonusYield == nil or iBonusYield == -1 then 
			iconString = "";
		else
			iconString = GetYieldString( GameInfo.Yields[iBonusYield].YieldType, iBonus );
		end

		tooltipText, requiredText = plot:GetAdjacencyBonusTooltip(Game:GetLocalPlayer(), pkCity:GetID(), eDistrict, iBonusYield);
		-- Ensure required text is NIL if none was returned.
		if requiredText ~= nil and string.len(requiredText) < 1 then
			requiredText = nil;
		end
	end	

	return iconString, tooltipText, requiredText;
end



-- ===========================================================================
--	Obtain all the owned (or could be owned) plots of a city.
--	ARGS: pCity, the city to obtain plots from
--	RETURNS: table of plot indices
-- ===========================================================================
function GetCityRelatedPlotIndexes( pCity:table )
	
	print("GetCityRelatedPlotIndexes() isn't updated with the latest purchaed plot if one was just purchased and this is being called on Event.CityMadePurchase !");
	local plots:table = Map.GetCityPlots():GetPurchasedPlots( pCity );

	-- Plots that arent't owned, but could be (and hence, could be a great spot for that district!)
	local tParameters :table = {};
	tParameters[CityCommandTypes.PARAM_PLOT_PURCHASE] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_PLOT_PURCHASE);
	local tResults = CityManager.GetCommandTargets( pCity, CityCommandTypes.PURCHASE, tParameters );
	if (tResults[CityCommandResults.PLOTS] ~= nil and table.count(tResults[CityCommandResults.PLOTS]) ~= 0) then
		for _,plotId in pairs(tResults[CityCommandResults.PLOTS]) do
			table.insert(plots, plotId);
		end
	end

	return plots;
end

-- ===========================================================================
--	Same as above but specific to districts and works despite the cache not having an updated value.
-- ===========================================================================
function GetCityRelatedPlotIndexesDistrictsAlternative( pCity:table, districtHash:number )

	local district		:table = GameInfo.Districts[districtHash];
	local plots			:table = {};
	local tParameters	:table = {};

	tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtHash;


	-- Available to place plots.
	local tResults :table = CityManager.GetOperationTargets( pCity, CityOperationTypes.BUILD, tParameters );
	if (tResults[CityOperationResults.PLOTS] ~= nil and table.count(tResults[CityOperationResults.PLOTS]) ~= 0) then			
		local kPlots:table = tResults[CityOperationResults.PLOTS];			
		for i, plotId in ipairs(kPlots) do
			table.insert(plots, plotId);
		end	
	end	

	--[[
	-- antonjs: Removing blocked plots from the UI display. Now that district placement can automatically remove features, resources, and improvements,
	-- as long as the player has the tech, there is not much need to show blocked plots and they end up being confusing.
	-- Plots that eventually can hold a district but are blocked by some required operation.
	if (tResults[CityOperationResults.BLOCKED_PLOTS] ~= nil and table.count(tResults[CityOperationResults.BLOCKED_PLOTS]) ~= 0) then			
		for _, plotId in ipairs(tResults[CityOperationResults.BLOCKED_PLOTS]) do
			table.insert(plots, plotId);		
		end
	end
	--]]

	-- Plots that arent't owned, but if they were, would give a bonus.
	tParameters = {};
	tParameters[CityCommandTypes.PARAM_PLOT_PURCHASE] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_PLOT_PURCHASE);
	local tResults = CityManager.GetCommandTargets( pCity, CityCommandTypes.PURCHASE, tParameters );
	if (tResults[CityCommandResults.PLOTS] ~= nil and table.count(tResults[CityCommandResults.PLOTS]) ~= 0) then
		for _,plotId in pairs(tResults[CityCommandResults.PLOTS]) do
			
			local kPlot	:table = Map.GetPlotByIndex(plotId);	
			if kPlot:CanHaveDistrict(district.DistrictType, pCity:GetOwner(), pCity:GetID()) then
				local isValid :boolean = IsShownIfPlotPurchaseable(district.Index, pCity, kPlot);
				if isValid then
					table.insert(plots, plotId);
				end
			end
			
		end
	end
	return plots;
end

-- ===========================================================================
--	Same as above but specific to wonders and works despite the cache not having an updated value.
-- ===========================================================================
function GetCityRelatedPlotIndexesWondersAlternative( pCity:table, buildingHash:number )

	local building		:table = GameInfo.Buildings[buildingHash];
	local plots			:table = {};
	local tParameters	:table = {};

	tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingHash;


	-- Available to place plots.
	local tResults :table = CityManager.GetOperationTargets( pCity, CityOperationTypes.BUILD, tParameters );
	if (tResults[CityOperationResults.PLOTS] ~= nil and table.count(tResults[CityOperationResults.PLOTS]) ~= 0) then			
		local kPlots:table = tResults[CityOperationResults.PLOTS];			
		for i, plotId in ipairs(kPlots) do
			table.insert(plots, plotId);
		end	
	end	

	-- Plots that aren't owned, but if they were, would give a bonus.
	tParameters = {};
	tParameters[CityCommandTypes.PARAM_PLOT_PURCHASE] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_PLOT_PURCHASE);
	local tResults = CityManager.GetCommandTargets( pCity, CityCommandTypes.PURCHASE, tParameters );
	if (tResults[CityCommandResults.PLOTS] ~= nil and table.count(tResults[CityCommandResults.PLOTS]) ~= 0) then
		for _,plotId in pairs(tResults[CityCommandResults.PLOTS]) do
			
			local kPlot	:table = Map.GetPlotByIndex(plotId);	
			if kPlot:CanHaveWonder(building.Index, pCity:GetOwner(), pCity:GetID()) then
				table.insert(plots, plotId);
			end
			
		end
	end
	return plots;
end
