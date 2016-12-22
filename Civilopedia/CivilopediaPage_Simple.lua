-- ===========================================================================
--	Civilopedia - Simple Page Layout
-- ===========================================================================

PageLayouts["Simple" ] = function(page)
	local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local chapters = GetPageChapters(page.PageLayoutId);
	for i, chapter in ipairs(chapters) do
		local chapterId = chapter.ChapterId;
		local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
		local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

		-- Do not show chapter header for the first chapter if it matches the page's title or subtitle.
		if(chapter_header == nil or i == 1 and (Locale.Lookup(chapter_header) == page.Title) or (Locale.Lookup(chapter_header) == page.Subtitle)) then
			AddParagraphs(chapter_body);
		else
			AddChapter(chapter_header, chapter_body);
		end
	end
end
