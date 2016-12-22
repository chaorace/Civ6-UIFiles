-- ===========================================================================
--	World Builder Launch Bar
-- ===========================================================================

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

function OnOpenPlayerEditor()

	LuaEvents.WorldBuilderLaunchBar_OpenPlayerEditor();

end

-- ===========================================================================
--	Init
-- ===========================================================================
function OnInit()

	Controls.PlayerEditorButton:RegisterCallback( Mouse.eLClick, OnOpenPlayerEditor );

end
ContextPtr:SetInitHandler( OnInit );