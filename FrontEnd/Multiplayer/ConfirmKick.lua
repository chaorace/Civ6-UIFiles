-------------------------------------------------
-- Confirm Player Kick
-------------------------------------------------

local g_kickIdx = 0;
local g_kickName = "";

-------------------------------------------------
-------------------------------------------------
function OnCancel()
    UIManager:PopModal( ContextPtr );
    ContextPtr:CallParentShowHideHandler( true );
    ContextPtr:SetHide( true );
end
Controls.CancelButton:RegisterCallback( Mouse.eLClick, OnCancel );


-------------------------------------------------
-------------------------------------------------
function OnAccept()
	print("OnAccept: g_kickIdx: " .. tostring(g_kickIdx));
	Network.KickPlayer( g_kickIdx );
	UIManager:PopModal( ContextPtr );
	ContextPtr:CallParentShowHideHandler( true );
	ContextPtr:SetHide( true );
end
Controls.AcceptButton:RegisterCallback( Mouse.eLClick, OnAccept );

----------------------------------------------------------------
-- Input processing
----------------------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyUp then
        if wParam == Keys.VK_ESCAPE then
            OnCancel();  
        end
        if wParam == Keys.VK_RETURN then
            OnAccept();  
        end
    end
    return true;
end
ContextPtr:SetInputHandler( InputHandler );

-------------------------------------------------
-------------------------------------------------
function ShowHideHandler( bIsHide, bIsInit )
    
	if( not bIsHide ) then
		-- Set player name in popup
		UpdateKickLabel();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler );

-------------------------------------------------
-------------------------------------------------
function UpdateKickLabel()
	Controls.DialogText:LocalizeAndSetText("LOC_CONFIRM_KICK_PLAYER_DESC", g_kickName);	
	Controls.StackContents:CalculateSize();
	Controls.StackContents:ReprocessAnchoring();
end

-------------------------------------------------
-------------------------------------------------
function OnSetKickPlayer(playerID, playerName)
	g_kickIdx = playerID;
	g_kickName = playerName;
	UpdateKickLabel();
end

-------------------------------------------------
-------------------------------------------------
function OnMultiplayerPostPlayerDisconnected(iPlayerID)
	-- Cancel out if the target player has disconnected from the game.
	if(ContextPtr:IsHidden() == false) then
		if(g_kickIdx == iPlayerID) then
			OnCancel();
		end
	end
end

-- ===========================================================================
--	Initialize screen
-- ===========================================================================
function Initialize()
	Events.MultiplayerPostPlayerDisconnected.Add(OnMultiplayerPostPlayerDisconnected);

	LuaEvents.SetKickPlayer.Add(OnSetKickPlayer);
end
Initialize();


