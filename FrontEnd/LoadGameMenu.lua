include( "InstanceManager" );
include( "SupportFunctions" );
include( "Civ6Common" );
include( "LoadSaveMenu_Shared" );	-- Shared code between the LoadGameMenu and the SaveGameMenu
include("PopupDialogSupport");
include( "LocalPlayerActionSupport" );


local RELOAD_CACHE_ID: string = "LoadGameMenu";		-- hotloading


-------------------------------------------------
-- Globals
-------------------------------------------------
local serverType : number = ServerType.SERVER_TYPE_NONE;
local m_thisLoadFile;
local m_QuickloadId;
g_IsDeletingFile = false;

g_QuickLoadQueryRequestID = nil;

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnLoadNo()
	m_kPopupDialog:Close();
end

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnLoadYes()
	UITutorialManager:EnableOverlay( false );	
	UITutorialManager:HideAll();
	m_kPopupDialog:Close();
	Network.LeaveGame();
    Network.LoadGame(m_thisLoadFile, serverType);
    Controls.ActionButton:SetDisabled( true );

    -- Don't DequeuePopup here.  
    -- In singleplayer, the entire lua context gets blasted once we transition to the LoadGameViewState.
    -- In multiplayer, the join room screen will send a JoiningRoom_Showing() to let us know it's safe to DequeuePopup.  See OnJoiningRoom_Showing().
end

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnActionButton()
	UIManager:SetUICursor( 1 );
	m_thisLoadFile = g_FileList[ g_iSelectedFileEntry ];

	if (m_thisLoadFile) then
    	local isInGame = false;
    	if(GameConfiguration ~= nil) then
    		isInGame = GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_PREGAME;
    	end

        if isInGame then
		   	if ( not m_kPopupDialog:IsOpen()) then
				m_kPopupDialog:AddText(Locale.Lookup("LOC_CONFIRM_LOAD_TXT"));
				m_kPopupDialog:AddTitle(Locale.ToUpper(Locale.Lookup("LOC_CONFIRM_TITLE_LOAD_TXT")));
				m_kPopupDialog:AddButton(Locale.Lookup("LOC_NO_BUTTON"), OnLoadNo);
				m_kPopupDialog:AddButton(Locale.Lookup("LOC_YES_BUTTON"), OnLoadYes, nil, nil, "PopupButtonAltInstancePositive"); 
				m_kPopupDialog:Open();
			end
        else
            OnLoadYes();
    	end
    end
end

----------------------------------------------------------------        
----------------------------------------------------------------        
function OnBack()
	if m_kPopupDialog:IsOpen() then
		UI.DataError("Popup confirmation was open when closing the load game menu; it will be forced closed but it shouldn't be possible to close the load screen while this prompt is up.");
		m_kPopupDialog:Close();
	end

    UIManager:DequeuePopup( ContextPtr );
end

---------------------------------------------------------------- 
-- Show/Hide Handlers
---------------------------------------------------------------- 
function OnShow()
	LoadSaveMenu_OnShow();

	g_MenuType = LOAD_GAME;
	UpdateGameType();
	Controls.ActionButton:SetHide( false );
	Controls.ActionButton:SetDisabled( false );
	Controls.ActionButton:SetToolTipString(nil);

	g_ShowCloudSaves = false;
	g_ShowAutoSaves = false;

	Controls.AutoCheck:SetSelected(false);
	Controls.CloudCheck:SetSelected(false);

	local isFullyLoggedIn = FiraxisLive.IsFullyLoggedIn();
	if isFullyLoggedIn and not GameConfiguration.IsAnyMultiplayer() then
		Controls.CloudCheck:SetHide(false);
		Controls.DecoContainer:SetSizeY(537);
	else
		Controls.CloudCheck:SetHide(true);
		Controls.DecoContainer:SetSizeY(562);
	end

	SetupFileList();
end

function OnHide()
	LoadSaveMenu_OnHide();
end


