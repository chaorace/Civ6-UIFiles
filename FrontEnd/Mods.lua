-------------------------------------------------
-- Mods Browser Screen
-------------------------------------------------
include( "InstanceManager" );

LOC_MODS_SEARCH_NAME = Locale.Lookup("LOC_MODS_SEARCH_NAME");

g_ModListingsManager = InstanceManager:new("ModInstance", "ModInstanceRoot", Controls.ModListingsStack);
g_SubscriptionsListingsManager = InstanceManager:new("SubscriptionInstance", "SubscriptionInstanceRoot", Controls.SubscriptionListingsStack);

g_SearchContext = "Mods";
g_SearchQuery = nil;
g_ModListings = nil;			-- An array of pairs containing the mod handle and its associated listing.
g_SelectedModHandle = nil;		-- The currently selected mod entry.
g_CurrentListingsSort = nil;	-- The current method of sorting the mod listings.
g_ModSubscriptions = nil;
g_SubscriptionsSortingMap = {};

function RefreshModGroups()
	local groups = Modding.GetModGroups();
	for i, v in ipairs(groups) do
		v.DisplayName = Locale.Lookup(v.Name);
	end
	table.sort(groups, function(a,b)
		if(a.SortIndex == b.SortIndex) then
			-- Sort by Name.
			return Locale.Compare(a.DisplayName, b.DisplayName) == -1;
		else
			return a.SortIndex < b.SortIndex;
		end
	end);	
	
	local g = Modding.GetCurrentModGroup();

	local comboBox = Controls.ModGroupPullDown;
	comboBox:ClearEntries();
	for i, v in ipairs(groups) do
		local controlTable = {};
		comboBox:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:LocalizeAndSetText(v.Name);
	
		controlTable.Button:RegisterCallback(Mouse.eLClick, function()
			Modding.SetCurrentModGroup(v.Handle);
			RefreshModGroups();
			RefreshListings();
		end);	

		if(v.Handle == g) then
			comboBox:GetButton():SetText(v.DisplayName);
			Controls.DeleteModGroup:SetDisabled(not v.CanDelete);
		end
	end

	comboBox:CalculateInternals();
