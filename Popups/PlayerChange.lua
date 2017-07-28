----------------------------------------------------------------  
-- PlayerChange
--
-- Screen used for when the player changes in hotseat mode.
----------------------------------------------------------------  

----------------------------------------------------------------  
-- Defines
---------------------------------------------------------------- 
CloudCommitState = {
	NONE = "NONE",
	UPLOADING = "UPLOADING",
	FAILED = "FAILED",
	SUCCESS = "SUCCESS",
};


----------------------------------------------------------------  
-- Globals
---------------------------------------------------------------- 
local PopupTitleSuffix = Locale.Lookup( "LOC_PLAYER_CHANGE_POPUP_TITLE_SUFFIX" );
local PopupTitlePlayByCloud = Locale.Lookup( "LOC_PLAYER_CHANGE_POPUP_TITLE_PLAYBYCLOUD" );
local bPlayerChanging :boolean = false; -- Are we in the "Please Wait" mode?
local bLocalPlayerTurnEnded :boolean = false;
local eCloudUploadState :string = CloudCommitState.NONE;


----------------------------------------------------------------        
-- Input Handler
----------------------------------------------------------------        
function OnInputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_RETURN or wParam == Keys.VK_ESCAPE then
			OnKeyUp_Return();
			return true;
		end
	end
	return false;
end

-- ===========================================================================
function OnKeyUp_Return()
	-- Is the internal dialog box hidden?  If so, we are in Please Wait mode so don't do anything.
	if (not Controls.PopupAlphaIn:IsHidden()) then
		local localPlayerID = Game.GetLocalPlayer();
		local localPlayer = PlayerConfigurations[localPlayerID];
		if(localPlayer ~= nil and localPlayer:GetHotseatPassword() == "") then
			OnOk();
		end
	end
end
-- ===========================================================================
function OnSave()
	UIManager:QueuePopup(Controls.SaveGameMenu, PopupPriority.Current);	
end

-- ===========================================================================
function OnOk()
	if(GameConfiguration.IsHotseat()) then
		SetPause(false);
	end
	LuaEvents.PlayerChange_Close(Game.GetLocalPlayer());
	UIManager:DequeuePopup( ContextPtr );
	Controls.PopupAlphaIn:SetHide(true);		-- Hide, so they can't click on it!
	Controls.PopupAlphaIn:SetToBeginning();
	Controls.PopupSlideIn:SetToBeginning();
end

-- ===========================================================================
function OnCancelUpload()
   	UIManager:SetUICursor( 1 );
	UITutorialManager:EnableOverlay( false );	
	UITutorialManager:HideAll();

	UIManager:Log("Shutting down via player change exit-to-main-menu.");
	Events.ExitToMainMenu();
end
	

-- ===========================================================================
function OnMenu()
    UIManager:QueuePopup( LookUpControl( "/InGame/TopOptionsMenu" ), PopupPriority.Utmost );
end

-- ===========================================================================
function OnLocalPlayerTurnBegin()
	bLocalPlayerTurnEnded = false;
	if(GameConfiguration.IsHotseat() == true) then
		-- In hotseat, we show the full player change popup before the player takes their turn.
		-- this tells the UI to display us. ContextPtr is the this pointer for this object.
		bPlayerChanging = false;
		BuildTurnControls();
	elseif(GameConfiguration.IsPlayByCloud() == true and not ContextPtr:IsHidden()) then
		-- In PlayByCloud, just close the screen if it is visible so the player can take their turn.
		OnOk();
	end
end

function OnRemotePlayerTurnBegin( playerID :number)
	-- In PlayByCloud, we show the full player change popup on the next human's turn after the local player
	-- ended their turn.
	if(bLocalPlayerTurnEnded and GameConfiguration.IsPlayByCloud() == true) then
		local pPlayer = Players[playerID];
		if (pPlayer ~= nil and pPlayer:IsHuman()) then
			-- GameCoreController handles the cloud upload process for us.  
			-- We just need to show our state and allow the player to cancel if needed.
			if(eCloudUploadState == CloudCommitState.NONE) then
				eCloudUploadState = CloudCommitState.UPLOADING;
			end
			bPlayerChanging = false;
			BuildTurnControls();
		end
	end
