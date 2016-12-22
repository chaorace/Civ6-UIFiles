-- ===========================================================================
function GetFormattedOperationDetailText(operation:table, spy:table, city:table)
	local outputString:string = "";
	local eOperation:number = GameInfo.UnitOperations[operation.Hash].Index;
	local sOperationDetails:string = UnitManager.GetOperationDetailText(eOperation, spy, Map.GetPlot(city:GetX(), city:GetY()));
	if operation.OperationType == "UNITOPERATION_SPY_GREAT_WORK_HEIST" then
		outputString = Locale.Lookup("LOC_SPYMISSIONDETAILS_UNITOPERATION_SPY_GREAT_WORK_HEIST", Locale.Lookup(sOperationDetails));
	elseif operation.OperationType == "UNITOPERATION_SPY_SIPHON_FUNDS" then
		outputString = Locale.Lookup("LOC_SPYMISSIONDETAILS_UNITOPERATION_SPY_SIPHON_FUNDS", Locale.ToUpper(city:GetName()), sOperationDetails);
	elseif sOperationDetails ~= "" then
		outputString = sOperationDetails;
	else
		-- Find the loc string by OperationType if this operation doesn't use GetOperationDetailText
		outputString = Locale.Lookup("LOC_SPYMISSIONDETAILS_" .. operation.OperationType);
	end

	return outputString;
end

-- ===========================================================================
function GetSpyRankNameByLevel(level:number)
	local spyRankName:string = "";

	if (level == 4) then
		spyRankName = "LOC_ESPIONAGE_LEVEL_4_NAME";
	elseif (level == 3) then
		spyRankName = "LOC_ESPIONAGE_LEVEL_3_NAME";
	elseif (level == 2) then
		spyRankName = "LOC_ESPIONAGE_LEVEL_2_NAME";
	else
		spyRankName = "LOC_ESPIONAGE_LEVEL_1_NAME";
	end

	return spyRankName;
end