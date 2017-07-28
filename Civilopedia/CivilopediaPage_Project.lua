-- ===========================================================================
--	Civilopedia - Project Page Layout
-- ===========================================================================

PageLayouts["Project" ] = function(page)
local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local project = GameInfo.Projects[pageId];
	if(project == nil) then
		return;
	end

	local projectType = project.ProjectType;

	local prereq_projects = {};
	for row in GameInfo.ProjectPrereqs() do
		if(row.ProjectType == projectType) then
			local p = GameInfo.Projects[row.PrereqProjectType];
			if(p) then
				table.insert(prereq_projects, Locale.Lookup(p.ShortName));
			end
		end
	end

	-- If a project's required district is a unique district, treat this as a unique-project.
	local unique_to = {};
	if(project.PrereqDistrict ~= nil) then
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


		local district = GameInfo.Districts[project.PrereqDistrict];
		if(district and district.TraitType) then
			local traitType = district.TraitType;
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

	end

	table.sort(prereq_projects, function(a,b) return Locale.Compare(a,b) == -1; end);

	-- Right Column
	AddPortrait("ICON_" .. projectType);
	
	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		s:AddSeparator();
		if(#unique_to > 0) then
			s:AddHeader("LOC_UI_PEDIA_UNIQUE_TO");
			for _, icon in ipairs(unique_to) do
				s:AddIconLabel(icon, icon[2]);
			end
			s:AddSeparator();
		end
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_REQUIREMENTS", function(s)
		s:AddSeparator();

		if(project.PrereqDistrict ~= nil) then
			local district = GameInfo.Districts[project.PrereqDistrict];
			if(district) then
				s:AddHeader("LOC_DISTRICT_NAME");
				s:AddIconLabel({"ICON_" .. district.DistrictType, district.Name, district.DistrictType}, district.Name);
			end
		end

		if(project.PrereqCivic ~= nil) then
			local civic = GameInfo.Civics[project.PrereqCivic];
			if(civic) then
				s:AddHeader("LOC_CIVIC_NAME");
				s:AddIconLabel({"ICON_" .. civic.CivicType, civic.Name, civic.CivicType}, civic.Name);
			end
		end

		if(project.PrereqResource) then
			local resource = GameInfo.Resources[project.PrereqResource];
			if(resource) then
				s:AddHeader("LOC_RESOURCE_NAME");
				s:AddIconLabel({"ICON_" .. resource.ResourceType, resource.Name, resource.ResourceType}, resource.Name);
			end
		end

		if(project.PrereqTech ~= nil) then
			local technology = GameInfo.Technologies[project.PrereqTech];
			if(technology) then
				s:AddHeader("LOC_TECHNOLOGY_NAME");
				s:AddIconLabel({"ICON_" .. technology.TechnologyType, technology.Name, technology.TechnologyType}, technology.Name);
			end
		end

		if(#prereq_projects > 0) then
			s:AddHeader("LOC_UI_PEDIA_PROJECTS");
			for i,v in ipairs(prereq_projects) do
				s:AddLabel("[ICON_Bullet] " .. v);
			end
		end
	
		s:AddSeparator();
	end);

	-- Left Column
	AddChapter("LOC_UI_PEDIA_DESCRIPTION", project.Description);

	local chapters = GetPageChapters(page.PageLayoutId);
	for i, chapter in ipairs(chapters) do
		local chapterId = chapter.ChapterId;
		local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
		local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

		AddChapter(chapter_header, chapter_body);
	end
end
