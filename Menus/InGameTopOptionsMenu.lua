-- ===========================================================================
--	InGameTopOptionsMenu
-- ===========================================================================

include( "Civ6Common" );
include( "SupportFunctions" ); --DarkenLightenColor
include( "InputSupport" );
include( "InstanceManager" );
include( "PopupDialogSupport" );
include( "LocalPlayerActionSupport" );


-- ===========================================================================
--	GLOBALS
-- ===========================================================================
g_ModListingsManager = InstanceManager:new("ModInstance", "ModTitle", Controls.ModListingsStack);

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_kPopupDialog	: table;			-- Custom due to Utmost popup status
local ms_ExitToMain		: boolean = true;
local m_isSimpleMenu	: boolean = false;
local m_isLoadingDone   : boolean = false;
local m_isRetired		: boolean = false;

-- ===========================================================================
--	COSTANTS
-- ===========================================================================
local ICON_PREFIX:string = "ICON_";

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function OnReallyRetire()
	m_isRetired = true;
    UI.RequestAction(ActionTypes.ACTION_RETIRE);
	CloseImmediately();
	UI.PlaySound("Notification_Misc_Negative");
end

function OnRetireGame()
	-- If we're in an extended game AND we're the winner.  Just re-open the end-game menu.
	-- Otherwise, prompt for retirement.
	local me = Game.GetLocalPlayer();
	if(me) then
		local localPlayer = Players[me];
		if(localPlayer) then
			if(Game.GetWinningTeam() == localPlayer:GetTeam()) then
				LuaEvents.ShowEndGame(me);	
			else
				if (not m_kPopupDialog:IsOpen()) then
					m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_RETIRE_WARNING"));
					m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), nil );
					m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnReallyRetire, nil, nil, "PopupButtonInstanceAlt" );
					m_kPopupDialog:Open();
				end
			end
		end
	end
end


-- ===========================================================================
function OnExitGame()
    if (Steam ~= nil) then
        Steam.ClearRichPresence();
    end

    Events.UserConfirmedClose();
end

-- ===========================================================================
function OnExitGameAskAreYouSure()
	if (not m_kPopupDialog:IsOpen()) then
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_QUIT_WARNING"));
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), nil );
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnExitGame, nil, nil, "PopupButtonInstanceAlt" );
		m_kPopupDialog:Open();
	end
end

-- ===========================================================================
function OnMainMenu()
	ms_ExitToMain = true;
	if (not m_kPopupDialog:IsOpen()) then
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_EXIT_WARNING"));
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), OnNo );
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnYes, nil, nil, "PopupButtonInstanceAlt" );
		m_kPopupDialog:Open();
	end
end

-- ===========================================================================
function OnQuickSaveGame()
	if (CanLocalPlayerSaveGame()) then 
		local gameFile = {};
		gameFile.Name = "quicksave";
		gameFile.Location = SaveLocations.LOCAL_STORAGE;
		gameFile.Type= Network.GetGameConfigurationSaveType();
		gameFile.IsAutosave = false;
		gameFile.IsQuicksave = true;

		Network.SaveGame(gameFile);	
		UI.PlaySound("Confirm_Bed_Positive");
	end
end

-- ===========================================================================
function OnOptions()
	UIManager:QueuePopup(Controls.Options, PopupPriority.Current);	
end

-- ===========================================================================
function OnLoadGame()
	if (CanLocalPlayerLoadGame()) then 
		LuaEvents.InGameTopOptionsMenu_SetLoadGameServerType(ServerType.SERVER_TYPE_NONE);
		UIManager:QueuePopup(Controls.LoadGameMenu, PopupPriority.Current);	
	end
end

-- ===========================================================================
function OnSaveGame()
	if (CanLocalPlayerSaveGame()) then 
		UIManager:QueuePopup(Controls.SaveGameMenu, PopupPriority.Current);	
	end
end

-- ===========================================================================
function CloseImmediately()
	LuaEvents.InGameTopOptionsMenu_Close();
	UIManager:DequeuePopup( ContextPtr );
	UI.SetSoundStateValue("Game_Views", "Normal_View");
end

