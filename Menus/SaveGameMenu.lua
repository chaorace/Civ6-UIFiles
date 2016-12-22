include( "InstanceManager" );
include( "SupportFunctions" );

-- Shared code between the LoadGameMenu and the SaveGameMenu
include( "LoadSaveMenu_Shared" );

local RELOAD_CACHE_ID: string = "SaveGameMenu";		-- hotloading
g_IsDeletingFile = false;
----------------------------------------------------------------        
----------------------------------------------------------------        
function OnBack()
    UIManager:DequeuePopup( ContextPtr );
end

----------------------------------------------------------------        
----------------------------------------------------------------
function OnActionButton()
	if (g_iSelectedFileEntry == -1) then
		local fileName = Controls.FileName:GetText();
		for i, v in ipairs(g_FileList) do
			local displayName = GetDisplayName(v.Name); 
			if(Locale.Length(displayName) > 0) then
				if(Locale.ToUpper(fileName) == Locale.ToUpper(displayName)) then
					SetSelected(i);
					break;
				end
			end
		end
	end
	
	if(g_iSelectedFileEntry ~= -1) then
		g_IsDeletingFile = false;
		Controls.DeleteHeader:SetText(Locale.ToUpper( "LOC_CONFIRM_TITLE_TXT" ));
		Controls.Message:LocalizeAndSetText( "LOC_OVERWRITE_TXT" );
		Controls.DeleteConfirm:SetHide(false);
		return;
	else
		local gameFile = {};
		gameFile.Name = Controls.FileName:GetText();
		if(g_ShowCloudSaves) then
			gameFile.Location = SaveLocations.FIRAXIS_CLOUD;
		else
			gameFile.Location = SaveLocations.LOCAL_STORAGE;
		end
		gameFile.Type = g_GameType;
-- KWG: Fix  The configuration (or somewhere else) needs to store whether the game is started or not.
--		if (GameConfiguration.IsNetworkMultiplayer() and GameConfiguration.GameStarted()) then
--			gameFile.UseLastAutosave = true;
--		end
		UIManager:SetUICursor( 1 );
		Network.SaveGame(gameFile);
		UIManager:SetUICursor( 0 );
		UI.PlaySound("Confirm_Bed_Positive");
	end
	
	Controls.FileName:ClearString();
	SetupFileList();
	OnBack();
end


----------------------------------------------------------------        
function OnFileNameChange( fileNameEntry )
	
	if( g_iSelectedFileEntry ~= -1 ) then
		local kSelectedFile = g_FileList[ g_iSelectedFileEntry ];
		local displayName = GetDisplayName(kSelectedFile.Name); 
		if (fileNameEntry:GetText() ~= displayName) then
			DismissCurrentSelected();
		end
	end
	
	local fileName = "";
	if(fileNameEntry:GetText() ~= nil) then
		fileName = fileNameEntry:GetText();
	end

	g_FilenameIsValid = ValidateFileName(fileName);

	UpdateActionButtonState();
	Controls.Delete:SetHide(true); 
	
end

----------------------------------------------------------------        
----------------------------------------------------------------
function OnCloudCheck( )
	local bWantShowCloudSaves = not g_ShowCloudSaves;

	if (bWantShowCloudSaves) then
		-- Make sure we can switch to it.
		if (not CanShowCloudSaves()) then
			return;
		end
	end

	g_ShowCloudSaves = bWantShowCloudSaves;
	Controls.CloudCheck:SetSelected(g_ShowCloudSaves);
	SetupFileList();
	UpdateActionButtonState();
end

----------------------------------------------------------------     
----------------------------------------------------------------
function OnShowReferencedPackages()
	Controls.ReferencedPackagesWindow:SetHide(false);
end

----------------------------------------------------------------        
----------------------------------------------------------------
function OnCloseReferencedPackages()
	Controls.ReferencedPackagesWindow:SetHide(true);
end

---------------------------------------------------------------- 
-- Show/Hide Handlers
---------------------------------------------------------------- 
function OnShow()

	g_ShowCloudSaves = false;
	g_ShowAutoSaves = false;

	LoadSaveMenu_OnShow();

	g_MenuType = SAVE_GAME;
	UpdateGameType();
	Controls.SaveMapButton:SetHide( true );
	Controls.Delete:SetHide( true );
	Controls.ActionButton:SetDisabled( true );
	Controls.ActionButton:SetToolTipString( nil );

	SetupFileList();
		
	Controls.CloudCheck:SetSelected(false);

	g_FilenameIsValid = Controls.FileName:GetText() ~= "";

	UpdateActionButtonState();

	local isFullyLoggedIn = FiraxisLive.IsFullyLoggedIn();

	if isFullyLoggedIn and not GameConfiguration.IsAnyMultiplayer() then
		Controls.CloudCheck:SetHide(false);
		Controls.DecoContainer:SetSizeY(562);
	else
		Controls.CloudCheck:SetHide(true);
		Controls.DecoContainer:SetSizeY(588);
	end
