-- ===========================================================================
--	View list of slots representing districts that can house great works.
--
--	Original Author: Sam Batista
-- ===========================================================================
include("InstanceManager");
include("PopupDialogSupport")

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID:string = "GreatWorksOverview"; -- Must be unique (usually the same as the file name)

local SIZE_SLOT_TYPE_ICON:number = 40;
local SIZE_GREAT_WORK_ICON:number = 64;
local PADDING_PROVIDING_LABEL:number = 10;
local PADDING_PLACING_DETAILS:number = 5;
local PADDING_PLACING_ICON:number = 10;
local PADDING_BUTTON_EDGES:number = 20;
local MIN_PADDING_SLOTS:number = 2;
local MAX_PADDING_SLOTS:number = 30;
local MAX_NUM_SLOTS:number = 6;

local NUM_RELIC_TEXTURES:number = 16;
local NUM_ARIFACT_TEXTURES:number = 25;
local GREAT_WORK_RELIC_TYPE:string = "GREATWORKOBJECT_RELIC";
local GREAT_WORK_ARTIFACT_TYPE:string = "GREATWORKOBJECT_ARTIFACT";

local LOC_PLACING:string = Locale.Lookup("LOC_GREAT_WORKS_PLACING");
local LOC_TOURISM:string = Locale.Lookup("LOC_GREAT_WORKS_TOURISM");
local LOC_THEME_BONUS:string = Locale.Lookup("LOC_GREAT_WORKS_THEMED_BONUS");
local LOC_SCREEN_TITLE:string = Locale.Lookup("LOC_GREAT_WORKS_SCREEN_TITLE");
local LOC_ORGANIZE_GREAT_WORKS:string = Locale.Lookup("LOC_GREAT_WORKS_ORGANIZE_GREAT_WORKS");

local DATA_FIELD_SLOT_CACHE:string = "SlotCache";
local DATA_FIELD_GREAT_WORK_IM:string = "GreatWorkIM";
local DATA_FIELD_TOURISM_YIELD:string = "TourismYield";
local DATA_FIELD_THEME_BONUS_IM:string = "ThemeBonusIM";

local YIELD_FONT_ICONS:table = {
	YIELD_FOOD				= "[ICON_FoodLarge]",
	YIELD_PRODUCTION		= "[ICON_ProductionLarge]",
	YIELD_GOLD				= "[ICON_GoldLarge]",
	YIELD_SCIENCE			= "[ICON_ScienceLarge]",
	YIELD_CULTURE			= "[ICON_CultureLarge]",
	YIELD_FAITH				= "[ICON_FaithLarge]",
	TourismYield			= "[ICON_TourismLarge]"
};

local DEFAULT_GREAT_WORKS_ICONS:table = {
	GREATWORKSLOT_WRITING	= "ICON_GREATWORKOBJECT_WRITING",
	GREATWORKSLOT_PALACE	= "ICON_GREATWORKOBJECT_SCULPTURE",
	GREATWORKSLOT_ART		= "ICON_GREATWORKOBJECT_PORTRAIT",
	GREATWORKSLOT_CATHEDRAL	= "ICON_GREATWORKOBJECT_RELIGIOUS",
	GREATWORKSLOT_ARTIFACT	= "ICON_GREATWORKOBJECT_ARTIFACT_ERA_ANCIENT",
	GREATWORKSLOT_MUSIC		= "ICON_GREATWORKOBJECT_MUSIC",
	GREATWORKSLOT_RELIC		= "ICON_GREATWORKOBJECT_RELIC"
};

local m_during_move:boolean = false;
local m_dest_building:number = 0;
local m_dest_city;
local m_isLocalPlayerTurn:boolean = true;

-- ===========================================================================
--	SCREEN VARIABLES
-- ===========================================================================
local m_FirstGreatWork:table = nil;
local m_GreatWorkYields:table = nil;
local m_GreatWorkSelected:table = nil;
local m_GreatWorkBuildings:table = nil;
local m_GreatWorkSlotsIM:table = InstanceManager:new("GreatWorkSlot", "TopControl", Controls.GreatWorksStack);
local m_TotalResourcesIM:table = InstanceManager:new("AgregateResource", "Resource", Controls.TotalResources);
local m_ToggleGreatWorksId;


-- ===========================================================================
--	PLAYER VARIABLES
-- ===========================================================================
local m_LocalPlayer:table;
local m_LocalPlayerID:number;

-- ===========================================================================
--	Called every time screen is shown
-- ===========================================================================
function UpdatePlayerData()
	m_LocalPlayerID = Game.GetLocalPlayer();
	if m_LocalPlayerID ~= -1 then
		m_LocalPlayer = Players[m_LocalPlayerID];
	end
end

