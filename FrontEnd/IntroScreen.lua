include("InputSupport");

-- ===========================================================================
--	Action Hotkeys
-- ===========================================================================

local m_actionHotkeyAccept		:number = Input.GetActionId("Accept");
local m_actionHotkeyAcceptAlt	:number = Input.GetActionId("AcceptAlt");


-- ===========================================================================
--	Accept EULA
-- ===========================================================================
function AcceptEULA()
	Controls.CopyrightAccept:SetHide( true );
	Events.UserAcceptsEULA();	
end


-- ===========================================================================
--	Hotkey
-- ===========================================================================
function OnInputActionTriggered( actionId:number )
	if	actionId == m_actionHotkeyAccept or 
		actionId == m_actionHotkeyAcceptAlt then		
			AcceptEULA();
	end
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnAccept()
	AcceptEULA();    
end

-- ===========================================================================
function OnRequestClose()
    Events.UserConfirmedClose();
end

-- ===========================================================================
function Startup()

	Input.SetActiveContext( InputContext.Startup );

    Controls.CopyrightAccept:RegisterCallback( Mouse.eLClick, OnAccept );
    Controls.CopyrightAccept:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Controls.CopyrightAccept:SetHide( Automation.IsActive() );
    Controls.CopyrightText:SetHide(false);

	Events.InputActionTriggered.Add( OnInputActionTriggered );
    Events.UserRequestClose.Add( OnRequestClose );
end
Startup();
