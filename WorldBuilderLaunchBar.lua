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
function OnOpenMapEditor()

	LuaEvents.WorldBuilderLaunchBar_OpenMapEditor();

end

-- ===========================================================================
--	Init
-- ===========================================================================
function OnInit()

	Controls.PlayerEditorButton:RegisterCallback( Mouse.eLClick, OnOpenPlayerEditor );
	Controls.MapEditorButton:RegisterCallback( Mouse.eLClick, OnOpenMapEditor );

end
ContextPtr:SetInitHandler( OnInit );