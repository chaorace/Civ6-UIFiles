-------------------------------------------------------------------------------
-- Manager functions to display narration events for an automated game
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function CanSeePlot(x, y)

	local pPlayerVis = PlayerVisibilityManager.GetPlayerVisibility(Game.GetLocalObserver());
	if (pPlayerVis ~= nil) then
		return pPlayerVis:IsVisible(x, y);
	end

	return false;
end	

-------------------------------------------------------------------------------
-- Is the event enabled, this will return true if all events are force to enabled.
function IsEventEnabled(eventName)

	if (Automation.GetSetParameter("CurrentTest", eventName, false) or
		Automation.GetSetParameter("CurrentTest", "NarrationEvent_All", false)) then
		return true;
	end
	return false;
end

-------------------------------------------------------------------------------
-- Send a narration message that involves a single player
function SendPlayerNarrationMessage(messageText, player)
	local pPlayerConfig = PlayerConfigurations[player];
	if (pPlayerConfig ~= nil) then
		local tMessage = {};
		tMessage.Message = Locale.Lookup(messageText, pPlayerConfig:GetCivilizationShortDescription());
		tMessage.ShowPortrait = true;

		LuaEvents.Automation_AddToNarrationQueue( tMessage );
	end
end

-------------------------------------------------------------------------------
-- Send a narration message that involves two players
function SendPlayerPlayerNarrationMessage(messageText, player1, player2)
	local pPlayer1Config = PlayerConfigurations[player1];
	local pPlayer2Config = PlayerConfigurations[player2];
	if (pPlayer1Config ~= nil and pPlayer2Config ~= nil) then
		local tMessage = {};
		tMessage.Message = Locale.Lookup(messageText, pPlayer1Config:GetCivilizationShortDescription(), pPlayer2Config:GetCivilizationShortDescription());
		tMessage.ShowPortrait = true;

		LuaEvents.Automation_AddToNarrationQueue( tMessage );
	end
end

-------------------------------------------------------------------------------
function OnWonderCompleted(x, y)

	if (IsEventEnabled("NarrationEvent_WonderCompleted")) then

		if (CanSeePlot(x, y)) then
			local plot = Map.GetPlot(x, y);
			if (plot ~= nil) then
				SendPlayerNarrationMessage("LOC_AUTONARRATE_WONDER_COMPLETED_BY", plot:GetOwner());
			end
		end
	end
end

-------------------------------------------------------------------------------
function OnDiplomacyDeclareWar(player1, player2)

	if (IsEventEnabled("NarrationEvent_DeclareWar")) then
		SendPlayerPlayerNarrationMessage("LOC_AUTONARRATE_DECLARE_WAR", player1, player2);
	end

end

-------------------------------------------------------------------------------
function OnDiplomacyMakePeace(player1, player2)

	if (IsEventEnabled("NarrationEvent_MakePeace")) then
		SendPlayerPlayerNarrationMessage("LOC_AUTONARRATE_MAKE_PEACE", player1, player2);
	end

end

-------------------------------------------------------------------------------
function OnDiplomacyRelationshipChanged(player1, player2)

end

-------------------------------------------------------------------------------
function OnPlayerDefeat(player1, player2)

	if (IsEventEnabled("NarrationEvent_PlayerDefeated")) then

		if (PlayerManager.IsValid(player2)) then
			-- Specifically defeated by another player
			SendPlayerPlayerNarrationMessage("LOC_AUTONARRATE_PLAYER_DEFEATED_BY", player1, player2);
		else
			SendPlayerNarrationMessage("LOC_AUTONARRATE_PLAYER_DEFEATED", player1);
		end
	end

end