end

function OnPlayerTurnDeactivated( ePlayer:number )
	if ePlayer == Game.GetLocalPlayer() then	
		bLocalPlayerTurnEnded = true;	
		bPlayerChanging = true;
		--if(GetNumAliveHumanPlayers() > 1) then
			UIManager:QueuePopup( ContextPtr, PopupPriority.Utmost);
		--end
	end
end

function GetNumAliveHumanPlayers()
	local aPlayers = PlayerManager.GetAliveMajors();
	local numAliveHumanPlayers = 0;
	for _, pPlayer in ipairs(aPlayers) do
		if(pPlayer:IsHuman()) then
			numAliveHumanPlayers = numAliveHumanPlayers + 1;
		end
	end

	return numAliveHumanPlayers;
end

-- ===========================================================================
function BuildTurnControls()
	--if(GetNumAliveHumanPlayers() > 1) then
		print("BuildTurnControls: CurrentGameTurn=" .. Game.GetCurrentGameTurn());
		if(GameConfiguration.IsHotseat()) then
			SetPause(true);

			-- Panel title is player's name.
			local localPlayerID = Game.GetLocalPlayer();
			local localPlayer = PlayerConfigurations[localPlayerID];
			--print("Hotseat password=" .. localPlayer:GetHotseatPassword());
			Controls.TitleText:SetText(Locale.ToUpper(localPlayer:GetPlayerName()));
		elseif(GameConfiguration.IsPlayByCloud() == true) then
			-- Panel title is static.
			Controls.TitleText:SetText(PopupTitlePlayByCloud);
		end

		if(ContextPtr:IsHidden()) then
			UIManager:QueuePopup( ContextPtr, PopupPriority.Utmost);
		else
			ShowTurnControls();
		end
	--end
end

-- ===========================================================================
function OnLoadScreenClose()

	-- Have we loaded and the player is active?
	local pPlayer = Players[ Game.GetLocalPlayer() ];
	if (pPlayer ~= nil) then
		if (pPlayer:IsTurnActive()) then
			-- Yes, then show the dialog
			OnLocalPlayerTurnBegin();
			return;
		end
	end
	
	-- No, just show the Please Wait, we will get a turn begin event later.
	bPlayerChanging = true;
	UIManager:QueuePopup( ContextPtr, PopupPriority.Utmost);
end

-- ===========================================================================
function OnShow()
	ShowTurnControls();
end

-- ===========================================================================
function ShowTurnControls()
	LuaEvents.PlayerChange_Show();
	if(not bPlayerChanging) then
		local localPlayerID = Game.GetLocalPlayer();
		local localPlayer = PlayerConfigurations[localPlayerID];
		Controls.PlayerChangingText:SetHide(true);
		Controls.PopupAlphaIn:SetHide(false);
		Controls.PasswordEntry:SetText("");
		Controls.PopupAlphaIn:SetToBeginning();
		Controls.PopupAlphaIn:Play();
		Controls.PopupSlideIn:SetToBeginning();
		Controls.PopupSlideIn:Play();
		if(localPlayer:GetHotseatPassword() == "" 
			or GameConfiguration.IsPlayByCloud() == true) then
			Controls.PasswordStack:SetHide(true);
			Controls.OkButton:SetDisabled(false);
		else
			Controls.PasswordStack:SetHide(false);
			Controls.OkButton:SetDisabled(true);
			Controls.PasswordEntry:TakeFocus();
		end

		UpdateBottomButtons();
	else
		-- While in the "Please Wait" mode, hide the controls.
		Controls.PlayerChangingText:SetHide(false);
		Controls.PopupAlphaIn:SetToBeginning();
		Controls.PopupSlideIn:SetToBeginning();
		Controls.PopupAlphaIn:SetHide(true);		-- Hide the box, else they can still click on the contents!
	end
