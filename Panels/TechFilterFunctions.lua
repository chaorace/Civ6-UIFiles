hstructure TechFilters
	TECHFILTER_RECOMMENDED	: ifunction
	TECHFILTER_FOOD			: ifunction
	TECHFILTER_SCIENCE		: ifunction
	TECHFILTER_PRODUCTION	: ifunction
	TECHFILTER_CULTURE		: ifunction
	TECHFILTER_FAITH		: ifunction
	TECHFILTER_HOUSING		: ifunction
	TECHFILTER_AMENITIES	: ifunction
	TECHFILTER_GOLD			: ifunction
	TECHFILTER_HEALTH		: ifunction
	TECHFILTER_UNITS		: ifunction
	TECHFILTER_IMPROVEMENTS : ifunction
	TECHFILTER_WONDERS		: ifunction
end

g_TechFilters = hmake TechFilters{};

-- Set up additional data for each filter
g_AdditionalFilters = {}
include("TechFilterFunctions_", true);

-- Recommended by Advisors Filter
--[[
g_TechFilters.TECHFILTER_RECOMMENDED = function(techType)
	for advisor : number = 0, AdvisorTypes.NUM_ADVISOR_TYPES - 1, 1 do
		if Game.IsTechRecommended(techType.ID, advisor) then
			return true;
		end
	end

	return false;
end
]]

-- Food Filter
g_TechFilters.TECHFILTER_FOOD = function(techType)
	return CheckUnlocksForYield(techType, "YIELD_FOOD") or CheckAdditionalFilter("TECHFILTER_FOOD", techType);
end

-- Science Filter
g_TechFilters.TECHFILTER_SCIENCE = function(techType)
	return CheckUnlocksForYield(techType, "YIELD_SCIENCE") or CheckAdditionalFilter("TECHFILTER_SCIENCE", techType);
end

-- Production Filter
g_TechFilters.TECHFILTER_PRODUCTION = function(techType)
	return CheckUnlocksForYield(techType, "YIELD_PRODUCTION") or CheckAdditionalFilter("TECHFILTER_PRODUCTION", techType);
end

-- Culture Filter
g_TechFilters.TECHFILTER_CULTURE = function(techType)
	return CheckUnlocksForYield(techType, "YIELD_CULTURE") or CheckAdditionalFilter("TECHFILTER_CULTURE", techType);
end

-- Faith Filter
g_TechFilters.TECHFILTER_FAITH = function(techType)
	return CheckUnlocksForYield(techType, "YIELD_FAITH") or CheckAdditionalFilter("TECHFILTER_FAITH", techType);
end

-- Housing Filter
g_TechFilters.TECHFILTER_HOUSING = function(techType)
	-- Housing via Buildings
	for row in GameInfo.Buildings() do
		if (row.PrereqTech == techType or row.PrereqCivic == techType) and row.Housing ~= nil and row.Housing > 0 then
			return true;
		end
	end

	-- Housing via Improvements
	for row in GameInfo.Improvements() do
		if (row.PrereqTech == techType or row.PrereqCivic == techType) and row.Housing ~= nil and row.Housing > 0 then
			return true;
		end
	end

	-- Housing via Districts
	for row in GameInfo.Districts() do
		if (row.PrereqTech == techType or row.PrereqCivic == techType) and row.Housing ~= nil and row.Housing > 0 then
			return true;
		end
	end

	return CheckAdditionalFilter("TECHFILTER_HOUSING", techType);
end

-- Amenities Filter
g_TechFilters.TECHFILTER_AMENITIES = function(techType)
	--??TODO - Implement Amenities filter function
	return CheckAdditionalFilter("TECHFILTER_AMENITIES", techType);
end

