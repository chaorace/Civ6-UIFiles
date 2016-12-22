-- ===========================================================================
--	Civilopedia - Front Page Layout
-- ===========================================================================

PageLayouts["FrontPage" ] = function(page)
	local sectionId = page.SectionId;
	local pageId = page.PageId;

	ShowFrontPageHeader();
	SetPageHeader(nil)
	SetPageSubHeader(nil)
	
	local chapters = GetPageChapters(page.PageLayoutId);
	for i, chapter in ipairs(chapters) do
		local chapterId = chapter.ChapterId;
		local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
		local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

		AddChapter(chapter_header, chapter_body);
	end
end