end

-- ===========================================================================
function UpdateBottomButtons()
	ShowOkButton();
	ShowSaveButton();
	ShowCloudUpload();

	Controls.BottomButtonsStack:CalculateSize();
	Controls.BottomButtonsStack:ReprocessAnchoring();
end

-- ===========================================================================
function ShowOkButton()
	local showOk = GameConfiguration.IsHotseat();
	Controls.OkButton:SetHide(not showOk);
end

-- ===========================================================================
function ShowSaveButton()
	local showSave = GameConfiguration.IsHotseat();
	Controls.SaveButton:SetHide(not showSave);
end

-- ===========================================================================
function ShowCloudUpload()
	local showCancel = GameConfiguration.IsPlayByCloud() 
		and eCloudUploadState ~= CloudCommitState.SUCCESS;
	Controls.CancelUploadButton:SetHide(not showCancel);

	-- Show Cloud Upload Status Text
	if(eCloudUploadState == CloudCommitState.SUCCESS) then
		Controls.CloudUploadStatus:SetHide(false);
		Controls.CloudUploadStatus:LocalizeAndSetText("LOC_PLAYER_CHANGE_UPLOAD_SUCCESS");
	elseif(eCloudUploadState == CloudCommitState.FAILED) then
		Controls.CloudUploadStatus:SetHide(false);
		Controls.CloudUploadStatus:LocalizeAndSetText("LOC_PLAYER_CHANGE_UPLOAD_FAILED");
	elseif(eCloudUploadState == CloudCommitState.UPLOADING) then
		Controls.CloudUploadStatus:SetHide(false);
		Controls.CloudUploadStatus:LocalizeAndSetText("LOC_PLAYER_CHANGE_UPLOAD_IN_PROGRESS");
	else
		Controls.CloudUploadStatus:SetHide(true);
		Controls.CloudUploadStatus:LocalizeAndSetText("");
	end
end

-- ===========================================================================
function SetPause(bNewPause)
	local localPlayerID = Game.GetLocalPlayer();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];
	if (localPlayerConfig ~= nil) then
		local bIsTurnActive = Players[localPlayerID]:IsTurnActive();
		if (bIsTurnActive or bNewPause == false) then
			localPlayerConfig:SetWantsPause(bNewPause);
		end
	end
	Network.BroadcastPlayerInfo();
end

-- ===========================================================================
function OnPasswordEntryStringChanged(passwordEditBox)
	local localPlayerID = Game.GetLocalPlayer();
	local localPlayer = PlayerConfigurations[localPlayerID]; 
	local password = "";

	if(passwordEditBox:GetText() ~= nil) then
		password = passwordEditBox:GetText();
		--print("OnPasswordEntryStringChanged: password=" .. password .. ", localPlayerPassword=" .. localPlayer:GetHotseatPassword());
		if(password == localPlayer:GetHotseatPassword()) then
			Controls.OkButton:SetDisabled(false);
		else
			Controls.OkButton:SetDisabled(true);
		end
	end
end

-- ===========================================================================
function OnPasswordEntryCommit()
	local localPlayerID = Game.GetLocalPlayer();
	local localPlayer = PlayerConfigurations[localPlayerID]; 
	local password = "";

	if(Controls.PasswordEntry:GetText() ~= nil) then
		password = Controls.PasswordEntry:GetText();
		--print("OnPasswordEntryCommit: password=" .. password .. ", localPlayerPassword=" .. localPlayer:GetHotseatPassword());
		if(password == localPlayer:GetHotseatPassword()) then
			OnOk();
		end
	end
end

