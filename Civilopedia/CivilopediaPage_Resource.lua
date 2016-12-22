-- ===========================================================================
--	Civilopedia - Resource Page Layout
-- ===========================================================================

PageLayouts["Resource" ] = function(page)
	local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local resource = GameInfo.Resources[pageId];
	if(resource == nil) then
		return;
	end
	local resourceType = resource.ResourceType;

	local resourceClasses = {
		RESOURCECLASS_BONUS = "LOC_RESOURCECLASS_BONUS_NAME",
		RESOURCECLASS_LUXURY = "LOC_RESOURCECLASS_LUXURY_NAME",
		RESOURCECLASS_STRATEGIC = "LOC_RESOURCECLASS_STRATEGIC_NAME",
		RESOURCECLASS_ARTIFACT = "LOC_RESOURCECLASS_ARTIFACT_NAME",
	}

	local resource_class = resourceClasses[resource.ResourceClassType];

	-- Get some info!
	local yield_changes = {};
	for row in GameInfo.Resource_YieldChanges() do
		if(row.ResourceType == resourceType) then
			local change = yield_changes[row.YieldType] or 0;
			yield_changes[row.YieldType] = change + row.YieldChange;
		end
	end

	for row in GameInfo.Yields() do
		local change = yield_changes[row.YieldType];
		if(change ~= nil) then
			table.insert(yield_changes, {change, row.IconString, Locale.Lookup(row.Name)}); 
		end
	end

	local improvements = {};
	for row in GameInfo.Improvement_ValidResources() do
		if(row.ResourceType == resourceType) then
			local improvement = GameInfo.Improvements[row.ImprovementType];
			if(improvement) then
				table.insert(improvements, {{improvement.Icon, improvement.Name, improvement.ImprovementType}, improvement.Name});
			end
			
		end
	end

	local harvests = {};
	for row in GameInfo.Resource_Harvests() do
		if(row.ResourceType == resourceType) then
			table.insert(harvests, row);
		end
	end


	-- Woo boy.  Let me explain what's about  to happen.
	-- A few of the resources are created on the fly by great people as a modifier effect.
	-- We want to display these great people of greatness on the side-bar because we're great like that.
	-- To do this... 
	-- Catalogue all modifiers that contain our effect "EFFECT_GRANT_FREE_RESOURCE_IN_CITY" 
	-- Find out all instances of modifiers of those type that has our resource in question as the ResourceType argument.
	-- Find out what great people possess such modifiers
	-- PROFIT.
	local creators = {};
	local has_any_modifiers = false;
	local has_modifier = {};
	local is_resource_modifier = {};
	for row in GameInfo.DynamicModifiers() do
		if(row.EffectType== "EFFECT_GRANT_FREE_RESOURCE_IN_CITY") then
			is_resource_modifier[row.ModifierType] = true;
		end
	end

	for row in GameInfo.Modifiers() do
		if(is_resource_modifier[row.ModifierType]) then
			for args in GameInfo.ModifierArguments() do
				if(args.ModifierId == row.ModifierId) then
					if(args.Name == "ResourceType" and args.Value == resourceType) then
						has_any_modifiers = true;
						has_modifier[row.ModifierId] = true;
					end
				end
			end
		end
	end

	if(has_any_modifiers) then
		for row in GameInfo.GreatPersonIndividualActionModifiers() do
			if(has_modifier[row.ModifierId]) then
				local t = row.GreatPersonIndividualType
				local greatPerson = GameInfo.GreatPersonIndividuals[t];
				if(greatPerson) then
					
					local gpClass = GameInfo.GreatPersonClasses[greatPerson.GreatPersonClassType];
			
					if(gpClass and gpClass.UnitType) then
						local gpUnit = GameInfo.Units[gpClass.UnitType];
						if(gpUnit) then
							local name = greatPerson.Name;

							table.insert(creators, {{"ICON_" .. gpUnit.UnitType, name, t}, name});
						end	
					end
				end
			end
		end
	end




	-- Now to the right!
	AddPortrait("ICON_" .. resourceType);

	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		s:AddSeparator();
	
		if(resource_class) then
			s:AddHeader(resource_class);
		end

		if(#yield_changes > 0) then
			for _, v in ipairs(yield_changes) do
				s:AddLabel(Locale.Lookup("LOC_TYPE_TRAIT_YIELD", v[1], v[2], v[3]));
			end
		end

		if(resource.Happiness > 0) then
			s:AddLabel(Locale.Lookup("LOC_TYPE_TRAIT_HAPPINESS", resource.Happiness));
		end

		s:AddSeparator();
	end);
	
	AddRightColumnStatBox("LOC_UI_PEDIA_REQUIREMENTS", function(s)
		s:AddSeparator();

		if(resource.PrereqTech) then
			local tech = GameInfo.Technologies[resource.PrereqTech];
			if(tech) then
				s:AddHeader("LOC_UI_PEDIA_UNLOCKED_BY");
				s:AddIconLabel({"ICON_" .. tech.TechnologyType, tech.Name, tech.TechnologyType}, tech.Name);
			end
			s:AddSeparator();
		end

		-- HAX! OMG LAZY DEVELOPER HAX
		if(resourceType == "RESOURCE_CLOVES" or resourceType == "RESOURCE_CINNAMON") then
			local zanzibar = GameInfo.Civilizations["CIVILIZATION_ZANZIBAR"];
			if(zanzibar) then
				s:AddHeader("LOC_UI_PEDIA_SUZERAIN");

				s:AddIconLabel({"ICON_CIVILIZATION_ZANZIBAR", zanzibar.Name, zanzibar.CivilizationType}, zanzibar.Name);

				s:AddSeparator();
			end
		end
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_USAGE", function(s)
		s:AddSeparator();

		if(#creators > 0) then
			s:AddHeader("LOC_UI_PEDIA_CREATED_BY");
			for i,v in ipairs(creators) do
				s:AddIconLabel(v[1], v[2]);
			end
			s:AddSeparator();
		end

		if(#improvements > 0) then
			s:AddHeader("LOC_UI_PEDIA_IMPROVED_BY");
			for i,v in ipairs(improvements) do
				s:AddIconLabel(v[1], v[2]);
			end
			s:AddSeparator();
		end
		
		if(#harvests > 0) then
			s:AddHeader("LOC_UI_PEDIA_HARVEST");
			for i,v in ipairs(harvests) do
				local yield = GameInfo.Yields[v.YieldType];
				if(yield) then
					s:AddLabel(Locale.Lookup("LOC_TYPE_TRAIT_YIELD", v.Amount, yield.IconString, yield.Name));
					if(v.PrereqTech) then
						local tech = GameInfo.Technologies[v.PrereqTech];
						if(tech) then
							s:AddIconLabel({"ICON_" .. tech.TechnologyType, tech.Name, tech.TechnologyType}, Locale.Lookup("LOC_UI_PEDIA_REQUIRES", tech.Name));
						end
					end
				end	
			end

			s:AddSeparator();	
		end
	end);

	-- Left Column!
	local chapters = GetPageChapters(page.PageLayoutId);
	if(chapters) then
		for i, chapter in ipairs(chapters) do
			local chapterId = chapter.ChapterId;
			local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
			local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

			AddChapter(chapter_header, chapter_body);
		end
	end
end