-- ===========================================================================
--	Called every time screen is shown
-- ===========================================================================
function UpdateGreatWorks()
	
	m_FirstGreatWork = nil;
	m_GreatWorkSelected = nil;
	m_GreatWorkSlotsIM:ResetInstances();
	Controls.MovingOverlay:SetHide(true);
	Controls.PlacingContainer:SetHide(true);
	Controls.PlacingTitle:SetText(LOC_ORGANIZE_GREAT_WORKS);
	Controls.HeaderStatsContainer:SetHide(false);

	if (m_LocalPlayer == nil) then
		return;
	end

	m_GreatWorkYields = {};
	m_GreatWorkBuildings = {};
	local numGreatWorks:number = 0;
	local numDisplaySpaces:number = 0;

	local pCities:table = m_LocalPlayer:GetCities();
	for i, pCity in pCities:Members() do
		if pCity ~= nil and pCity:GetOwner() == m_LocalPlayerID then
			local pCityBldgs:table = pCity:GetBuildings();
			for buildingInfo in GameInfo.Buildings() do
				local buildingIndex:number = buildingInfo.Index;
				local buildingType:string = buildingInfo.BuildingType;
				if(pCityBldgs:HasBuilding(buildingIndex)) then
					local numSlots:number = pCityBldgs:GetNumGreatWorkSlots(buildingIndex);
					if (numSlots ~= nil and numSlots > 0) then
						local instance:table = m_GreatWorkSlotsIM:GetInstance();
						local greatWorks:number = PopulateGreatWorkSlot(instance, pCity, pCityBldgs, buildingInfo);
						table.insert(m_GreatWorkBuildings, {Instance=instance, Type=buildingType, Index=buildingIndex, CityBldgs=pCityBldgs});
						numDisplaySpaces = numDisplaySpaces + pCityBldgs:GetNumGreatWorkSlots(buildingIndex);
						numGreatWorks = numGreatWorks + greatWorks;
					end
				end
			end
		end
	end

	Controls.NumGreatWorks:SetText(numGreatWorks);
	Controls.NumDisplaySpaces:SetText(numDisplaySpaces);

	-- Realize stack and scrollbar
	Controls.GreatWorksStack:CalculateSize();
	Controls.GreatWorksStack:ReprocessAnchoring();
	Controls.GreatWorksScrollPanel:CalculateInternalSize();
	Controls.GreatWorksScrollPanel:ReprocessAnchoring();

	m_TotalResourcesIM:ResetInstances();

	if table.count(m_GreatWorkYields) > 0 then
		table.sort(m_GreatWorkYields, function(a,b) return a.Name < b.Name; end);

		for _, data in ipairs(m_GreatWorkYields) do
			local instance:table = m_TotalResourcesIM:GetInstance();
			instance.Resource:SetText(data.Icon .. data.Value);
			instance.Resource:SetToolTipString(data.Name);
		end

		Controls.TotalResources:CalculateSize();
		Controls.TotalResources:ReprocessAnchoring();
		Controls.ProvidingLabel:SetOffsetX(Controls.TotalResources:GetOffsetX() + Controls.TotalResources:GetSizeX() + PADDING_PROVIDING_LABEL);
		Controls.ProvidingLabel:SetHide(false);
	else
		Controls.ProvidingLabel:SetHide(true);
	end

	-- Hide "View Gallery" button if we don't have a single great work
	Controls.ViewGallery:SetHide(m_FirstGreatWork == nil);
end

function PopulateGreatWorkSlot(instance:table, pCity:table, pCityBldgs:table, pBuildingInfo:table)
	
	instance.DefaultBG:SetHide(false);
	instance.DisabledBG:SetHide(true);
	instance.HighlightedBG:SetHide(true);
	instance.DefaultBG:RegisterCallback(Mouse.eLClick, function() end); -- clear callback
	instance.HighlightedBG:RegisterCallback(Mouse.eLClick, function() end); -- clear callback

	local buildingType:string = pBuildingInfo.BuildingType;
	local buildingIndex:number = pBuildingInfo.Index;
	local themeDescription = GetThemeDescription(buildingType);
	instance.CityName:SetText(Locale.Lookup(pCity:GetName()));
	instance.BuildingName:SetText(Locale.ToUpper(Locale.Lookup(pBuildingInfo.Name)));

	-- Ensure we have Instance Managers for the great works
	local greatWorkIM:table = instance[DATA_FIELD_GREAT_WORK_IM];
	if(greatWorkIM == nil) then
		greatWorkIM = InstanceManager:new("GreatWork", "TopControl", instance.GreatWorks);
		instance[DATA_FIELD_GREAT_WORK_IM] = greatWorkIM;
	else
		greatWorkIM:ResetInstances();
	end

	local index:number = 0;
	local numGreatWorks:number = 0;
	local numThemedGreatWorks:number = 0;
	local instanceCache:table = {};
	local firstGreatWork:table = nil;
	local numSlots:number = pCityBldgs:GetNumGreatWorkSlots(buildingIndex);

	if (numSlots ~= nil and numSlots > 0) then
		for _:number=0, numSlots - 1 do
			local instance:table = greatWorkIM:GetInstance();
			local greatWorkIndex:number = pCityBldgs:GetGreatWorkInSlot(buildingIndex, index);
			local greatWorkSlotType:number = pCityBldgs:GetGreatWorkSlotType(buildingIndex, index);
			local greatWorkSlotString:string = GameInfo.GreatWorkSlotTypes[greatWorkSlotType].GreatWorkSlotType;

			PopulateGreatWork(instance, pCityBldgs, pBuildingInfo, index, greatWorkIndex, greatWorkSlotString);
			index = index + 1;
			instanceCache[index] = instance;
			if greatWorkIndex ~= -1 then
				numGreatWorks = numGreatWorks + 1;
				local greatWorkType:number = pCityBldgs:GetGreatWorkTypeFromIndex(greatWorkIndex);
				local greatWorkInfo:table = GameInfo.GreatWorks[greatWorkType];
				if firstGreatWork == nil then
					firstGreatWork = greatWorkInfo;
				end
				if greatWorkInfo ~= nil and GreatWorkFitsTheme(pCityBldgs, pBuildingInfo, greatWorkIndex, greatWorkInfo) then
					numThemedGreatWorks = numThemedGreatWorks + 1;
				end
			end
		end                            

		if firstGreatWork ~= nil and themeDescription ~= nil then
			local slotTypeIcon:string = "ICON_" .. firstGreatWork.GreatWorkObjectType;
			if firstGreatWork.GreatWorkObjectType == "GREATWORKOBJECT_ARTIFACT" then
				slotTypeIcon = slotTypeIcon .. "_" .. firstGreatWork.EraType;
			end

			local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(slotTypeIcon, SIZE_SLOT_TYPE_ICON);
			if(textureSheet == nil or textureSheet == "") then
				UI.DataError("Could not find slot type icon in PopulateGreatWorkSlot: icon=\""..slotTypeIcon.."\", iconSize="..tostring(SIZE_SLOT_TYPE_ICON));
			else
				for i:number=0, numSlots - 1 do
					local slotIndex:number = index - i;
					instanceCache[slotIndex].SlotTypeIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
				end
			end
		end
	end

	instance[DATA_FIELD_SLOT_CACHE] = instanceCache;

	local numSlots:number = table.count(instanceCache);
	if(numSlots > 1) then
		local slotRange:number = MAX_NUM_SLOTS - 2;
		local paddingRange:number = MAX_PADDING_SLOTS - MIN_PADDING_SLOTS;
		local finalPadding:number = ((MAX_NUM_SLOTS - numSlots) * paddingRange / slotRange) + MIN_PADDING_SLOTS;
		instance.GreatWorks:SetPadding(finalPadding);
	else
		instance.GreatWorks:SetPadding(0);
	end

	-- Ensure we have Instance Managers for the theme bonuses
	local themeBonusIM:table = instance[DATA_FIELD_THEME_BONUS_IM];
	if(themeBonusIM == nil) then
		themeBonusIM = InstanceManager:new("Resource", "Resource", instance.ThemeBonuses);
		instance[DATA_FIELD_THEME_BONUS_IM] = themeBonusIM;
	else
		themeBonusIM:ResetInstances();
	end

	if numGreatWorks == 0 then
		if themeDescription ~= nil then
			instance.ThemingLabel:SetText(Locale.Lookup("LOC_GREAT_WORKS_THEME_BONUS_PROGRESS", numThemedGreatWorks, numSlots));
			instance.ThemingLabel:SetToolTipString(themeDescription);
		end
	else
		instance.ThemingLabel:SetText("");
		instance.ThemingLabel:SetToolTipString("");
		if pCityBldgs:IsBuildingThemedCorrectly(buildingIndex) then
			instance.ThemingLabel:SetText(LOC_THEME_BONUS);
			if m_during_move then
				if buildingIndex == m_dest_building then
                    if (m_dest_city == pCityBldgs:GetCity():GetID()) then
                        UI.PlaySound("UI_GREAT_WORKS_BONUS_ACHIEVED");
                    end
				end
			end
		else
			if themeDescription ~= nil then
                -- if we're being called due to moving a work
				if numSlots > 1 then
					instance.ThemingLabel:SetText(Locale.Lookup("LOC_GREAT_WORKS_THEME_BONUS_PROGRESS", numThemedGreatWorks, numSlots));
					if m_during_move then
						if buildingIndex == m_dest_building then
                            if (m_dest_city == pCityBldgs:GetCity():GetID()) then
                                if numThemedGreatWorks == 2 then
                                    UI.PlaySound("UI_GreatWorks_Bonus_Increased");
                                end
                            end
						end
					end
				end

				if instance.ThemingLabel:GetText() ~= "" then
					instance.ThemingLabel:SetToolTipString(themeDescription);
				end
			end
		end
	end

	for row in GameInfo.Yields() do
		local yieldValue:number = pCityBldgs:GetBuildingYieldFromGreatWorks(row.Index, buildingIndex);
		if yieldValue > 0 then
			AddYield(themeBonusIM:GetInstance(), Locale.Lookup(row.Name), YIELD_FONT_ICONS[row.YieldType], yieldValue);
		end
	end

	local regularTourism:number = pCityBldgs:GetBuildingTourismFromGreatWorks(false, buildingIndex);
	local religionTourism:number = pCityBldgs:GetBuildingTourismFromGreatWorks(true, buildingIndex);
	local totalTourism:number = regularTourism + religionTourism;

	if totalTourism > 0 then
		AddYield(themeBonusIM:GetInstance(), LOC_TOURISM, YIELD_FONT_ICONS[DATA_FIELD_TOURISM_YIELD], totalTourism);
	end

	instance.ThemeBonuses:CalculateSize();
	instance.ThemeBonuses:ReprocessAnchoring();

	return numGreatWorks;