-- ===========================================================================
function OnTeamVictory(team, victory, eventID)
	if(not ContextPtr:IsHidden()) then
		UIManager:DequeuePopup(ContextPtr);
		Events.LocalPlayerTurnBegin.Remove(OnLocalPlayerTurnBegin);
		Events.PlayerTurnDeactivated.Remove(OnPlayerTurnDeactivated);
		Events.LoadScreenClose.Remove(OnLoadScreenClose);
	end
end

-- ===========================================================================
function OnUploadCloudSaveComplete(success)
	if(success == true) then
		eCloudUploadState = CloudCommitState.SUCCESS;
	else
		eCloudUploadState = CloudCommitState.FAILED;
	end

	UpdateBottomButtons();

	-- exit to main menu after updating the buttons so the player will see the exiting message 
	-- during the exit stall.
	if(success == true) then
		UIManager:Log("Shutting down via player change cloud commit success.");
		Events.ExitToMainMenu();
	end
end


-- ===========================================================================
function OnEndGameMenu_OneMoreTurn()
	print("OnEndGameMenu_OneMoreTurn");
	Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
	Events.PlayerTurnDeactivated.Add(OnPlayerTurnDeactivated);
	Events.LoadScreenClose.Add(OnLoadScreenClose);
end

-- ===========================================================================
function OnEndGameMenu_ViewingPlayerDefeat()
	-- In hotseat, it is possible for a human player to get defeated by an AI civ during the turn processing.
	-- If that happens, the PlayerChange screen needs to hide so the defeat screen can be seen.
	-- The PlayerChange screen will be restored when the defeated player clicks "next player" and ends their turn.
	print("OnEndGameMenu_ViewingPlayerDefeat");
	if(not ContextPtr:IsHidden()) then
		UIManager:DequeuePopup(ContextPtr);
	end
end

-- ===========================================================================
--	INITIALIZE
-- ===========================================================================
function Initialize()

	-- If not in a hotseat or PlayByCloud, do not register for events.
	if (GameConfiguration.IsHotseat() == false 
		and GameConfiguration.IsPlayByCloud() == false) then
		return;
	end

	-- NOTE: LuaEvents. are events that only exist inside the Lua system. Nothing native.

	-- When player info is changed, this pulldown needs to know so it can update itself if it becomes invalid.
	-- NOTE: Events.XXX are Engine(App/Civ6) Events. Where XXX is a native event, defined in native. Look for: LUAEVENT_NAMESPACED(LocalMachineEvent, PlayerInfoChanged);
	--Events.LocalPlayerChanged.Add(OnLocalPlayerChanged);
	-- changing to listen for TurnBegin so that on the initial turn, the first player will get this popup screen. this is consistent with Civ V's behavior.
	Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
	Events.RemotePlayerTurnBegin.Add( OnRemotePlayerTurnBegin );
	Events.PlayerTurnDeactivated.Add(OnPlayerTurnDeactivated);
	Events.LoadScreenClose.Add(OnLoadScreenClose);
	Events.TeamVictory.Add(OnTeamVictory);
	Events.UploadCloudSaveComplete.Add(OnUploadCloudSaveComplete);

	LuaEvents.EndGameMenu_OneMoreTurn.Add(OnEndGameMenu_OneMoreTurn);
	LuaEvents.EndGameMenu_ViewingPlayerDefeat.Add(OnEndGameMenu_ViewingPlayerDefeat);

	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetInputHandler( OnInputHandler );

	Controls.SaveButton:RegisterCallback(Mouse.eLClick, OnSave);
	Controls.OkButton:RegisterCallback(Mouse.eLClick, OnOk);
	Controls.MenuButton:RegisterCallback( Mouse.eLClick, OnMenu );
	Controls.PasswordEntry:RegisterStringChangedCallback(OnPasswordEntryStringChanged);
	Controls.PasswordEntry:RegisterCommitCallback(OnPasswordEntryCommit);
	Controls.CancelUploadButton:RegisterCallback( Mouse.eLClick, OnCancelUpload);
end
Initialize();


