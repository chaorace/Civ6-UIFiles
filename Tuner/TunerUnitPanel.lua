g_PanelHasFocus = false;
g_SelectedPlayer = -1;
g_SelectedUnitID = -1;

-------------------------------------------------------------------------------
function GetSelectedUnit()
	if (g_SelectedPlayer >= 0 and g_SelectedUnitID >= 0) then
		local pPlayer = Players[g_SelectedPlayer];
		if pPlayer ~= nil then
			pUnit = pPlayer:GetUnits():FindID(g_SelectedUnitID);
			return pUnit;
		end
	end
	return nil;
end

-------------------------------------------------------------------------------
function GetSelectedPlayer()
	if (g_SelectedPlayer >= 0) then
		local pPlayer = Players[g_SelectedPlayer];
		return pPlayer;
	end
	return nil;
end