end

-- IMPORTANT: This logic is largely derived from GetGreatWorkTooltip() - if you make an update here, make sure to update that function as well
function GreatWorkFitsTheme(pCityBldgs:table, pBuildingInfo:table, greatWorkIndex:number, greatWorkInfo:table)
	local firstGreatWork:number = GetFirstGreatWorkInBuilding(pCityBldgs, pBuildingInfo);
	if firstGreatWork < 0 then
		return false;
	end

	local firstGreatWorkObjectTypeID:number = pCityBldgs:GetGreatWorkTypeFromIndex(firstGreatWork);
	local firstGreatWorkObjectType:string = GameInfo.GreatWorks[firstGreatWorkObjectTypeID].GreatWorkObjectType;
	
	if pCityBldgs:IsBuildingThemedCorrectly(GameInfo.Buildings[pBuildingInfo.BuildingType].Index) then
		return true;
	else
		if pBuildingInfo.BuildingType == "BUILDING_MUSEUM_ART" then

			if firstGreatWork == greatWorkIndex then
				return true;
			elseif firstGreatWorkObjectType == greatWorkInfo.GreatWorkObjectType then
				return pCityBldgs:GetCreatorNameFromIndex(firstGreatWork) ~= pCityBldgs:GetCreatorNameFromIndex(greatWorkIndex);
			else
				return false;
			end
		elseif pBuildingInfo.BuildingType == "BUILDING_MUSEUM_ARTIFACT" then

			if firstGreatWork == greatWorkIndex then
				return true;
			else
				if greatWorkInfo.EraType ~= GameInfo.GreatWorks[firstGreatWorkObjectTypeID].EraType then
					return false;
				else
					local greatWorkPlayer:number = Game.GetGreatWorkPlayer(greatWorkIndex);
					local greatWorks:table = GetGreatWorksInBuilding(pCityBldgs, pBuildingInfo);
					
					-- Find duplicates for theming description
					local hash:table = {}
					local duplicates:table = {}
					for _,index in ipairs(greatWorks) do
						local gwPlayer:number = Game.GetGreatWorkPlayer(index);
						if (not hash[gwPlayer]) then
							hash[gwPlayer] = true;
						else
							table.insert(duplicates, gwPlayer);
						end
					end

					return table.count(duplicates) == 0;
				end
			end
		end
	end
end

