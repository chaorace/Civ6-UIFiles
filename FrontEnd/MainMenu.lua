include("InstanceManager");
include("LobbyTypes"); --MPLobbyMode
include("PopupDialogSupport");

-- ===========================================================================
--	Members
-- ===========================================================================
local m_mainOptionIM :	table = InstanceManager:new( "MenuOption", "Top", Controls.MainMenuOptionStack );
local m_subOptionIM :	table = InstanceManager:new( "MenuOption", "Top", Controls.SubMenuOptionStack );
local m_preSaveMainMenuOptions:	table = {};
local m_defaultMainMenuOptions:	table = {};
local m_singlePlayerListOptions:table = {};
local m_hasSaves:boolean = false;
local m_kPopupDialog;
local m_currentOptions:table = {};		--Track which main menu options are being displayed and selected. Indices follow the format of {optionControl:table, isSelected:boolean}
local m_initialPause = 1.5;				--How long to wait before building the main menu options when the game first loads
local m_internetButton:table = nil;		--Cache internet button so it can be updated when online status events fire
local m_resumeButton:table = nil;		--Cache resume button so it can be updated when FileListQueryResults event fires
local m_scenariosButton:table = nil;	--Cache scenarios button so it can be updated later.

-- ===========================================================================
--	Constants
-- ===========================================================================
local PAUSE_INCREMENT = .18;			--How long to wait (in seconds) between main menu flyouts - length of the menu cascade
local TRACK_PADDING = 40;				--The amount of Y pixels to add to the track on top of the list heigh

-- ===========================================================================
--	Globals
-- ===========================================================================

g_LastFileQueryRequestID = nil;			-- The file list ID used to determine whether the call-back is for us or not.
g_MostRecentSave = nil;					-- The most recent single player save a user has (locally)

-- ===========================================================================
-- Button Handlers
-- ===========================================================================
function OnResumeGame()
	if(g_MostRecentSave) then
		local serverType : number = ServerType.SERVER_TYPE_NONE;
		Network.LeaveGame();
		Network.LoadGame(g_MostRecentSave, serverType);
	end
end

function UpdateResumeGame(resumeButton)
	if (resumeButton ~= nil) then
		m_resumeButton = resumeButton;
	end
	if(m_resumeButton ~= nil) then
		if(g_MostRecentSave ~= nil) then

			local mods = g_MostRecentSave.RequiredMods or {};
	
			-- Test for errors.
			-- Will return a combination array/map of any errors regarding this combination of mods.
			-- Array messages are generalized error codes regarding the set.
			-- Map messages are error codes specific to the mod Id.
			local errors = Modding.CheckRequirements(mods, SaveTypes.SINGLE_PLAYER);
			local success = (errors == nil or errors.Success);

			m_resumeButton.Top:SetHide(not success);
		else
			m_resumeButton.Top:SetHide(true);
		end
	end
end

