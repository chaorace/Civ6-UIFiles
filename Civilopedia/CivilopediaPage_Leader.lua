-- ===========================================================================
--	Civilopedia - Leader Page Layout
-- ===========================================================================

PageLayouts["Leader" ] = function(page)

local sectionId = page.SectionId;
    local pageId = page.PageId;

    SetPageHeader(page.Title);
    SetPageSubHeader(page.Subtitle);

	-- Gather info.
    local base_leader = GameInfo.Leaders[pageId];
    if(base_leader == nil) then
        return;
    end           
    local leaderType = base_leader.LeaderType;

	function AddInheritedLeaders(leaders, leader)
		local inherit = leader.InheritFrom;
        if(inherit ~= nil) then
            local parent = GameInfo.Leaders[inherit];
            if(parent) then
                table.insert(leaders, parent);
                AddInheritedLeaders(leaders, parent);
            end
        end
    end

	-- Recurse base leaders and populate list with inherited leaders.
	local leaders = {};
    table.insert(leaders, base_leader);
	AddInheritedLeaders(leaders, base_leader);

	-- Enumerate final list and index.
	local has_leader = {};
	for i,leader in ipairs(leaders) do
		has_leader[leader.LeaderType] = true;
	end
    
    local civilizations = {};
    for row in GameInfo.CivilizationLeaders() do
        if(has_leader[row.LeaderType] == true) then
            local civ = GameInfo.Civilizations[row.CivilizationType];
            if(civ) then
                table.insert(civilizations, civ);
            end
        end
    end

	-- Unique Abilities
	-- We're considering a unique ability to be a trait which does 
	-- not have a unique unit, building, district, or improvement associated with it.
	-- While we scrub for unique units and infrastructure, mark traits that match 
	-- so we can filter them later.
    local traits = {};
	local has_trait = {};
	local not_ability = {};
    for row in GameInfo.LeaderTraits() do
        if(has_leader[row.LeaderType] == true) then
			local trait = GameInfo.Traits[row.TraitType];
			if(trait) then
				table.insert(traits, trait);			
			end
			has_trait[row.TraitType] = true;
        end
    end

    -- Unique Units
    local uu = {};
    for row in GameInfo.Units() do
        local trait = row.TraitType;
		
        if(trait) then
			not_ability[trait] = true;
			if(has_trait[trait] == true) then
				table.insert(uu, {row.UnitType, row.Name});
			end
        end
    end
    
    -- Unique Buildings/Districts/Improvements
    local ub = {};
    for row in GameInfo.Buildings() do
        local trait = row.TraitType;
        if(trait) then
			not_ability[trait] = true;
			if(has_trait[trait] == true) then
				table.insert(ub, {row.BuildingType, row.Name});
			end
        end
    end

    for row in GameInfo.Districts() do
        local trait = row.TraitType;
        if(trait) then
			not_ability[trait] = true;
			if(has_trait[trait] == true) then
				table.insert(ub, {row.DistrictType, row.Name});
			end
        end
    end

    for row in GameInfo.Improvements() do
        local trait = row.TraitType;
        if(trait) then
			not_ability[trait] = true;
			if(has_trait[trait] == true) then
				table.insert(ub, {row.ImprovementType, row.Name});
			end
        end
    end

	local unique_abilities = {};
	for i, trait in ipairs(traits) do
		if(not_ability[trait.TraitType] ~= true and not trait.InternalOnly) then
			table.insert(unique_abilities, trait);
		end
	end

	local preferred_religion;
	for row in GameInfo.FavoredReligions() do
		if(row.CivilizationType == nil and has_leader[row.LeaderType] == true) then
			local religion = GameInfo.Religions[row.ReligionType];
			if(religion) then
				preferred_religion = religion;
			end
		end
	end

	local agendas = {};
	for row in GameInfo.HistoricalAgendas() do
		if(has_leader[row.LeaderType] == true) then
			local agenda = GameInfo.Agendas[row.AgendaType];
			if(agenda ~= nil) then
				table.insert(agendas, agenda);
			end
		end
	end

    -- Random bits of info.
    local info = {};
    for row in GameInfo.LeaderInfo() do
        if(has_leader[row.LeaderType] == true) then
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
	AddTallPortrait("ICON_" .. leaderType);
	
	-- Leader Quotes!
	for row in GameInfo.LeaderQuotes() do
		if(has_leader[row.LeaderType] == true) then
			AddQuote(row.Quote, row.QuoteAudio);
		end
	end

    AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
        s:AddSeparator();

        if(#civilizations > 0) then
            s:AddHeader("LOC_UI_PEDIA_CIVILIZATIONS");
            for _, civ in ipairs(civilizations) do
				local icon = {"ICON_" .. civ.CivilizationType, civ.Name, civ.CivilizationType};

                s:AddIconLabel(icon, civ.Name);
				
            end
            s:AddSeparator();
        end

        if(#uu > 0) then
            s:AddHeader("LOC_UI_PEDIA_SPECIAL_UNITS");
            local icons = {};
            for _, item in ipairs(uu) do
                table.insert(icons, {"ICON_" .. item[1], item[2],  item[1]});	

                if(#icons == 4) then
                    s:AddIconList(icons[1], icons[2], icons[3], icons[4]);
                    icons = {};
                end
            end

            if(#icons > 0) then
                s:AddIconList(icons[1], icons[2], icons[3], icons[4]);
            end

            s:AddSeparator();
        end

        if(#ub > 0) then
            s:AddHeader("LOC_UI_PEDIA_SPECIAL_INFRASTRUCTURE");
        
            local icons = {};
            for _, item in ipairs(ub) do
                table.insert(icons, {"ICON_" .. item[1], item[2],  item[1]});	

                if(#icons == 4) then
                    s:AddIconList(icons[1], icons[2], icons[3], icons[4]);
                    icons = {};
                end
            end

            if(#icons > 0) then
                s:AddIconList(icons[1], icons[2], icons[3], icons[4]);
            end
            s:AddSeparator();
        end
    end);

	AddRightColumnStatBox("LOC_UI_PEDIA_PREFERENCES", function(s)
		s:AddSeparator();

		if(#agendas > 0) then
			s:AddHeader("LOC_UI_PEDIA_AGENDAS");
			for i, v in ipairs(agendas) do
				local icon = {"ICON_" .. v.AgendaType, v.Name, v.AgendaType};
				s:AddLabel(v.Name);
				s:AddLabel(v.Description);
			end
			s:AddSeparator();
		end

		if(preferred_religion ~= nil) then
			s:AddHeader("LOC_UI_PEDIA_PREFERRED_RELIGION");

			local icon = {"ICON_" .. preferred_religion.ReligionType,preferred_religion.Name, preferred_religion.ReligionType};
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