function GetGreatWorkIcon(greatWorkInfo:table)

	local greatWorkIcon:string;
	
	if greatWorkInfo.GreatWorkObjectType == GREAT_WORK_ARTIFACT_TYPE then
		local greatWorkType:string = greatWorkInfo.GreatWorkType;
		greatWorkType = greatWorkType:gsub("GREATWORK_ARTIFACT_", "");
		local greatWorkID:number = tonumber(greatWorkType);
		greatWorkID = ((greatWorkID - 1) % NUM_ARIFACT_TEXTURES) + 1;
		greatWorkIcon = "ICON_GREATWORK_ARTIFACT_" .. greatWorkID;
	elseif greatWorkInfo.GreatWorkObjectType == GREAT_WORK_RELIC_TYPE then
		local greatWorkType:string = greatWorkInfo.GreatWorkType;
		greatWorkType = greatWorkType:gsub("GREATWORK_RELIC_", "");
		local greatWorkID:number = tonumber(greatWorkType);
		greatWorkID =  ((greatWorkID - 1) % NUM_RELIC_TEXTURES) + 1;
		greatWorkIcon = "ICON_GREATWORK_RELIC_" .. greatWorkID;
	else
		greatWorkIcon = "ICON_" .. greatWorkInfo.GreatWorkType;
	end

	local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(greatWorkIcon, SIZE_GREAT_WORK_ICON);
	if(textureSheet == nil or textureSheet == "") then
		UI.DataError("Could not find slot type icon in GetGreatWorkIcon: icon=\""..greatWorkIcon.."\", iconSize="..tostring(SIZE_GREAT_WORK_ICON));
	end

	return textureOffsetX, textureOffsetY, textureSheet;
end

function GetThemeDescription(buildingType:string)
    local eBuilding = m_LocalPlayer:GetCulture():GetAutoThemedBuilding();
	if (GameInfo.Buildings[buildingType].Index == eBuilding) then
		return Locale.Lookup("LOC_BUILDING_THEMINGBONUS_FULL_MUSEUM");
	else
		for row in GameInfo.Building_GreatWorks() do
			if row.BuildingType == buildingType then
				if row.ThemingBonusDescription ~= nil then
					return Locale.Lookup(row.ThemingBonusDescription);
				end		
			end
		end
	end
	return nil;
end

function PopulateGreatWork(instance:table, pCityBldgs:table, pBuildingInfo:table, slotIndex:number, greatWorkIndex:number, slotType:string)
	
	local buildingIndex:number = pBuildingInfo.Index;
	local slotTypeIcon:string = DEFAULT_GREAT_WORKS_ICONS[slotType];
	local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(slotTypeIcon, SIZE_SLOT_TYPE_ICON);
	if(textureSheet == nil or textureSheet == "") then
		UI.DataError("Could not find slot type icon in PopulateGreatWork: icon=\""..slotTypeIcon.."\", iconSize="..tostring(SIZE_SLOT_TYPE_ICON));
	else
		instance.SlotTypeIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
	end
	
	if greatWorkIndex == -1 then
		instance.GreatWorkIcon:SetHide(true);

		local validWorks:string = "";
		for row in GameInfo.GreatWork_ValidSubTypes() do
			if slotType == row.GreatWorkSlotType then
				if validWorks ~= "" then
					validWorks = validWorks .. "[NEWLINE]";
				end
				validWorks = validWorks .. Locale.Lookup("LOC_" .. row.GreatWorkObjectType);
			end
		end

		instance.EmptySlot:RegisterCallback(Mouse.eLClick, function() end); -- clear callback
		instance.EmptySlot:SetToolTipString(Locale.Lookup("LOC_GREAT_WORKS_EMPTY_TOOLTIP", validWorks));
	else
		instance.GreatWorkIcon:SetHide(false);

		local greatWorkType:number = pCityBldgs:GetGreatWorkTypeFromIndex(greatWorkIndex);
		local textureOffsetX:number, textureOffsetY:number, textureSheet:string = GetGreatWorkIcon(GameInfo.GreatWorks[greatWorkType]);
		instance.GreatWorkIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
		instance.GreatWorkIcon:SetOffsetVal(-13,-2);

		instance.EmptySlot:SetToolTipString(GetGreatWorkTooltip(pCityBldgs, greatWorkIndex, greatWorkType, slotIndex, pBuildingInfo));
		instance.EmptySlot:RegisterCallback(Mouse.eLClick, function() OnClickGreatWork(instance.GreatWorkIcon, pCityBldgs, buildingIndex, greatWorkIndex, slotIndex); end);

		if m_FirstGreatWork == nil then
			m_FirstGreatWork = {Index=greatWorkIndex, Building=buildingIndex, CityBldgs=pCityBldgs};
		end
	end
	instance.EmptySlotHighlight:SetHide(true);
	
end

