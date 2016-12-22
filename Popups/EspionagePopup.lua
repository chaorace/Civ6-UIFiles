-- ===========================================================================
-- Popup - Show mission briefings as well as when a mission is completed/failed
-- ===========================================================================
include("InstanceManager");
include("EspionageSupport");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID:string = "EspionagePopup"; -- Must be unique (usually the same as the file name)

local EspionagePopupStates:table = {
	MISSION_BRIEFING		= 0;
	ABORT_MISSION			= 1;
	MISSION_COMPLETED		= 2;
};

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_currentPopupState:number = -1;

local m_spy			:table = nil;
local m_city		:table = nil;
local m_operation	:table = nil;

-- Instance managers
local m_OutcomePercentIM	:table = InstanceManager:new("OutcomePercentInstance",	"Top",			Controls.OutcomeStack);
local m_OutcomeLabelIM		:table = InstanceManager:new("OutcomeLabelInstance",	"OutcomeLabel",	Controls.OutcomeStack);

-- ===========================================================================
function Refresh()
	if not m_operation or not m_spy or not m_city then
		return
	end

	-- Update Misison Title
	if m_currentPopupState == EspionagePopupStates.MISSION_BRIEFING then
		Controls.MissionTitle:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_MISSION_BRIEFING", Locale.ToUpper(m_operation.Description)));
	else
		Controls.MissionTitle:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_CURRENT_MISSION", Locale.ToUpper(m_operation.Description)));
	end

	-- Update Mission Icon
	local operationInfo:table = GameInfo.UnitOperations[m_operation.Hash];
	local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(operationInfo.Icon,200);
	Controls.MissionIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);

	-- Refresh Info Stack
	RefreshStack();
end

-- ===========================================================================
function RefreshStack()
	-- Update Mission Objective
	Controls.MissionObjectiveLabel:SetText(GetFormattedOperationDetailText(m_operation, m_spy, m_city));

	-- Get operation index
	local eOperation:number = GameInfo.UnitOperations[m_operation.Hash].Index;

	-- Update Mission Duration
	if m_currentPopupState == EspionagePopupStates.MISSION_BRIEFING then
		Controls.MissionDurationLabel:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_TURNS", UnitManager.GetTimeToComplete(eOperation, m_spy)));
	else
		local remainingTurns = m_spy:GetSpyOperationEndTurn() - Game.GetCurrentGameTurn();
		Controls.MissionDurationLabel:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_TURNS_REMAINING", remainingTurns));
	end

	-- Update Possible Outcomes
	m_OutcomePercentIM:ResetInstances();
	m_OutcomeLabelIM:ResetInstances();

	local cityPlot:table = Map.GetPlot(m_city:GetX(), m_city:GetY());
	local resultProbability:table = UnitManager.GetResultProbability(eOperation, m_spy, cityPlot);
	if resultProbability["ESPIONAGE_SUCCESS_UNDETECTED"] then
		local successProbability:number = resultProbability["ESPIONAGE_SUCCESS_UNDETECTED"];

		-- Add ESPIONAGE_SUCCESS_MUST_ESCAPE
		if resultProbability["ESPIONAGE_SUCCESS_MUST_ESCAPE"] then
			successProbability = successProbability + resultProbability["ESPIONAGE_SUCCESS_MUST_ESCAPE"];
		end

		-- Add intelligence report message
		AddOutcomeLabel("LOC_ESPIONAGEPOPUP_OUTCOME_DETAILS");

		-- Always show success chance
		--successProbability = math.floor(successProbability * 100);
		successProbability = math.floor((successProbability * 100)+0.5);
		AddOutcomePercent(successProbability, "LOC_ESPIONAGEPOPUP_SUCCESS_OUTCOME_CHANCE");

		if successProbability < 100 then -- When less than 100% success chance show other probabilities
			-- Add failure probability
			local failureProbability:number = 0;
			if resultProbability["ESPIONAGE_FAIL_UNDETECTED"] then
				failureProbability = failureProbability + resultProbability["ESPIONAGE_FAIL_UNDETECTED"];
			end
			if resultProbability["ESPIONAGE_FAIL_MUST_ESCAPE"] then
				failureProbability = failureProbability + resultProbability["ESPIONAGE_FAIL_MUST_ESCAPE"];
			end
			if failureProbability > 0 then
				failureProbability = math.floor((failureProbability * 100)+0.5);
				AddOutcomePercent(failureProbability, "LOC_ESPIONAGEPOPUP_FAILURE_OUTCOME_CHANCE");
			end

			-- Add captured or killed probability
			local capturedOrKilledProbability:number = 100 - successProbability - failureProbability;
			if capturedOrKilledProbability > 0 then
				AddOutcomePercent(capturedOrKilledProbability, "LOC_ESPIONAGEPOPUP_CAPTUREDORKILLED_OUTCOME_CHANCE");
			end

			-- Add discovered warning for city owner
			local targetPlayerConfiguration = PlayerConfigurations[m_city:GetOwner()];
			AddOutcomeLabel(Locale.Lookup("LOC_ESPIONAGEPOPUP_DISCOVERED_WARNING", targetPlayerConfiguration:GetPlayerName()));
		end
	end

	-- Only show appropriate buttons
	if m_currentPopupState == EspionagePopupStates.MISSION_BRIEFING then
		Controls.AcceptButton:SetHide(false);
		Controls.AbortButton:SetHide(true);
	else
		Controls.AcceptButton:SetHide(true);
		Controls.AbortButton:SetHide(false);
	end

	Controls.OutcomeStack:CalculateSize();
	Controls.OutcomeStack:ReprocessAnchoring();
