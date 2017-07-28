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

local m_spy				:table = nil;
local m_city			:table = nil;
local m_operation		:table = nil;
local m_missionHistory	:table = nil;

-- Instance managers
local m_OutcomePercentIM	:table = InstanceManager:new("OutcomePercentInstance",	"Top",			Controls.OutcomeStack);
local m_OutcomeLabelIM		:table = InstanceManager:new("OutcomeLabelInstance",	"OutcomeLabel",	Controls.OutcomeStack);

-- Internal popup quque used when multiple popups of this type happen at the same time
local m_internalPopupQueue:table = {};

-- ===========================================================================
function Refresh()
	if m_operation then
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
	end

	-- Refresh Info Stack
	RefreshStack();
end

-- ===========================================================================
function RefreshStack()
	if m_spy and m_currentPopupState ~= EspionagePopupStates.MISSION_COMPLETED then
		-- Update Mission Objective
		Controls.MissionObjectiveLabel:SetText(GetFormattedOperationDetailText(m_operation, m_spy, m_city));
		Controls.MissionObjectiveContainer:SetHide(false);
		Controls.MissionOutcomeContainer:SetHide(true);
		Controls.MissionRewardsContainer:SetHide(true);
		Controls.MissionConsequencesContainer:SetHide(true);
	else
		-- Refresh Outcome if mission is completed
		RefreshMissionOutcome();
		Controls.MissionObjectiveContainer:SetHide(true);
		Controls.MissionOutcomeContainer:SetHide(false);
	end

	-- Get operation index
	local eOperation:number = GameInfo.UnitOperations[m_operation.Hash].Index;

	-- Update Mission Duration
	if m_currentPopupState == EspionagePopupStates.MISSION_BRIEFING then
		Controls.MissionDurationLabel:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_TURNS", UnitManager.GetTimeToComplete(eOperation, m_spy)));
		Controls.MissionDurationContainer:SetHide(false);
	elseif m_currentPopupState == EspionagePopupStates.ABORT_MISSION then
		local remainingTurns = m_spy:GetSpyOperationEndTurn() - Game.GetCurrentGameTurn();
		Controls.MissionDurationLabel:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_TURNS_REMAINING", remainingTurns));
		Controls.MissionDurationContainer:SetHide(false);
	elseif m_currentPopupState == EspionagePopupStates.MISSION_COMPLETED then
		Controls.MissionDurationContainer:SetHide(true);
	end

	if m_currentPopupState ~= EspionagePopupStates.MISSION_COMPLETED then
		RefreshPossibleOutcomes();
		Controls.PossibleOutcomesContainer:SetHide(false);
	else
		Controls.PossibleOutcomesContainer:SetHide(true);
	end

	-- Only show appropriate buttons
	if m_currentPopupState == EspionagePopupStates.MISSION_BRIEFING then
		Controls.AcceptButton:SetHide(false);
		Controls.AbortButton:SetHide(true);
		Controls.CancelButton:SetHide(false);
		Controls.MissionSucceedButton:SetHide(true)
		Controls.MissionFailureButton:SetHide(true);
	elseif m_currentPopupState == EspionagePopupStates.MISSION_BRIEFING then
		Controls.AcceptButton:SetHide(true);
		Controls.AbortButton:SetHide(false);
		Controls.CancelButton:SetHide(false);
		Controls.MissionSucceedButton:SetHide(true)
		Controls.MissionFailureButton:SetHide(true);
	else
		Controls.AcceptButton:SetHide(true);
		Controls.AbortButton:SetHide(true);
		Controls.CancelButton:SetHide(true);

		-- Show proper button depending on mission outcome
		local missionWasSuccess:boolean = false;
		if m_missionHistory then
			local outcomeDetails:table = GetMissionOutcomeDetails(m_missionHistory);
			if outcomeDetails and outcomeDetails.Success then
				missionWasSuccess = true;
			end
		end

		if missionWasSuccess then
			Controls.MissionSucceedButton:SetHide(false);
			Controls.MissionFailureButton:SetHide(true);		
		else
			Controls.MissionSucceedButton:SetHide(true);
			Controls.MissionFailureButton:SetHide(false);
		end
	end

	Controls.OutcomeStack:CalculateSize();
	Controls.OutcomeStack:ReprocessAnchoring();
	Controls.OperationInfoStack:ReprocessAnchoring();
