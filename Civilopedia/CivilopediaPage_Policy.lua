-- ===========================================================================
--	Civilopedia - Policy Page Layout
-- ===========================================================================

PageLayouts["Policy" ] = function(page)
local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local policy = GameInfo.Policies[pageId];
	if(policy == nil) then
		return;
	end

	local policyType = policy.PolicyType;

	local obsolete_policies = {};
	for row in GameInfo.ObsoletePolicies() do
		if(row.PolicyType == policyType) then
			table.insert(obsolete_policies, GameInfo.Policies[row.ObsoletePolicy]);
		end
	end

	-- Right Column
	AddPortrait("ICON_" .. policyType);

	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		s:AddSeparator();

		if(#obsolete_policies > 0) then
			s:AddHeader("LOC_UI_PEDIA_MADE_OBSOLETE_BY");
			for i,v in ipairs(obsolete_policies) do
				s:AddIconLabel({"ICON_" .. v.PolicyType, v.Name, v.PolicyType}, v.Name);
			end
		end
			
		s:AddSeparator();
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_REQUIREMENTS", function(s)
		s:AddSeparator();

		if(policy.PrereqCivic ~= nil) then
			local civic = GameInfo.Civics[policy.PrereqCivic];
			if(civic) then
				s:AddHeader("LOC_CIVIC_NAME");
				s:AddIconLabel({"ICON_" .. civic.CivicType, civic.Name, civic.CivicType}, civic.Name);
			end
		end

		s:AddSeparator();
	end);

	-- Left Column
	AddChapter("LOC_UI_PEDIA_DESCRIPTION", policy.Description);

	local chapters = GetPageChapters(page.PageLayoutId);
	for i, chapter in ipairs(chapters) do
		local chapterId = chapter.ChapterId;
		local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
		local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

		AddChapter(chapter_header, chapter_body);
	end
end