----------------------------------------------------------------        
----------------------------------------------------------------
function OnDelete()
	Controls.ActionButton:SetDisabled(true);
	if ( not m_kPopupDialog:IsOpen()) then
		m_kPopupDialog:AddText(Locale.Lookup("LOC_CONFIRM_TXT"));
		m_kPopupDialog:AddTitle(Locale.ToUpper(Locale.Lookup("LOC_CONFIRM_DELETE_TITLE_TXT")));
		m_kPopupDialog:AddButton(Locale.Lookup("LOC_NO_BUTTON"), OnDeleteNo);
		m_kPopupDialog:AddButton(Locale.Lookup("LOC_YES_BUTTON"), OnDeleteYes, nil, nil, "PopupButtonAltInstance"); 
		m_kPopupDialog:Open();
	end
end

----------------------------------------------------------------        
----------------------------------------------------------------
function OnDeleteYes()
	m_kPopupDialog:Close();
	if (g_iSelectedFileEntry ~= -1) then
		local kSelectedFile = g_FileList[ g_iSelectedFileEntry ];		
		UI.DeleteSavedGame( kSelectedFile );
	end
	
	Controls.ActionButton:SetDisabled(false);
	SetupFileList();
end

----------------------------------------------------------------        
----------------------------------------------------------------
function OnDeleteNo( )
	m_kPopupDialog:Close();
end

----------------------------------------------------------------        
----------------------------------------------------------------
function OnAutoCheck( )
	-- print("Auto Saves - " .. tostring(g_ShowAutoSaves));
	g_ShowAutoSaves = not g_ShowAutoSaves;
	Controls.AutoCheck:SetSelected(g_ShowAutoSaves);

	-- Mutually exclusive with other locations.
	if(g_ShowAutoSaves) then
		g_ShowCloudSaves = false;
		Controls.CloudCheck:SetSelected(g_ShowCloudSaves);
	end

	SetupFileList();
end

----------------------------------------------------------------        
----------------------------------------------------------------
function OnCloudCheck( )
	-- print("Cloud Saves - " .. tostring(g_ShowCloudSaves));

	local bWantShowCloudSaves = not g_ShowCloudSaves;

	if (bWantShowCloudSaves) then
		-- Make sure we can switch to it.
		if (not CanShowCloudSaves()) then
			return;
		end
	end

	g_ShowCloudSaves = bWantShowCloudSaves;

	Controls.CloudCheck:SetSelected(g_ShowCloudSaves);

	-- Mutually exclusive with other locations.
	if(g_ShowCloudSaves) then
		g_ShowAutoSaves = false;
		Controls.AutoCheck:SetSelected(g_ShowAutoSaves);
	end

	SetupFileList();
end


---------------------------------------------------------------- 
-- Event Handler: ChangeMPLobbyMode
---------------------------------------------------------------- 
function OnSetLoadGameServerType(newServerType)
	serverType = newServerType;
end

-- ===========================================================================
--	Input Processing
-- ===========================================================================
function KeyHandler( key:number )
	if key == Keys.VK_ESCAPE then
		if(m_kPopupDialog:IsOpen()) then
			m_kPopupDialog:Close();
		else
			OnBack();
		end		
		return true;
	end	
	if key == Keys.VK_RETURN then
        if(not Controls.ActionButton:IsHidden() and not Controls.ActionButton:IsDisabled()) then
            OnActionButton();
            return true;
        end
	end
	return false;
end
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then KeyHandler( pInputStruct:GetKey() ); end;
    return true;
end

-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues( RELOAD_CACHE_ID );
	end
end

-- ===========================================================================
function OnShutdown()
	-- Cache values for hotloading...
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden());
end

-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	if context == RELOAD_CACHE_ID and contextTable["isHidden"] == false then
		UIManager:QueuePopup(ContextPtr, PopupPriority.Current);
	end	
end