end

-- ===========================================================================
function RefreshMissionOutcome()
	if m_missionHistory then
		local outcomeDetails:table = GetMissionOutcomeDetails(m_missionHistory);
		if outcomeDetails then
			if outcomeDetails.Success then
				Controls.MissionOutcomeLabel:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_SUCCESS"));
				Controls.MissionOutcomeIcon:SetIcon("ICON_CONSEQUENCE_SUCCESS");

				-- Show promotion reward
				Controls.SpyPromotionLabel:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_PROMOTIONREADY", Locale.ToUpper(GetSpyRankNameByLevel(m_missionHistory.LevelAfter))));
				Controls.SpyPromotionDescription:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_AGENTREADYFORPROMOTION", Locale.Lookup(m_missionHistory.Name)));
				
				-- Show loot reward
				local missionLootString:string = GetMissionLootString(m_missionHistory);
				if missionLootString ~= "" then
					Controls.SpyLootRewardLabel:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_LOOTREWARD_TITLE", missionLootString));
					Controls.SpyLootRewardDescription:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_LOOTREWARD_DESCRIPTION", missionLootString));
					Controls.SpyLootGrid:SetHide(false);
				else
					Controls.SpyLootGrid:SetHide(true);
				end

				Controls.MissionRewardsContainer:SetHide(false);
				Controls.MissionConsequencesContainer:SetHide(true);
			else
				Controls.MissionOutcomeLabel:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_FAILURE"));
				Controls.MissionOutcomeIcon:SetIcon("ICON_CONSEQUENCE_FAILURE");

				-- Show agent lost consequence if agent was captured or killed
				if m_missionHistory.InitialResult == EspionageResultTypes.KILLED or m_missionHistory.EscapeResult == EspionageResultTypes.KILLED then
					Controls.LostAgentIcon:SetIcon("ICON_CONSEQUENCE_SPY_LOST");
					Controls.LostAgentTitle:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_AGENT_KILLED_TITLE"));
					Controls.LostAgentDescription:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_AGENT_KILLED_DESC", Locale.Lookup(m_missionHistory.Name), Locale.Lookup(m_missionHistory.CityName)));
					Controls.LostAgentGrid:SetHide(false);
				elseif m_missionHistory.InitialResult == EspionageResultTypes.CAPTURED or m_missionHistory.EscapeResult == EspionageResultTypes.CAPTURED then
					Controls.LostAgentIcon:SetIcon("ICON_CONSEQUENCE_SPY_CAPTURED");
					Controls.LostAgentTitle:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_AGENT_CAPTURED_TITLE"));
					Controls.LostAgentDescription:SetText(Locale.Lookup("LOC_ESPIONAGEPOPUP_AGENT_CAPTURED_DESC", Locale.Lookup(m_missionHistory.Name), Locale.Lookup(m_missionHistory.CityName)));
					Controls.LostAgentGrid:SetHide(false);
				else
					Controls.LostAgentGrid:SetHide(true);
				end

				-- Don't show the relationship damaged box if we escaped undetected
				if (m_missionHistory.InitialResult == EspionageResultTypes.FAIL_MUST_ESCAPE and m_missionHistory.EscapeResult == EspionageResultTypes.FAIL_MUST_ESCAPE) or m_missionHistory.InitialResult == EspionageResultTypes.FAIL_UNDETECTED then
					Controls.MissionConsequencesContainer:SetHide(true);
				else
					Controls.MissionConsequencesContainer:SetHide(false);
				end

				Controls.MissionRewardsContainer:SetHide(true);
			end

			Controls.MissionOutcomeDescription:SetText(outcomeDetails.Description);
		end
	end

	Controls.MissionOutcomeContainer:ReprocessAnchoring();
end

