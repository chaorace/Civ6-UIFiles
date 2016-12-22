-- ===========================================================================
--	Civilopedia - Unit Promotion Page Layout
-- ===========================================================================

PageLayouts["UnitPromotion" ] = function(page)
	local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local promotion = GameInfo.UnitPromotions[pageId];
	if(promotion == nil) then
		return;
	end
	local promotionType = promotion.UnitPromotionType;

	-- Get some info!
	local prereqs = {};
	for row in GameInfo.UnitPromotionPrereqs() do
		if(row.UnitPromotion == promotionType) then
			local req_promotion = GameInfo.UnitPromotions[row.PrereqUnitPromotion];
			if(req_promotion) then
				table.insert(prereqs, Locale.Lookup(req_promotion.Name));
			end
		end
	end
	table.sort(prereqs, function(a,b) return Locale.Compare(a,b) == -1; end);

	-- Now to the right!
	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		s:AddSeparator();
		local promotionClass = promotion.PromotionClass;
		if(promotionClass) then
			local class = GameInfo.UnitPromotionClasses[promotionClass];
			if(class) then
				s:AddHeader("LOC_UI_PEDIA_PROMOTION_CLASS");
				s:AddLabel(class.Name);
			end
		end
		s:AddSeparator();
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_REQUIREMENTS", function(s)
		s:AddSeparator();
		if(#prereqs > 0) then
			s:AddHeader("LOC_UI_PEDIA_PROMOTIONS");
			for i, v in ipairs(prereqs) do
				s:AddLabel("[ICON_Bullet] " .. v);
			end
		end
		s:AddSeparator();
	end);

	-- Left Column!
	AddChapter("LOC_UI_PEDIA_DESCRIPTION", promotion.Description);

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
