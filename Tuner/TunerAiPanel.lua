g_PanelHasFocus = false;
g_DangerThreshold = 1;
g_SelectedPlayer = -1;

-------------------------------------------------------------------------------
function GetSelectedPlayer()
	if (g_SelectedPlayer >= 0) then
		local pPlayer = Players[g_SelectedPlayer];
		return pPlayer;
	end
	return nil;
end

function ShowSelectedThreat()
	if ( g_SelectedPlayer >= 0 ) then
		UILens.ClearLayerHexes(PlotHighlightTypes.PLACEMENT);
		local player = Players[ g_SelectedPlayer ];
		if ( player ~= nil ) then
			local influenceMap = player:GetInfluenceMap();
			local threatenedSpots = {};
			for plotIndex = 0, Map.GetPlotCount()-1, 1 do
				if ( influenceMap.Find( plotIndex ) >= g_DangerThreshold ) then
					table.insert( threatenedSpots, plotIndex );
				end
			end
			UILens.SetLayerHexes(PlotHighlightTypes.PLACEMENT, player, threatenedSpots);
		end
	end
end