-- ===========================================================================
function OnJoiningRoom_Showing()
	-- Remove ourself if the joining room screen is showing.
	UIManager:DequeuePopup( ContextPtr );
end

-- Call-back for when the list of files have been updated.
function OnQuickLoadQueryResults( fileList, queryID )
	if g_QuickLoadQueryRequestID ~= nil then
		if (g_QuickLoadQueryRequestID == queryID) then
			if (fileList ~= nil and #fileList > 0) then
				local save = fileList[1];
			
				local mods = save.RequiredMods or {};
	
				-- Test for errors.
				-- Will return a combination array/map of any errors regarding this combination of mods.
				-- Array messages are generalized error codes regarding the set.
				-- Map messages are error codes specific to the mod Id.
				local errors = Modding.CheckRequirements(mods, SaveTypes.SINGLE_PLAYER);
				local success = (errors == nil or errors.Success);

				if(success) then
					Network.LoadGame(save, serverType);
				end
			end

			UI.CloseFileListQuery(g_QuickLoadQueryRequestID);
			g_QuickLoadQueryRequestID = nil;
		end
	end
end

-- ===========================================================================
--	Hotkey Event
-- ===========================================================================
function OnInputActionTriggered( actionId )
    if actionId == m_QuickloadId then
        -- Quick load
        if CanLocalPlayerLoadGame() then
			g_QuickLoadQueryRequestID = nil;
			local options = SaveLocationOptions.QUICKSAVE + SaveLocationOptions.LOAD_METADATA ;
			g_QuickLoadQueryRequestID = UI.QuerySaveGameList( SaveLocations.LOCAL_STORAGE, SaveTypes.SINGLE_PLAYER, options );
        end
    end
end

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

function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end
-- ===========================================================================
function Initialize()
	m_kPopupDialog = PopupDialogLogic:new( "LoadGameMenu", Controls.PopupDialog, Controls.StackContents, Controls.PopupTitle );
	m_kPopupDialog:SetInstanceNames( "PopupButtonInstance", "Button", "PopupTextInstance", "Text", "RowInstance", "Row");	
    m_kPopupDialog:SetOpenAnimationControls( Controls.PopupAlphaIn, Controls.PopupSlideIn );	
	m_kPopupDialog:SetSize(400,200);

	AutoSizeGridButton(Controls.BackButton,133,36);
	SetupSortPulldown();
	Resize();

	-- UI Events
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShowHandler(OnShow);
	ContextPtr:SetHideHandler(OnHide);
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	LuaEvents.JoiningRoom_Showing.Add(OnJoiningRoom_Showing);

	-- UI Callbacks
	Controls.ActionButton:RegisterCallback( Mouse.eLClick, OnActionButton );
	Controls.ActionButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.AutoCheck:RegisterCallback( Mouse.eLClick, OnAutoCheck );
	Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack );
	Controls.BackButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CloudCheck:RegisterCallback( Mouse.eLClick, OnCloudCheck );
	Controls.Delete:RegisterCallback( Mouse.eLClick, OnDelete );
	Controls.Delete:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	-- LUA Events
	--??TRON remove LuaEvents.Lobby_ShowLoadScreen.Add(function() m_showMainMenuOnHide = false; end);
	--??TRON remove LuaEvents.MainMenu_ShowLoadScreen.Add(function() m_showMainMenuOnHide = true; end);
	LuaEvents.HostGame_SetLoadGameServerType.Add( OnSetLoadGameServerType );
	LuaEvents.MainMenu_SetLoadGameServerType.Add( OnSetLoadGameServerType );
	LuaEvents.InGameTopOptionsMenu_SetLoadGameServerType.Add( OnSetLoadGameServerType );

	LuaEvents.FileListQueryResults.Add( OnQuickLoadQueryResults );

	Events.SystemUpdateUI.Add( OnUpdateUI );

    m_QuickloadId = Input.GetActionId("QuickLoad");
    Events.InputActionTriggered.Add( OnInputActionTriggered );
end
Initialize();