end

-- ===========================================================================
function AddOutcomePercent(percent:number, percentLabel:string)
	local outcomePercentInstance:table = m_OutcomePercentIM:GetInstance();
	outcomePercentInstance.OutcomePercentNumber:SetText(percent);
	outcomePercentInstance.OutcomePercentLabel:SetText(Locale.Lookup(percentLabel));
end

-- ===========================================================================
function AddOutcomeLabel(labelString:string)
	local outcomeLabelInstance:table = m_OutcomeLabelIM:GetInstance();
	outcomeLabelInstance.OutcomeLabel:SetText(Locale.Lookup(labelString));
end

-- ===========================================================================
function OnShowMissionBriefing(operationHash:number, spyID:number)
	-- Cache spy unit
	local localPlayer:table = Players[Game.GetLocalPlayer()];
	local playerUnits:table = localPlayer:GetUnits();
	m_spy = playerUnits:FindID(spyID);
	
	-- Cache operation
	m_operation = GameInfo.UnitOperations[operationHash];

	-- Find target city
	local spyPlot:table = Map.GetPlot(m_spy:GetX(), m_spy:GetY());
	m_city = Cities.GetPlotPurchaseCity(spyPlot);

	m_currentPopupState = EspionagePopupStates.MISSION_BRIEFING;

	Open();
	UI.PlaySound("UI_Screen_Open");
end

-- ===========================================================================
function OnShowMissionAbort(spyID:number)
	-- Cache spy unit
	local localPlayer:table = Players[Game.GetLocalPlayer()];
	local playerUnits:table = localPlayer:GetUnits();
	m_spy = playerUnits:FindID(spyID);

	-- Cache operation
	m_operation = GameInfo.UnitOperations[m_spy:GetSpyOperation()];

	-- If we're counterspying or running a listening post just instancly cancel the mission without a popup
	if m_operation.OperationType == "UNITOPERATION_SPY_COUNTERSPY" or m_operation.OperationType == "UNITOPERATION_SPY_LISTENING_POST" then
		OnAbort();
		return;
	end

	-- Find target city
	local spyPlot:table = Map.GetPlot(m_spy:GetX(), m_spy:GetY());
	m_city = Cities.GetPlotPurchaseCity(spyPlot);

	m_currentPopupState = EspionagePopupStates.ABORT_MISSION;

	Open();
	UI.PlaySound("UI_Screen_Open");
end

-- ===========================================================================
function OnAccept()
	if m_spy and m_operation then
		UnitManager.RequestOperation(m_spy, m_operation.Hash);
		Close();
		UI.PlaySound("UI_Spy_Mission_Accepted");
	end
end

-- ===========================================================================
function OnAbort()
	if m_spy then
		UnitManager.RequestCommand( m_spy, UnitCommandTypes.CANCEL );

		Close();
	end
end

-- ===========================================================================
function Open()
	-- Queue Popup
	UIManager:QueuePopup( ContextPtr, PopupPriority.Current);

	Refresh();
end

-- ===========================================================================
function Close()
	-- Dequeue popup from UI mananger (will re-queue if another is about to show).
	UIManager:DequeuePopup( ContextPtr );

	-- Callback to chooser so it can unselect any selected mission
	LuaEvents.EspionagePopup_MissionBriefingClosed();
	UI.PlaySound("UI_Screen_Close");
end

-- ===========================================================================
function OnCancel()
	Close();
end

------------------------------------------------------------------------------------------------
function OnLocalPlayerTurnEnd()
	if(GameConfiguration.IsHotseat()) then
		Close();
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "spy", m_spy);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "city", m_city);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "operation", m_operation);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "popupState", m_currentPopupState);
end

-- ===========================================================================
--	LUA EVENT
--	Reload support
-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then
		if contextTable["popupState"] ~= nil then			
			m_currentPopupState = contextTable["popupState"];
		end
		if contextTable["spy"] ~= nil then			
			m_spy = contextTable["spy"];
		end
		if contextTable["city"] ~= nil then			
			m_city = contextTable["city"];
		end
		if contextTable["operation"] ~= nil then			
			m_operation = contextTable["operation"];
		end

		Refresh();
	end
end

-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg:number = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then 
		if pInputStruct:GetKey() == Keys.VK_ESCAPE then
			Close();
			return true;
		end
	end

	return false;
end

-- ===========================================================================
--	INIT
-- ===========================================================================
function Initialize()
	-- Lua Events
	LuaEvents.EspionageChooser_ShowMissionBriefing.Add( OnShowMissionBriefing );
	LuaEvents.UnitPanel_CancelMission.Add( OnShowMissionAbort );

	-- Game Engine Events
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );

	-- Control Events
	Controls.AcceptButton:RegisterCallback( Mouse.eLClick, OnAccept );
	Controls.AcceptButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.AbortButton:RegisterCallback( Mouse.eLClick, OnAbort );
	Controls.AbortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CancelButton:RegisterCallback( Mouse.eLClick, OnCancel );
	Controls.CancelButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	-- Hot-Reload Events
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	ContextPtr:SetInputHandler( OnInputHandler, true );
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
end
Initialize();