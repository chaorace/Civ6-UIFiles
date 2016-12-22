-- ===========================================================================
--	Code to support various debugging operations, primarily the placement 
--	functionality of the Tuner's Map Panel.  
--	Most of the code consists of capturing the user input and relaying it to 
--	the Tuner's Lua  state through LuaEvents.
-- ===========================================================================

-- ===========================================================================
function DebugPlacement( plotID:number, edge )
    local plot = Map.GetPlotByIndex(plotID);

	local normalizedX, normalizedY = UIManager:GetNormalizedMousePos();
	worldX, worldY, worldZ = UI.GetWorldFromNormalizedScreenPos(normalizedX, normalizedY);

	-- Communicate this to the TunerMapPanel handler
	LuaEvents.TunerMapLButtonUp(plot:GetX(), plot:GetY(), worldX, worldY, worldZ, edge);

	return true;
end

-- ===========================================================================
function OnTunerExitDebugMode()
	if (UI.GetInterfaceMode() == InterfaceModeTypes.DEBUG) then
		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
	end
	-- Send an acknowldgement
	LuaEvents.UIDebugModeExited();
end

-- ===========================================================================
function OnTunerEnterDebugMode()
	if (UI.GetInterfaceMode() ~= InterfaceModeTypes.DEBUG) then
		UI.SetInterfaceMode(InterfaceModeTypes.DEBUG);
	end
	-- Send an acknowldgement
	LuaEvents.UIDebugModeEntered();
end

-- ===========================================================================
--	File init...
-- ===========================================================================
LuaEvents.TunerExitDebugMode.Add(OnTunerExitDebugMode);
LuaEvents.TunerEnterDebugMode.Add(OnTunerEnterDebugMode);