end
----------------------------------------------------------------        
function OnHide()
	LoadSaveMenu_OnHide();
end

function OnDelete()
	g_IsDeletingFile = true;
	Controls.DeleteHeader:SetText( Locale.ToUpper(Locale.Lookup("LOC_CONFIRM_DELETE_TITLE_TXT")));
	Controls.Message:LocalizeAndSetText( "LOC_CONFIRM_TXT" );
	Controls.DeleteConfirm:SetHide(false);
	Controls.DeleteConfirmAlpha:SetToBeginning();
	Controls.DeleteConfirmAlpha:Play();
	Controls.DeleteConfirmSlide:SetToBeginning();
	Controls.DeleteConfirmSlide:Play();
end    
----------------------------------------------------------------
function OnYes()
	Controls.DeleteConfirm:SetHide(true);

	if (g_iSelectedFileEntry ~= -1) then
		local kSelectedFile = g_FileList[ g_iSelectedFileEntry ];		
		if(g_IsDeletingFile) then
			UI.DeleteSavedGame( kSelectedFile );
		else
			UI.PlaySound("Confirm_Bed_Positive");

			if(g_ShowCloudSaves) then
				local gameFile = {};
				gameFile.Name = Controls.FileName:GetText();
				gameFile.Location = SaveLocations.FIRAXIS_CLOUD;
				gameFile.LocationIndex = g_iSelectedFileEntry;
				gameFile.Type = g_GameType;
				UIManager:SetUICursor( 1 );
				Network.SaveGame(gameFile);
				UIManager:SetUICursor( 0 );
			else
				Network.SaveGame( kSelectedFile );
			end

			OnBack();
		end
	end
	
	SetupFileList();
	Controls.FileName:ClearString();
	Controls.ActionButton:SetDisabled(true);
end       
----------------------------------------------------------------
function OnNo( )
	Controls.DeleteConfirm:SetHide(true);
	Controls.MainGrid:SetHide(false);
end


-- ===========================================================================
--	Input Processing
-- ===========================================================================
function KeyHandler( key:number )
	if (key == Keys.VK_ESCAPE) then
		if(not Controls.DeleteConfirm:IsHidden()) then
			OnNo();
		else
			OnBack(); 
		end
		return true;
	end	
	if key == Keys.VK_RETURN then
        if(not Controls.ActionButton:IsHidden() and not Controls.ActionButton:IsDisabled()) then
            OnActionButton();
        end
        return true;
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
--	Handle Window Sizing
-- ===========================================================================

function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	local hideLogo = true;
	if(screenY >= Controls.MainWindow:GetSizeY() + Controls.LogoContainer:GetSizeY()+ Controls.LogoContainer:GetOffsetY()) then
		hideLogo = false;
	end
	Controls.LogoContainer:SetHide(hideLogo);
	Controls.MainGrid:ReprocessAnchoring();
	Controls.ReferencedPackagesWindow:ReprocessAnchoring();
	Controls.DeleteConfirm:SetSizeVal(screenX,screenY);
	Controls.DeleteConfirm:ReprocessAnchoring();
end

-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

-- ===========================================================================
function OnFileListQueryComplete()
	UpdateActionButtonState();
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	SetupSortPulldown();

	LuaEvents.FileListQueryComplete.Add( OnFileListQueryComplete );

	Controls.ActionButton:RegisterCallback( Mouse.eLClick, OnActionButton );
	Controls.ActionButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack );
	Controls.BackButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CloseReferencedPackagesButton:RegisterCallback( Mouse.eLClick, OnCloseReferencedPackages);
	Controls.CloseReferencedPackagesButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CloudCheck:RegisterCallback( Mouse.eLClick, OnCloudCheck );
	Controls.FileName:RegisterStringChangedCallback( OnFileNameChange )
	Controls.No:RegisterCallback( Mouse.eLClick, OnNo );
	Controls.No:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.Yes:RegisterCallback( Mouse.eLClick, OnYes );
	Controls.Yes:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ShowModsButton:RegisterCallback( Mouse.eLClick, OnShowReferencedPackages );
	Controls.Delete:RegisterCallback( Mouse.eLClick, OnDelete );
	Controls.Delete:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	-- UI Events
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetHideHandler( OnHide );
	ContextPtr:SetInputHandler( OnInputHandler, true );

end
Initialize();