-- Gold Filter
g_TechFilters.TECHFILTER_GOLD = function(techType)
	local yieldType : string = "YIELD_GOLD";

	if CheckUnlocksForYield(techType, yieldType) then
		return true;
	end

	for row in GameInfo.Policies() do
		if (row.PrereqTech == techType or row.PrereqCivic == techType) then
			local policyType = row.PolicyType;
			for rowPolicyModifier in GameInfo.PolicyModifiers() do
				if rowPolicyModifier.PolicyType == policyType then
					local modifier = GameInfo.Modifiers[rowPolicyModifier.ModifierId];
					if modifier.ModifierType == "MODIFIER_PLAYER_ADJUST_UNIT_MAINTENANCE_DISCOUNT" then
						return true;
					end
				end
			end
		end
	end

	return CheckAdditionalFilter("TECHFILTER_GOLD", techType);
end

-- Health Filter
g_TechFilters.TECHFILTER_HEALTH = function(techType)
	return CheckUnlocksForHealth(techType) or CheckAdditionalFilter("TECHFILTER_HEALTH", techType);
end


-- Improvements Filter
g_TechFilters.TECHFILTER_IMPROVEMENTS = function(techType)
	local has_trait:table = GetTraits();

	for row in GameInfo.Improvements() do
		if (row.PrereqTech == techType or row.PrereqCivic == techType) and (row.TraitType== nil or has_trait == nil or has_trait[row.TraitType]) then
			return true;
		end
	end

	return CheckAdditionalFilter("TECHFILTER_IMPROVEMENTS", techType);
end

-- Wonders Filter
g_TechFilters.TECHFILTER_WONDERS = function(techType)	
	for row in GameInfo.Buildings() do
		if (row.PrereqTech == techType or row.PrereqCivic == techType) and row.IsWonder then
			return true;
		end
	end

	return CheckAdditionalFilter("TECHFILTER_WONDERS", techType);
end

-- Units Filter
g_TechFilters.TECHFILTER_UNITS = function(techType)
	local has_trait:table = GetTraits();
	for row in GameInfo.Units() do
		if (row.PrereqTech == techType or row.PrereqCivic == techType) and (row.TraitType== nil or has_trait == nil or has_trait[row.TraitType]) then
			return true;
		end
	end

	for row in GameInfo.CivicModifiers() do
		if row.CivicType == techType then
			local modifier = GameInfo.Modifiers[row.ModifierId];
			if(modifier) then
				local dynamicModifier = GameInfo.DynamicModifiers[modifier.ModifierType];
				local effect = dynamicModifier and dynamicModifier.EffectType;
				if effect == "EFFECT_GRANT_UNIT_IN_CITY" then
					return true;
				end
			end
		end
	end

	for row in GameInfo.TechnologyModifiers() do
		if row.TechnologyType == techType then
			local modifier = GameInfo.Modifiers[row.ModifierId];
			if(modifier) then
				local dynamicModifier = GameInfo.DynamicModifiers[modifier.ModifierType];
				local effect = dynamicModifier and dynamicModifier.EffectType;
				if effect == "EFFECT_GRANT_UNIT_IN_CITY" then
					return true;
				end
			end
		end
	end

	return CheckAdditionalFilter("TECHFILTER_UNITS", techType);
end


