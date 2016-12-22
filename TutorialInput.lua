-- ===========================================================================
--	TutorialInput
--	Handles the special input cases (on the main UI root) of an active tutorial.
-- ===========================================================================


-- ===========================================================================
function OnFilterKeysActive()
	ContextPtr:SetHide(false);		--	If visible input handler will be active
end

-- ===========================================================================
function OnFilterKeysDisabled()
	ContextPtr:SetHide(true);		--
end

-- ===========================================================================
function KeyHandler( key:number )	
	if key == Keys.VK_ESCAPE then
		LuaEvents.Tutorial_ToggleInGameOptionsMenu();
		return true;
	end
	return false;	
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then 
		return KeyHandler( pInputStruct:GetKey() ); 
	end
	return false;
end

-- ===========================================================================
function Initialize()

	-- UI Events
	ContextPtr:SetInputHandler( OnInputHandler, true );
	
	-- LUA Events
	LuaEvents.TutorialUIRoot_FilterKeysActive.Add( OnFilterKeysActive );
	LuaEvents.TutorialUIRoot_FilterKeysDisabled.Add( OnFilterKeysDisabled );

end
Initialize();
