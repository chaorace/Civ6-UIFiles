-- ===========================================================================
--	Civilopedia - Terrain Page Layout
-- ===========================================================================

PageLayouts["Terrain" ] = function(page)
	local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local terrain = GameInfo.Terrains[pageId];
	if(terrain == nil) then
		return;
	end
	local terrainType = terrain.TerrainType;

	-- Get some info!
	local yield_changes = {};
	for row in GameInfo.Terrain_YieldChanges() do
		if(row.TerrainType== terrainType) then
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

	if(terrain.Hills) then
		table.insert(traits, Locale.Lookup("LOC_UI_PEDIA_TERRAIN_HILLS"));
	end

	if(terrain.Water) then
		table.insert(traits, Locale.Lookup("LOC_UI_PEDIA_TERRAIN_WATER"));
	end

	if(terrain.ShallowWater) then
		table.insert(traits, Locale.Lookup("LOC_UI_PEDIA_TERRAIN_SHALLOW_WATER"));
	end

	if(terrain.Impassable) then
		table.insert(traits, Locale.Lookup("LOC_UI_PEDIA_TERRAIN_IMPASSABLE"));
	end
	table.sort(traits, function(a,b) return Locale.Compare(a,b) == -1; end);

	-- Right column, first!
	AddPortrait("ICON_" .. terrainType);
	
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