-- IMPORTANT: This logic is largely duplicated in GreatWorkFitsTheme() - if you make an update here, make sure to update that function as well
function GetGreatWorkTooltip(pCityBldgs:table, greatWorkIndex:number, greatWorkType:number, slotIndex:number, pBuildingInfo:table)
	local themeText:string;
	local tooltipText:string;
	local greatWorkTypeName:string;
	local greatWorkInfo:table = GameInfo.GreatWorks[greatWorkType];
	local greatWorkName:string = Locale.Lookup(greatWorkInfo.Name);
	local greatWorkCreator:string = Locale.Lookup(pCityBldgs:GetCreatorNameFromIndex(greatWorkIndex));
	local greatWorkCreationDate:string = Calendar.MakeDateStr(pCityBldgs:GetTurnFromIndex(greatWorkIndex), GameConfiguration.GetCalendarType(), GameConfiguration.GetGameSpeedType(), false);
	local yieldType:string = GameInfo.GreatWork_YieldChanges[greatWorkInfo.GreatWorkType].YieldType;
	local yieldValue:number = GameInfo.GreatWork_YieldChanges[greatWorkInfo.GreatWorkType].YieldChange;
	local greatWorkYields:string = YIELD_FONT_ICONS[yieldType] .. yieldValue .. " " .. YIELD_FONT_ICONS[DATA_FIELD_TOURISM_YIELD] .. greatWorkInfo.Tourism;
	local buildingName:string = Locale.Lookup(GameInfo.Buildings[pBuildingInfo.BuildingType].Name);
	
	if greatWorkInfo.EraType ~= nil then
		greatWorkTypeName = Locale.Lookup("LOC_" .. greatWorkInfo.GreatWorkObjectType .. "_" .. greatWorkInfo.EraType);
	else
		greatWorkTypeName = Locale.Lookup("LOC_" .. greatWorkInfo.GreatWorkObjectType);
	end

	if GetThemeDescription(pBuildingInfo.BuildingType) ~= nil then
		if greatWorkInfo.GreatWorkObjectType == "GREATWORKOBJECT_ARTIFACT" then
			tooltipText = Locale.Lookup("LOC_GREAT_WORKS_ARTIFACT_TOOLTIP_THEMABLE", greatWorkName, greatWorkTypeName, greatWorkCreator, greatWorkCreationDate, greatWorkYields);
		else
			tooltipText = Locale.Lookup("LOC_GREAT_WORKS_TOOLTIP_THEMABLE", greatWorkName, greatWorkTypeName, greatWorkCreator, greatWorkCreationDate, greatWorkYields);
		end

		local firstGreatWork:number = GetFirstGreatWorkInBuilding(pCityBldgs, pBuildingInfo);
		if firstGreatWork < 0 then
			return tooltipText;
		end

		local firstGreatWorkObjectTypeID:number = pCityBldgs:GetGreatWorkTypeFromIndex(firstGreatWork);
		local firstGreatWorkObjectType:string = GameInfo.GreatWorks[firstGreatWorkObjectTypeID].GreatWorkObjectType;
		
		if pCityBldgs:IsBuildingThemedCorrectly(GameInfo.Buildings[pBuildingInfo.BuildingType].Index) then
			themeText = Locale.Lookup("LOC_GREAT_WORKS_ART_MATCHED_THEME", buildingName);
		else
			if pBuildingInfo.BuildingType == "BUILDING_MUSEUM_ART" then

				if firstGreatWork == greatWorkIndex then
					themeText = Locale.Lookup("LOC_GREAT_WORKS_ART_THEME_SINGLE", Locale.Lookup("LOC_" .. firstGreatWorkObjectType));
				elseif firstGreatWorkObjectType == greatWorkInfo.GreatWorkObjectType then
					local firstGreatWorkCreator:string = Locale.Lookup(pCityBldgs:GetCreatorNameFromIndex(firstGreatWork));

					if firstGreatWorkCreator == greatWorkCreator then
						themeText = Locale.Lookup("LOC_GREAT_WORKS_ART_THEME_DUPLICATE_ARTIST", Locale.Lookup("LOC_" .. firstGreatWorkObjectType));
					else
						themeText = Locale.Lookup("LOC_GREAT_WORKS_ART_THEME_DUAL", Locale.Lookup("LOC_" .. firstGreatWorkObjectType));
					end
				else
					themeText = Locale.Lookup("LOC_GREAT_WORKS_MISMATCHED_THEME",  greatWorkTypeName, Locale.Lookup("LOC_" .. firstGreatWorkObjectType .. "_PLURAL"));
				end
			elseif pBuildingInfo.BuildingType == "BUILDING_MUSEUM_ARTIFACT" then

				local artifactEraName:string = Locale.Lookup("LOC_" .. greatWorkInfo.GreatWorkObjectType .. "_" .. greatWorkInfo.EraType);
				if firstGreatWork == greatWorkIndex then
					themeText = Locale.Lookup("LOC_GREAT_WORKS_ART_THEME_SINGLE", artifactEraName);
				else
					local firstArtifactEraName:string = Locale.Lookup("LOC_" .. firstGreatWorkObjectType .. "_" .. GameInfo.GreatWorks[firstGreatWorkObjectTypeID].EraType .. "_PLURAL");

					if greatWorkInfo.EraType ~= GameInfo.GreatWorks[firstGreatWorkObjectTypeID].EraType then
						themeText = Locale.Lookup("LOC_GREAT_WORKS_MISMATCHED_ERA",  artifactEraName, firstArtifactEraName);
					else
						local greatWorkPlayer:number = Game.GetGreatWorkPlayer(greatWorkIndex);
						local greatWorks:table = GetGreatWorksInBuilding(pCityBldgs, pBuildingInfo);
						
						-- Find duplicates for theming description
						local hash:table = {}
						local duplicates:table = {}
						for _,index in ipairs(greatWorks) do
							local gwPlayer:number = Game.GetGreatWorkPlayer(index);
							if (not hash[gwPlayer]) then
								hash[gwPlayer] = true;
							else
								table.insert(duplicates, gwPlayer);
							end
						end

						if table.count(duplicates) > 0 then
							themeText = Locale.Lookup("LOC_GREAT_WORKS_DUPLICATE_ARTIFACT_CIVS", PlayerConfigurations[duplicates[1]]:GetCivilizationShortDescription(), firstArtifactEraName);
						end
					end
				end
			end
		end
		
		if themeText ~= nil then
			tooltipText = tooltipText .. "[NEWLINE][NEWLINE]" .. themeText;
		end
	else
		if greatWorkInfo.GreatWorkObjectType == "GREATWORKOBJECT_ARTIFACT" then
			tooltipText = Locale.Lookup("LOC_GREAT_WORKS_ARTIFACT_TOOLTIP", greatWorkName, greatWorkTypeName, greatWorkCreator, greatWorkCreationDate, greatWorkYields);
		else
			tooltipText = Locale.Lookup("LOC_GREAT_WORKS_TOOLTIP", greatWorkName, greatWorkTypeName, greatWorkCreator, greatWorkCreationDate, greatWorkYields);
		end
	end

	return tooltipText;
end

function GetFirstGreatWorkInBuilding(pCityBldgs:table, pBuildingInfo:table)
	local index:number = 0;
	local buildingIndex:number = pBuildingInfo.Index;
	local numSlots:number = pCityBldgs:GetNumGreatWorkSlots(buildingIndex);
	for _:number=0, numSlots - 1 do
		local greatWorkIndex:number = pCityBldgs:GetGreatWorkInSlot(buildingIndex, index);
		if greatWorkIndex ~= -1 then
			return greatWorkIndex;
		end
		index = index + 1;
	end
	return -1;
end

function GetGreatWorksInBuilding(pCityBldgs:table, pBuildingInfo:table)
	local index:number = 0;
	local results:table = {};
	local buildingIndex:number = pBuildingInfo.Index;
	local numSlots:number = pCityBldgs:GetNumGreatWorkSlots(buildingIndex);
	for _:number=0, numSlots - 1 do
		local greatWorkIndex:number = pCityBldgs:GetGreatWorkInSlot(buildingIndex, index);
		if greatWorkIndex ~= -1 then
			table.insert(results, greatWorkIndex);
		end
		index = index + 1;
	end
	return results;
