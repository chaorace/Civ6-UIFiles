-- ===========================================================================
--	Civilopedia - Religion Page Layout
-- ===========================================================================

PageLayouts["Religion" ] = function(page)	
	local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	-- Gather info.
	local religion = GameInfo.Religions[pageId];
	if(religion == nil) then
		return;
	end           
	local religionType = religion.ReligionType;
 
	local followers = {};
	for row in GameInfo.FavoredReligions() do
		if(row.ReligionType == religionType) then
			if(row.LeaderType == nil and row.CivilizationType) then
				local civ = GameInfo.Civilizations[row.CivilizationType];
				if(civ) then
					table.insert(followers, {"ICON_" .. civ.CivilizationType, civ.Name, civ.CivilizationType});
				end
			elseif(row.LeaderType) then
				local leader = GameInfo.Leaders[row.LeaderType];
				if(leader) then
					table.insert(followers, {"ICON_" .. leader.LeaderType, leader.Name, leader.LeaderType});
				end
			end
		end
	end

	-- Left column
	local chapters = GetPageChapters(page.PageLayoutId);
	for i, chapter in ipairs(chapters) do
		local chapterId = chapter.ChapterId;
		local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
		local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

		AddLeftColumnChapter(chapter_header, chapter_body);
	end

	-- Right column stats.
	AddPortrait("ICON_" .. religionType);
	
	if(#followers > 0) then
		AddRightColumnStatBox("LOC_UI_PEDIA_FOLLOWERS", function(s)
			s:AddSeparator();
			for i,v in ipairs(followers) do
				s:AddIconLabel(v, v[2]);
			end
		end);
	end
end