-- ===========================================================================
function Close()
	if(Controls.AlphaIn:IsStopped()) then
		-- Animation is good for a nice clean animation out..
		Controls.AlphaIn:Reverse();
		Controls.SlideIn:Reverse();
		Controls.PauseWindowClose:SetToBeginning();
		Controls.PauseWindowClose:Play();
	else
		-- Animation is not in an expected state, just reset all...
		Controls.AlphaIn:SetToBeginning();
		Controls.SlideIn:SetToBeginning();
		Controls.PauseWindowClose:SetToBeginning();
		ShutdownAfterClose();
		ContextPtr:SetHide(true);
		UI.DataError("Forced closed() of the in game top options menu.  (Okay if someone was spamming ESC.)");
	end

	local playerChange =  ContextPtr:LookUpControl( "/InGame/PlayerChange" );
	if (not UIManager:IsInPopupQueue(playerChange)) then
		LuaEvents.InGameTopOptionsMenu_Close();
	end	

	Input.PopContext();
end

-- ===========================================================================
function ShutdownAfterClose()
	UIManager:DequeuePopup( ContextPtr );
	UI.SetSoundStateValue("Game_Views", "Normal_View");
	UI.PlaySound("UI_Pause_Menu_On");
end

-- ===========================================================================
--	UI callback
-- ===========================================================================
function OnReturn()
	if (not ContextPtr:IsHidden() ) then
		Close();
	end
end

-- ===========================================================================
--	LUA Event
--	Reduce the # of options in the menu (for tutorial purposes)
-- ===========================================================================
function OnSimpleInGameMenu( isSimpleMenu )

	-- For the demo, always keep it simple
	if UI.HasFeature("Demo") then
		isSimpleMenu = true;
	end

	if isSimpleMenu == nil then isSimpleMenu = true; end
	m_isSimpleMenu = isSimpleMenu;

	SetupButtons();

end

-- ===========================================================================
function SetupButtons()

	local bIsAutomation = Automation.IsActive();
	local bIsMultiplayer = GameConfiguration.IsAnyMultiplayer();
	local bCanSave = CanLocalPlayerSaveGame();
	local bCanLoad = CanLocalPlayerLoadGame();
	local bIsLocalPlayersTurn = IsLocalPlayerTurnActive();

	Controls.QuickSaveButton:SetDisabled( not bCanSave );
	Controls.SaveGameButton:SetDisabled( not bCanSave );
	Controls.LoadGameButton:SetDisabled( not bCanLoad );
	Controls.RetireButton:SetDisabled( not bIsLocalPlayersTurn );

	-- Hide the restart button until functionality is implemented and stable.
	Controls.RestartGameButton:SetHide(true); -- m_isSimpleMenu or bIsAutomation or bIsMultiplayer);

	Controls.QuickSaveButton:SetHide(m_isSimpleMenu or bIsAutomation);
	Controls.SaveGameButton:SetHide(m_isSimpleMenu or bIsAutomation);			
	Controls.LoadGameButton:SetHide(m_isSimpleMenu or bIsAutomation or bIsMultiplayer);
	Controls.OptionsButton:SetHide(bIsAutomation or not CanLocalPlayerChangeOptions());	

	-- Eventually remove this check.  Retiring after winning is perfectly fine
	-- so long as we update the tooltip to no longer state the player will be defeated.
	local bAlreadyWon = false;
	local me = Game.GetLocalPlayer();
	if(me) then
		local localPlayer = Players[me];
		if(localPlayer) then
			if(Game.GetWinningTeam() == localPlayer:GetTeam()) then
				bAlreadyWon = true;
			end
		end
	end

	Controls.RetireButton:SetHide(m_isSimpleMenu or bIsAutomation or bIsMultiplayer or bAlreadyWon);

	Controls.ExitGameButton:SetHide(false);	

	RefreshModsInUse();
	RefreshIconData();

	Controls.MainStack:CalculateSize();
	Controls.PauseWindow:ReprocessAnchoring();
end

