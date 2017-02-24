include( "SupportFunctions" );
----------------------------------------------------------------        
-- Shared code for the LoadGameMenu and the SaveGameMenu
----------------------------------------------------------------        

-- The menu type that is using the shared code.
LOAD_GAME = 1;
SAVE_GAME = 2;
PAUSE_INCREMENT = .18;

-- Global Constants
g_FileEntryInstanceManager	= InstanceManager:new("FileEntry", "InstanceRoot", Controls.FileListEntryStack );
g_DescriptionTextManager	= InstanceManager:new("DescriptionText", "Root", Controls.GameInfoStack );
g_DescriptionHeaderManager	= InstanceManager:new("DetailsHeader", "Root", Controls.GameInfoStack );
g_DescriptionItemManager	= InstanceManager:new("DetailsItem", "Root", Controls.GameInfoStack );

-- Global Variables
g_ShowCloudSaves = false;
g_ShowAutoSaves = false;
g_MenuType = 0;
g_iSelectedFileEntry = -1;

g_CloudSaves = {};

g_FileList = {};
g_FileEntryInstanceList = {};
g_GameType = SaveTypes.SINGLE_PLAYER;

g_CurrentGameMetaData = nil

g_FilenameIsValid = false;

----------------------------------------------------------------        
-- File Name Handling
----------------------------------------------------------------

----------------------------------------------------------------
function ValidateFileName(text)
	local isAllWhiteSpace = true;
	for i = 1, #text, 1 do
		if (string.byte(text, i) ~= 32) then
			isAllWhiteSpace = false;
			break;
		end
	end
	
	if (isAllWhiteSpace) then
		return false;
	end

	-- don't allow % character
	for i = 1, #text, 1 do
		if string.byte(text, i) == 37 then
			return false;
		end
	end

	local invalidCharArray = { '\"', '<', '>', '|', '\b', '\0', '\t', '\n', '/', '\\', '*', '?', ':' };

	for i, ch in ipairs(invalidCharArray) do
		if (string.find(text, ch) ~= nil) then
			return false;
		end
	end

	-- don't allow control characters
	for i = 1, #text, 1 do
		if (string.byte(text, i) < 32) then
			return false;
		end
	end

	return true;
end

----------------------------------------------------------------        
-- File sort pulldown and related
----------------------------------------------------------------        
g_CurrentSort = nil;	-- The current sorting technique.

----------------------------------------------------------------        
function AlphabeticalSort( a, b )    
    return Locale.Compare(a.DisplayName, b.DisplayName) == -1;
end

----------------------------------------------------------------        
function ReverseAlphabeticalSort( a, b ) 
    return Locale.Compare(a.DisplayName, b.DisplayName) == -1;
end

----------------------------------------------------------------        
function SortByName(a, b)
	if(g_ShowAutoSaves) then
		return ReverseAlphabeticalSort(a,b);
	else
		return AlphabeticalSort(a,b);
	end 
end

----------------------------------------------------------------        
function SortByLastModified(a, b)

	if(a.LastModifiedHigh == nil or a.LastModifiedLow == nil) then
        return false;
    elseif(b.LastModifiedHigh == nil or b.LastModifiedLow == nil) then
        return true;
    elseif ( a.LastModifiedHigh == b.LastModifiedHigh ) then
		return (a.LastModifiedLow > b.LastModifiedLow );
	else
		return ( a.LastModifiedHigh > b.LastModifiedHigh );
	end

end

---------------------------------------------------------------------------
-- Sort By Pulldown setup
-- Must exist below callback function names
---------------------------------------------------------------------------
local m_sortOptions = {
	{"LOC_SORTBY_LASTMODIFIED", SortByLastModified},
	{"LOC_SORTBY_NAME",			SortByName},
};