end

function AddYield(instance:table, yieldName:string, yieldIcon:string, yieldValue:number)
	local bFoundYield:boolean = false;
	for _,data in ipairs(m_GreatWorkYields) do
		if data.Name == yieldName then
			data.Value = data.Value + yieldValue;
			bFoundYield = true;
			break;
		end
	end
	if bFoundYield == false then
		table.insert(m_GreatWorkYields, {Name=yieldName, Icon=yieldIcon, Value=yieldValue});
	end
	instance.Resource:SetText(yieldIcon .. yieldValue);
	instance.Resource:SetToolTipString(yieldName);
end

function OnClickGreatWork(greatWorkIcon:table, pCityBldgs:table, buildingIndex:number, greatWorkIndex:number, slotIndex:number)

	-- Don't allow moving great works unless it's the local player's turn
	if not m_isLocalPlayerTurn then return; end

	-- Don't allow moving artifacts if the museum is not full
	if not CanMoveWorkAtAll(pCityBldgs, buildingIndex, slotIndex) then
		return;
	end

	-- If we're already moving a great work, attempt to swap great works
	if m_GreatWorkSelected ~= nil then
		local srcSlot:number = m_GreatWorkSelected.Slot;
		local srcBldgs:table = m_GreatWorkSelected.CityBldgs;
		local srcBuilding:number = m_GreatWorkSelected.Building;

		if CanMoveGreatWork(srcBldgs, srcBuilding, srcSlot,  pCityBldgs, buildingIndex, slotIndex) then
			OnClickSlot(pCityBldgs, buildingIndex, slotIndex);
		end
		return;
	end
	
	-- TODO: Check to make sure player can move this great work
	greatWorkIcon:SetHide(true);
	
	local greatWorkType:number = pCityBldgs:GetGreatWorkTypeFromIndex(greatWorkIndex);
	local textureOffsetX:number, textureOffsetY:number, textureSheet:string = GetGreatWorkIcon(GameInfo.GreatWorks[greatWorkType]);
	Controls.MovingIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
	Controls.PlacingIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);

	-- Subscribe to updates to keep great work icon attached to mouse
	Controls.MovingOverlay:SetHide(false);
	m_GreatWorkSelected = {Icon=Controls.MovingIcon, Index=greatWorkIndex, Slot=slotIndex, Building=buildingIndex, CityBldgs=pCityBldgs};
	m_GreatWorkSelected.Icon:SetOffsetVal(UIManager:GetMousePos());
	ContextPtr:SetUpdate(OnMouseMove);
	OnMouseMove();

	-- Set placing label and details
	Controls.PlacingContainer:SetHide(false);
	Controls.HeaderStatsContainer:SetHide(true);
	Controls.PlacingTitle:SetText(LOC_PLACING);
	Controls.PlacingName:SetText(Locale.ToUpper(Locale.Lookup(GameInfo.GreatWorks[greatWorkType].Name)));
	Controls.PlacingIcon:SetOffsetX(Controls.PlacingTitle:GetOffsetX() + Controls.PlacingTitle:GetSizeX() + PADDING_PLACING_ICON);
	Controls.PlacingName:SetOffsetX(Controls.PlacingIcon:GetOffsetX() + Controls.PlacingIcon:GetSizeX() + PADDING_PLACING_DETAILS);
	Controls.ViewGreatWork:SetSizeX(Controls.ViewGreatWork:GetTextControl():GetSizeX() + PADDING_BUTTON_EDGES);
	Controls.ViewGreatWork:SetOffsetX(PADDING_BUTTON_EDGES);

	for _:number, destination:table in ipairs(m_GreatWorkBuildings) do
		local firstValidSlot:number = -1;
		local instance:table = destination.Instance;
		local dstBuilding:number = destination.Index;
		local dstBldgs:table = destination.CityBldgs;
		local slotCache:table = instance[DATA_FIELD_SLOT_CACHE];
		local numSlots:number = dstBldgs:GetNumGreatWorkSlots(dstBuilding);
		for index:number = 0, numSlots - 1 do
			if CanMoveGreatWork(pCityBldgs, buildingIndex, slotIndex, dstBldgs, dstBuilding, index) then
				if firstValidSlot == -1 then
					firstValidSlot = index;
				end
				-- Cache index in local var to ensure it gets boxed in lambda callback
				local tmpIndex:number = index;
				local clickSlotCallbak:ifunction = function() OnClickSlot(dstBldgs, dstBuilding, tmpIndex); end

				local slotInstance:table = slotCache[index + 1];
				slotInstance.EmptySlot:RegisterCallback(Mouse.eLClick, clickSlotCallbak);
				slotInstance.EmptySlotHighlight:RegisterCallback(Mouse.eLClick, clickSlotCallbak);
				slotInstance.EmptySlotHighlight:SetHide(false);
			end
		end

		if firstValidSlot ~= -1 then
			local clickSlotCallbak:ifunction = function() OnClickSlot(dstBldgs, dstBuilding, firstValidSlot); end
			instance.DefaultBG:RegisterCallback(Mouse.eLClick, clickSlotCallbak);
			instance.HighlightedBG:RegisterCallback(Mouse.eLClick, clickSlotCallbak);
            UI.PlaySound("UI_GreatWorks_Pick_Up");
		end

		instance.HighlightedBG:SetHide(firstValidSlot == -1);
		instance.DefaultBG:SetHide(firstValidSlot == -1);
		instance.DisabledBG:SetHide(firstValidSlot ~= -1);
	end
end

