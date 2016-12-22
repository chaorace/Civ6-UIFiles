-- ===========================================================================
--	Civilopedia - Feature Page Layout
-- ===========================================================================

PageLayouts["Feature" ] = function(page)
	local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local feature = GameInfo.Features[pageId];
	if(feature == nil) then
		return;
	end
	local featureType = feature.FeatureType;

	-- Get some info!
	local yield_changes = {};
	for row in GameInfo.Feature_YieldChanges() do
		if(row.FeatureType == featureType) then
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

	local traits = {};

	if(feature.Impassable) then
		table.insert(traits, Locale.Lookup("LOC_UI_PEDIA_TERRAIN_IMPASSABLE"));
	end

	table.sort(traits, function(a,b) return Locale.Compare(a,b) == -1; end);

	-- Right column, first!
	AddPortrait("ICON_" .. featureType);
	AddQuote(feature.Quote, feature.QuoteAudio);

	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		s:AddSeparator();
		if(#traits > 0) then
			for i,v in ipairs(traits) do
				s:AddLabel("[ICON_Bullet] " .. v);
			end
			s:AddSeparator();
		end

		if(#yield_changes > 0) then
			for _, v in ipairs(yield_changes) do
				s:AddLabel(Locale.Lookup("LOC_TYPE_TRAIT_YIELD", v[1], v[2], v[3]));
			end
			s:AddSeparator();
		end
	end);

	-- Now do left
	AddChapter("LOC_UI_PEDIA_DESCRIPTION", feature.Description);

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