function RefreshIconData()

	-- Check for an invalid local player first!
	local eLocalPlayer :number = Game.GetLocalPlayer();
	if (eLocalPlayer < 0) then
		return;
	end

	m_pPlayer= Players[eLocalPlayer];

	m_primaryColor, m_secondaryColor  = UI.GetPlayerColors( m_pPlayer:GetID() );
	local darkerBackColor = DarkenLightenColor(m_primaryColor,(-85),100);
	local brighterBackColor = DarkenLightenColor(m_primaryColor,90,255);

	-- Icon colors
	Controls.CivBacking_Base:SetColor(m_primaryColor);
	Controls.CivBacking_Lighter:SetColor(brighterBackColor);
	Controls.CivBacking_Darker:SetColor(darkerBackColor);
	Controls.CivIcon:SetColor(m_secondaryColor);

	local leader:string = PlayerConfigurations[m_pPlayer:GetID()]:GetLeaderTypeName();
	if GameInfo.CivilizationLeaders[leader] == nil then
		UI.DataError("Banners found a leader \""..leader.."\" which is not/no longer in the game; icon may be whack.");
	else
		if(GameInfo.CivilizationLeaders[leader].LeaderType ~= nil) then
			local leaderIconName = ICON_PREFIX.. GameInfo.CivilizationLeaders[leader].LeaderType;
			-- Set Leader Icon
			Controls.LeaderIcon:SetIcon(leaderIconName);
			local leaderTooltip = GameInfo.Leaders[leader].Name;
			Controls.LeaderIcon:SetToolTipString(Locale.Lookup(leaderTooltip));
		end
		if(GameInfo.CivilizationLeaders[leader].CivilizationType ~= nil) then
			local civTypeName = GameInfo.CivilizationLeaders[leader].CivilizationType
			local civIconName = ICON_PREFIX..civTypeName;
			-- Set Civ Icon
			Controls.CivIcon:SetIcon(civIconName);
			civTooltip = GameInfo.Civilizations[civTypeName].Name;
			Controls.CivIcon:SetToolTipString(Locale.Lookup(civTooltip));
		end
	end

	-- Game difficulty
	local playerConfig:table = PlayerConfigurations[eLocalPlayer];
	local gameDifficultyTypeID = playerConfig:GetHandicapTypeID();
	local gameDifficultyType = GameInfo.Difficulties[gameDifficultyTypeID].DifficultyType;
	Controls.GameDifficulty:SetIcon(ICON_PREFIX..gameDifficultyType);
	local difficultyTooltip = Locale.Lookup("LOC_MULTIPLAYER_DIFFICULTY_HEADER")..":[NEWLINE]"..Locale.Lookup(GameInfo.Difficulties[gameDifficultyTypeID].Name);
	Controls.GameDifficulty:SetToolTipString(difficultyTooltip);

	local gameSpeedType = GameInfo.GameSpeeds[GameConfiguration.GetGameSpeedType()].GameSpeedType;
	Controls.GameSpeed:SetIcon(ICON_PREFIX..gameSpeedType);
	local speedTooltip = Locale.Lookup("LOC_AD_SETUP_GAME_SPEED")..":[NEWLINE]"..Locale.Lookup(GameInfo.GameSpeeds[GameConfiguration.GetGameSpeedType()].Name);
	Controls.GameSpeed:SetToolTipString(speedTooltip);
end

-- ===========================================================================
function OnYes( )

   	UIManager:SetUICursor( 1 );
	UITutorialManager:EnableOverlay( false );	
	UITutorialManager:HideAll();

	UIManager:Log("Shutting down via user exit on menu.");
	if(ms_ExitToMain) then
		Events.ExitToMainMenu();
	else
		UI.ExitGame();
	end
end

-- ===========================================================================
function OnNo( )
	m_kPopupDialog:Close();
end


-- ===========================================================================
function KeyHandler( key:number )
	if key == Keys.VK_ESCAPE then		
		if not Controls.PopupDialog:IsHidden() then
			m_kPopupDialog:Close();
		else
			if (not ContextPtr:IsHidden() ) then
				Close();
			end
		end
		return true;
	end
	return false;
end