-- ===========================================================================
-- 	Utility Functions
-- ===========================================================================
function CheckUnlocksForYield(techType, yieldType)
	local has_trait:table = GetTraits();

	-- Yield via Buildings
	for row in GameInfo.Buildings() do
		if (row.PrereqTech == techType or row.PrereqCivic == techType) and (row.TraitType== nil or has_trait == nil or has_trait[row.TraitType]) then
			local buildingType = row.BuildingType;

			-- Direct yield from building
			for rowBuildingYield in GameInfo.Building_YieldChanges() do
				if rowBuildingYield.BuildingType == buildingType and rowBuildingYield.YieldType == yieldType then
					if rowBuildingYield.YieldChange > 0 then
						return true;
					end
				end
			end

			for rowBuildingModifier in GameInfo.BuildingModifiers() do
				if rowBuildingModifier.BuildingType == buildingType then
					local modifierID = rowBuildingModifier.ModifierId;
					for rowModifierYieldChange in GameInfo.ModifierArguments() do
						if(rowModifierYieldChange.ModifierId == rowBuildingModifier.ModifierId and rowModifierYieldChange.Name == "ModifierId") then
							modifierID = rowModifierYieldChange.Value;
						end

						if(rowModifierYieldChange.ModifierId == modifierID and rowModifierYieldChange.Value == yieldType) then
							return true;
						end
					end
				end
			end
		end
	end

	-- Yield via Improvements
	for row in GameInfo.Improvements() do
		if (row.TraitType== nil or has_trait == nil or has_trait[row.TraitType]) then
			for rowYieldChange in GameInfo.Adjacency_YieldChanges() do
				if rowYieldChange.AdjacentImprovement == row.ImprovementType and (rowYieldChange.PrereqCivic == techType or rowYieldChange.PrereqTech == techType) then
					if(rowYieldChange.YieldType == yieldType) then
						return true;
					end
				end
			end

			for rowBonusYieldChange in GameInfo.Improvement_BonusYieldChanges() do
				if rowBonusYieldChange.ImprovementType == row.ImprovementType and (rowBonusYieldChange.PrereqCivic == techType or rowBonusYieldChange.PrereqTech == techType) then
					if(rowBonusYieldChange.YieldType == yieldType) then
						return true;
					end
				end
			end

			if (row.PrereqTech == techType or row.PrereqCivic == techType) then
				local improvementType = row.ImprovementType;
				for rowImprovementYield in GameInfo.Improvement_YieldChanges() do
					if rowImprovementYield.ImprovementType == improvementType and rowImprovementYield.YieldType == yieldType then
						if rowImprovementYield.YieldChange> 0 then
							return true;
						end
					end
				end

				for rowImprovementModifier in GameInfo.ImprovementModifiers() do
					if rowImprovementModifier.ImprovementType == improvementType then
						local modifierID = rowImprovementModifier.ModifierId;
						for rowModifierYieldChange in GameInfo.ModifierArguments() do
							if(rowModifierYieldChange.ModifierId == rowImprovementModifier.ModifierId and rowModifierYieldChange.Name == "ModifierId") then
								modifierID = rowModifierYieldChange.Value;
							end

							if(rowModifierYieldChange.ModifierId == modifierID and rowModifierYieldChange.Value == yieldType) then
								return true;
							end
						end
					end
				end
			end
		end
	end
		
	-- Yield via Districts
	for row in GameInfo.Districts() do
		if (row.PrereqTech == techType or row.PrereqCivic == techType) and (row.TraitType == nil or has_trait == nil or has_trait[row.TraitType]) then
			local districtType = row.DistrictType;
			for rowDistrictAdjacency in GameInfo.District_Adjacencies() do
				if rowDistrictAdjacency.DistrictType == districtType then
					local yieldChangeId = rowDistrictAdjacency.YieldChangeId;
					for rowAdjacencyYieldChange in GameInfo.Adjacency_YieldChanges() do
						if rowAdjacencyYieldChange.ID == yieldChangeId then
							if rowAdjacencyYieldChange.YieldType == yieldType then
								return true;
							end
						end
					end
				end
			end

			for rowDistrictModifier in GameInfo.DistrictModifiers() do
				if rowDistrictModifier.DistrictType == districtType then
					local modifierID = rowDistrictModifier.ModifierId;
					for rowModifierYieldChange in GameInfo.ModifierArguments() do
						if(rowModifierYieldChange.ModifierId == rowDistrictModifier.ModifierId and rowModifierYieldChange.Name == "ModifierId") then
							modifierID = rowModifierYieldChange.Value;
						end

						if(rowModifierYieldChange.ModifierId == modifierID and rowModifierYieldChange.Value == yieldType) then
							return true;
						end
					end
				end
			end

			for rowDistrictCitizenYield in GameInfo.District_CitizenYieldChanges() do
				if rowDistrictCitizenYield.DistrictType == districtType then
					if rowDistrictCitizenYield.YieldType == yieldType then
						return true;
					end
				end
			end
		end
	end

	-- Yields from other sources? ... add them here.
	for row in GameInfo.Policies() do
		if (row.PrereqTech == techType or row.PrereqCivic == techType) then
			local policyType = row.PolicyType;
			for rowPolicyModifier in GameInfo.PolicyModifiers() do
				if rowPolicyModifier.PolicyType == policyType then
					local modifierID = rowPolicyModifier.ModifierId;
					for rowModifierYieldChange in GameInfo.ModifierArguments() do
						if(rowModifierYieldChange.ModifierId == rowPolicyModifier.ModifierId and rowModifierYieldChange.Name == "ModifierId") then
							modifierID = rowModifierYieldChange.Value;
						end

						if(rowModifierYieldChange.ModifierId == modifierID and rowModifierYieldChange.Value == yieldType) then
							return true;
						end

						-- policies that affect constriction speed of units do not use the yieldtype
						if rowModifierYieldChange.ModifierId == modifierID and yieldType == "YIELD_PRODUCTION" and string.find(rowModifierYieldChange.ModifierId, "PRODUCTION") then
							return true;
						end
					end
				end
			end
		end
	end

	for row in GameInfo.TechnologyModifiers() do
		if (row.TechnologyType == techType) then
			local modifierID = row.ModifierId;
			for rowModifierYieldChange in GameInfo.ModifierArguments() do
				if(rowModifierYieldChange.ModifierId == row.ModifierId and rowModifierYieldChange.Name == "ModifierId") then
					modifierID = rowModifierYieldChange.Value;
				end

				if(rowModifierYieldChange.ModifierId == modifierID and rowModifierYieldChange.Value == yieldType) then
					return true;
				end
			end
		end
	end

	for row in GameInfo.CivicModifiers() do
		if (row.CivicType == techType) then
			local modifierID = row.ModifierId;
			for rowModifierYieldChange in GameInfo.ModifierArguments() do
				if(rowModifierYieldChange.ModifierId == row.ModifierId and rowModifierYieldChange.Name == "ModifierId") then
					modifierID = rowModifierYieldChange.Value;
				end

				if(rowModifierYieldChange.ModifierId == modifierID and rowModifierYieldChange.Value == yieldType) then
					return true;
				end
			end
		end
	end

	return false;