end
---------------------------------------------------------------------------
---------------------------------------------------------------------------
function RefreshListings()
	local mods = Modding.GetInstalledMods();

	g_ModListings = {};
	g_ModListingsManager:ResetInstances();

	Controls.EnableAll:SetDisabled(true);
	Controls.DisableAll:SetDisabled(true);

	if(mods == nil or #mods == 0) then
		Controls.ModListings:SetHide(true);
		Controls.NoModsInstalled:SetHide(false);
	else
		Controls.ModListings:SetHide(false);
		Controls.NoModsInstalled:SetHide(true);

		PreprocessListings(mods);

		mods = FilterListings(mods);

		SortListings(mods);

		local hasEnabledMods = false;
		local hasDisabledMods = false;

		for i,v in ipairs(mods) do		
			local instance = g_ModListingsManager:GetInstance();

			table.insert(g_ModListings, {v.Handle, instance});

			local handle = v.Handle;

			instance.ModInstanceRoot:RegisterCallback(Mouse.eLClick, function()
				SelectMod(handle);
			end);

			if(v.Allowance == false) then
				v.DisplayName = v.DisplayName .. " [COLOR_RED](" .. Locale.Lookup("LOC_MODS_DETAILS_OWNERSHIP_NO") .. ")[ENDCOLOR]";
			end
			instance.ModTitle:LocalizeAndSetText(v.DisplayName);

			local tooltip;
			if(#v.Teaser) then
				tooltip = Locale.Lookup(v.Teaser);
			end
			instance.ModInstanceRoot:SetToolTipString(tooltip);

			local enabled = v.Enabled;
			if(enabled) then
				hasEnabledMods = true;
				instance.ModEnabled:LocalizeAndSetText("LOC_MODS_ENABLED");
			else
				hasDisabledMods = true;
				instance.ModEnabled:SetText("[COLOR_RED]" .. Locale.Lookup("LOC_MODS_DISABLED") .. "[ENDCOLOR]");
			end

			instance.OfficialIcon:SetHide(v.Official ~= true);
		end

		if(hasEnabledMods) then
			Controls.DisableAll:SetDisabled(false);
		end

		if(hasDisabledMods) then
			Controls.EnableAll:SetDisabled(false);
		end

		Controls.ModListingsStack:CalculateSize();
		Controls.ModListingsStack:ReprocessAnchoring();
		Controls.ModListings:CalculateInternalSize();
	end

	-- Update the selection state of each listing.
	RefreshListingsSelectionState();
	RefreshModDetails();
end

---------------------------------------------------------------------------
-- Pre-process listings by translating strings or stripping tags.
---------------------------------------------------------------------------
function PreprocessListings(mods)
	for i,v in ipairs(mods) do
		v.DisplayName = Locale.Lookup(v.Name);
		v.StrippedDisplayName = Locale.StripTags(v.DisplayName);
	end
end

---------------------------------------------------------------------------
-- Filter the listings, returns filtered list.
---------------------------------------------------------------------------
function FilterListings(mods)

	local isFinalRelease = UI.IsFinalRelease();
	local showOfficialContent = Controls.ShowOfficialContent:IsChecked();
	local showCommunityContent = Controls.ShowCommunityContent:IsChecked();

	local original = mods;
	mods = {};
	for i,v in ipairs(original) do	
		-- Hide mods marked as always hidden or DLC which is not owned.
		local category = Modding.GetModProperty(v.Handle, "ShowInBrowser");
		if(category ~= "AlwaysHidden" and not (isFinalRelease and v.Allowance == false)) then
			-- Filter by selected options (currently only official and community content).
			if(v.Official and showOfficialContent) then
				table.insert(mods, v);
			elseif(not v.Official and showCommunityContent) then
				table.insert(mods, v);
			end
		end
	end

	-- Index remaining mods and filter by search query.
	if(Search.HasContext(g_SearchContext)) then
		Search.ClearData(g_SearchContext);
		for i, v in ipairs(mods) do
			Search.AddData(g_SearchContext, v.Handle, v.DisplayName, Locale.Lookup(v.Teaser or ""));
		end
		Search.Optimize(g_SearchContext);

		if(g_SearchQuery) then
			if (g_SearchQuery ~= nil and #g_SearchQuery > 0 and g_SearchQuery ~= LOC_MODS_SEARCH_NAME) then
				local include_map = {};
				local search_results = Search.Search(g_SearchContext, g_SearchQuery .. "*");
				if (search_results and #search_results > 0) then
					for i, v in ipairs(search_results) do
						include_map[tonumber(v[1])] = v[2];
					end
				end

				local original = mods;
				mods = {};
				for i,v in ipairs(original) do
					if(include_map[v.Handle]) then
						v.DisplayName = include_map[v.Handle];
						v.StrippedDisplayName = Locale.StripTags(v.DisplayName);
						table.insert(mods, v);
					end
				end
			end
		end
	end
	
	return mods;
end

---------------------------------------------------------------------------
-- Sort the listings in-place.
---------------------------------------------------------------------------
function SortListings(mods)
	if(g_CurrentListingsSort) then
		g_CurrentListingsSort(mods);
	end
end

-- Update the state of each instanced listing to reflect whether it is selected.
function RefreshListingsSelectionState()
	for i,v in ipairs(g_ModListings) do
		if(v[1] == g_SelectedModHandle) then
			v[2].ModInstanceRoot:SetColor(2/255,200/255,148/255);
		else
			v[2].ModInstanceRoot:SetColor(2/255,89/255,148/255);
		end
	end
end

function RefreshModDetails()
	if(g_SelectedModHandle == nil) then
		-- Hide details and offer up a guidance string.
		Controls.NoModSelected:SetHide(false);
		Controls.ModDetails:SetHide(true);

	else
		Controls.NoModSelected:SetHide(true);
		Controls.ModDetails:SetHide(false);

		local modHandle = g_SelectedModHandle;
		local info = Modding.GetModInfo(modHandle);

		if(info.Official) then
			Controls.ModContent:LocalizeAndSetText("LOC_MODS_FIRAXIAN_CONTENT");
		else
			Controls.ModContent:LocalizeAndSetText("LOC_MODS_USER_CONTENT");
		end

		local enableButton = Controls.EnableButton;
		local disableButton = Controls.DisableButton;
		if(info.Official and info.Allowance == false) then
			enableButton:SetHide(true);
			disableButton:SetHide(true);
		else
			local enabled = info.Enabled;
			if(enabled) then
				enableButton:SetHide(true);
				disableButton:SetHide(false);
				
				local err, xtra, sources = Modding.CanDisableMod(modHandle);
				if(err == "OK") then
					disableButton:SetDisabled(false);
					disableButton:SetToolTipString(Locale.Lookup("LOC_MODS_DISABLE"));

					disableButton:RegisterCallback(Mouse.eLClick, function()
						Modding.DisableMod(modHandle);
						RefreshListings();
					end);
				else
					disableButton:SetDisabled(true);
							
					-- Generate tip w/ list of mods to enable.
					local tip = {};
					local items = xtra or {};
					if(err == "MissingDependencies") then
						tip[1] = Locale.Lookup("LOC_MODS_DISABLE_ERROR_DEPENDS");
						items = sources or {}; -- show sources of errors rather than targets of error.
					else
						tip[1] = Locale.Lookup("LOC_MODS_DISABLE_ERROR") .. err;
					end

					for k,ref in ipairs(items) do
						table.insert(tip, "[ICON_BULLET] " .. Locale.Lookup(ref.Name));
					end

					disableButton:SetToolTipString(table.concat(tip, "[NEWLINE]"));
				end
			else
				enableButton:SetHide(false);
				disableButton:SetHide(true);
				local err, xtra = Modding.CanEnableMod(modHandle);
				if(err == "MissingDependencies") then
					-- Don't replace xtra since we want the old list to enumerate missing mods.
					err, _ = Modding.CanEnableMod(modHandle, true);
				end

				if(err == "OK") then
					enableButton:SetDisabled(false);

					if(xtra and #xtra > 0) then
						-- Generate tip w/ list of mods to enable.
						local tip = {Locale.Lookup("LOC_MODS_ENABLE_INCLUDE")};
						for k,ref in ipairs(xtra) do
							table.insert(tip, "[ICON_BULLET] " .. Locale.Lookup(ref.Name));
						end

						enableButton:SetToolTipString(table.concat(tip, "[NEWLINE]"));
					else	
						enableButton:SetToolTipString(Locale.Lookup("LOC_MODS_ENABLE"));
					end

					enableButton:RegisterCallback(Mouse.eLClick, function()
						Modding.EnableMod(modHandle, true);
						RefreshListings();
					end);
				else
					enableButton:SetDisabled(true);
							
					-- Generate tip w/ list of mods to enable.
					local tip = {Locale.Lookup("LOC_MODS_ENABLE_ERROR")};
					for k,ref in ipairs(xtra) do
						table.insert(tip, "[ICON_BULLET] " .. Locale.Lookup(ref.Name));
					end

					enableButton:SetToolTipString(table.concat(tip, "[NEWLINE]"));
				end
			end
		end

		Controls.ModTitle:LocalizeAndSetText(info.Name);
		Controls.ModIdVersion:SetText(info.Id);

		local desc = Modding.GetModProperty(g_SelectedModHandle, "Description") or info.Teaser;
		if(desc) then
			desc = Modding.GetModText(g_SelectedModHandle, desc) or desc
			Controls.ModDescription:LocalizeAndSetText(desc);
			Controls.ModDescription:SetHide(false);
		else
			Controls.ModDescription:SetHide(true);
		end

		local authors = Modding.GetModProperty(g_SelectedModHandle, "Authors");
		if(authors) then
			authors = Modding.GetModText(g_SelectedModHandle, authors) or authors
			Controls.ModAuthorsValue:LocalizeAndSetText(authors);
			Controls.ModAuthorsCaption:SetHide(false);
			Controls.ModAuthorsValue:SetHide(false);
		else
			Controls.ModAuthorsCaption:SetHide(true);
			Controls.ModAuthorsValue:SetHide(true);
		end

		local specialThanks = Modding.GetModProperty(g_SelectedModHandle, "SpecialThanks");
		if(specialThanks) then
			specialThanks = Modding.GetModText(g_SelectedModHandle, specialThanks) or specialThanks
			Controls.ModSpecialThanksValue:LocalizeAndSetText(specialThanks);
			Controls.ModSpecialThanksCaption:SetHide(false);
			Controls.ModSpecialThanksValue:SetHide(false);
		else
			Controls.ModSpecialThanksCaption:SetHide(true);
			Controls.ModSpecialThanksValue:SetHide(true);
		end

		if(info.Official and info.Allowance ~= nil) then
			
			Controls.ModOwnershipCaption:SetHide(false);
			Controls.ModOwnershipValue:SetHide(false);
			if(info.Allowance) then
				Controls.ModOwnershipValue:SetText("[COLOR_GREEN]" .. Locale.Lookup("LOC_MODS_YES") .. "[ENDCOLOR]");
			else
				Controls.ModOwnershipValue:SetText("[COLOR_RED]" .. Locale.Lookup("LOC_MODS_NO") .. "[ENDCOLOR]");
			end
		else
			Controls.ModOwnershipCaption:SetHide(true);
			Controls.ModOwnershipValue:SetHide(true);
		end

		local affectsSavedGames = Modding.GetModProperty(g_SelectedModHandle, "AffectsSavedGames");
		if(affectsSavedGames and tonumber(affectsSavedGames) == 0) then
			Controls.ModAffectsSavedGamesValue:LocalizeAndSetText("LOC_MODS_NO");
		else
			Controls.ModAffectsSavedGamesValue:LocalizeAndSetText("LOC_MODS_YES");
		end

		local supportsSinglePlayer = Modding.GetModProperty(g_SelectedModHandle, "SupportsSinglePlayer");
		if(supportsSinglePlayer and tonumber(supportsSinglePlayer) == 0) then
			Controls.ModSupportsSinglePlayerValue:LocalizeAndSetText("[COLOR_RED]" .. Locale.Lookup("LOC_MODS_NO") .. "[ENDCOLOR]");
		else
			Controls.ModSupportsSinglePlayerValue:LocalizeAndSetText("LOC_MODS_YES");
		end

		local supportsMultiplayer = Modding.GetModProperty(g_SelectedModHandle, "SupportsMultiplayer");
		if(supportsMultiplayer and tonumber(supportsMultiplayer) == 0) then
			Controls.ModSupportsMultiplayerValue:LocalizeAndSetText("[COLOR_RED]" .. Locale.Lookup("LOC_MODS_NO") .. "[ENDCOLOR]");
		else
			Controls.ModSupportsMultiplayerValue:LocalizeAndSetText("LOC_MODS_YES");
		end

		Controls.ModPropertiesValuesStack:CalculateSize();
		Controls.ModPropertiesValuesStack:ReprocessAnchoring();
		Controls.ModPropertiesCaptionStack:CalculateSize();
		Controls.ModPropertiesCaptionStack:ReprocessAnchoring();
		Controls.ModPropertiesStack:CalculateSize();
		Controls.ModPropertiesStack:ReprocessAnchoring();
		Controls.ModDetailsStack:CalculateSize();
		Controls.ModDetailsStack:ReprocessAnchoring();
		Controls.ModDetails:CalculateInternalSize();
	end
end

-- Select a specific entry in the listings.
function SelectMod(handle)
	g_SelectedModHandle = handle;
	RefreshListingsSelectionState();
	RefreshModDetails();
end

function CreateModGroup()
	Controls.ModGroupEditBox:SetText("");
	Controls.CreateModGroupButton:SetDisabled(true);

	Controls.NameModGroupPopup:SetHide(false);
	Controls.NameModGroupPopupAlpha:SetToBeginning();
	Controls.NameModGroupPopupAlpha:Play();
	Controls.NameModGroupPopupSlide:SetToBeginning();
	Controls.NameModGroupPopupSlide:Play();

	Controls.ModGroupEditBox:TakeFocus();
end

function DeleteModGroup()
	local currentGroup = Modding.GetCurrentModGroup();
	local groups = Modding.GetModGroups();
	for i, v in ipairs(groups) do
		v.DisplayName = Locale.Lookup(v.Name);
	end

	table.sort(groups, function(a,b)
		if(a.SortIndex == b.SortIndex) then
			-- Sort by Name.
			return Locale.Compare(a.DisplayName, b.DisplayName) == -1;
		else
			return a.SortIndex < b.SortIndex;
		end
	end);	

	for i, v in ipairs(groups) do
		if(v.Handle ~= currentGroup) then
			Modding.SetCurrentModGroup(v.Handle);
			Modding.DeleteModGroup(currentGroup);
			break;
		end
	end

	RefreshModGroups();
	RefreshListings();
end

function EnableAllMods()
	local mods = Modding.GetInstalledMods();
	PreprocessListings(mods);
	mods = FilterListings(mods);

	local modHandles = {};
	for i,v in ipairs(mods) do
		modHandles[i] = v.Handle;
	end
	Modding.EnableMod(modHandles);
	RefreshListings();
end

function DisableAllMods()
	local mods = Modding.GetInstalledMods();
	PreprocessListings(mods);
	mods = FilterListings(mods);

	local modHandles = {};
	for i,v in ipairs(mods) do
		modHandles[i] = v.Handle;
	end
	Modding.DisableMod(modHandles);
	RefreshListings();
end

----------------------------------------------------------------        
-- Subscriptions Tab
----------------------------------------------------------------        
function RefreshSubscriptions()
	local subs = Modding.GetSubscriptions();

	g_Subscriptions = {};
	g_SubscriptionsSortingMap = {};
	g_SubscriptionsListingsManager:ResetInstances();

	Controls.NoSubscriptions:SetHide(#subs > 0);

	for i,v in ipairs(subs) do
		local instance = g_SubscriptionsListingsManager:GetInstance();
		table.insert(g_Subscriptions, {
			SubscriptionId = v,
			Instance = instance,
			NeedsRefresh = true
		});
	end
	UpdateSubscriptions()

	Controls.SubscriptionListingsStack:CalculateSize();
	Controls.SubscriptionListingsStack:ReprocessAnchoring();
	Controls.SubscriptionListings:CalculateInternalSize();
end
----------------------------------------------------------------  
function RefreshSubscriptionItem(item)

	local needsRefresh = false;
	local instance = item.Instance;
	local subscriptionId = item.SubscriptionId;

	local details = Modding.GetSubscriptionDetails(subscriptionId);

	local name = details.Name;
	if(name == nil) then
		name = Locale.Lookup("LOC_MODS_SUBSCRIPTION_NAME_PENDING");
		needsRefresh = true;
	end

	instance.SubscriptionTitle:SetText(name);
	g_SubscriptionsSortingMap[tostring(instance.SubscriptionInstanceRoot)] = name;

	if(details.LastUpdated) then
		instance.LastUpdated:SetText(Locale.Lookup("LOC_MODS_LAST_UPDATED", details.LastUpdated));
	end
	
	local status = details.Status;
	instance.SubscriptionDownloadProgress:SetHide(status ~= "Downloading");
	if(status == "Downloading") then
		local downloaded, total = Modding.GetSubscriptionDownloadStatus(subscriptionId);

		if(total > 0) then
			local w = instance.SubscriptionInstanceRoot:GetSizeX();
			local pct = downloaded/total;

			instance.SubscriptionDownloadProgress:SetSizeX(math.floor(w * pct));
			instance.SubscriptionDownloadProgress:SetHide(false);
		else
			instance.SubscriptionDownloadProgress:SetHide(true);
		end

		instance.SubscriptionStatus:LocalizeAndSetText("LOC_MODS_SUBSCRIPTION_DOWNLOADING", downloaded, total);
	else
		local statusStrings = {
			["Installed"] = "LOC_MODS_SUBSCRIPTION_DOWNLOAD_INSTALLED",
			["DownloadPending"] = "LOC_MODS_SUBSCRIPTION_DOWNLOAD_PENDING",
			["Subscribed"] = "LOC_MODS_SUBSCRIPTION_SUBSCRIBED"
		};
		instance.SubscriptionStatus:LocalizeAndSetText(statusStrings[status]);
	end

	if(Steam and Steam.IsOverlayEnabled and Steam.IsOverlayEnabled()) then
		instance.SubscriptionViewButton:SetHide(false);
		instance.SubscriptionViewButton:RegisterCallback(Mouse.eLClick, function()
			local url = "http://steamcommunity.com/sharedfiles/filedetails/?id=" .. subscriptionId;
			Steam.ActivateGameOverlayToUrl(url);
		end);
	else
		instance.SubscriptionViewButton:SetHide(true);
	end

	-- If we're downloading or about to download, keep refreshing the details.
	if(status == "Downloading" or status == "DownloadingPending") then
		needsRefresh = true;
		instance.SubscriptionUpdateButton:SetHide(true);
	else
		local needsUpdate = details.NeedsUpdate;
		if(needsUpdate) then
			instance.SubscriptionUpdateButton:SetHide(false);
			instance.SubscriptionUpdateButton:RegisterCallback(Mouse.eLClick, function()
				Modding.UpdateSubscription(subscriptionId);
				RefreshSubscriptions();
			end);
		else
			instance.SubscriptionUpdateButton:SetHide(true);
		end
	end



	item.NeedsRefresh = needsRefresh;
end
----------------------------------------------------------------  
function SortSubscriptionListings(a,b)
	-- ForgUI requires a strict weak ordering sort.
	local ap = g_SubscriptionsSortingMap[tostring(a)];
	local bp = g_SubscriptionsSortingMap[tostring(b)];

	if(ap == nil and bp ~= nil) then
		return true;
	elseif(ap == nil and bp == nil) then
		return tostring(a) < tostring(b);
	elseif(ap ~= nil and bp == nil) then
		return false;
	else
		return Locale.Compare(ap, bp) == -1;
	end
end
----------------------------------------------------------------  
function UpdateSubscriptions()
	local updated = false;
	if(g_Subscriptions) then
		for i, v in ipairs(g_Subscriptions) do
			if(v.NeedsRefresh) then
				RefreshSubscriptionItem(v);
				updated = true;
			end
		end
	end

	if(updated) then
		Controls.SubscriptionListingsStack:SortChildren(SortSubscriptionListings);
	end
end


----------------------------------------------------------------        
-- Input Handler
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			HandleExitRequest();
		end
	end

	-- TODO: Is this needed?
	return true;
end
ContextPtr:SetInputHandler( InputHandler );

----------------------------------------------------------------  
function OnInstalledModsTabClick(bForce)
	if(Controls.InstalledTabPanel:IsHidden() or bForce) then
		Controls.SubscriptionsTabPanel:SetHide(true);
		Controls.InstalledTabPanel:SetHide(false);

		-- Clear search queries.
		g_SearchQuery = nil;
		g_SelectedModHandle = nil;

		Controls.SearchEditBox:SetText(LOC_MODS_SEARCH_NAME);
		RefreshModGroups();
		RefreshListings();
	end
end
----------------------------------------------------------------  
function OnSubscriptionsTabClick()
	if(Controls.SubscriptionsTabPanel:IsHidden() or bForce) then
		Controls.InstalledTabPanel:SetHide(true);
		Controls.SubscriptionsTabPanel:SetHide(false);

		RefreshSubscriptions();
	end
end
----------------------------------------------------------------  
function OnOpenWorkshop()
	if (Steam ~= nil) then
		Steam.ActivateGameOverlayToWorkshop();
	end
end

----------------------------------------------------------------  
function OnWorldBuilder()
	local worldBuilderMenu = ContextPtr:LookUpControl("/FrontEnd/MainMenu/WorldBuilder");
	if (worldBuilderMenu ~= nil) then
		GameConfiguration.SetWorldBuilderEditor(true);
		UIManager:QueuePopup(worldBuilderMenu, PopupPriority.Current);
	end
end

----------------------------------------------------------------    
function OnShow()
	OnInstalledModsTabClick(true);

	if(GameConfiguration.IsAnyMultiplayer() or not UI.HasFeature("WorldBuilder")) then
		Controls.WorldBuilder:SetHide(true);
		Controls.BrowseWorkshop:SetHide(true);
	else
		Controls.WorldBuilder:SetHide(false);
		Controls.BrowseWorkshop:SetHide(false);
	end
end	
----------------------------------------------------------------    
function HandleExitRequest()
	UIManager:DequeuePopup( ContextPtr );
end
----------------------------------------------------------------  
function PostInit()
	if(not ContextPtr:IsHidden()) then
		OnShow();
	end
end

function OnUpdate(delta)
	-- Overkill..
	UpdateSubscriptions();
end
----------------------------------------------------------------  
-- ===========================================================================
--	Handle Window Sizing
-- ===========================================================================
function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	local hideLogo = true;
	if(screenY >= Controls.MainWindow:GetSizeY() + (Controls.LogoContainer:GetSizeY()+ Controls.LogoContainer:GetOffsetY())*2) then
		hideLogo = false;
	end
	Controls.LogoContainer:SetHide(hideLogo);
	Controls.MainGrid:ReprocessAnchoring();
end

function OnSearchBarGainFocus()
	Controls.SearchEditBox:ClearString();
end

function OnSearchCharCallback()
	local str = Controls.SearchEditBox:GetText();
	if (str ~= nil and #str > 0 and str ~= LOC_MODS_SEARCH_NAME) then
		g_SearchQuery = str;
		RefreshListings();
	elseif(str == nil or #str == 0) then
		g_SearchQuery = nil;
		RefreshListings();
	end
end


---------------------------------------------------------------------------
-- Sort By Pulldown setup
-- Must exist below callback function names
---------------------------------------------------------------------------
function SortListingsByName(mods)
	table.sort(mods, function(a,b) 
		return Locale.Compare(a.StrippedDisplayName, b.StrippedDisplayName) == -1;
	end);
end
---------------------------------------------------------------------------
function SortListingsByEnabled(mods)
	table.sort(mods, function(a,b)
		if(a.Enabled == b.Enabled) then
			-- Sort by Name.
			return Locale.Compare(a.StrippedDisplayName, b.StrippedDisplayName) == -1;
		else
			return a.Enabled;
		end
	end);	
end
---------------------------------------------------------------------------
local g_SortListingsOptions = {
	{"{LOC_MODS_SORTBY} {LOC_MODS_SORTBY_NAME}", SortListingsByName},
	{"{LOC_MODS_SORTBY} {LOC_MODS_SORTBY_ENABLED}", SortListingsByEnabled},
};
---------------------------------------------------------------------------
function InitializeSortListingsPulldown()
	local sortByPulldown = Controls.SortListingsPullDown;
	sortByPulldown:ClearEntries();
	for i, v in ipairs(g_SortListingsOptions) do
		local controlTable = {};
		sortByPulldown:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:LocalizeAndSetText(v[1]);
	
		controlTable.Button:RegisterCallback(Mouse.eLClick, function()
			sortByPulldown:GetButton():LocalizeAndSetText( v[1] );
			g_CurrentListingsSort = v[2];
			RefreshListings();
		end);
	
	end
	sortByPulldown:CalculateInternals();

	sortByPulldown:GetButton():LocalizeAndSetText(g_SortListingsOptions[1][1]);
	g_CurrentListingsSort = g_SortListingsOptions[1][2];
end

function Initialize()
	Controls.EnableAll:RegisterCallback(Mouse.eLClick, EnableAllMods);
	Controls.DisableAll:RegisterCallback(Mouse.eLClick, DisableAllMods);
	Controls.CreateModGroup:RegisterCallback(Mouse.eLClick, CreateModGroup);
	Controls.DeleteModGroup:RegisterCallback(Mouse.eLClick, DeleteModGroup);
	
	if(not Search.CreateContext(g_SearchContext, "[COLOR_LIGHTBLUE]", "[ENDCOLOR]", "...")) then
		print("Failed to create mods browser search context!");
	end
	Controls.SearchEditBox:RegisterStringChangedCallback(OnSearchCharCallback);
	Controls.SearchEditBox:RegisterHasFocusCallback(OnSearchBarGainFocus);

	Controls.ShowOfficialContent:RegisterCallback(Mouse.eLClick, function()
		RefreshListings();
	end);

	Controls.ShowCommunityContent:RegisterCallback(Mouse.eLClick, function()
		RefreshListings();
	end);

	Controls.CancelBindingButton:RegisterCallback(Mouse.eLClick, function()
		Controls.NameModGroupPopup:SetHide(true);
	end);

	Controls.CreateModGroupButton:RegisterCallback(Mouse.eLCick, function()
		Controls.NameModGroupPopup:SetHide(true);
		local groupName = Controls.ModGroupEditBox:GetText();
		local currentGroup = Modding.GetCurrentModGroup();
		Modding.CreateModGroup(groupName, currentGroup);
		RefreshModGroups();
		RefreshListings();
	end);

	Controls.ModGroupEditBox:RegisterStringChangedCallback(function()
		local str = Controls.ModGroupEditBox:GetText();
		Controls.CreateModGroupButton:SetDisabled(str == nil or #str == 0);
	end);

	Controls.ModGroupEditBox:RegisterCommitCallback(function()
		local str = Controls.ModGroupEditBox:GetText();
		if(str and #str > 0) then
			Controls.NameModGroupPopup:SetHide(true);
			local currentGroup = Modding.GetCurrentModGroup();
			Modding.CreateModGroup(str, currentGroup);
			RefreshModGroups();
			RefreshListings();
		end
	end);

	if(Steam.IsOverlayEnabled()) then
		Controls.SubscriptionsTab:RegisterCallback(Mouse.eLClick, function() OnSubscriptionsTabClick() end);
		Controls.SubscriptionsTab:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
		Controls.BrowseWorkshop:RegisterCallback( Mouse.eLClick, OnOpenWorkshop );
		Controls.BrowseWorkshop:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	else
		Controls.SubscriptionsTab:SetDisabled(true);
		Controls.BrowseWorkshop:SetDisabled(true);
	end
	Controls.ShowOfficialContent:SetCheck(true);
	Controls.ShowCommunityContent:SetCheck(true);

	InitializeSortListingsPulldown();
	Resize();
	Controls.InstalledTab:RegisterCallback(Mouse.eLClick, function() OnInstalledModsTabClick() end);
	Controls.InstalledTab:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CloseButton:RegisterCallback( Mouse.eLClick, HandleExitRequest );
	Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Controls.WorldBuilder:RegisterCallback(Mouse.eLClick, OnWorldBuilder);
	Controls.WorldBuilder:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetUpdate(OnUpdate);
	ContextPtr:SetPostInit(PostInit);	
end

Initialize();