-- ===========================================================================
function RefreshPossibleOutcomes()
	m_OutcomePercentIM:ResetInstances();
	m_OutcomeLabelIM:ResetInstances();

	if m_city == nil then
		return;
	end

	local cityPlot:table = Map.GetPlot(m_city:GetX(), m_city:GetY());
	local eOperation:number = GameInfo.UnitOperations[m_operation.Hash].Index;
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
	if Game.GetLocalPlayer() == -1 then
		return;
	end

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
function ShowMissionCompletedPopup(playerID:number, missionID:number)
	-- Find the mission in the mission history
	local mission:table = nil;
	local pPlayer:table = Players[playerID];
	if pPlayer then
		local pPlayerDiplomacy:table = pPlayer:GetDiplomacy();
		if pPlayerDiplomacy then
			mission = pPlayerDiplomacy:GetMission(playerID, missionID);
			if mission == 0 then
				UI.DataError("Unable to show misison completed popup for mission ID: " .. tostring(missionID));
				return
			end
		end
	end

	-- Clear spy reference since not needed for mission completed popup
	m_spy = nil;
	
	-- Clear city reference since not needed for mission completed popup
	m_city = nil;

	-- Cache mission history
	m_missionHistory = mission;
	
	-- Cache operation
	m_operation = GameInfo.UnitOperations[mission.Operation];

	m_currentPopupState = EspionagePopupStates.MISSION_COMPLETED;

	Open();
	UI.PlaySound("UI_Screen_Open");
end

-- ===========================================================================
function OnSpyMissionCompleted( playerID:number, missionID:number )
	local localPlayerID:number = Game.GetLocalPlayer();
	if localPlayerID == -1 or localPlayerID ~= playerID then
		return;
	end

	if UIManager:IsInPopupQueue( ContextPtr ) then
		-- If the popup is currently queue then save this popup to be shown later
		local queuedPopup:table = {};
		queuedPopup.PopupState = EspionagePopupStates.MISSION_COMPLETED;
		queuedPopup.PlayerID = playerID;
		queuedPopup.MissionID = missionID;

		table.insert(m_internalPopupQueue, queuedPopup);
	else
		-- Show popup immediately if this popup isn't queued
		ShowMissionCompletedPopup(playerID, missionID);
	end
end

-- ===========================================================================
function OnShowMissionAbort(spyID:number)
	if Game.GetLocalPlayer() == -1 then
		return;
	end

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
	if not ContextPtr:IsHidden() then
		UI.PlaySound("UI_Screen_Close");
	end

	-- Dequeue popup from UI mananger (will re-queue if another is about to show).
	UIManager:DequeuePopup( ContextPtr );

	-- Callback to chooser so it can unselect any selected mission
	LuaEvents.EspionagePopup_MissionBriefingClosed();

	-- Check if we have any popups queued internally and show those if necessary
	local queuedPopup:table = table.remove(m_internalPopupQueue);
	if queuedPopup then
		if queuedPopup.PopupState == EspionagePopupStates.MISSION_COMPLETED then
			ShowMissionCompletedPopup(queuedPopup.PlayerID, queuedPopup.MissionID);
		end
	end
end

-- ===========================================================================
function OnCancel()
	Close();
end

-- ===========================================================================
function OnMissionSucceedButton()
	Close();
end

-- ===========================================================================
function OnMissionFailureButton()
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
	Events.SpyMissionCompleted.Add( OnSpyMissionCompleted );

	-- Control Events
	Controls.AcceptButton:RegisterCallback( Mouse.eLClick, OnAccept );
	Controls.AcceptButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.AbortButton:RegisterCallback( Mouse.eLClick, OnAbort );
	Controls.AbortButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CancelButton:RegisterCallback( Mouse.eLClick, OnCancel );
	Controls.CancelButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.MissionSucceedButton:RegisterCallback( Mouse.eLClick, OnMissionSucceedButton );
	Controls.MissionSucceedButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.MissionFailureButton:RegisterCallback( Mouse.eLClick, OnMissionFailureButton );
	Controls.MissionFailureButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	-- Hot-Reload Events
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	ContextPtr:SetInputHandler( OnInputHandler, true );
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
end
Initialize();