end

function CheckAdditionalFilter(filterKey:string, techOrCivicType:string)
	local filters = g_AdditionalFilters[filterKey];
	if filters then
		for _, value in ipairs(filters) do
			if value == techOrCivicType then
				return true;
			end
		end
	end
	return false;
end

function GetTraits()
	local has_trait:table = nil;
	local player = Players[Game.GetLocalPlayer()];
	if(player ~= nil) then
		has_trait = {};
		local config = PlayerConfigurations[Game.GetLocalPlayer()];
		if(config ~= nil) then
			local leaderType = config:GetLeaderTypeName();
			local civType = config:GetCivilizationTypeName();

			if(leaderType) then
				for row in GameInfo.LeaderTraits() do
					if(row.LeaderType== leaderType) then
						has_trait[row.TraitType] = true;
					end
				end
			end

			if(civType) then
				for row in GameInfo.CivilizationTraits() do
					if(row.CivilizationType== civType) then
						has_trait[row.TraitType] = true;
					end
				end
			end
		end
	end
	return has_trait;
end

-- ===========================================================================
--[[
function CheckUnlocksForHealth(techType)
	-- Health from Buildings
	for row in GameInfo.Buildings() do
		if row.Health > 0 then
			return true;
		end
	end

	-- Health from other sources..?
	
	return false;
end
]]