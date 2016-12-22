------------------------------------------------------------------------------
--	Common LUA support functions for helping with user actions
------------------------------------------------------------------------------

-- ===========================================================================
function IsLocalPlayerTurnActive()
	local localPlayer = Game.GetLocalPlayer();
	if (localPlayer ~= -1) then
		local pPlayer = Players[localPlayer];
		if pPlayer ~= nil and pPlayer:IsTurnActive() then
			return true;
		end
	end
	return false;
end

-- ===========================================================================
function CanLocalPlayerSaveGame()
	if IsLocalPlayerTurnActive() or WorldBuilder:IsActive() then
		return true;
	end
	return false;
end

-- ===========================================================================
function CanLocalPlayerLoadGame()
	if IsLocalPlayerTurnActive() then
		return true;
	end
	return false;
end

