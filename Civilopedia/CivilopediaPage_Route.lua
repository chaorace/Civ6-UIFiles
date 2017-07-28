-- ===========================================================================
--	Civilopedia - Route Page Layout
-- ===========================================================================

PageLayouts["Route" ] = function(page)
local sectionId = page.SectionId;
	local pageId = page.PageId;

	SetPageHeader(page.Title);
	SetPageSubHeader(page.Subtitle);

	local route = GameInfo.Routes[pageId];
	if(route == nil) then
		return;
	end

	local routeType = route.RouteType;

	local built_by = {};
	for row in GameInfo.Route_ValidBuildUnits() do
		if(row.RouteType == routeType) then
			local unit = GameInfo.Units[row.UnitType];
			if(unit) then
				table.insert(built_by, unit);
			end
		end
	end

	-- Traders can build all routes, but this isn't really conveyed anywhere via data.
	local trader = GameInfo.Units["UNIT_TRADER"]
	table.insert(built_by, trader);

	table.sort(built_by, function(a,b) return Locale.Compare(Locale.Lookup(a.Name), Locale.Lookup(b.Name)) == -1; end);


	-- Right Column
	AddPortrait("ICON_" .. routeType);

	AddRightColumnStatBox("LOC_UI_PEDIA_TRAITS", function(s)
		s:AddSeparator();

		s:AddLabel(Locale.Lookup("LOC_ROUTE_MOVEMENT_COST", route.MovementCost));
		
		if(route.SupportsBridges) then
			s:AddLabel("LOC_ROUTE_SUPPORTS_BRIDGES");
		end

		s:AddSeparator();
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_REQUIREMENTS", function(s)
		s:AddSeparator();

		if(route.PrereqEra ~= nil) then
			local era = GameInfo.Eras[route.PrereqEra];
			if(era) then
				s:AddHeader("LOC_ERA_NAME");
				s:AddLabel(era.Name);
			end
		end

		s:AddSeparator();
	end);

	AddRightColumnStatBox("LOC_UI_PEDIA_USAGE", function(s)
		s:AddSeparator();

		if(#built_by > 0) then
			s:AddHeader("LOC_UI_PEDIA_BUILT_BY");
			for i,v in ipairs(built_by) do
				s:AddIconLabel({"ICON_" .. v.UnitType, v.Name, v.UnitType}, v.Name);
			end
		end

		s:AddSeparator();
	end);

	-- Left Column
	AddChapter("LOC_UI_PEDIA_DESCRIPTION", route.Description);
	
	local chapters = GetPageChapters(page.PageLayoutId);
	for i, chapter in ipairs(chapters) do
		local chapterId = chapter.ChapterId;
		local chapter_header = GetChapterHeader(sectionId, pageId, chapterId);
		local chapter_body = GetChapterBody(sectionId, pageId, chapterId);

		AddChapter(chapter_header, chapter_body);
	end
end
