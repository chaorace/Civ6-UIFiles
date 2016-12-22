-- ===========================================================================
--	Civilopedia - Civilization Page Layout
-- ===========================================================================
PageLayouts["Civilization" ] = function(page)
    local sectionId = page.SectionId;
    local pageId = page.PageId;

    SetPageHeader(page.Title);
    SetPageSubHeader(page.Subtitle);

    -- Search for the civilization.
    -- Stop populating layout if the civ cannot be found.
    local civ = GameInfo.Civilizations[pageId];
    if(civ == nil) then
        return;
    end        
    
    local civType = civ.CivilizationType;

    -- Leaders
    local leaders = {};
    for row in GameInfo.CivilizationLeaders() do
        if(row.CivilizationType == civType) then
            local leader = GameInfo.Leaders[row.LeaderType];
            if(leader) then
                table.insert(leaders, leader);
            end
        end
    end

    local traits = {};
    for row in GameInfo.CivilizationTraits() do
        if(row.CivilizationType == civType) then
            traits[row.TraitType] = true;
        end
    end

	-- Unique Abilities
	-- We're considering a unique ability to be a trait which does 
	-- not have a unique unit, building, district, or improvement associated with it.
	-- While we scrub for unique units and infrastructure, mark traits that match 
	-- so we can filter them later.
	local not_abilities = {};
	
    -- Unique Units
    local uu = {};
    for row in GameInfo.Units() do
        local trait = row.TraitType;
		
        if(trait) then
			not_abilities[trait] = true;
			if(traits[trait] == true) then
				table.insert(uu, {row.UnitType, row.Name});
			end
        end
    end
    
    -- Unique Buildings/Districts/Improvements
    local ub = {};
    for row in GameInfo.Buildings() do
        local trait = row.TraitType;
        if(trait) then
			not_abilities[trait] = true;
			if(traits[trait] == true) then
				table.insert(ub, {row.BuildingType, row.Name});
			end
        end
    end

    for row in GameInfo.Districts() do
        local trait = row.TraitType;
        if(trait) then
			not_abilities[trait] = true;
			if(traits[trait] == true) then
				table.insert(ub, {row.DistrictType, row.Name});
			end
        end
    end

    for row in GameInfo.Improvements() do
        local trait = row.TraitType;
        if(trait) then
			not_abilities[trait] = true;
			if(traits[trait] == true) then
				table.insert(ub, {row.ImprovementType, row.Name});
			end
        end
    end

	local unique_abilities = {};
	for row in GameInfo.CivilizationTraits() do
		if(row.CivilizationType == civType and not_abilities[row.TraitType] ~= true) then
			local trait = GameInfo.Traits[row.TraitType];
			if(trait) then
				table.insert(unique_abilities, trait);
			end			
		end
	end

	local preferred_religion;
	for row in GameInfo.FavoredReligions() do
		if(row.CivilizationType == civType and row.LeaderType == nil) then
			local religion = GameInfo.Religions[row.ReligionType];
			if(religion) then
				preferred_religion = religion;
			end
		end
	end

    -- Random bits of info.
    local info = {};
    for row in GameInfo.CivilizationInfo() do
        if(row.CivilizationType == civType) then
            table.insert(info, row);
        end
    end
    table.sort(info, function(a, b) 
        if(a.SortIndex ~= b.SortIndex) then
            return tonumber(a.SortIndex) < tonumber(b.SortIndex);
        else
           return Locale.Compare(a.Header, b.Header) == -1;    
        end	
    end);

	-- Right column stats.
	AddPortrait("ICON_" .. civType);

    AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
        s:AddSeparator();

        if(#leaders > 0) then
            s:AddHeader("LOC_UI_PEDIA_LEADERS");
            for _, leader in ipairs(leaders) do
				local icon = {"ICON_" .. leader.LeaderType, leader.Name, leader.LeaderType};
                s:AddIconLabel(icon, leader.Name);
            end
            s:AddSeparator();
        end

        if(#uu > 0) then
            s:AddHeader("LOC_UI_PEDIA_SPECIAL_UNITS");
            for _, item in ipairs(uu) do
				s:AddIconLabel({"ICON_" .. item[1], item[2],  item[1]}, item[2]);
            end
            s:AddSeparator();
        end

        if(#ub > 0) then
            s:AddHeader("LOC_UI_PEDIA_SPECIAL_INFRASTRUCTURE");
            for _, item in ipairs(ub) do
				s:AddIconLabel({"ICON_" .. item[1], item[2],  item[1]}, item[2]);
            end
            s:AddSeparator();
        end
    end);


	AddRightColumnStatBox("LOC_UI_PEDIA_PREFERENCES", function(s)
		s:AddSeparator();
		if(preferred_religion ~= nil) then
			s:AddHeader("LOC_UI_PEDIA_PREFERRED_RELIGION");

			local icon = {"ICON_" .. preferred_religion.RelgionType, preferred_religion.Name, preferred_religion.RelgionType};
			s:AddIconLabel(icon, preferred_religion.Name);
			s:AddSeparator();
		end
    end);

    AddRightColumnStatBox("LOC_UI_PEDIA_GEOGRAPHY_AND_SOCIAL_DATA", function(s)
        s:AddSeparator();
        for _, item in ipairs(info) do
            s:AddHeader(item.Header);
            s:AddLabel(item.Caption);
            s:AddSeparator();
        end
    end);

	-- Unique ability goes at the top!
	if(#unique_abilities > 0) then
		AddHeader("LOC_UI_PEDIA_UNIQUE_ABILITY");
	
		for _, item in ipairs(unique_abilities) do
			AddHeaderBody(item.Name,  item.Description);
		end
	end

	-- Add bulk text.
	local chapters = GetPageChapters(page.PageLayoutId);
    for i, chapter in ipairs(chapters) do
        local chapterId = chapter.ChapterId;
        local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
        local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

        AddChapter(chapter_header, chapter_body);
    end
end
