-------------------------------------------------
-- Multiplayer Select Screen
-------------------------------------------------
include("LobbyTypes"); --MPLobbyMode

-------------------------------------------------
-- Globals
-------------------------------------------------
local displayNetworkModes = false;	-- Are we displaying the network mode buttons?

local InternetButtonOnlineStr : string = Locale.Lookup("LOC_MULTIPLAYER_INTERNET_GAME_TT");
local InternetButtonOfflineStr : string = Locale.Lookup("LOC_MULTIPLAYER_INTERNET_GAME_OFFLINE_TT");


-------------------------------------------------
-- Helper Functions
-------------------------------------------------
function ToggleNetworkModeDisplay(showNetworkMode)
		Controls.StandardButton:SetHide(showNetworkMode);
		Controls.HotSeatButton:SetHide(showNetworkMode);	

		-- Show network mode buttons
		Controls.InternetButton:SetHide(not showNetworkMode);
		Controls.LANButton:SetHide(not showNetworkMode);

		Controls.MainStack:CalculateSize();
		
		displayNetworkModes = showNetworkMode;
end

-------------------------------------------------
-- Internet Game Button Handler
-------------------------------------------------
function InternetButtonClick()
	GameConfiguration.SetToDefaults(GameModeTypes.INTERNET);
	LuaEvents.ChangeMPLobbyMode(MPLobbyTypes.STANDARD_INTERNET);
	UIManager:QueuePopup( Controls.LobbyScreen, PopupPriority.Current );
end
Controls.InternetButton:RegisterCallback( Mouse.eLClick, InternetButtonClick );

function UpdateInternetButton()
	-- Internet available?
	if (Network.IsInternetLobbyServiceAvailable()) then
		Controls.InternetButton:SetDisabled(false);
		Controls.InternetButton:SetToolTipString(InternetButtonOnlineStr);
	else
		Controls.InternetButton:SetDisabled(true);
		Controls.InternetButton:SetToolTipString(InternetButtonOfflineStr);
	end
end
Events.SteamServersConnected.Add( UpdateInternetButton );
Events.SteamServersDisconnected.Add( UpdateInternetButton );

-------------------------------------------------
-- LAN Game Button Handler
-------------------------------------------------
function LANButtonClick()
	GameConfiguration.SetToDefaults(GameModeTypes.LAN);
	LuaEvents.ChangeMPLobbyMode(MPLobbyTypes.STANDARD_LAN);
	UIManager:QueuePopup( Controls.LobbyScreen, PopupPriority.Current );

end
Controls.LANButton:RegisterCallback( Mouse.eLClick, LANButtonClick );

-------------------------------------------------
-- Standard Multiplayer Game Button Handler
-------------------------------------------------
function StandardButtonClick()
	ToggleNetworkModeDisplay(true);
end
Controls.StandardButton:RegisterCallback( Mouse.eLClick, StandardButtonClick );

-------------------------------------------------
-- Hotseat Game Button Handler
-------------------------------------------------
function HotSeatButtonClick()
	GameConfiguration.SetToDefaults(GameModeTypes.HOTSEAT);
	LuaEvents.ChangeMPLobbyMode(MPLobbyTypes.HOTSEAT);
	UIManager:QueuePopup( Controls.HostGameScreen, PopupPriority.Current );
end
Controls.HotSeatButton:RegisterCallback( Mouse.eLClick, HotSeatButtonClick );

-------------------------------------------------
-- Cloud Game Button Handler
-------------------------------------------------
function CloudButtonClick()
	UIManager:QueuePopup( Controls.CloudGameScreen, PopupPriority.Current );
end
Controls.CloudButton:RegisterCallback( Mouse.eLClick, CloudButtonClick );

-------------------------------------------------
-- Back Button Handler
-------------------------------------------------
function BackButtonClick()
	if(displayNetworkModes) then
		ToggleNetworkModeDisplay(false);
	else
		UIManager:DequeuePopup( ContextPtr );
	end
end
Controls.BackButton:RegisterCallback( Mouse.eLClick, BackButtonClick );


-------------------------------------------------
-- Input Handler
-------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			BackButtonClick();
		end
	end
	return true;
end
ContextPtr:SetInputHandler( InputHandler );


-------------------------------------------------
-- Show / Hide Handler
-------------------------------------------------
function ShowHideHandler( bIsHide )
	if not bIsHide then
		UpdateInternetButton();

		local isFullyLoggedIn = FiraxisLive.IsFullyLoggedIn()
		Controls.CloudButton:SetDisabled(not isFullyLoggedIn)
	end

	--[[
	-- UINETTODO - We need to have a similar mechanic for Civ 6.
	if not bIsHide then
		-- To prevent settings getting carried over from scenarios and what not
		-- reset pregame here.
		if (not ContextPtr:IsHotLoad()) then
			UIManager:SetUICursor( 1 );
			Modding.ActivateDLC();
			PreGame.Reset();
			UIManager:SetUICursor( 0 );				
		end
	end
	--]]
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

-------------------------------------------------
-- Event Handler: MultiplayerGameLaunched
-------------------------------------------------
function OnGameLaunched()
	UIManager:DequeuePopup( ContextPtr );
end
Events.MultiplayerGameLaunched.Add( OnGameLaunched );


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


