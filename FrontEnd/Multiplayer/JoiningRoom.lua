---------------------------------------------------------------- 
-- Globals
----------------------------------------------------------------  
local PADDING:number = 60;
local MIN_SIZE_X:number = 250;
local MIN_SIZE_Y:number = 200;
local g_waitingForContentConfigure : boolean = false;

----------------------------------------------------------------        
-- Input Handler
----------------------------------------------------------------        
function OnInputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			HandleExitRequest();
		end
	end
	return true;
end

-------------------------------------------------
-- Leave the game we're trying to join.
-------------------------------------------------
function HandleExitRequest()
	Network.LeaveGame();
	UIManager:DequeuePopup( ContextPtr );
end


-------------------------------------------------
-- Trigger transition to the staging room.
-------------------------------------------------
function TransitionToStagingRoom()
	-- Staging room must be notified before this is dequeued
	-- or the screen below will be shown (for a frame) and
	-- that lobby screen will attempt to disconnect.
	LuaEvents.JoiningRoom_ShowStagingRoom();	
	UIManager:DequeuePopup( ContextPtr );	
end


-------------------------------------------------
-- Event Handler: MultiplayerJoinRoomComplete
-------------------------------------------------
function OnJoinRoomComplete()
	if (not ContextPtr:IsHidden()) then
		if(not Network.IsHost()) then
			Controls.JoiningLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_JOINING_HOST")));
		end
	end
end

-------------------------------------------------
-- Event Handler: MultiplayerJoinRoomFailed
-------------------------------------------------
function OnJoinRoomFailed( iExtendedError)
	if (not ContextPtr:IsHidden()) then
		if iExtendedError == JoinGameErrorType.JOINGAME_ROOM_FULL then
			Events.FrontEndPopup.CallImmediate( "LOC_MP_ROOM_FULL" );
		else
			Events.FrontEndPopup.CallImmediate( "LOC_MP_JOIN_FAILED" );
		end
		Network.LeaveGame();
		UIManager:DequeuePopup( ContextPtr );
	end
end

-------------------------------------------------
-- Event Handler: MultiplayerJoinGameComplete
-------------------------------------------------
function OnJoinGameComplete()
	print("OnJoinGameComplete()");
	-- This event triggers when the game has finished joining the multiplayer.  
	-- NOTE:  If you are the game host, you'll get this event before MultiplayerJoinRoomComplete because
	--				the game host creates and joins the game before advertising with the lobby system.
	if (not ContextPtr:IsHidden()) then
		-- Next stage is to wait for content configuration.
		-- The game host doesn't do a content configuration and heads to the staging room now.
		if(Network.IsHost()) then
			-- Game host 
			TransitionToStagingRoom();
		else	
			g_waitingForContentConfigure = true;
			Controls.JoiningLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_CONFIGURING_CONTENT")));
		end
	end
end

-------------------------------------------------
-- Event Handler: FinishedGameplayContentConfigure
-------------------------------------------------
function OnFinishedGameplayContentConfigure()
	print("OnFinishedGameplayContentConfigure() g_waitingForContentConfigure=" .. tostring(g_waitingForContentConfigure));
	-- This event triggers when the game has finished content configuration.
	-- For remote clients, this is the last step before transitioning to the staging room.
	-- Game hosts don't perform a content configuration so they will transition in OnJoinGameComplete.
	if (not ContextPtr:IsHidden() and g_waitingForContentConfigure == true) then
		g_waitingForContentConfigure = false;
		TransitionToStagingRoom();
	end 
end

-------------------------------------------------
-- Event Handler: MultiplayerGameAbandoned
-------------------------------------------------
function OnMultiplayerGameAbandoned(eReason)
	if (not ContextPtr:IsHidden()) then
		if (eReason == KickReason.KICK_HOST) then
			Events.FrontEndPopup.CallImmediate( "LOC_GAME_ABANDONED_KICKED" );
		elseif (eReason == KickReason.KICK_NO_ROOM) then
			Events.FrontEndPopup.CallImmediate( "LOC_GAME_ABANDONED_ROOM_FULL" );
		elseif (eReason == KickReason.KICK_VERSION_MISMATCH) then
			Events.FrontEndPopup.CallImmediate( "LOC_GAME_ABANDONED_VERSION_MISMATCH" );
		elseif (eReason == KickReason.KICK_MOD_ERROR) then
			Events.FrontEndPopup.CallImmediate( "LOC_GAME_ABANDONED_MOD_ERROR" );
		else
			Events.FrontEndPopup.CallImmediate( "LOC_GAME_ABANDONED_JOIN_FAILED" );
		end
		Network.LeaveGame();
		UIManager:DequeuePopup( ContextPtr );	
	end
end

-- ===========================================================================
-- Event Handler: BeforeMultiplayerInviteProcessing
-- ===========================================================================
function OnBeforeMultiplayerInviteProcessing()
	-- We're about to process a game invite.  Get off the popup stack before we accidently break the invite!
	UIManager:DequeuePopup( ContextPtr );
end