function CanMoveWorkAtAll(srcBldgs:table, srcBuilding:number, srcSlot:number)
	local srcGreatWork:number = srcBldgs:GetGreatWorkInSlot(srcBuilding, srcSlot);
	local srcGreatWorkType:number = srcBldgs:GetGreatWorkTypeFromIndex(srcGreatWork);
	local srcGreatWorkObjectType:string = GameInfo.GreatWorks[srcGreatWorkType].GreatWorkObjectType;

	-- Don't allow moving artifacts if the museum is not full
	if (srcGreatWorkObjectType == "GREATWORKOBJECT_ARTIFACT") then
		local numSlots:number = srcBldgs:GetNumGreatWorkSlots(srcBuilding);
		for index:number = 0, numSlots - 1 do
			local greatWorkIndex:number = srcBldgs:GetGreatWorkInSlot(srcBuilding, index);
			if (greatWorkIndex == -1) then
				local cannotMoveWorkDialog = PopupDialog:new("CannotMoveWork");
				cannotMoveWorkDialog:ShowOkDialog(Locale.Lookup("LOC_GREAT_WORKS_ARTIFACT_LOCKED_FROM_MOVE"));
				return false;
			end
		end
	end

	-- Don't allow moving art that has been recently created
	if (srcGreatWorkObjectType == "GREATWORKOBJECT_SCULPTURE" or
	    srcGreatWorkObjectType == "GREATWORKOBJECT_LANDSCAPE" or
		srcGreatWorkObjectType == "GREATWORKOBJECT_PORTRAIT" or
		srcGreatWorkObjectType == "GREATWORKOBJECT_RELIGIOUS") then

		local iTurnCreated:number = srcBldgs:GetTurnFromIndex(srcGreatWork);
		local iCurrentTurn:number = Game.GetCurrentGameTurn();
		local iTurnsBeforeMove:number = GlobalParameters.GREATWORK_ART_LOCK_TIME or 10;
		local iTurnsToWait = iTurnCreated + iTurnsBeforeMove - iCurrentTurn;
		if (iTurnsToWait > 0) then
		    local cannotMoveWorkDialog = PopupDialog:new("CannotMoveWork");
            cannotMoveWorkDialog:ShowOkDialog(Locale.Lookup("LOC_GREAT_WORKS_LOCKED_FROM_MOVE", iTurnsToWait));
			return false;
		end
	end

	return true;
end

function CanMoveToSlot(destBldgs:table, destBuilding:number)

	-- Don't allow moving artifacts if the museum is not full
	local srcGreatWorkType:number = m_GreatWorkSelected.CityBldgs:GetGreatWorkTypeFromIndex(m_GreatWorkSelected.Index);
	local srcGreatWorkObjectType:string = GameInfo.GreatWorks[srcGreatWorkType].GreatWorkObjectType;
	if (srcGreatWorkObjectType ~= "GREATWORKOBJECT_ARTIFACT") then
	    return true;
	end

	-- Don't allow moving artifacts if the museum is not full
	local numSlots:number = destBldgs:GetNumGreatWorkSlots(destBuilding);
	for index:number = 0, numSlots - 1 do
		local greatWorkIndex:number = destBldgs:GetGreatWorkInSlot(destBuilding, index);
		if (greatWorkIndex == -1) then
			return false;
		end
	end

	return true;
end

function CanMoveGreatWork(srcBldgs:table, srcBuilding:number, srcSlot:number, dstBldgs:table, dstBuilding:number, dstSlot:number)

	local srcGreatWork:number = srcBldgs:GetGreatWorkInSlot(srcBuilding, srcSlot);
	local srcGreatWorkType:number = srcBldgs:GetGreatWorkTypeFromIndex(srcGreatWork);
	local srcGreatWorkObjectType:string = GameInfo.GreatWorks[srcGreatWorkType].GreatWorkObjectType;

	local dstGreatWork:number = dstBldgs:GetGreatWorkInSlot(dstBuilding, dstSlot);
	local dstSlotType:number = dstBldgs:GetGreatWorkSlotType(dstBuilding, dstSlot);
	local dstSlotTypeString:string = GameInfo.GreatWorkSlotTypes[dstSlotType].GreatWorkSlotType;

	for row in GameInfo.GreatWork_ValidSubTypes() do
		-- Ensure source great work can be placed into destination slot
		if dstSlotTypeString == row.GreatWorkSlotType and srcGreatWorkObjectType == row.GreatWorkObjectType then
			if dstGreatWork == -1 then
				return true;
			else -- If destination slot has a great work, ensure it can be swapped to the source slot
				local srcSlotType:number = srcBldgs:GetGreatWorkSlotType(srcBuilding, srcSlot);
				local srcSlotTypeString:string = GameInfo.GreatWorkSlotTypes[srcSlotType].GreatWorkSlotType;

				local dstGreatWorkType:number = dstBldgs:GetGreatWorkTypeFromIndex(dstGreatWork);
				local dstGreatWorkObjectType:string = GameInfo.GreatWorks[dstGreatWorkType].GreatWorkObjectType;
				
				for row in GameInfo.GreatWork_ValidSubTypes() do
					if srcSlotTypeString == row.GreatWorkSlotType and dstGreatWorkObjectType == row.GreatWorkObjectType then
						return true;
					end
				end
			end
		end
	end
	return false;
end

function OnClickSlot(pCityBldgs:table, buildingIndex:number, slotIndex:number)
	print("moving great work ["..slotIndex.."] from "..Locale.Lookup(m_GreatWorkSelected.CityBldgs:GetCity():GetName()).." to "..Locale.Lookup(pCityBldgs:GetCity():GetName()));

	-- Don't allow moving artifacts to a museum that is not full
	if not CanMoveToSlot(pCityBldgs, buildingIndex, slotIndex) then
		return;
	end

	m_dest_building = buildingIndex;
    m_dest_city = pCityBldgs:GetCity():GetID();
	
	local tParameters = {};
	tParameters[PlayerOperations.PARAM_PLAYER_ONE] = Game.GetLocalPlayer();
	tParameters[PlayerOperations.PARAM_CITY_SRC] = m_GreatWorkSelected.CityBldgs:GetCity():GetID();
	tParameters[PlayerOperations.PARAM_CITY_DEST] = pCityBldgs:GetCity():GetID();
	tParameters[PlayerOperations.PARAM_GREAT_WORK_INDEX] = m_GreatWorkSelected.Index;
	tParameters[PlayerOperations.PARAM_BUILDING_SRC] = m_GreatWorkSelected.Building;
	tParameters[PlayerOperations.PARAM_BUILDING_DEST] = buildingIndex;
	tParameters[PlayerOperations.PARAM_SLOT] = slotIndex;
	UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.MOVE_GREAT_WORK, tParameters);

    UI.PlaySound("UI_GreatWorks_Put_Down");

	-- Clear the transfer, but don't do an update, that will be handled when the move completes.
	m_GreatWorkSelected = nil;
	ContextPtr:ClearUpdate();