---------------------------------------------------------------------------
function SetupSortPulldown()
	local sortByPulldown = Controls.SortByPullDown;
	sortByPulldown:ClearEntries();
	for i, v in ipairs(m_sortOptions) do
		local controlTable = {};
		sortByPulldown:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:LocalizeAndSetText(v[1]);
	
		controlTable.Button:RegisterCallback(Mouse.eLClick, function()
			sortByPulldown:GetButton():LocalizeAndSetText( v[1] );
			g_CurrentSort = v[2];
			RebuildFileList();
		end);
	
	end
	sortByPulldown:CalculateInternals();

	sortByPulldown:GetButton():LocalizeAndSetText(m_sortOptions[1][1]);
	g_CurrentSort = m_sortOptions[1][2];
end

----------------------------------------------------------------        
-- File List creation
----------------------------------------------------------------        

function UpdateGameType()
	-- Updates the gameType from the game configuration. 
	if(GameConfiguration.IsWorldBuilderEditor()) then
		g_GameType = SaveTypes.WORLDBUILDER_MAP;
	else
		g_GameType = Network.GetGameConfigurationSaveType();
	end
end

----------------------------------------------------------------        
---------------------------------------------------------------- 
function GetDisplayName(file)
	return Path.GetFileNameWithoutExtension(file);
end

----------------------------------------------------------------        
----------------------------------------------------------------   
function DismissCurrentSelected()   
    if( g_iSelectedFileEntry ~= -1 ) then
		g_FileEntryInstanceList[ g_iSelectedFileEntry ].SelectionAnimAlpha:Reverse();
		g_FileEntryInstanceList[ g_iSelectedFileEntry ].SelectionAnimSlide:Reverse();
		g_FileEntryInstanceList[ g_iSelectedFileEntry ].Button:SetDisabled(false);
		g_iSelectedFileEntry = -1;
    end  
end

function SetSelected( index )
	if( index == -1) then
		Controls.NoSelectedFile:SetHide(false);
		Controls.SelectedFile:SetHide(true);
	else
		Controls.NoSelectedFile:SetHide(true);
		Controls.SelectedFile:SetHide(false);
	end
	
	DismissCurrentSelected();

    g_iSelectedFileEntry = index;
	local modsHidden = true;
    if( g_iSelectedFileEntry ~= -1 ) then
		g_FileEntryInstanceList[ g_iSelectedFileEntry ].SelectionAnimAlpha:SetToBeginning();
		g_FileEntryInstanceList[ g_iSelectedFileEntry ].SelectionAnimAlpha:Play();
		g_FileEntryInstanceList[ g_iSelectedFileEntry ].SelectionAnimSlide:SetToBeginning();
		g_FileEntryInstanceList[ g_iSelectedFileEntry ].SelectionAnimSlide:Play();
		g_FileEntryInstanceList[ g_iSelectedFileEntry ].Button:SetDisabled(true);
		local kSelectedFile = g_FileList[ g_iSelectedFileEntry ];
		local displayName = GetDisplayName(kSelectedFile.Name); 

		local mods = kSelectedFile.RequiredMods or {};
		local mod_errors = Modding.CheckRequirements(mods, g_GameType);
		local success = (mod_errors == nil or mod_errors.Success);

		-- Populate details of the save, include list of mod errors so the UI can reflect.
		PopulateInspectorData(kSelectedFile, displayName, mod_errors);

		if (g_MenuType == LOAD_GAME) then
			-- Assume the filename is valid when loading.
			g_FilenameIsValid = true;
		else
			g_FilenameIsValid = ValidateFileName(displayName);
		end

		UpdateActionButtonState();
		Controls.Delete:SetHide( false );

		-- Presume there are no errors if the table is nil.
		Controls.ActionButton:SetDisabled(not success);
	else
		if (g_MenuType == LOAD_GAME) then
			Controls.ActionButton:SetDisabled( true );
			Controls.ActionButton:SetToolTipString(nil);
		end

		Controls.Delete:SetHide( true );
    end
	if(not modsHidden) then
		Controls.GameInfoScrollPanel:SetSizeY(280);
	else
		Controls.GameInfoScrollPanel:SetSizeY(320);
	end
