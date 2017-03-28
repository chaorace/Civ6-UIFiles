-------------------------------------------------
-- Confirm Player Kick
-------------------------------------------------

local g_playerID = -1;
local g_initialName:string = "";
local g_initialPassword:string = "";

local HotseatPasswordsMatch = Locale.Lookup( "LOC_MULTIPLAYER_HOTSEAT_PASSWORDS_MATCH" );
local HotseatPasswordsDontMatch = Locale.Lookup( "LOC_MULTIPLAYER_HOTSEAT_PASSWORDS_DONT_MATCH" );
-------------------------------------------------
-------------------------------------------------
function OnCancel()
	local pPlayerConfig = PlayerConfigurations[g_playerID];
	pPlayerConfig:SetHotseatName(g_initialName);
	pPlayerConfig:SetHotseatPassword(g_initialPassword);

    UIManager:PopModal( ContextPtr );
    ContextPtr:CallParentShowHideHandler( true );
    ContextPtr:SetHide( true );
end

-------------------------------------------------
-------------------------------------------------
function OnAccept()
	local passwordString = "";
	local passwordVerifyString = "";
	if(Controls.HotseatPasswordEntry:GetText() ~= nil) then 
		passwordString = Controls.HotseatPasswordEntry:GetText();
	end
	if(Controls.HotseatPasswordVerifyEntry:GetText() ~= nil) then
		passwordVerifyString = Controls.HotseatPasswordVerifyEntry:GetText();
	end
	
	if(passwordString == passwordVerifyString) then
		LuaEvents.EditHotseatPlayer_UpdatePlayer(g_playerID);
		UIManager:PopModal( ContextPtr );
		ContextPtr:CallParentShowHideHandler( true );
		ContextPtr:SetHide( true );
	end
end

function ValidateData()
	local bValid:boolean = true;
	local passwordString = "";
	local passwordVerifyString = "";

	if(Controls.HotseatPasswordEntry:GetText() ~= nil) then 
		passwordString = Controls.HotseatPasswordEntry:GetText();
	end
	if(Controls.HotseatPasswordVerifyEntry:GetText() ~= nil) then
		passwordVerifyString = Controls.HotseatPasswordVerifyEntry:GetText();
	end

	if(passwordString ~= passwordVerifyString) then
		bValid = false;
	end

	local pPlayerConfig = PlayerConfigurations[g_playerID];
	if(pPlayerConfig:GetNickName() == nil or pPlayerConfig:GetNickName() == "") then
		bValid = false;
	end

	Controls.AcceptButton:SetDisabled(not bValid);
end
-------------------------------------------------
-------------------------------------------------
function UpdateHotseatPassword()
	local pPlayerConfig = PlayerConfigurations[g_playerID];
	local passwordString = "";
	local passwordVerifyString = "";
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];

	if(GameConfiguration.IsHotseat()) then
		if(Controls.HotseatPasswordEntry:GetText() ~= nil) then 
			passwordString = Controls.HotseatPasswordEntry:GetText();
		end
		if(Controls.HotseatPasswordVerifyEntry:GetText() ~= nil) then
			passwordVerifyString = Controls.HotseatPasswordVerifyEntry:GetText();
		end
		
		if(passwordString == passwordVerifyString) then
			pPlayerConfig:SetHotseatPassword(passwordString);
			--Controls.HotseatPasswordsMatchLabel:SetText(HotseatPasswordsMatch);
			Controls.HotseatPasswordsMatchLabel:SetHide(true);
			Controls.HotseatPasswordsMatchLabel:SetColor(COLOR_GREEN, 0);
		else
			pPlayerConfig:SetHotseatPassword("");
			Controls.HotseatPasswordsMatchLabel:SetText(HotseatPasswordsDontMatch);
			Controls.HotseatPasswordsMatchLabel:SetHide(false);
			Controls.HotseatPasswordsMatchLabel:SetColor(COLOR_RED, 0);
		end

		ValidateData();
	end
end

-------------------------------------------------
-------------------------------------------------
function Realize()
	local pPlayerConfig:table = PlayerConfigurations[g_playerID];
	Controls.HotseatPlayerNameEntry:SetText(pPlayerConfig:GetNickName());
	
	local passwordString = pPlayerConfig:GetHotseatPassword();
	if(passwordString == nil) then
		passwordString = "";
	end
	Controls.HotseatPasswordEntry:SetText(passwordString);
	Controls.HotseatPasswordVerifyEntry:SetText(passwordString);
end
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnPlayerNameChanged(playerNameEntry)
	local pPlayerConfig = PlayerConfigurations[g_playerID];
	local playerName = "";
	if(playerNameEntry:GetText() ~= nil) then
		playerName = playerNameEntry:GetText();
	end
	pPlayerConfig:SetHotseatName(playerName);
	ValidateData();
end
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnShutdown()
	-- Cache values for hotloading...
	LuaEvents.GameDebug_AddValue("EditHotseatPlayer", "isHidden", ContextPtr:IsHidden());
	LuaEvents.GameDebug_AddValue("EditHotseatPlayer", "g_playerID", g_playerID);
end

function OnGameDebugReturn( context:string, contextTable:table )
	if context == "EditHotseatPlayer" and contextTable["isHidden"] == false then
		g_playerID = contextTable["g_playerID"];
		Realize();
	end
end

function OnShow()
	Controls.PopupAlphaIn:SetToBeginning();
	Controls.PopupAlphaIn:Play();
	Controls.PopupSlideIn:SetToBeginning();
	Controls.PopupSlideIn:Play();
	Controls.HotseatPlayerNameEntry:TakeFocus();
end

function OnInputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyUp then
        if wParam == Keys.VK_ESCAPE then
            OnCancel();  
        end
    end
    return true;
end
-- ===========================================================================
--	Initialize screen
-- ===========================================================================
function Initialize()

	ContextPtr:SetShowHandler(OnShow);
	ContextPtr:SetShutdown(OnShutdown);
	ContextPtr:SetInputHandler(OnInputHandler);

	Controls.AcceptButton:RegisterCallback(Mouse.eLClick, OnAccept);
	Controls.CancelButton:RegisterCallback(Mouse.eLClick, OnCancel);
	Controls.HotseatPlayerNameEntry:RegisterStringChangedCallback(OnPlayerNameChanged);
	Controls.HotseatPasswordEntry:RegisterStringChangedCallback(UpdateHotseatPassword);
	Controls.HotseatPasswordVerifyEntry:RegisterStringChangedCallback(UpdateHotseatPassword);

	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);



	LuaEvents.StagingRoom_SetPlayerID.Add(function(playerID)
		local pPlayerConfig = PlayerConfigurations[playerID];
		g_playerID = playerID;
		g_initialName = pPlayerConfig:GetNickName();
		g_initialPassword = pPlayerConfig:GetHotseatPassword();
		Realize();
	end);
end
Initialize();