end

function ClearGreatWorkTransfer()
	m_GreatWorkSelected = nil;
	ContextPtr:ClearUpdate();
	UpdateData();
end

-- ===========================================================================
--	Update player data and refresh the display state
-- ===========================================================================
function UpdateData()
	UpdatePlayerData();
	UpdateGreatWorks();
end

-- ===========================================================================
--	Show / Hide
-- ===========================================================================
function Open()
	UpdateData();
	ContextPtr:SetHide(false);

	-- From Civ6_styles: FullScreenVignetteConsumer
	Controls.ScreenAnimIn:SetToBeginning();
	Controls.ScreenAnimIn:Play();
	LuaEvents.GreatWorks_OpenGreatWorks();
end

function Close()
	ContextPtr:SetHide(true);
	ContextPtr:ClearUpdate();
end
function ViewGreatWork(greatWorkData:table)
	local city:table = greatWorkData.CityBldgs:GetCity();
	local buildingID:number = greatWorkData.Building;
	local greatWorkIndex:number = greatWorkData.Index;
	LuaEvents.GreatWorksOverview_ViewGreatWork(city, buildingID, greatWorkIndex);
end

-- ===========================================================================
--	Game Event Callbacks
-- ===========================================================================
function OnShowScreen()
	Open();
	UI.PlaySound("UI_Screen_Open");
end

-- ===========================================================================
function OnHideScreen()
	Close();
	UI.PlaySound("UI_Screen_Close");
	LuaEvents.GreatWorks_CloseGreatWorks();
end

-- ===========================================================================
function OnInputHandler(pInputStruct:table)
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp and pInputStruct:GetKey() == Keys.VK_ESCAPE then
		if m_GreatWorkSelected ~= nil then
			ClearGreatWorkTransfer();
		else
			OnHideScreen();
		end
		return true;
	end
	return false;
end
-- ===========================================================================
function OnMouseMove()
	if m_GreatWorkSelected ~= nil then
		local mouseX:number, mouseY:number = UIManager:GetMousePos();
		local screenWidth:number, screenHeight:number = UIManager:GetScreenSizeVal();
		mouseX = mouseX - (screenWidth - 1024) / 2;
		mouseY = mouseY - (screenHeight - 768) / 2;
		m_GreatWorkSelected.Icon:SetOffsetVal(mouseX, mouseY);
	end
end
-- ===========================================================================
function OnViewGallery()
	if m_FirstGreatWork ~= nil then
		ViewGreatWork(m_FirstGreatWork);
		if m_GreatWorkSelected ~= nil then
			ClearGreatWorkTransfer();
		end
        UI.PlaySound("Play_GreatWorks_Gallery_Ambience");
	end
end
-- ===========================================================================
function OnViewGreatWork()
	if m_GreatWorkSelected ~= nil then
		ViewGreatWork(m_GreatWorkSelected);
		ClearGreatWorkTransfer();
        UI.PlaySound("Play_GreatWorks_Gallery_Ambience");
	end
end

------------------------------------------------------------------------------
-- A great work was moved.
function OnGreatWorkMoved(fromCityOwner, fromCityID, toCityOwner, toCityID, buildingID, greatWorkType)
	if (not ContextPtr:IsHidden() and (fromCityOwner == Game.GetLocalPlayer() or toCityOwner == Game.GetLocalPlayer())) then
        m_during_move = true;
		UpdateData();
        m_during_move = false;
	end
end

-- ===========================================================================
--	Hot Reload Related Events
-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden());
end
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID and contextTable["isHidden"] ~= nil and not contextTable["isHidden"] then
		Open();
	end
end

-- ===========================================================================
--	Input Hotkey Event
-- ===========================================================================
function OnInputActionTriggered( actionId )
	if actionId == m_ToggleGreatWorksId then
		if(ContextPtr:IsHidden()) then
			LuaEvents.LaunchBar_OpenGreatWorksOverview();
			UI.PlaySound("UI_Screen_Open");
		else
			OnHideScreen();
			UI.PlaySound("UI_Screen_Close");
		end
	end
end

-- ===========================================================================
--	Player Turn Events
-- ===========================================================================
function OnLocalPlayerTurnBegin()
	m_isLocalPlayerTurn = true;
end
function OnLocalPlayerTurnEnd()
	m_isLocalPlayerTurn = false;
	if(GameConfiguration.IsHotseat()) then
		OnHideScreen();
	end
end

-- ===========================================================================
--	INIT
-- ===========================================================================
function Initialize()
	
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	ContextPtr:SetInputHandler(OnInputHandler, true);

	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	LuaEvents.LaunchBar_OpenGreatWorksOverview.Add(OnShowScreen);
	LuaEvents.GreatWorkCreated_OpenGreatWorksOverview.Add(OnShowScreen);
	LuaEvents.LaunchBar_CloseGreatWorksOverview.Add(OnHideScreen);

	Controls.ModalBG:SetTexture("GreatWorks_Background");
	Controls.ModalScreenTitle:SetText(Locale.ToUpper(LOC_SCREEN_TITLE));
	Controls.ModalScreenClose:RegisterCallback(Mouse.eLClick, OnHideScreen);
	Controls.ModalScreenClose:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ViewGallery:RegisterCallback(Mouse.eLClick, OnViewGallery);
	Controls.ViewGallery:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ViewGreatWork:RegisterCallback(Mouse.eLClick, OnViewGreatWork);
	Controls.ViewGreatWork:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Events.GreatWorkMoved.Add(OnGreatWorkMoved);
	Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
	Events.LocalPlayerTurnEnd.Add(OnLocalPlayerTurnEnd);

	-- Hot Key Handling
	m_ToggleGreatWorksId = Input.GetActionId("ToggleGreatWorks");
	if m_ToggleGreatWorksId ~= nil then
		Events.InputActionTriggered.Add( OnInputActionTriggered )
	end

end
Initialize();
