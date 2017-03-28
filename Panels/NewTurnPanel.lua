----------------------------------------------------------------------------
-- Ingame Turn Order Panel
----------------------------------------------------------------------------

----------------------------------------------------------------------------
-- Globals


----------------------------------------------------------------------------
-- Event Handlers
function ShowNewTurnPanel()
	local endTurn = Game.GetGameEndTurn();
	local currentTurn = Game.GetCurrentGameTurn();
	-- Turns remaining is shifted by 1 so that 0 Turns Remaining is shown on the last actionable turn prior to the turn limit.
	local turnsRemaining = endTurn - currentTurn - 1; 

	-- Show Turns Remaining Reminder if we're getting close to the end of a turn limited game.
	if(endTurn ~= 0 -- game has a turn limit
		and turnsRemaining >= 0 -- Not past turn limit (one more turn mode)
		and (turnsRemaining == 10 or turnsRemaining <= 5)) then
		Controls.NewTurnLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_TURNS_REMAINING_VAL", turnsRemaining)));
		Controls.Root:SetHide(false);
		RestartAnimations();
	else
		Controls.Root:SetHide(true);
	end
end

----------------------------------------------------------------------------
-- Restart all the animations
function RestartAnimations()
	Controls.AlphaIn:SetToBeginning();
	Controls.SlideIn:SetToBeginning();
	Controls.AlphaOut:SetToBeginning();
	Controls.SlideOut:SetToBeginning();
	Controls.AlphaIn:Play();
	Controls.SlideIn:Play();
	Controls.AlphaOut:Play();
	Controls.SlideOut:Play();
end

----------------------------------------------------------------------------
-- Initialization
function Initialize()
	Events.LocalPlayerTurnBegin.Add(ShowNewTurnPanel);
	Events.PhaseBegin.Add(ShowNewTurnPanel); 
end
Initialize();
