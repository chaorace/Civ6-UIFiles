-- Get idle Trade Units by Player ID
function GetIdleTradeUnits( playerID:number )
	local idleTradeUnits:table = {};

	-- Loop through the Players units
	local localPlayerUnits:table = Players[playerID]:GetUnits();
	for i,unit in localPlayerUnits:Members() do

		-- Find any trade units
		local unitInfo:table = GameInfo.Units[unit:GetUnitType()];
		if unitInfo.MakeTradeRoute then
			local doestradeUnitHasRoute:boolean = false;

			-- Determine if those trade units are busy by checking outgoing routes from the players cities
			local localPlayerCities:table = Players[playerID]:GetCities();
			for i,city in localPlayerCities:Members() do
				local routes = city:GetTrade():GetOutgoingRoutes();
				for i,route in ipairs(routes) do
					if route.TraderUnitID == unit:GetID() then
						doestradeUnitHasRoute = true;
					end
				end
			end

			-- If this trade unit isn't attached to an outgoing route then they are idle
			if not doestradeUnitHasRoute then
				table.insert(idleTradeUnits, unit);
			end
		end
	end

	return idleTradeUnits;
end