function UpdateScenariosButton(button)
	if(button) then 
		m_scenariosButton = button; 
	end

	if(button) then
		button.Top:SetHide(true);
		local query = "SELECT 1 from Rulesets where IsScenario = 1 and SupportsSinglePlayer = 1 LIMIT 1";
		local results = DB.ConfigurationQuery(query);
		if(results and #results > 0) then
			button.Top:SetHide(false);
		end
	end
end


function OnPlayCiv6()
	local save = Options.GetAppOption("Debug", "PlayNowSave");
	if(save ~= nil) then
		Network.LeaveGame();

		local serverType : number = ServerType.SERVER_TYPE_NONE;
		Network.LoadGame(save, serverType);
	else
		GameConfiguration.SetToDefaults();
		Network.HostGame(ServerType.SERVER_TYPE_NONE);
	end
end

-- ===========================================================================
function OnAdvancedSetup()
	GameConfiguration.SetToDefaults();
	UIManager:QueuePopup(Controls.AdvancedSetup, PopupPriority.Current);
end

-- ===========================================================================
function OnScenarioSetup()
	GameConfiguration.SetToDefaults();
	UIManager:QueuePopup(Controls.ScenarioSetup, PopupPriority.Current);
end

-- ===========================================================================
function OnLoadSinglePlayer()
	GameConfiguration.SetToDefaults();
	LuaEvents.MainMenu_SetLoadGameServerType(ServerType.SERVER_TYPE_NONE);
	UIManager:QueuePopup(Controls.LoadGameMenu, PopupPriority.Current);		
	Close();
end

-- ===========================================================================
function OnOptions()
	UIManager:QueuePopup(Controls.Options, PopupPriority.Current);
	Close();
end

-- ===========================================================================
function OnMods()
	GameConfiguration.SetToDefaults();
	UIManager:QueuePopup(Controls.ModsContext, PopupPriority.Current);
	Close();
end

-- ===========================================================================
function OnPlayMultiplayer()
	UIManager:QueuePopup(Controls.MultiplayerSelect, PopupPriority.Current);
	Close();
end

-- ===========================================================================
function OnMy2KLogin()
	Events.Begin2KLoginProcess();
	Close();
end

-- ===========================================================================
--	Engine Event
-- ===========================================================================
function OnUserRequestClose()
    if ( not m_kPopupDialog:IsOpen()) then
		m_kPopupDialog:AddText(Locale.Lookup("LOC_CONFIRM_EXIT_TXT"));
		m_kPopupDialog:AddTitle(Locale.ToUpper(Locale.Lookup("LOC_MAIN_MENU_EXIT_TO_DESKTOP")), Controls.PopupTitle);
		m_kPopupDialog:AddButton(Locale.Lookup("LOC_CANCEL_BUTTON"), ExitCancel);
		m_kPopupDialog:AddButton(Locale.Lookup("LOC_OK_BUTTON"), ExitOK, nil, nil, "PopupButtonAltInstance"); 
		m_kPopupDialog:Open();
		UIManager:PushModal(Controls.PopupDialog, true);
	end
end

-- ===========================================================================
function ExitOK()
	ExitCancel();

	if (Steam ~= nil) then
		Steam.ClearRichPresence();
	end

	Events.UserConfirmedClose();
end    

-- ===========================================================================
function ExitCancel()
	m_kPopupDialog:Close();
	UIManager:PopModal(Controls.PopupDialog);
end

    -- ===========================================================================
function OnGraphicsBenchmark()
	Benchmark.RunGraphicsBenchmark("GraphicsBenchmark.Civ6Save");
end

function OnAIBenchmark()
	Benchmark.RunAIBenchmark("AIBenchmark.Civ6Save");
end

-- ===========================================================================
function OnCredits()
	UIManager:QueuePopup( Controls.CreditsScreen, PopupPriority.Current );
	Close();
end

-- ===========================================================================
-- Multiplayer Select Screen
-- ===========================================================================
local InternetButtonOnlineStr : string = Locale.Lookup("LOC_MULTIPLAYER_INTERNET_GAME_TT");
local InternetButtonOfflineStr : string = Locale.Lookup("LOC_MULTIPLAYER_INTERNET_GAME_OFFLINE_TT");

-- ===========================================================================
function OnInternet()
	LuaEvents.ChangeMPLobbyMode(MPLobbyTypes.STANDARD_INTERNET);
	UIManager:QueuePopup( Controls.Lobby, PopupPriority.Current );
	Close();	
end

-- ===========================================================================
--	WB: This callback is complicated by these events which can happen at any time.
--	Because NO other buttons in the shell function in this way, using a special 
--	variable to save this control (instead of a more general solution).
-- ===========================================================================
function UpdateInternetButton(buttonControl: table)
	if (buttonControl ~=nil) then
		m_internetButton = buttonControl;
	end
	-- Internet available?
	if(m_internetButton ~= nil) then
		if (Network.IsInternetLobbyServiceAvailable()) then
			m_internetButton.OptionButton:SetDisabled(false);
			m_internetButton.Top:SetToolTipString(InternetButtonOnlineStr);
			m_internetButton.ButtonLabel:SetText(Locale.Lookup("LOC_MULTIPLAYER_INTERNET_GAME"));
			m_internetButton.ButtonLabel:SetColorByName( "ButtonCS" );
		else
			m_internetButton.OptionButton:SetDisabled(true);
			m_internetButton.Top:SetToolTipString(InternetButtonOfflineStr);
			m_internetButton.ButtonLabel:SetText(Locale.Lookup("LOC_MULTIPLAYER_INTERNET_GAME_OFFLINE"));
			m_internetButton.ButtonLabel:SetColorByName( "ButtonDisabledCS" );
		end
	end
end

-- ===========================================================================
function OnLANGame()
	LuaEvents.ChangeMPLobbyMode(MPLobbyTypes.STANDARD_LAN);
	UIManager:QueuePopup( Controls.Lobby, PopupPriority.Current );
	Close();
end

-- ===========================================================================
function OnHotSeat()
	LuaEvents.ChangeMPLobbyMode(MPLobbyTypes.HOTSEAT);
	LuaEvents.MainMenu_RaiseHostGame();
	Close();
end

-- ===========================================================================
function OnCloud()
	UIManager:QueuePopup( Controls.CloudGameScreen, PopupPriority.Current );
end

-- ===========================================================================
function OnGameLaunched()	
end

-- ===========================================================================
-- ESC handler
-- ===========================================================================
function InputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			if(m_kPopupDialog ~= nil) then
				if(m_kPopupDialog:IsOpen()) then
					m_kPopupDialog:Close();
				end
			end
		end
		return true;
	end
end

-- ===========================================================================
function Close()
	-- Set pause to 0 so it loads in right away when returning from any screen.
	m_initialPause = 0;
end


--[[
--UINETTODO - Do we need this so that multiplayer game invites skip straight into the invited game?
-------------------------------------------------
-------------------------------------------------
-- The UI has requested that we go to the multiplayer select.  Show ourself
function OnUpdateUI( type, tag, iData1, iData2, strData1 )
    if (type == SystemUpdateUI.RestoreUI and tag == "MultiplayerSelect") then
		if (ContextPtr:IsHidden()) then
			UIManager:QueuePopup(ContextPtr, PopupPriority.Current );    
		end
    end
end
Events.SystemUpdateUI.Add( OnUpdateUI );
--]]

-- ===========================================================================
--	ToggleOption - called from button handlers
-- ===========================================================================
--	Toggles the specified index within the main menu
--	ARG0: optionIndex - the index of the button control to deselect
--	ARG1: submenu - if the specified index has a submenu, then build that menu
-- ===========================================================================
function ToggleOption(optionIndex, submenu)
	if (not Controls.SubMenuSlide:IsStopped()) then
		return;
	end
	local optionControl = m_currentOptions[optionIndex].control;
	if(m_currentOptions[optionIndex].isSelected) then
		-- If the thing I selected was already selected, then toggle it off
		UI.PlaySound("Main_Main_Panel_Collapse"); 
		--Controls.SubMenuContainer:SetHide(true);
		Controls.SubMenuAlpha:Reverse();
		Controls.SubMenuSlide:Reverse();
		DeselectOption(optionIndex);
	else
		-- OTHERWISE - I am selecting a new thing
		-- Was anything else OTHER than the optionIndex selected?  If so, we should hide its selection fanciness and turn it off
		-- Let's also check to see if the submenu was already open
		local subMenuClosed = true;
		for i=1, table.count(m_currentOptions) do
			if (i ~= optionIndex) then
				if(m_currentOptions[i].isSelected) then
					subMenuClosed = false;
					DeselectOption(i);
				end
			end
		end
		
		if(subMenuClosed) then
			--If the submenu wasn't opened yet, then let's slide it out
			Controls.SubMenuAlpha:SetToBeginning();
			Controls.SubMenuAlpha:Play();
			Controls.SubMenuSlide:SetToBeginning();
			Controls.SubMenuSlide:Play();
		end
		-- Now show the selector around the new thing 
		optionControl.SelectionAnimAlpha:SetToBeginning();
		optionControl.SelectionAnimSlide:SetToBeginning();
		optionControl.SelectionAnimAlpha:Play();
		optionControl.SelectionAnimSlide:Play();
		optionControl.LabelAlphaAnim:SetPauseTime(0);
		optionControl.LabelAlphaAnim:SetSpeed(6);
		optionControl.LabelAlphaAnim:Reverse();
		if (submenu ~= nil) then
			BuildSubMenu(submenu);
		end
		m_currentOptions[optionIndex].isSelected = true;
	end
end

-- ===========================================================================
--	Called from ToggleOption
--	Visually deselects the specified index and tracks within m_currentOptions
--	ARG0:	index - the index of the button control to deselect
-- ===========================================================================
function DeselectOption(index:number)
	local control:table = m_currentOptions[index].control;
	control.LabelAlphaAnim:SetSpeed(1);
	control.LabelAlphaAnim:SetPauseTime(.4);
	control.SelectionAnimAlpha:Reverse();
	control.SelectionAnimSlide:Reverse();
	control.LabelAlphaAnim:SetToBeginning();
	control.LabelAlphaAnim:Play();
	m_currentOptions[index].isSelected = false;
end

-- ===========================================================================
function OnTutorial()
	GameConfiguration.SetToDefaults();
	UIManager:QueuePopup(Controls.TutorialSetup, PopupPriority.Current);
end


-- ===========================================================================
--	Callbacks for the main menu options which have submenus
--	ARG0:	optionIndex - which index of the current options to toggle
--	ARG1:	submenu - the submenu table to draw in
-- ===========================================================================
function OnSinglePlayer( optionIndex:number, submenu:table )	
	ToggleOption(optionIndex, submenu);
end

function OnMultiPlayer( optionIndex:number, submenu:table )	
	ToggleOption(optionIndex, submenu);
end

function OnBenchmark( optionIndex:number, submenu:table )	
	ToggleOption(optionIndex, submenu);
end



-- *******************************************************************************
--	MENUS need to be defined here as the callbacks reference functions which
--	are defined above.
-- *******************************************************************************


-- ===============================================================================
-- Sub Menu Option Tables
--	--------------------------------------------------------------------------
--	label - the text string for the button (un-localized)
--	callback - the function to call from this button
--	tooltip - the tooltip for this button
--	buttonState - a function to call which will update the buttonstate and tooltip
-- ===============================================================================
local m_SinglePlayerSubMenu :table = {
								{label = "LOC_MAIN_MENU_RESUME_GAME",		callback = OnResumeGame,	tooltip = "LOC_MAINMENU_RESUME_GAME_TT", buttonState = UpdateResumeGame},
								{label = "LOC_LOAD_GAME",					callback = OnLoadSinglePlayer,	tooltip = "LOC_MAINMENU_LOAD_GAME_TT",},
								{label = "LOC_PLAY_CIVILIZATION_6",			callback = OnPlayCiv6,	tooltip = "LOC_MAINMENU_PLAY_NOW_TT"},
								{label = "LOC_SETUP_SCENARIOS",				callback = OnScenarioSetup,	tooltip = "LOC_MAINMENU_SCENARIOS_TT", buttonState = UpdateScenariosButton},
								{label = "LOC_SETUP_CREATE_GAME",			callback = OnAdvancedSetup,	tooltip = "LOC_MAINMENU_CREATE_GAME_TT"},
							

							};

local m_MultiPlayerSubMenu :table = {
								{label = "LOC_MULTIPLAYER_INTERNET_GAME",	callback = OnInternet,	tooltip = "LOC_MULTIPLAYER_INTERNET_GAME_TT", buttonState = UpdateInternetButton},
								{label = "LOC_MULTIPLAYER_LAN_GAME",		callback = OnLANGame,	tooltip = "LOC_MULTIPLAYER_LAN_GAME_TT"},
								{label = "LOC_MULTIPLAYER_HOTSEAT_GAME",	callback = OnHotSeat,	tooltip = "LOC_MULTIPLAYER_HOTSEAT_GAME_TT"},
								--{label = "LOC_MULTIPLAYER_CLOUD_GAME",		callback = OnCloud,		tooltip = "LOC_MULTIPLAYER_CLOUD_GAME_TT"},
							};

local m_BenchmarkSubMenu :table = {
								{label = "LOC_BENCHMARK_GRAPHICS",			callback = OnGraphicsBenchmark,	tooltip = "LOC_BENCHMARK_GRAPHICS_TT"},
								{label = "LOC_BENCHMARK_AI",				callback = OnAIBenchmark,		tooltip = "LOC_BENCHMARK_AI_TT"},
							};

-- ===========================================================================
--	Main Menu Option Tables
--	--------------------------------------------------------------------------
--	label - the text string for the button (un-localized)
--	callback - the function to call from this button
--	submenu - the submenu table to open for this button (defined above)
-- ===========================================================================
local m_preSaveMainMenuOptions :table = {	{label = "LOC_PLAY_CIVILIZATION_6",			callback = OnPlayCiv6}};  
local m_defaultMainMenuOptions :table = {	
								{label = "LOC_SINGLE_PLAYER",				callback = OnSinglePlayer,	tooltip = "LOC_MAINMENU_SINGLE_PLAYER_TT",	submenu = m_SinglePlayerSubMenu}, 
								{label = "LOC_PLAY_MULTIPLAYER",			callback = OnMultiPlayer,	tooltip = "LOC_MAINMENU_MULTIPLAYER_TT",	submenu = m_MultiPlayerSubMenu},
								{label = "LOC_MAIN_MENU_OPTIONS",			callback = OnOptions,	tooltip = "LOC_MAINMENU_GAME_OPTIONS_TT"},
								{label = "LOC_MAIN_MENU_ADDITIONAL_CONTENT",				callback = OnMods,	tooltip = "LOC_MAIN_MENU_ADDITIONAL_CONTENT_TT"},
								{label = "LOC_MAIN_MENU_TUTORIAL",			callback = OnTutorial,	tooltip = "LOC_MAINMENU_TUTORIAL_TT"},
								{label = "LOC_MAIN_MENU_BENCH",				callback = OnBenchmark,	tooltip = "LOC_MAINMENU_BENCHMARK_TT",			submenu = m_BenchmarkSubMenu},
								{label = "LOC_MAIN_MENU_CREDITS",			callback = OnCredits,	tooltip = "LOC_MAINMENU_CREDITS_TT"},
								{label = "LOC_MAIN_MENU_EXIT_TO_DESKTOP",	callback = OnUserRequestClose,	tooltip = "LOC_MAINMENU_EXIT_GAME_TT"}
							};


-- ===========================================================================
--	Animation callback for top-menu option controls.
-- ===========================================================================
function TopMenuOptionAnimationCallback(control, progress)
	local progress :number = control:GetProgress();
													
	-- Only if the animation has just begun, play its sound
	if(not control:IsReversing() and progress <.1) then 
		UI.PlaySound("Main_Menu_Expand_Notch");				
	elseif(not control:IsReversing() and progress >.65) then 
		control:SetSpeed(.9);	-- As the flag is nearing the top of its bounce, slow it down
	end													
													
	-- After the flag animation has bounced, stop it at the correct position													
	if(control:IsReversing() and progress > .2) then
		control:SetProgress( 0.2 );
		control:Stop();																									
	elseif(control:IsReversing() and progress < .03) then
		control:SetSpeed(.4);	-- Right after the flag animation has bounced, slow it down dramatically
	end
end

-- ===========================================================================
--	Animation callback for sub-menu option controls.
-- ===========================================================================
function SubMenuOptionAnimationCallback(control, progress) 
	if(not control:IsReversing() and progress <.1) then 
		UI.PlaySound("Main_Menu_Panel_Expand_Short"); 
	elseif(not control:IsReversing() and progress >.65) then 
		control:SetSpeed(2);
	end
	if(control:IsReversing() and progress > .2) then
		control:SetProgress( 0.2 );
		control:Stop();														
	elseif(control:IsReversing() and progress < .03) then
		control:SetSpeed(1);
	end
end


function MenuOptionMouseEnterCallback()
	UI.PlaySound("Main_Menu_Mouse_Over"); 
end

-- ===========================================================================
--	Animates the main menu options in
--	ARG0:	menuOptions - Expects the table of options that is to appear on 
--			the topmost level - either [m_preSave/m_default]MainMenuOptions
-- ===========================================================================
function BuildMenu(menuOptions:table)
	m_mainOptionIM:ResetInstances();
	UI.PlaySound("Main_Menu_Panel_Expand_Top_Level");	
	local pauseAccumulator = m_initialPause + PAUSE_INCREMENT;
	for i, menuOption in ipairs(menuOptions) do

		-- Add the instances to the table and play the animations and add the sounds
		local option = m_mainOptionIM:GetInstance();
		option.ButtonLabel:LocalizeAndSetText(menuOption.label);
		option.SelectedLabel:LocalizeAndSetText(menuOption.label);
		option.LabelAlphaAnim:SetToBeginning();
		option.LabelAlphaAnim:Play();
		-- The label begin its alpha animation slightly after the flag begins to fly out
		option.LabelAlphaAnim:SetPauseTime(pauseAccumulator + .2);
		option.OptionButton:RegisterCallback( Mouse.eLClick, function() 
																--If a submenu exists, specify the index and pass the submenu along to the callback
																if (menuOption.submenu ~= nil) then 
																	menuOption.callback(i, menuOption.submenu);
																else  
																	menuOption.callback();
																end
															end);
		option.OptionButton:RegisterCallback( Mouse.eMouseEnter, MenuOptionMouseEnterCallback);

		-- Define a custom animation curve and sounds for the button flag - this function is called for every frame
		option.FlagAnim:RegisterAnimCallback(TopMenuOptionAnimationCallback);
		-- Will not be called due to "Bounce" cycle being used: option.FlagAnim:RegisterEndCallback( function() print("done!"); end ); 
		option.FlagAnim:SetPauseTime(pauseAccumulator);
		option.FlagAnim:SetSpeed(4);
		option.FlagAnim:SetToBeginning();
		option.FlagAnim:Play();

		
		option.Top:LocalizeAndSetToolTip(menuOption.tooltip);
		
		-- Accumulate a pause so that the flags appear one at a time
		pauseAccumulator = pauseAccumulator + PAUSE_INCREMENT;
		-- Track which options are being displayed and preserve the selection state so that we can rebuild a submenu
		m_currentOptions[i] = {control = option, isSelected = false};
	end
	Controls.MainMenuOptionStack:CalculateSize();
	Controls.MainMenuOptionStack:ReprocessAnchoring();


	local trackHeight = Controls.MainMenuOptionStack:GetSizeY() + TRACK_PADDING;
	-- Make sure the vertical div line is correctly sized for the number of options and draw it in
	Controls.MainButtonTrack:SetSizeY(trackHeight);
	Controls.MainButtonTrackAnim:SetBeginVal(0,-trackHeight);
	Controls.MainButtonTrackAnim:Play();
	Controls.MainMenuClip:SetSizeY(trackHeight);
end

-- ===========================================================================
--	Builds the table of submenu options
--	ARG0:	menuOptions - Expects the table specified in the 'submenu' field 
--			of the m_defaultMainMenuOptions table	
--
--	WB: While this function shares a fair amount of code with BuildMenu, 
--	I have decided to keep them separate as I continue differentiate behavior
--	and tweak the animations. 
-- ===========================================================================
function BuildSubMenu(menuOptions:table)
	m_subOptionIM:ResetInstances();

	for i, menuOption in ipairs(menuOptions) do
		-- Add the instances to the table and play the animations and add the sounds
		-- * Submenu options animate in all at once, instead of one at at a time
		local option = m_subOptionIM:GetInstance();
		option.ButtonLabel:LocalizeAndSetText(menuOption.label);
		option.SelectedLabel:LocalizeAndSetText(menuOption.label);
		option.LabelAlphaAnim:SetToBeginning();
		option.LabelAlphaAnim:Play();
		option.LabelAlphaAnim:SetPauseTime(0);
		option.OptionButton:RegisterCallback( Mouse.eLClick, menuOption.callback);
		option.OptionButton:RegisterCallback( Mouse.eMouseEnter, MenuOptionMouseEnterCallback);

		-- * Submenu options have a slightly different animation curve as well as a different animation sound
		option.FlagAnim:RegisterAnimCallback(SubMenuOptionAnimationCallback);

		-- Will not be called due to "Bounce" cycle being used: option.FlagAnim:RegisterEndCallback( function() print("done!"); end ); 
		option.FlagAnim:SetSpeed(4);
		option.FlagAnim:SetToBeginning();
		option.FlagAnim:Play();

		option.Top:LocalizeAndSetToolTip(menuOption.tooltip);
		
		-- Set a special disabled state for buttons (right now, only the Internet button has this function)
		if (menuOption.buttonState ~= nil) then
			menuOption.buttonState(option); 
		else
			--ATTN:TRON For some reason my instances are not being completely reset when I rebuild the my list here
			-- So I have to reset my tooltip string and button state.
			option.OptionButton:SetDisabled(false);
			option.ButtonLabel:SetColorByName( "ButtonCS" );
		end		
	end

	Controls.SubMenuOptionStack:CalculateSize();
	Controls.SubMenuOptionStack:ReprocessAnchoring();
	local trackHeight = Controls.SubMenuOptionStack:GetSizeY() + TRACK_PADDING;
	Controls.SubButtonTrack:SetSizeY(trackHeight);
	Controls.SubButtonTrackAnim:SetBeginVal(0,-trackHeight);
	-- * The track line for the submenu also draws in more quickly since all the options are feeding in at once
	Controls.SubButtonTrackAnim:SetSpeed(5);
	Controls.SubButtonTrackAnim:SetToBeginning();
	Controls.SubButtonTrackAnim:Play();
	Controls.SubMenuClip:SetSizeY(trackHeight);
	Controls.SubMenuAlpha:SetSizeY(trackHeight);
	Controls.SubButtonClip:SetSizeY(trackHeight);
	Controls.SubMenuContainer:SetSizeY(Controls.MainMenuClip:GetSizeY());
end


-- =============================================================================
--	Searches the menu table for a value which contains a matching [label]. If 
--	found, that index is removed
--	ARG0:	menu - the parent menu table.  Expects options to have a name 
--			string in the [label] field to compare against
--	ARG1:	option - the table containing both the [label] and [callback] 
--			for the submenu option
-- =============================================================================
function RemoveOptionFromMenu(menu:table, option:table)
	for i=1, table.count(menu) do
		if(menu[i] ~= nil) then
			if(menu[i].label == option.label) then
				table.remove(menu,i);
			end
		end
	end
end

-- =============================================================================
--	Searches the menu table for a value which contains a matching [label]. If 
--	that value is NOT found, the submenu option is inserted at the first index
--	ARG0:	menu - the parent menu table.  Expects options to have a name 
--			string in the [label] field to compare against
--	ARG1:	option - the table containing both the [label] and [callback] 
--			for the submenu option
--	ARG2:	(OPTIONAL) index - the index of the submenu where the option should
--			be inserted.
-- =============================================================================
function AddOptionToMenu(menu:table, option:table, index:number)
	local hasOption = false;
	if (index == nil) then
		index = 1;
	end
	for i=1, table.count(menu) do
		if(menu[i].label == option) then
			hasOption = true;
		end
	end
	if (not hasOption) then
		table.insert(menu,submenu,1);
	end
end

-- =============================================================================
--	Called from the ESC handler and also when we show the screen
--	Rebuilds the menu taking into account any submenus that were already open
-- =============================================================================
function BuildAllMenus()

	-- Reset cached buttons to make sure we don't reference reused instances
	m_resumeButton = nil;
	m_internetButton = nil;
	m_scenariosButton = nil;

	-- WISHLIST: When we rebuild the menus, let's check to see if there are ANY saved games whatsoever.  
	-- If none exist, then do not display the option in the submenu. (See: OnFileListQueryResults)
	local selectedIndex = -1;
	for i=1, table.count(m_currentOptions) do
		if(m_currentOptions[i].isSelected) then
			selectedIndex = i;
		end
	end
	if(selectedIndex ~= -1) then
		if(m_defaultMainMenuOptions[selectedIndex].submenu ~= nil) then
			BuildSubMenu(m_defaultMainMenuOptions[selectedIndex].submenu);
		else
			BuildMenu(m_defaultMainMenuOptions);
		end
	else
		BuildMenu(m_defaultMainMenuOptions);
	end
end

function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	local adjustedWidth = screenY*1.9;
	Controls.Logo:ReprocessAnchoring();
	Controls.ShellMenuAndLogo:ReprocessAnchoring();
		Controls.VersionLabel:ReprocessAnchoring();
	Controls.ShellStack:ReprocessAnchoring();
	Controls.My2KContents:ReprocessAnchoring();
end
-- ===========================================================================
--	UI Callback
--	Restart animation on show
-- ===========================================================================
function OnShow()
	local save = Options.GetAppOption("Debug", "PlayNowSave");
	if (save ~= nil) then
		--If we have a save specified in AppOptions, then only display the play button
		BuildMenu(m_preSaveMainMenuOptions);
	else
		BuildAllMenus();
	end
	GameConfiguration.SetToDefaults();
	UI.SetSoundStateValue("Game_Views", "Main_Menu");
	LuaEvents.UpdateFiraxisLiveState();

	if (Steam ~= nil) then
		Steam.SetRichPresence("location", "LOC_PRESENCE_IN_SHELL");
	end

	local gameType = SaveTypes.SINGLE_PLAYER;
	local saveLocation = SaveLocations.LOCAL_STORAGE;

	g_MostRecentSave = nil;
	g_LastFileQueryRequestID = nil;
	local options = SaveLocationOptions.NORMAL + SaveLocationOptions.AUTOSAVE + SaveLocationOptions.QUICKSAVE + SaveLocationOptions.MOST_RECENT_ONLY + SaveLocationOptions.LOAD_METADATA ;
	g_LastFileQueryRequestID = UI.QuerySaveGameList( saveLocation, gameType, options );
end

function OnHide()
	-- Set the pause to 0 as soon as we hide the main menu, so it loads in right 
	-- away when we return from any screen.
	m_initialPause = 0;
end

function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

-- Call-back for when the list of files have been updated.
function OnFileListQueryResults( fileList, queryID )
	if g_LastFileQueryRequestID ~= nil then
		if (g_LastFileQueryRequestID == queryID) then
			g_MostRecentSave = nil;
			if (fileList ~= nil) then
				for i, v in ipairs(fileList) do
					g_MostRecentSave = v;		-- There really should only be one or 
				end
			
				UpdateResumeGame();
			end

			UI.CloseFileListQuery(g_LastFileQueryRequestID);
			g_LastFileQueryRequestID = nil;
		end
	end
	
end

-- ===========================================================================
function Initialize()
	m_kPopupDialog = PopupDialogLogic:new( "MainMenu", Controls.PopupDialog, Controls.StackContents );
    m_kPopupDialog:SetInstanceNames( "PopupButtonInstance", "Button", "PopupTextInstance", "Text", "RowInstance", "Row");
	m_kPopupDialog:SetOpenAnimationControls( Controls.PopupAlphaIn, Controls.PopupSlideIn );
	m_kPopupDialog:SetSize(400,200);

	UI.CheckUserSetup();

	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetInputHandler( InputHandler );
	Controls.VersionLabel:SetText( UI.GetAppVersion() );
	Controls.My2KLogin:RegisterCallback( Mouse.eLClick, OnMy2KLogin );
	Controls.My2KLogin:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	-- Game Events
	Events.SteamServersConnected.Add( UpdateInternetButton );
	Events.SteamServersDisconnected.Add( UpdateInternetButton );
	Events.MultiplayerGameLaunched.Add( OnGameLaunched );
	Events.SystemUpdateUI.Add( OnUpdateUI );
    Events.UserRequestClose.Add( OnUserRequestClose );

	-- LUA Events
	LuaEvents.FileListQueryResults.Add( OnFileListQueryResults );

	BuildAllMenus();
	Resize();
end
Initialize();
