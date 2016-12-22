-- ===========================================================================
-- Shared code to get the tool tip for the local player's gold.
--
-- May want to merge this with ToolTipHelper, though it that file is quite large
-- and the files that currently need the yields tool tip don't require all that
-- extra baggge.
-- ===========================================================================

-- ===========================================================================
function GetExtendedGoldTooltip()
	local szReturnValue = "";

	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID ~= -1) then
		local playerTreasury:table	= Players[localPlayerID]:GetTreasury();
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_NET", playerTreasury:GetGoldYield() - playerTreasury:GetTotalMaintenance());
		szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_GROSS", playerTreasury:GetGoldYield());
		szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_COSTS", playerTreasury:GetTotalMaintenance());
		szReturnValue = szReturnValue .. "[NEWLINE]  ";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_COSTS_BUILDINGS", playerTreasury:GetBuildingMaintenance());
		szReturnValue = szReturnValue .. "[NEWLINE]  ";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_COSTS_DISTRICTS", playerTreasury:GetDistrictMaintenance());
		szReturnValue = szReturnValue .. "[NEWLINE]  ";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_COSTS_UNITS", playerTreasury:GetUnitMaintenance());
		szReturnValue = szReturnValue .. "[NEWLINE]  ";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_COSTS_WMDS", playerTreasury:GetWMDMaintenance());
		szReturnValue = szReturnValue .. "[NEWLINE]  ";
		local inferredSiphonFundsAmount = playerTreasury:GetTotalMaintenance() - playerTreasury:GetBuildingMaintenance() - playerTreasury:GetDistrictMaintenance() - playerTreasury:GetUnitMaintenance() - playerTreasury:GetWMDMaintenance();
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_COSTS_HOSTILE_SPIES", inferredSiphonFundsAmount);
	end
	return szReturnValue;
end

-- ===========================================================================
function GetGoldTooltip()
	local szReturnValue = "";

	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID ~= -1) then
		local playerTreasury:table	= Players[localPlayerID]:GetTreasury();

		local income_tt_details = playerTreasury:GetGoldYieldToolTip();
		local expense_tt_details = playerTreasury:GetTotalMaintenanceToolTip();

		szReturnValue = Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD");
		szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_INCOME", playerTreasury:GetGoldYield());
		if(#income_tt_details > 0) then
			szReturnValue = szReturnValue .. "[NEWLINE]" .. income_tt_details;
		end

		szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_EXPENSE", -playerTreasury:GetTotalMaintenance());
		if(#expense_tt_details > 0) then
			szReturnValue = szReturnValue .. "[NEWLINE]" .. expense_tt_details;
		end
	end
	return szReturnValue;
end

-- ===========================================================================
function GetScienceTooltip()
	local szReturnValue = "";

	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID ~= -1) then
		local playerTechnology		:table	= Players[localPlayerID]:GetTechs();
		local currentScienceYield	:number = playerTechnology:GetScienceYield();

		szReturnValue = Locale.Lookup("LOC_TOP_PANEL_SCIENCE_YIELD");
		local science_tt_details = playerTechnology:GetScienceYieldToolTip();
		if(#science_tt_details > 0) then
			szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]" .. science_tt_details;
		end
	end
	return szReturnValue;
end

-- ===========================================================================
function GetCultureTooltip()
	local szReturnValue = "";

	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID ~= -1) then
		local playerCulture			:table	= Players[localPlayerID]:GetCulture();
		local currentCultureYield	:number = playerCulture:GetCultureYield();

		szReturnValue = Locale.Lookup("LOC_TOP_PANEL_CULTURE_YIELD");
		local culture_tt_details = playerCulture:GetCultureYieldToolTip();
		if(#culture_tt_details > 0) then
			szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]" .. culture_tt_details;
		end
	end
	return szReturnValue;
end

-- ===========================================================================
function GetFaithTooltip()
	local szReturnValue = "";

	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID ~= -1) then
		local playerReligion		:table	= Players[localPlayerID]:GetReligion();
		local faithYield			:number = playerReligion:GetFaithYield();
		local faithBalance			:number = playerReligion:GetFaithBalance();

		szReturnValue = Locale.Lookup("LOC_TOP_PANEL_FAITH_YIELD");
		local faith_tt_details = playerReligion:GetFaithYieldToolTip();
		if(#faith_tt_details > 0) then
			szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]" .. faith_tt_details;
		end
	end
	return szReturnValue;
end