-- APPNETTODO - Implement these events for better join game status reporting
--[[
-------------------------------------------------
-- Event Handler: MultiplayerConnectionFailed
-------------------------------------------------
function OnMultiplayerConnectionFailed()
	if (not ContextPtr:IsHidden()) then
		-- We should only get this if we couldn't complete the connection to the host of the room	
		Events.FrontEndPopup.CallImmediate( "LOC_MP_JOIN_FAILED" );
		Network.LeaveGame();
		UIManager:DequeuePopup( ContextPtr );
	end
end
Events.MultiplayerConnectionFailed.Add( OnMultiplayerConnectionFailed );

-------------------------------------------------
-- Event Handler: ConnectedToNetworkHost
-------------------------------------------------
function OnHostConnect()
	if (not ContextPtr:IsHidden()) then
		Controls.JoiningLabel:SetText( Locale.ConvertTextKey("LOC_MULTIPLAYER_JOINING_PLAYERS" ));  
	end
end
Events.ConnectedToNetworkHost.Add ( OnHostConnect );

-------------------------------------------------
-- Event Handler: MultiplayerNetRegistered
-------------------------------------------------
function OnNetRegistered()
	if (not ContextPtr:IsHidden()) then
		Controls.JoiningLabel:SetText( Locale.ConvertTextKey("LOC_MULTIPLAYER_JOINING_GAMESTATE" ));    
	end
end
Events.MultiplayerNetRegistered.Add( OnNetRegistered );  

-------------------------------------------------
-- Event Handler: PlayerVersionMismatchEvent
-------------------------------------------------
function OnVersionMismatch( iPlayerID, playerName, bIsHost )
	if (not ContextPtr:IsHidden()) then
    if( bIsHost ) then
        Events.FrontEndPopup.CallImmediate( Locale.ConvertTextKey( "LOC_MP_VERSION_MISMATCH_FOR_HOST", playerName ) );
    	Matchmaking.KickPlayer( iPlayerID );
    else
        Events.FrontEndPopup.CallImmediate( Locale.ConvertTextKey( "LOC_MP_VERSION_MISMATCH_FOR_PLAYER" ) );
        HandleExitRequest();
    end
	end
end
Events.PlayerVersionMismatchEvent.Add( OnVersionMismatch );
--]]


-- ===========================================================================
--	UI Event
--	Screen is now shown....
-- ===========================================================================
function OnShow()
	-- APPNETTODO - implement DLC handling.
	--[[
	-- Activate only the DLC allowed for this MP game.  Mods will also deactivated/activate too.
	if (not ContextPtr:IsHotLoad()) then 
		local prevCursor = UIManager:SetUICursor( 1 );
		local bChanged = Modding.ActivateAllowedDLC();
		UIManager:SetUICursor( prevCursor );
				
		-- Send out an event to continue on, as the ActivateDLC may have swapped out the UI	
		Events.SystemUpdateUI( SystemUpdateUI.RestoreUI, "JoiningRoom" );
	end
	--]]

	-- In the specific case of a user joinging a game from an invite, while they are
	-- in the the tutorial; be sure the tutorial guards are all off.
	UITutorialManager:SetActiveAlways( false );
	UITutorialManager:EnableOverlay( false );
	UITutorialManager:HideAll();
	UITutorialManager:ClearPersistantInputControls();	
	

	Controls.JoiningLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_JOINING_ROOM")));

	LuaEvents.JoiningRoom_Showing();
end


-------------------------------------------------
function AdjustScreenSize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	local hideLogo = true;
	if(screenY >= Controls.MainWindow:GetSizeY() + Controls.LogoContainer:GetSizeY()+ Controls.LogoContainer:GetOffsetY()) then
		hideLogo = false;
	end
	Controls.LogoContainer:SetHide(hideLogo);
	Controls.MainGrid:ReprocessAnchoring();
end

-------------------------------------------------
function OnUpdateUI( type, tag, iData1, iData2, strData1)
	if( type == SystemUpdateUI.ScreenResize ) then
		AdjustScreenSize();
	-- APPNETTODO - Need RestoreUI system for game invites.
	--[[
	elseif (type == SystemUpdateUI.RestoreUI and tag == "JoiningRoom") then
		if (ContextPtr:IsHidden()) then
			UIManager:QueuePopup(ContextPtr, PopupPriority.JoiningScreen );    
		end
	--]]
	end
end


-- ===========================================================================
--	Initialize screen
-- ===========================================================================
function Initialize()

	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetInputHandler( OnInputHandler );

	Events.MultiplayerJoinRoomComplete.Add( OnJoinRoomComplete );
	Events.MultiplayerJoinRoomFailed.Add( OnJoinRoomFailed );
	Events.MultiplayerJoinGameComplete.Add( OnJoinGameComplete);
	Events.FinishedGameplayContentConfigure.Add(OnFinishedGameplayContentConfigure);
	Events.MultiplayerGameAbandoned.Add( OnMultiplayerGameAbandoned );
	Events.SystemUpdateUI.Add( OnUpdateUI );
	Events.BeforeMultiplayerInviteProcessing.Add( OnBeforeMultiplayerInviteProcessing );

	Controls.CancelButton:RegisterCallback(Mouse.eLClick, HandleExitRequest);
	AdjustScreenSize();
end
Initialize();