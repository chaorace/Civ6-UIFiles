-- ===========================================================================
--	Demo end-game screen.
-- ===========================================================================

-- ===========================================================================
function Close()
	UIManager:DequeuePopup( ContextPtr );
	LuaEvents.EndGameMenu_Closed();
	Events.ExitToMainMenu();
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnClose()
	Close();
end

function ShowStore()
    if (Steam ~= nil) then
	    Steam.ActivateGameOverlayToStore(289070);
    end
	-- Change to exit to main menu.
	Controls.MenuButton:LocalizeAndSetText("LOC_GAME_MENU_EXIT_TO_MAIN");
	
end

-- ===========================================================================
function ShowPopup()

	Controls.StackContents:CalculateSize();
	Controls.StackContents:ReprocessAnchoring();	

	UIManager:QueuePopup(ContextPtr, PopupPriority.Current );
	LuaEvents.EndGameMenu_Shown();
end

-- ===========================================================================
function OnPlayerDefeat( player, defeat)
	local localPlayer = Game.GetLocalPlayer();
	if (localPlayer >= 0) then		-- Check to see if there is any local player
		-- Was it the local player?
		if (localPlayer == player) then
			ShowPopup();
		end
	end
end

-- ===========================================================================
function OnTeamVictory( team, victory)
	local localPlayer = Game.GetLocalPlayer();

	if (localPlayer >= 0) then		-- Check to see if there is any local player
		ShowPopup();
	end
end

-- ===========================================================================
function Initialize()
	Controls.MenuButton:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.StoreButton:RegisterCallback(Mouse.eLClick, ShowStore);
	-- Let the Tutorial handle the victory/defeat.
	local ruleset = GameConfiguration.GetValue("RULESET");
	if(ruleset ~= "RULESET_TUTORIAL") then
		Events.TeamVictory.Add(OnTeamVictory);
		Events.PlayerDefeat.Add(OnPlayerDefeat);
	end
	Events.DemoTurnLimitReached.Add(ShowPopup);
end
Initialize();
