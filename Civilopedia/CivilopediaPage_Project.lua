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

	table.sort(prereq_projects, function(a,b) return Locale.Compare(a,b) == -1; end);

	-- Right Column
	AddPortrait("ICON_" .. projectType);

	-- Right Column
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