end

-----------------------------------------------------------------------------------------------------------------------
function PopulateInspectorData(fileInfo, fileName, mod_errors)

	function LookupBundleOrText(value)
		if(value) then
			local text = Locale.LookupBundle(value);
			if(text == nil) then
				text = Locale.Lookup(value);
			end
			return text;
		end
	end

	local name = fileInfo.DisplayName or fileName;
	if(name ~= nil) then
		Controls.FileName:SetText(name);
	else
		-- Set default file data for save game...
		local defaultFileName: string = "";
		local turnNumber = Game.GetCurrentGameTurn();
		local localPlayer = Game.GetLocalPlayer();
		if (localPlayer ~= -1) then
			local player = Players[localPlayer];
			local playerConfig = PlayerConfigurations[player:GetID()];
			local strDate = Calendar.MakeYearStr(turnNumber, GameConfiguration.GetCalendarType(), GameConfiguration.GetGameSpeedType(), false);
			defaultFileName = Locale.ToUpper( Locale.Lookup(playerConfig:GetLeaderName())).." "..turnNumber.. " ".. strDate;
		end
		Controls.FileName:SetText(defaultFileName);
	end
		
	-- Preview image
	local bHasPreview = UI.ApplyFileQueryPreviewImage( g_LastFileQueryRequestID, fileInfo.Id, Controls.SavedMinimap);
	Controls.SavedMinimapContainer:SetShow(bHasPreview);
	Controls.SavedMinimap:SetShow(bHasPreview);
	Controls.NoMapDataLabel:SetHide(bHasPreview);

	local hostCivilizationName = LookupBundleOrText(fileInfo.HostCivilizationName);
	Controls.CivIcon:SetToolTipString(hostCivilizationName);
		
	local hostLeaderName = LookupBundleOrText(fileInfo.HostLeaderName);
	Controls.LeaderIcon:SetToolTipString(hostLeaderName);

	if (fileInfo.HostLeader ~= nil and fileInfo.HostCivilization ~= nil) then

		if (fileInfo.HostBackgroundColorValue ~= nil and fileInfo.HostForegroundColorValue ~= nil) then

			local m_secondaryColor = fileInfo.HostBackgroundColorValue;
			local m_primaryColor = fileInfo.HostForegroundColorValue;
			local darkerBackColor = DarkenLightenColor(m_primaryColor,(-85),100);
			local brighterBackColor = DarkenLightenColor(m_primaryColor,90,255);

			-- Icon colors
			Controls.CivBacking_Base:SetColor(m_primaryColor);
			Controls.CivBacking_Lighter:SetColor(brighterBackColor);
			Controls.CivBacking_Darker:SetColor(darkerBackColor);
			Controls.CivIcon:SetColor(m_secondaryColor);
		end

		if (not UI.ApplyFileQueryLeaderImage( g_LastFileQueryRequestID, fileInfo.Id, Controls.LeaderIcon)) then
			if(not Controls.LeaderIcon:SetIcon("ICON_"..fileInfo.HostLeader)) then
				Controls.LeaderIcon:SetIcon("ICON_LEADER_DEFAULT")
			end
		end

		if (not UI.ApplyFileQueryCivImage( g_LastFileQueryRequestID, fileInfo.Id, Controls.CivIcon)) then
			if(not Controls.CivIcon:SetIcon("ICON_"..fileInfo.HostCivilization)) then
				Controls.CivIcon:SetIcon("ICON_CIVILIZATION_UNKNOWN")
			end
		end

	else
		Controls.CivBacking_Base:SetColorByName("LoadSaveGameInfoIconBackingBase");
		Controls.CivBacking_Darker:SetColorByName("LoadSaveGameInfoIconBackingDarker");
		Controls.CivBacking_Lighter:SetColorByName("LoadSaveGameInfoIconBackingLighter");
		Controls.CivIcon:SetColorByName("White");			

		Controls.CivIcon:SetIcon("ICON_CIVILIZATION_UNKNOWN");
		Controls.LeaderIcon:SetIcon("ICON_LEADER_DEFAULT");
	end

	-- Difficulty
	local gameDifficulty = LookupBundleOrText(fileInfo.HostDifficultyName);
	Controls.GameDifficulty:SetToolTipString(gameDifficulty);
	if (fileInfo.HostDifficulty ~= nil) then
		if(not Controls.GameDifficulty:SetIcon("ICON_"..fileInfo.HostDifficulty)) then
			Controls.GameDifficulty:SetIcon("ICON_DIFFICULTY_SETTLER");
		end
	else
		Controls.GameDifficulty:SetIcon("ICON_DIFFICULTY_SETTLER");
	end

	-- Game speed
	local gameSpeedName = LookupBundleOrText(fileInfo.GameSpeedName);
	Controls.GameSpeed:SetToolTipString(gameSpeedName);

	if (fileInfo.GameSpeed ~= nil) then
		if(not Controls.GameSpeed:SetIcon("ICON_"..fileInfo.GameSpeed)) then
			Controls.GameSpeed:SetIcon("ICON_GAMESPEED_STANDARD");
		end
	else
		Controls.GameSpeed:SetIcon("ICON_GAMESPEED_STANDARD");
	end
		
	if (fileInfo.CurrentTurn ~= nil) then
		Controls.SelectedCurrentTurnLabel:LocalizeAndSetText("LOC_LOADSAVE_CURRENT_TURN", fileInfo.CurrentTurn);
	else
		Controls.SelectedCurrentTurnLabel:SetText("");
	end

	if (fileInfo.DisplaySaveTime ~= nil) then
		Controls.SelectedTimeLabel:SetText(fileInfo.DisplaySaveTime);
	else
		Controls.SelectedTimeLabel:SetText("");
	end

	local hostEraName = LookupBundleOrText(fileInfo.HostEraName);
	Controls.SelectedHostEraLabel:SetText(hostEraName);

	g_DescriptionTextManager:ResetInstances();
	g_DescriptionHeaderManager:ResetInstances();
	g_DescriptionItemManager:ResetInstances();

	optionsHeader = g_DescriptionHeaderManager:GetInstance();
	optionsHeader.HeadingTitle:LocalizeAndSetText("LOC_LOADSAVE_GAME_OPTIONS_HEADER_TITLE");

	local mapScriptName = LookupBundleOrText(fileInfo.MapScriptName);
	if(mapScriptName) then
		local maptype = g_DescriptionItemManager:GetInstance();
		maptype.Title:SetText("LOC_LOADSAVE_GAME_OPTIONS_MAP_TYPE_TITLE");
		maptype.Description:SetText(mapScriptName);
	end

	local mapSizeName = LookupBundleOrText(fileInfo.MapSizeName);
	if (mapSizeName) then
		local mapsize = g_DescriptionItemManager:GetInstance();
		mapsize.Title:LocalizeAndSetText("LOC_LOADSAVE_GAME_OPTIONS_MAP_SIZE_TITLE");
		mapsize.Description:SetText(mapSizeName);
	end

	if (fileInfo.SavedByVersion ~= nil) then
		local savedByVersion = g_DescriptionItemManager:GetInstance();
		savedByVersion.Title:LocalizeAndSetText("LOC_LOADSAVE_SAVED_BY_VERSION_TITLE");
		savedByVersion.Description:SetText(fileInfo.SavedByVersion);
	end

	if (fileInfo.TunerActive ~= nil and fileInfo.TunerActive == true) then
		local tunerActive = g_DescriptionItemManager:GetInstance();
		tunerActive.Title:LocalizeAndSetText("LOC_LOADSAVE_TUNER_ACTIVE_TITLE");
		tunerActive.Description:LocalizeAndSetText("LOC_YES_BUTTON");
	end

	-- advanced = g_DescriptionItemManager:GetInstance();
	-- advanced.Title:LocalizeAndSetText("LOC_LOADSAVE_GAME_OPTIONS_ADVANCED_TITLE");
	-- advanced.Description:SetText("Quick Combat[NEWLINE]Quick Movement[NEWLINE]No City Razing[NEWLINE]No Barbarians");

	-- List mods.
	local mods = fileInfo.RequiredMods or {};
	local mod_titles = {};

	for i,v in ipairs(mods) do
		local title;
			
		local mod_handle = Modding.GetModHandle(v.Id);
		if(mod_handle) then
			local mod_info = Modding.GetModInfo(mod_handle);
			title = Locale.Lookup(mod_info.Name);
		else
			title = Locale.LookupBundle(v.Title);
			if(title == nil or #title == 0) then
				title = Locale.Lookup(v.Title);
			end
		end

		if(mod_errors and mod_errors[v.Id]) then
			table.insert(mod_titles, "[ICON_BULLET] [COLOR_RED]" .. title .. "[ENDCOLOR]");
		else
			table.insert(mod_titles, "[ICON_BULLET] " .. title);
		end
	end
	table.sort(mod_titles, function(a,b) return Locale.Compare(a,b) == -1 end);
	
	if(#mod_titles > 0) then		
		spacer = g_DescriptionTextManager:GetInstance();
		spacer.Text:SetText(" ");

		local header = g_DescriptionHeaderManager:GetInstance();
		header.HeadingTitle:LocalizeAndSetText("LOC_MAIN_MENU_ADDITIONAL_CONTENT");
		for i,v in ipairs(mod_titles) do
			local instance = g_DescriptionTextManager:GetInstance();
			instance.Text:SetText(v);	
		end
	end

	Controls.SelectedGameInfoStack1:CalculateSize();
	Controls.SelectedGameInfoStack1:ReprocessAnchoring();
	Controls.SelectedGameInfoStack2:CalculateSize();
	Controls.SelectedGameInfoStack2:ReprocessAnchoring();

	Controls.Root:CalculateVisibilityBox();
	Controls.Root:ReprocessAnchoring();

	Controls.SavedMinimap:SetSizeX(249);
	Controls.SavedMinimap:ReprocessAnchoring();
	Controls.SavedMinimapContainer:ReprocessAnchoring();

	Controls.InspectorTopAreaStack:CalculateSize();
	Controls.InspectorTopAreaStack:ReprocessAnchoring();

	Controls.InspectorTopAreaGrid:DoAutoSize();
	Controls.InspectorTopAreaGrid:ReprocessAnchoring();

	Controls.InspectorTopAreaGridContainer:DoAutoSize();
	Controls.InspectorTopAreaGridContainer:ReprocessAnchoring();

	Controls.InspectorTopAreaBox:DoAutoSize();
	Controls.InspectorTopAreaBox:ReprocessAnchoring();

	Controls.InspectorTopArea:DoAutoSize();
	Controls.InspectorTopArea:ReprocessAnchoring();


	Controls.GameInfoStack:CalculateSize();
	Controls.GameInfoStack:ReprocessAnchoring();
	Controls.GameInfoScrollPanel:CalculateSize();
	Controls.GameInfoScrollPanel:ReprocessAnchoring();

end

----------------------------------------------------------------     
function BuildCascadingButtonList()

end

----------------------------------------------------------------     
-- Executes a function every frame so long as that function 
-- returns true.
----------------------------------------------------------------     
function UpdateOverTime(func)
	
end

----------------------------------------------------------------     
-- Returns an iterator function that will enumerate 'entries'
-- and execute 'per_entry_func' for each entry.  Each execution
-- will enumerate 'batch_count' entries or whatever is left.
-- After each batch, 'per_batch_func' will be executed.
-- When all entries are finished, post_process_func will be 
-- executed.
----------------------------------------------------------------   
function ProcessEntries(entries, batch_count, per_entry_func, per_batch_func, post_process_func)
	
	local it, a, i = ipairs(entries);

	return function()
		local num_processed = 0;
		repeat
			i,v = it(a, i);	
			if(v) then
				per_entry_func(v);
				num_processed = num_processed + 1;
			end
		until(v == nil or num_processed >= batch_count);
	
		if(per_batch_func) then per_batch_func(); end		

		if(v == nil and post_process_func) then post_process_func(); end

		return v ~= nil;
	end
end
   
function RebuildFileList()
	for i, v in ipairs(g_FileList) do
		if(v.IsQuicksave) then
			v.DisplayName = Locale.Lookup("LOC_LOADSAVE_QUICK_SAVE");
		else
			v.DisplayName = GetDisplayName(v.Name);
		end
	
		local high, low = UI.GetSaveGameModificationTimeRaw(v);
		v.LastModifiedHigh = high;
		v.LastModifiedLow = low;
	end
	table.sort(g_FileList, g_CurrentSort);

	-- Destroying the instance, rather than resetting.
	-- This is needed because resetting only hides the instances, meaning SortChildren
	-- will sort the hidden instances, but the sort compare function in lua uses a parallel lua table (g_SortTable)
	-- which will be indexed only by the visible ones.
    g_FileEntryInstanceManager:DestroyInstances();
	local pauseAccumulator = PAUSE_INCREMENT;

	-- Predefine functions out of loop.
	function OnMouseEnter() UI.PlaySound("Main_Menu_Mouse_Over"); end

	function OnDoubleClick(i)
		SetSelected(i);
		OnActionButton();
	end

	g_FileEntryInstanceList = {};

	local instance_index = 1;
	function per_entry(entry)
		local controlTable = g_FileEntryInstanceManager:GetInstance();
		g_FileEntryInstanceList[instance_index] = controlTable;
		TruncateString(controlTable.ButtonText, controlTable.Button:GetSizeX()-60, entry.DisplayName);
		controlTable.Button:SetVoid1( instance_index );
		controlTable.Button:RegisterCallback( Mouse.eMouseEnter, OnMouseEnter);
		controlTable.Button:RegisterCallback( Mouse.eLClick, SetSelected );
		controlTable.Button:RegisterCallback( Mouse.eLDblClick, OnDoubleClick); 

		instance_index = instance_index + 1;
	end

	function per_batch()
		Controls.FileListEntryStack:CalculateSize();
		Controls.ScrollPanel:CalculateSize();
		Controls.FileListEntryStack:ReprocessAnchoring();
	end

	function post_process()
		ContextPtr:ClearUpdate();
	end

	local iterator = ProcessEntries(g_FileList, 100, per_entry, per_batch, post_process);
	
	ContextPtr:SetUpdate(function() iterator(); end);	
	
	Controls.NoGames:SetHide( #g_FileList > 0 );
	
		
	--	WISHLIST: I want to sort the actual list of instances, instead of just the display.  This would allow me to animate these instances with the
	--	same cascading effect as the main menu. Also it would allow me to auto-select the first item in the save list.
	--	***************************************************************************************************************************************************
	--	table.sort(g_FileEntryInstanceList, "How in the heck can I do this?");
	--	for i=0,table.count(g_FileEntryInstanceList) do
	--		local controlTable = g_FileEntryInstanceList[i];
	--		-- Set the animation behaviors and sounds
	--		controlTable.LabelAlphaAnim:SetToBeginning();
	--		controlTable.LabelAlphaAnim:Play();
	--		-- The label begin its alpha animation slightly after the flag begins to fly out
	--		controlTable.LabelAlphaAnim:SetPauseTime(pauseAccumulator + .2);
	--		
	--		-- Define a custom animation curve and sounds for the button flag - this function is called for every frame
	--		controlTable.FlagAnim:RegisterAnimCallback(function() 
	--													local progress :number = controlTable.FlagAnim:GetProgress();
	--													if(not controlTable.FlagAnim:IsReversing() and progress <.1) then 
	--														UI.PlaySound("Main_Menu_Panel_Expand_Top_Level");				
	--													elseif(not controlTable.FlagAnim:IsReversing() and progress >.65) then 
	--														controlTable.FlagAnim:SetSpeed(.9);
	--													end													
	--													if(controlTable.FlagAnim:IsReversing() and progress > .2) then
	--														controlTable.FlagAnim:SetProgress( 0.2 );
	--														controlTable.FlagAnim:Stop();																									
	--													elseif(controlTable.FlagAnim:IsReversing() and progress < .03) then
	--														controlTable.FlagAnim:SetSpeed(.4);	-- Right after the flag animation has bounced, slow it down dramatically
	--													end
	--												end);
	--		-- Will not be called due to "Bounce" cycle being used: option.FlagAnim:RegisterEndCallback( function() print("done!"); end ); 
	--		controlTable.FlagAnim:SetPauseTime(pauseAccumulator);
	--		controlTable.FlagAnim:SetSpeed(4);
	--		controlTable.FlagAnim:SetToBeginning();
	--		controlTable.FlagAnim:Play();
	--		-- Accumulate a pause so that the flags appear one at a time
	--		pauseAccumulator = pauseAccumulator + PAUSE_INCREMENT;
	--	end
	--	-- Auto Select the first item
	--	if( g_FileEntryInstanceList[ 1 ] ~= nil) then
	--		SetSelected(1);
	--	end

	--for i, v in ipairs(g_FileList) do
	--	local controlTable = g_FileEntryInstanceManager:GetInstance();
	--	g_FileEntryInstanceList[i] = controlTable;
	--	    
	--	local displayName = GetDisplayName(v.Name); 
	--        
	--	TruncateString(controlTable.ButtonText, controlTable.Button:GetSizeX(), displayName);
	--	         
	--	controlTable.Button:SetVoid1( i );
	--	controlTable.Button:RegisterCallback( Mouse.eLClick, SetSelected );
	--	controlTable.Button:RegisterCallback( Mouse.eLDblClick, 
	--		function()
	--			SetSelected(i);
	--			OnActionButton();
	--		end
	--	 );
	--		
	--	local high, low = UI.GetSaveGameModificationTimeRaw(v);
	--		
	--	g_SortTable[ tostring( controlTable.InstanceRoot ) ] = {Title = displayName, LastModified = {High = high, Low = low} };
	--	Controls.NoGames:SetHide( true );
	--end
		
	--Controls.FileListEntryStack:CalculateSize();
    --Controls.ScrollPanel:CalculateSize();
    --Controls.FileListEntryStack:ReprocessAnchoring();
end

----------------------------------------------------------------        
function UpdateActionButtonState()

	-- Valid filename?
	local bIsValid = g_FilenameIsValid;

	local bWaitingForFileList = false;
	local bAtMaximumSaves = false;
	if (bIsValid) then
		if (g_ShowCloudSaves) then
			-- If we are doing a cloud save, the file query for the cloud save must be complete.
			if (not UI.IsFileListQueryComplete(g_LastFileQueryRequestID)) then
				bIsValid = false;
				bWaitingForFileList = true;
			end

			if (g_MenuType == SAVE_GAME) then
				local gameFile = {};
				gameFile.Location = SaveLocations.FIRAXIS_CLOUD;
				gameFile.Type = g_GameType;

				if (UI.IsAtMaxSaveCount(gameFile)) then
					bIsValid = false;
					bAtMaximumSaves = true;
				end
			end
		end
	end

	Controls.ActionButton:SetHide(false);
	if(not bIsValid) then
		-- Set the reason for the control being disabled.
		if (bAtMaximumSaves) then
			Controls.ActionButton:SetToolTipString(Locale.Lookup("LOC_SAVE_AT_MAXIMUM_CLOUD_SAVES_TOOLTIP"));
		elseif (bWaitingForFileList) then
			Controls.ActionButton:SetToolTipString(Locale.Lookup("LOC_SAVE_WAITING_FOR_CLOUD_SAVE_LIST_TOOLTIP"));
		elseif (not g_FilenameIsValid) then
			Controls.ActionButton:SetToolTipString(Locale.Lookup("LOC_SAVE_INVALID_FILE_NAME_TOOLTIP"));
		else
			Controls.ActionButton:SetToolTipString(nil);
		end

		Controls.ActionButton:SetDisabled(true);
	else
		Controls.ActionButton:SetToolTipString(nil);
		Controls.ActionButton:SetDisabled(false);
	end	
end

g_LastFileQueryRequestID = 0;

----------------------------------------------------------------        
-- Can we show cloud saves?
function CanShowCloudSaves()

	if (not UI.IsFileListQueryComplete(g_LastFileQueryRequestID)) then
		return false;
	end

	return true;
end

----------------------------------------------------------------        
function SetupFileList()

	g_iSelectedFileEntry = -1;

	if(g_MenuType == SAVE_GAME) then
		Controls.NoSelectedFile:SetHide(true);
		Controls.SelectedFile:SetHide(false);
		if (g_CurrentGameMetaData == nil) then
			g_CurrentGameMetaData = UI.MakeSaveGameMetaData();
		end

		if (g_CurrentGameMetaData ~= nil and g_CurrentGameMetaData[1] ~= nil) then
			PopulateInspectorData(g_CurrentGameMetaData[1]);
		end
	else
		SetSelected( -1 );
	end
    -- build a table of all save file names that we found
    g_FileList = {};
    g_InstanceList = {};
    	
	local saveLocation = SaveLocations.LOCAL_STORAGE;
    if (g_ShowCloudSaves) then
		saveLocation = SaveLocations.FIRAXIS_CLOUD;		
    end

	-- Query for the files, this is asynchronous

	UI.CloseFileListQuery( g_LastFileQueryRequestID );

	local saveLocationOptions = SaveLocationOptions.NO_OPTIONS;
	if (g_ShowAutoSaves) then
		saveLocationOptions = SaveLocationOptions.AUTOSAVE;
	else
		-- Don't include quick saves when saving, but do when loading.
		if(g_MenuType == SAVE_GAME) then
			saveLocationOptions = SaveLocationOptions.NORMAL;
		else
			saveLocationOptions = SaveLocationOptions.NORMAL + SaveLocationOptions.QUICKSAVE;
		end
	end

	saveLocationOptions = saveLocationOptions + SaveLocationOptions.LOAD_METADATA;

	g_LastFileQueryRequestID = UI.QuerySaveGameList( saveLocation, g_GameType, saveLocationOptions);
	
	RebuildFileList();	-- It will be empty at this time

end

----------------------------------------------------------------        
-- The callback for file queries
function OnFileListQueryResults( fileList : table, id : number )
	g_FileList = fileList;
	RebuildFileList();
	LuaEvents.FileListQueryComplete( id );
end

----------------------------------------------------------------        
-- This should be called by the show handler FIRST.
function LoadSaveMenu_OnShow()
	LuaEvents.FileListQueryResults.Add( OnFileListQueryResults );
	Controls.ScrollPanel:SetScrollValue(0);
end

----------------------------------------------------------------        
-- This should be called by the hide handler LAST.
function LoadSaveMenu_OnHide()
	LuaEvents.FileListQueryResults.Remove( OnFileListQueryResults );

	UI.CloseAllFileListQueries();

	g_FileEntryInstanceManager:DestroyInstances();
	g_FileEntryInstanceList = nil;
	g_iSelectedFileEntry = -1;
	g_FileList = nil;
	g_CurrentGameMetaData = nil;
	g_LastFileQueryRequestID = 0;
end