-- ===========================================================================
--	World Builder UI Context
-- ===========================================================================

-- ===========================================================================
--	DATA MEMBERS
-- ===========================================================================
local DefaultMessageHandler = {};

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================
  
DefaultMessageHandler[KeyEvents.KeyUp] =
function( pInputStruct )
	
	local uiKey = pInputStruct:GetKey();
	if uiKey == Keys.VK_ESCAPE then
		if( Controls.TopOptionsMenu:IsHidden() ) then
			UIManager:QueuePopup( Controls.TopOptionsMenu, PopupPriority.Utmost );
			return true;
		end
	elseif uiKey == Keys.Z and pInputStruct:IsControlDown() then
		if pInputStruct:IsShiftDown() then
			WorldBuilder.Redo();
		else
			WorldBuilder.Undo();
		end
	elseif uiKey == Keys.Y and pInputStruct:IsControlDown() then
		WorldBuilder.Redo();
	elseif uiKey == Keys.VK_F5 then
		-- TODO: Quick save maps in world builder?
	end

	return false;
end

-- ===========================================================================  
function OnLoadGameViewStateDone()
	
end

-- ===========================================================================    
function InputHandler( pInputStruct )

	local uiMsg = pInputStruct:GetMessageType();

	if DefaultMessageHandler[uiMsg] ~= nil then
		return DefaultMessageHandler[uiMsg]( pInputStruct );
	else
		return false;
	end

end

-- ===========================================================================    
function OnShow()

	Controls.WorldViewControls:SetHide( false );

end

-- ===========================================================================    
function OnOpenPlayerEditor()

	Controls.WorldBuilderPlayerEditor:SetHide( not Controls.WorldBuilderPlayerEditor:IsHidden() );

end

-- ===========================================================================
--	Init
-- ===========================================================================
function OnInit()

	-- Register for events
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetInputHandler( InputHandler, true );
	Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone );
	LuaEvents.WorldBuilderLaunchBar_OpenPlayerEditor.Add( OnOpenPlayerEditor );

end
ContextPtr:SetInitHandler( OnInit );