-- ===========================================================================
function OnInput( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then 
		return KeyHandler( pInputStruct:GetKey() ); 
	end;
	return false;
end

-- ===========================================================================
function RefreshModsInUse()
	local mods = Modding.GetActiveMods();
	
	g_ModListingsManager:ResetInstances();

	local modNames = {};
	for i,v in ipairs(mods) do
		modNames[i] = Locale.Lookup(v.Name);
	end

	table.sort(modNames, function(a,b) return Locale.Compare(a,b) == -1 end);
	
	for i,v in ipairs(modNames) do
		local instance = g_ModListingsManager:GetInstance();
		
		instance.ModTitle:SetText(v);	
	end
	
	Controls.ModListingsStack:CalculateSize();
	Controls.ModListingsStack:ReprocessAnchoring();
	Controls.ModListings:CalculateSize();
	Controls.ModsInUse:SetHide( (#mods == 0) or m_isSimpleMenu );
	Controls.MainStack:CalculateSize();
	Controls.GameDetails:ReprocessAnchoring();
	Controls.CompassDeco:ReprocessAnchoring();
end

-- ===========================================================================
function OnOpenInGameOptionsMenu()
	-- Don't show pause menu if the player has retired (forfeit) from the game - fixes TTP 20129
	if not m_isRetired then 
		UIManager:QueuePopup( ContextPtr, PopupPriority.Utmost );
	end
end

-- ===========================================================================
--	Raised (typically) from InGame since when this is hidden it will not
--	receive input from ForgeUI.
-- ===========================================================================
function OnShow()

	-- do not re-push the context if we're already in the GameOptions context
	-- (e.g. returning from a sub-screen)
	if Input.GetActiveContext() ~= InputContext.GameOptions then
		Input.PushActiveContext( InputContext.GameOptions );
	end

    LuaEvents.InGameTopOptionsMenu_Show();
	UI.PlaySound("UI_Pause_Menu_On");
	UI.SetSoundStateValue("Game_Views", "Paused");
	
	Controls.AlphaIn:SetToBeginning();
	Controls.AlphaIn:Play();
	Controls.SlideIn:SetToBeginning();
	Controls.SlideIn:Play();

	-- Reset interface mode... may want to re-evaluate this if there are
	-- common situation(s) where a player is in a difference interface mode
	-- and are bringing up this menu.	
	if WorldBuilder:IsActive() then
		UI.SetInterfaceMode( InterfaceModeTypes.WB_SELECT_PLOT );
	else
		UI.SetInterfaceMode( InterfaceModeTypes.SELECTION );
	end

	SetupButtons();

	-- Do not deselect all as on-rails scenarios (e.g., tutorials) may get out of sync.	

end

-- ===========================================================================
function OnLoadGameViewStateDone()
	m_isLoadingDone = true;
end

-- ===========================================================================
function OnPlayerTurnActivationChanged()
	if (not ContextPtr:IsHidden()) then
		SetupButtons();
	end
end

-- ===========================================================================
function OnRequestClose()
	if m_isLoadingDone then
		-- Only handle the message if popup queuing is active (diplomacy is not up)
		if UIManager:IsPopupQueueDisabled()==false then
			if (ContextPtr:IsHidden() ) then
				UIManager:QueuePopup( ContextPtr, PopupPriority.Utmost );
			end
			OnExitGameAskAreYouSure();
		end
    else
		Events.UserConfirmedClose();
	end
end

-- ===========================================================================
function Initialize()

	ContextPtr:SetInputHandler( OnInput, true );
	ContextPtr:SetShowHandler( OnShow );

	Controls.ExitGameButton:RegisterCallback( Mouse.eLClick, OnExitGameAskAreYouSure );
	Controls.ExitGameButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.LoadGameButton:RegisterCallback( Mouse.eLClick, OnLoadGame );
	Controls.LoadGameButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.MainMenuButton:RegisterCallback( Mouse.eLClick, OnMainMenu );
	Controls.MainMenuButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.OptionsButton:RegisterCallback( Mouse.eLClick, OnOptions );
	Controls.OptionsButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.QuickSaveButton:RegisterCallback( Mouse.eLClick, OnQuickSaveGame );      
	Controls.QuickSaveButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);                   
	Controls.RetireButton:RegisterCallback( Mouse.eLClick, OnRetireGame );
	Controls.RetireButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ReturnButton:RegisterCallback( Mouse.eLClick, OnReturn );
	Controls.ReturnButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.SaveGameButton:RegisterCallback( Mouse.eLClick, OnSaveGame );
	Controls.SaveGameButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.RestartGameButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.PauseWindowClose:RegisterEndCallback( ShutdownAfterClose );

	LuaEvents.InGame_OpenInGameOptionsMenu.Add( OnOpenInGameOptionsMenu );

	LuaEvents.TutorialUIRoot_SimpleInGameMenu.Add( OnSimpleInGameMenu );

	Events.PlayerTurnActivated.Add( OnPlayerTurnActivationChanged );
	Events.PlayerTurnDeactivated.Add( OnPlayerTurnActivationChanged );
    Events.UserRequestClose.Add( OnRequestClose );
	Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone );

	Controls.VersionLabel:SetText( UI.GetAppVersion() );

	-- Custom popup setup	
	m_kPopupDialog = PopupDialogLogic:new( "InGameTopOptionsMenu", Controls.PopupDialog, Controls.PopupStack );
	m_kPopupDialog:SetInstanceNames( "PopupButtonInstance", "Button", "PopupTextInstance", "Text", "RowInstance", "Row");
	m_kPopupDialog:SetOpenAnimationControls( Controls.PopupAlphaIn, Controls.PopupSlideIn );	
	m_kPopupDialog:SetSize(400,200);

	if UI.HasFeature("Demo") then
		m_isSimpleMenu = true;
	end

end
Initialize();
