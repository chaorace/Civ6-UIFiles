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
	Steam.ActivateGameOverlayToStore();
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
function OnPlayerVictory( player, victory)
	local localPlayer = Game.GetLocalPlayer();

	if (localPlayer >= 0) then		-- Check to see if there is any local player
		ShowPopup();
	end
end

-- ===========================================================================
function Initialize()
	Controls.MenuButton:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.StoreButton:RegisterCallback(Mouse.eLClick, ShowStore);
	Events.PlayerDefeat.Add(OnPlayerDefeat);
	Events.PlayerVictory.Add(OnPlayerVictory);
end
Initialize();