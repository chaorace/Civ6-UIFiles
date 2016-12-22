-- ===========================================================================
--	Civilopedia - Improvement Page Layout
-- ===========================================================================

PageLayouts["Improvement" ] = function(page)
local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local improvement = GameInfo.Improvements[pageId];
	if(improvement == nil) then
		return;
	end

	local improvementType = improvement.ImprovementType;

	local stats = {};
	
	for row in GameInfo.Improvement_YieldChanges() do
		if(row.ImprovementType == improvementType and row.YieldChange ~= 0) then
			local yield = GameInfo.Yields[row.YieldType];
			if(yield) then
				table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_YIELD",row.YieldChange, yield.IconString, yield.Name));
			end
		end
	end

	local housing = 0;

	if(tonumber(improvement.TilesRequired) > 0) then
		housing = tonumber(improvement.Housing)/tonumber(improvement.TilesRequired);
	end

	if(housing ~= 0) then
		table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_HOUSING", housing));
	end

	local airSlots = improvement.AirSlots or 0;
	if(airSlots ~= 0) then
		table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_AIRSLOTS", airSlots));
	end

	local citizenSlots = improvement.CitizenSlots or 0;
	if(citizenSlots ~= 0) then
		table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_CITIZENSLOTS", citizenSlots));
	end

	local weaponSlots = improvement.WeaponSlots or 0;
	if(weaponSlots ~= 0) then
		table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_WEAPONSLOTS", weaponSlots));
	end

	for row in GameInfo.Improvement_BonusYieldChanges() do
		if(row.ImprovementType == improvementType and row.BonusYieldChange ~= 0) then
			local yield = GameInfo.Yields[row.YieldType];
			if(yield) then

				local item;
				if(row.PrereqCivic) then
					item = GameInfo.Civics[row.PrereqCivic];
				else
					item = GameInfo.Technologies[row.PrereqTech];
				end

				if(item) then
					table.insert(stats, Locale.Lookup("LOC_TYPE_TRAIT_BONUS_YIELD", row.BonusYieldChange, yield.IconString, yield.Name, item.Name));
				end
			end
		end
	end

	local unique_to = {};
	if(improvement.TraitType) then
		local traitType = improvement.TraitType;

		-- Index city-states
		-- City states are always referenced by their civilization type and not leader type
		-- despite game data referencing it that way.
		local city_state_civilizations = {};
		local city_state_leaders = {};
		for row in GameInfo.Civilizations() do
			if(row.StartingCivilizationLevelType == "CIVILIZATION_LEVEL_CITY_STATE") then
				city_state_civilizations[row.CivilizationType] = true;
			end
		end

		for row in GameInfo.CivilizationLeaders() do
			if(city_state_civilizations[row.CivilizationType]) then
				city_state_leaders[row.LeaderType] = row.CivilizationType;
			end
		end

		for row in GameInfo.LeaderTraits() do
			if(row.TraitType == traitType) then
				local leader = GameInfo.Leaders[row.LeaderType];
				if(leader) then
					-- If this is a city state, use the civilization type.
					local city_state_civilization = city_state_leaders[row.LeaderType];
					if(city_state_civilization) then
						local civ = GameInfo.Civilizations[city_state_civilization];
						if(civ) then
							table.insert(unique_to, {"ICON_" .. civ.CivilizationType, civ.Name, civ.CivilizationType});
						end
					else
						table.insert(unique_to, {"ICON_" .. row.LeaderType, leader.Name, row.LeaderType});
					end
				end
			end
		end

		for row in GameInfo.CivilizationTraits() do
			if(row.TraitType == traitType) then
				local civ = GameInfo.Civilizations[row.CivilizationType];
				if(civ) then
					table.insert(unique_to, {"ICON_" .. row.CivilizationType, civ.Name, row.CivilizationType});
				end
			end
		end
	end

	local built_by = {};
	for row in GameInfo.Improvement_ValidBuildUnits() do
		if(row.ImprovementType == improvementType) then
			local unit = GameInfo.Units[row.UnitType];
			if(unit) then
				table.insert(built_by, unit);
			end
		end
	end
	table.sort(built_by, function(a,b) return Locale.Compare(Locale.Lookup(a.Name), Locale.Lookup(b.Name)) == -1; end);
	
	-- Generate list of adjacency bonuses.
	local adjacency_yields = {};
	local has_bonus = {};
	for row in GameInfo.Improvement_Adjacencies() do
		if(row.ImprovementType == improvementType) then
			has_bonus[row.YieldChangeId] = true;
		end
	end

	for row in GameInfo.Adjacency_YieldChanges() do
		if(has_bonus[row.ID]) then
			
			local object;
			if(row.OtherDistrictAdjacent) then
				object = "LOC_TYPE_TRAIT_ADJACENT_OBJECT_DISTRICT";
			elseif(row.AdjacentResource) then
				object = "LOC_TYPE_TRAIT_ADJACENT_OBJECT_RESOURCE";
			elseif(row.AdjacentSeaResource) then
				object = "LOC_TYPE_TRAIT_ADJACENT_OBJECT_SEA_RESOURCE";
			elseif(row.AdjacentRiver) then
				object = "LOC_TYPE_TRAIT_ADJACENT_OBJECT_RIVER";
			elseif(row.AdjacentWonder) then
				object = "LOC_TYPE_TRAIT_ADJACENT_OBJECT_WONDER";
			elseif(row.AdjacentNaturalWonder) then
				object = "LOC_TYPE_TRAIT_ADJACENT_OBJECT_NATURAL_WONDER";
			elseif(row.AdjacentTerrain) then
				local terrain = GameInfo.Terrains[row.AdjacentTerrain];
				if(terrain) then
					object = terrain.Name;
				end
			elseif(row.AdjacentFeature) then
				local feature = GameInfo.Features[row.AdjacentFeature];
				if(feature) then
					object = feature.Name;
				end
			elseif(row.AdjacentImprovement) then
				local improvement = GameInfo.Improvements[row.AdjacentImprovement];
				if(improvement) then
					object = improvement.Name;
				end
			elseif(row.AdjacentDistrict) then		
				local district = GameInfo.Districts[row.AdjacentDistrict];
				if(district) then
					object = district.Name;
				end
			end

			local yield = GameInfo.Yields[row.YieldType];

			if(object and yield) then

				local key = (row.TilesRequired > 1) and "LOC_TYPE_TRAIT_ADJACENT_BONUS_PER" or "LOC_TYPE_TRAIT_ADJACENT_BONUS";

				local value = Locale.Lookup(key, row.YieldChange, yield.IconString, yield.Name, row.TilesRequired, object);

				if(row.PrereqCivic or row.PrereqTech) then
					local item;
					if(row.PrereqCivic) then
						item = GameInfo.Civics[row.PrereqCivic];
					else
						item = GameInfo.Technologies[row.PrereqTech];
					end

					if(item) then
						local text = Locale.Lookup("LOC_TYPE_TRAIT_ADJACENT_BONUS_REQUIRES_TECH_OR_CIVIC", item.Name);
						value = value .. "  " .. text;
					end
				end

				if(row.ObsoleteCivic or row.ObsoleteTech) then
					local item;
					if(row.ObsoleteCivic) then
						item = GameInfo.Civics[row.ObsoleteCivic];
					else
						item = GameInfo.Technologies[row.ObsoleteTech];
					end
				
					if(item) then
						local text = Locale.Lookup("LOC_TYPE_TRAIT_ADJACENT_BONUS_OBSOLETE_WITH_TECH_OR_CIVIC", item.Name);
						value = value .. "  " .. text;
					end
				end

				table.insert(adjacency_yields, value);
			end		
		end
	end

	-- placement requirements
	local placement_requirements = {};
	for row in GameInfo.Improvement_ValidFeatures() do
		if(row.ImprovementType == improvementType) then
			local feature = GameInfo.Features[row.FeatureType];
			if(feature ~= nil) then
				table.insert(placement_requirements, Locale.Lookup(feature.Name));
			end
		end
	end

	for row in GameInfo.Improvement_ValidResources() do
		if(row.ImprovementType == improvementType) then
			local resource = GameInfo.Resources[row.ResourceType];
			if(resource ~= nil) then
				table.insert(placement_requirements, Locale.Lookup(resource.Name));
			end
		end
	end

	for row in GameInfo.Improvement_ValidTerrains() do
		if(row.ImprovementType == improvementType) then
			local terrain = GameInfo.Terrains[row.TerrainType];
			if(terrain ~= nil) then
				table.insert(placement_requirements, Locale.Lookup(terrain.Name));
			end
		end
	end
	table.sort(placement_requirements, function(a,b) return Locale.Compare(a,b) == -1 end);


	-- Right Column
	AddPortrait(improvement.Icon);

	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		s:AddSeparator();

		if(#unique_to > 0) then		
			s:AddHeader("LOC_UI_PEDIA_UNIQUE_TO");
			for _, icon in ipairs(unique_to) do
				s:AddIconLabel(icon, icon[2]);
			end

			s:AddSeparator();
		end
			
		if(#stats > 0) then
			for _, v in ipairs(stats) do
				s:AddLabel(v);
			end
			s:AddSeparator();
		end

		if(#adjacency_yields > 0) then
			s:AddHeader("LOC_UI_PEDIA_ADJACENCY_BONUS");
			for i,v in ipairs(adjacency_yields) do
				s:AddLabel(v);
			end
			s:AddSeparator();
		end		
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_REQUIREMENTS", function(s)
		s:AddSeparator();

		if(improvement.PrereqCivic ~= nil or improvement.PrereqTech ~= nil) then
			if(improvement.PrereqCivic ~= nil) then
				local civic = GameInfo.Civics[improvement.PrereqCivic];
				if(civic) then
					s:AddHeader("LOC_CIVIC_NAME");
					s:AddIconLabel({"ICON_" .. civic.CivicType, civic.Name, civic.CivicType}, civic.Name);
				end
			end

			if(improvement.PrereqTech ~= nil) then
				local technology = GameInfo.Technologies[improvement.PrereqTech];
				if(technology) then
					s:AddHeader("LOC_TECHNOLOGY_NAME");
					s:AddIconLabel({"ICON_" .. technology.TechnologyType, technology.Name, technology.TechnologyType}, technology.Name);
				end
			end

			s:AddSeparator();
		end

		if(#placement_requirements > 0) then
			s:AddHeader("LOC_UI_PEDIA_PLACEMENT");

			for i, v in ipairs(placement_requirements) do
				s:AddLabel("[ICON_Bullet] " .. v);
			end

			s:AddSeparator();
		end
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_USAGE", function(s)
		s:AddSeparator();

		if(#built_by > 0) then
			s:AddHeader("LOC_UI_PEDIA_BUILT_BY");
			for i,v in ipairs(built_by) do
				s:AddIconLabel({"ICON_" .. v.UnitType, v.Name, v.UnitType}, v.Name);
			end
		end

		s:AddSeparator();
	end);

	-- Left Column
	AddChapter("LOC_UI_PEDIA_DESCRIPTION", improvement.Description);

	local chapters = GetPageChapters(page.PageLayoutId);
	for i, chapter in ipairs(chapters) do
		local chapterId = chapter.ChapterId;
		local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
		local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

		AddChapter(chapter_header, chapter_body);
	end
end
