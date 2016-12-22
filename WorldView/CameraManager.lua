-- ===========================================================================
--	Camera Manager
--	Handles: Focusing the camera based on world events.
-- ===========================================================================

local LookAtCombatTypes = {}
LookAtCombatTypes.NONE			= 0;
LookAtCombatTypes.MOVE_TO		= 1;
LookAtCombatTypes.MOVE_AND_ZOOM = 2;

-------------------------------------------------------------------------------
function OnCombatVisBegin(combatMembers)
	
	if (GameConfiguration.IsNetworkMultiplayer()) then
		-- In network MP, don't move the camera, the game is essentially real-time MP and it is annoying to have the camera move around
		return;
	end

	local localObserverID = Game.GetLocalObserver();
	local attacker = combatMembers[1];
	local defender = combatMembers[2];
	if ( (attacker ~= nil and attacker.playerID == localObserverID) or
	     (defender ~= nil and defender.playerID == localObserverID) ) then

		 local isLocalTurn = false;
		 local cameraMoveStyle = LookAtCombatTypes.NONE;

		 -- The local observer owns own of the units.
		local pPlayer = Players[localObserverID];
		if ( pPlayer:IsTurnActive() ) then
			isLocalTurn = true;
			cameraMoveStyle = Options.GetUserOption("Gameplay", "LookAtPlayerTurnCombat");
		else
			cameraMoveStyle = Options.GetUserOption("Gameplay", "LookAtPlayerOffTurnCombat");
		end

		if (cameraMoveStyle == LookAtCombatTypes.MOVE_TO) then			
			UI.LookAtPlot(combatMembers.x, combatMembers.y);
		else
			if (cameraMoveStyle == LookAtCombatTypes.MOVE_AND_ZOOM) then			
				local prevZoom = UI.GetMapZoom();
				local zoom;
				if (isLocalTurn) then
					zoom = Options.GetUserOption("Gameplay", "LookAtPlayerTurnCombatZoomLevel");
				else
					zoom = Options.GetUserOption("Gameplay", "LookAtPlayerOffTurnCombatZoomLevel");
				end
				UI.LookAtPlot(combatMembers.x, combatMembers.y, zoom);
				UI.SetRestoreMapZoom(prevZoom);
			end
		end
	end
end
Events.CombatVisBegin.Add( OnCombatVisBegin );

-------------------------------------------------------------------------------
function OnCombatVisEnd(attacker)

	UI.RestoreMapZoom();

end
Events.CombatVisEnd.Add( OnCombatVisEnd );
