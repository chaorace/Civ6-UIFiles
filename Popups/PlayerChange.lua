----------------------------------------------------------------  
-- PlayerChange
--
-- Screen used for when the player changes in hotseat mode.
----------------------------------------------------------------  


----------------------------------------------------------------  
-- Globals
---------------------------------------------------------------- 
local PopupTitleSuffix = Locale.Lookup( "LOC_PLAYER_CHANGE_POPUP_TITLE_SUFFIX" );
local bPlayerChanging :boolean = false;

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
	SetPause(false);
	LuaEvents.PlayerChange_Close(Game.GetLocalPlayer());
	UIManager:DequeuePopup( ContextPtr );
	Controls.PopupAlphaIn:SetHide(true);		-- Hide, so they can't click on it!
	Controls.PopupAlphaIn:SetToBeginning();
	Controls.PopupSlideIn:SetToBeginning();
end

-- ===========================================================================
function OnMenu()
    UIManager:QueuePopup( LookUpControl( "/InGame/TopOptionsMenu" ), PopupPriority.Utmost );
end

-- ===========================================================================
function OnLocalPlayerTurnBegin()
	-- this tells the UI to display us. ContextPtr is the this pointer for this object.
	bPlayerChanging = false;
	SetupHotseatControls();
	Controls.PlayerChangingText:SetHide(true);
end

function OnPlayerTurnDeactivated( ePlayer:number )
	if ePlayer == Game.GetLocalPlayer() then		
		bPlayerChanging = true;
		--if(GetNumAliveHumanPlayers() > 1) then
			UIManager:QueuePopup( ContextPtr, PopupPriority.Utmost);
			Controls.PlayerChangingText:SetHide(false);
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
function SetupHotseatControls()
	--if(GetNumAliveHumanPlayers() > 1) then
		print("SetupHotseatControls: CurrentGameTurn=" .. Game.GetCurrentGameTurn());
		--if(Game.GetCurrentGameTurn() > 1) then
			SetPause(true);
		--end
		local localPlayerID = Game.GetLocalPlayer();
		local localPlayer = PlayerConfigurations[localPlayerID];
		print("Hotseat password=" .. localPlayer:GetHotseatPassword());
		Controls.TitleText:SetText(Locale.ToUpper(localPlayer:GetPlayerName()));
		if(ContextPtr:IsHidden()) then
			UIManager:QueuePopup( ContextPtr, PopupPriority.Utmost);
		else
			ShowHotseatControls();
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
	Controls.PlayerChangingText:SetHide(false);
	Controls.PopupAlphaIn:SetToBeginning();
	Controls.PopupSlideIn:SetToBeginning();
	Controls.PopupAlphaIn:SetHide(true);		-- Hide the box, else they can still click on the contents!
	UIManager:QueuePopup( ContextPtr, PopupPriority.Utmost);
end

-- ===========================================================================
function OnShow()
	ShowHotseatControls();
end

-- ===========================================================================
function ShowHotseatControls()
	LuaEvents.PlayerChange_Show();
	if(not bPlayerChanging) then
		local localPlayerID = Game.GetLocalPlayer();
		local localPlayer = PlayerConfigurations[localPlayerID];
		Controls.PopupAlphaIn:SetHide(false);
		Controls.PasswordEntry:SetText("");
		Controls.PopupAlphaIn:SetToBeginning();
		Controls.PopupAlphaIn:Play();
		Controls.PopupSlideIn:SetToBeginning();
		Controls.PopupSlideIn:Play();
		if(localPlayer:GetHotseatPassword() == "") then
			Controls.PasswordStack:SetHide(true);
			Controls.OkButton:SetDisabled(false);
		else
			Controls.PasswordStack:SetHide(false);
			Controls.OkButton:SetDisabled(true);
		end
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
function OnEndGameMenu_OneMoreTurn()
	print("OnEndGameMenu_OneMoreTurn");
	Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
	Events.PlayerTurnDeactivated.Add(OnPlayerTurnDeactivated);
	Events.LoadScreenClose.Add(OnLoadScreenClose);
end

-- ===========================================================================
--	INITIALIZE
-- ===========================================================================
function Initialize()

	-- If not in a hotseat mode, do not register for events.
	if (GameConfiguration.IsHotseat() == false) then
		return;
	end

	-- NOTE: LuaEvents. are events that only exist inside the Lua system. Nothing native.

	-- When player info is changed, this pulldown needs to know so it can update itself if it becomes invalid.
	-- NOTE: Events.XXX are Engine(App/Civ6) Events. Where XXX is a native event, defined in native. Look for: LUAEVENT_NAMESPACED(LocalMachineEvent, PlayerInfoChanged);
	--Events.LocalPlayerChanged.Add(OnLocalPlayerChanged);
	-- changing to listen for TurnBegin so that on the initial turn, the first player will get this popup screen. this is consistent with Civ V's behavior.
	Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
	Events.PlayerTurnDeactivated.Add(OnPlayerTurnDeactivated);
	Events.LoadScreenClose.Add(OnLoadScreenClose);
	Events.TeamVictory.Add(OnTeamVictory);

	LuaEvents.EndGameMenu_OneMoreTurn.Add(OnEndGameMenu_OneMoreTurn);

	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetInputHandler( OnInputHandler );

	Controls.SaveButton:RegisterCallback(Mouse.eLClick, OnSave);
	Controls.OkButton:RegisterCallback(Mouse.eLClick, OnOk);
	Controls.MenuButton:RegisterCallback( Mouse.eLClick, OnMenu );
	Controls.PasswordEntry:RegisterStringChangedCallback(OnPasswordEntryStringChanged);
	Controls.PasswordEntry:RegisterCommitCallback(OnPasswordEntryCommit);
end
Initialize();


