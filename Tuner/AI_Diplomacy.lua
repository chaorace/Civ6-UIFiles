GameEvents.DiploSurpriseDeclareWar.Add(function( mainPlayer, opponentPlayer )
--	local player = Players[mainPlayer];
--	if ( player ~= nil ) then
--		Print(player);
--		local ai = player:GetAi_Military();
--		Print(ai);
--		ai:PrepareForWarWith(opponentPlayer);
--		if ( ai:HasOperationAgainst( opponentPlayer, true ) ) then
--			return true;
--		end
--	end
	return false;
end );