-------------------------------------------------------------------------------
function OnTeamVictory(team, victoryType)

	if (IsEventEnabled("NarrationEvent_TeamVictory")) then

		local victoryDef = GameInfo.Victories[victoryType];
		if (victoryDef ~= nil) then
			-- Have specific victory text?
			local textKey = "LOC_AUTONARRATE_PLAYER_" .. victoryDef.VictoryType;
			if (not Locale.HasTextKey(textKey)) then
				-- Show generic text
				textKey = "LOC_AUTONARRATE_PLAYER_VICTORY";
			end

			local bPauseOnVictory = Automation.GetSetParameter("CurrentTest", "NarrationPauseOnVictory", false);
			local tMessage = {};
			tMessage.Message = Locale.Lookup(textKey, GameConfiguration.GetTeamName(team));
			if (bPauseOnVictory) then
				-- Show a "done" button
				tMessage.Button1Text = Locale.Lookup("LOC_AUTONARRATE_BUTTON_DONE");
				-- Stop the test 
				tMessage.Button1Func = function() 
					Automation.Pause(false);
					AutoplayManager.SetActive(false);	-- Stop the autoplay
				end 
			end

			tMessage.ShowPortrait = true;

			LuaEvents.Automation_AddToNarrationQueue( tMessage );

			if (bPauseOnVictory) then
				Automation.Pause(true);
			end
			
		end
	end

end

-------------------------------------------------------------------------------
function OnPlayerEraChanged(player, era)

	if (IsEventEnabled("NarrationEvent_PlayerEraChanged")) then

		local eraDef = GameInfo.Eras[era];
		if (eraDef ~= nil) then
			if (eraDef.Hash ~= GameConfiguration.GetStartEra()) then
				-- Have specific era text?
				local textKey = "LOC_AUTONARRATE_PLAYER_" .. eraDef.EraType;
				if (Locale.HasTextKey(textKey)) then
					SendPlayerNarrationMessage(textKey, player);
				else
					-- Show generic text
					SendPlayerNarrationMessage("LOC_AUTONARRATE_PLAYER_ERA_CHANGED", player);
				end
			end
		end
	end

end

-------------------------------------------------------------------------------
function OnCityOccupationChanged(player, cityID)

end

-------------------------------------------------------------------------------
function OnSpyMissionUpdated()

end

-------------------------------------------------------------------------------
function OnUnitActivate(owner, unitID, x, y, eReason, bVisibleToLocalPlayer)

	if (IsEventEnabled("NarrationEvent_CityFounded")) then

		if (bVisibleToLocalPlayer) then
			if (eReason == EventSubTypes.FOUND_CITY) then
				SendPlayerNarrationMessage("LOC_AUTONARRATE_CITY_FOUNDED", owner);
			end
		end
	end
end

-- ===========================================================================
function KeyHandler( key:number )
	if key == Keys.VK_SPACE then
		Automation.Pause( not Automation.IsPaused() );
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

-------------------------------------------------------------------------------
function Initialize()

	Events.WonderCompleted.Add( OnWonderCompleted );
	Events.DiplomacyDeclareWar.Add( OnDiplomacyDeclareWar );
	Events.DiplomacyMakePeace.Add( OnDiplomacyMakePeace );	
	Events.DiplomacyRelationshipChanged.Add( OnDiplomacyRelationshipChanged );	
	Events.PlayerDefeat.Add( OnPlayerDefeat );	
	Events.PlayerEraChanged.Add( OnPlayerEraChanged );	
	Events.TeamVictory.Add( OnTeamVictory );
	Events.CityOccupationChanged.Add( OnCityOccupationChanged );	
	Events.SpyMissionUpdated.Add( OnSpyMissionUpdated );			
	Events.UnitActivate.Add( OnUnitActivate );

	Automation.SetInputHandler( OnInputHandler );

end

-------------------------------------------------------------------------------
function Uninitialize()

	Automation.RemoveInputHandler( OnInputHandler );

end
-------------------------------------------------------------------------------
function OnAutomationGameStarted()
	Initialize();
end

LuaEvents.AutomationGameStarted.Add( OnAutomationGameStarted );

-------------------------------------------------------------------------------
function OnAutomationGameEnded()
	Uninitialize();
end
LuaEvents.AutomationGameEnded.Add( OnAutomationGameEnded );
