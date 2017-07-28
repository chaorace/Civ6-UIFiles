-- ===========================================================================
--	VARIABLES
-- ===========================================================================

-- ===========================================================================
function DiplomacySupport_GetMoodName( mood : number )

	return DiplomacyManager.GetKeyName( mood );

end

-- ===========================================================================
function DiplomacySupport_GetPlayerMood(pPlayer, localPlayerID)
	local pPlayerDiplomaticAI = pPlayer:GetDiplomaticAI();
	local iState : number = pPlayerDiplomaticAI:GetDiplomaticStateIndex(localPlayerID);

	-- Do not assume ordering of the database, so get the hash and compare the known values.
	local kStateEntry = GameInfo.DiplomaticStates[iState];
	local eState = kStateEntry.Hash;

	if (eState == DiplomaticStates.ALLIED or eState == DiplomaticStates.DECLARED_FRIEND) then 
		return DiplomacyMoodTypes.HAPPY;
	end

	if (eState == DiplomaticStates.FRIENDLY or eState == DiplomaticStates.NEUTRAL or eState == DiplomaticStates.UNFRIENDLY) then 
		return DiplomacyMoodTypes.NEUTRAL;
	end

	if (eState == DiplomaticStates.DENOUNCED or eState == DiplomaticStates.WAR) then 
		return DiplomacyMoodTypes.UNHAPPY;
	end

	return DiplomacyMoodTypes.NEUTRAL;
end

-- ===========================================================================
function DiplomacySupport_ParseStatementSelection( entry : table, kOutputTable : table )

	if (kOutputTable.Selections == nil) then
		kOutputTable.Selections = {};
	end

	table.insert( kOutputTable.Selections, entry );

end

-------------------------------------------------------------------------------
function GetStatementSelectionsFromQuery(handler : table, q, kOutputTable : table)

	local bFound = false;
	for i, row in ipairs(q) do
		handler.ParseStatementSelection(row, kOutputTable);
		bFound = true;
	end

	return bFound;
end

-------------------------------------------------------------------------------
function DiplomacySupport_ParseStatement( entry : table, kOutputTable : table )

	kOutputTable.StatementText = entry.StatementText;
	kOutputTable.LeaderAnimation = entry.LeaderAnimation;
	kOutputTable.SceneEffect = entry.SceneEffect;
	kOutputTable.DiplomaticActionType = entry.DiplomaticActionType;
	kOutputTable.ReasonText = entry.ReasonText;

end

-------------------------------------------------------------------------------
function GetStatementFromQuery(handler : table, q, fromLeaderName, fromLeaderMoodName, kOutputTable : table)
	local bFound = false;

	for i, row in ipairs(q) do

		handler.ParseStatement(row, kOutputTable);

		local q = DB.Query("SELECT Text, Tooltip, Key, Sort, DiplomaticActionType from DiplomacySelections WHERE Type = ? AND Leader = ? AND Mood = ?", row.Selections, fromLeaderName, fromLeaderMoodName );
		if (not GetStatementSelectionsFromQuery(handler, q, kOutputTable)) then
			q = DB.Query("SELECT Text, Tooltip, Key, Sort, DiplomaticActionType from DiplomacySelections WHERE Type = ? AND Leader = ? AND Mood = 'ANY'", row.Selections, fromLeaderName );
			if (not GetStatementSelectionsFromQuery(handler, q, kOutputTable)) then
				q = DB.Query("SELECT Text, Tooltip, Key, Sort, DiplomaticActionType from DiplomacySelections WHERE Type = ? AND Leader = 'ANY' AND Mood = ?", row.Selections, fromLeaderMoodName );
				if (not GetStatementSelectionsFromQuery(handler, q, kOutputTable)) then
					q = DB.Query("SELECT Text, Tooltip, Key, Sort, DiplomaticActionType from DiplomacySelections WHERE Type = ? AND Leader = 'ANY' AND Mood = 'ANY'", row.Selections );
					GetStatementSelectionsFromQuery(handler, q, kOutputTable);
				end
			end
		end

		bFound = true;
	end

	return bFound;
end


-------------------------------------------------------------------------------
function DiplomacySupport_ExtractStatement(handler : table, statementTypeName : string, statementSubTypeName : string, fromPlayerID : number, fromPlayerMood : number, initiator : number)

	local kOutputTable = {};

	local fromLeaderName = nil;
	if (fromPlayerID ~= nil) then
		fromLeaderName = PlayerConfigurations[ fromPlayerID ]:GetLeaderTypeName();
	end
	if (fromLeaderName == nil) then
		fromLeaderName	= "ANY";
	end

	local fromLeaderMoodName = nil;
	if (fromPlayerMood ~= nil) then
		fromLeaderMoodName = DiplomacySupport_GetMoodName( fromPlayerMood );
	end
	if (fromLeaderMoodName == nil) then
		fromLeaderMoodName = "ANY";
	end

	local initiatorName = nil;
	if (initiator ~= nil) then
		if (PlayerManager.IsValid(initiator)) then
			if ( PlayerConfigurations[ initiator ]:IsHuman() ) then
				initiatorName = "HUMAN";
			else
				initiatorName = "AI";
			end
		end
	end
	if (initiatorName == nil) then
		initiatorName = "HUMAN";
	end
	
	local q = DB.Query("SELECT StatementText, LeaderAnimation, Selections, SceneEffect, ReasonText from DiplomacyStatements WHERE Type = ? AND SubType = ? AND Initiator = ? AND Leader = ? AND Mood = ?", statementTypeName, statementSubTypeName, initiatorName, fromLeaderName, fromLeaderMoodName );
	if (not GetStatementFromQuery(handler, q, fromLeaderName, fromLeaderMoodName, kOutputTable)) then
		q = DB.Query("SELECT StatementText, LeaderAnimation, Selections, SceneEffect, ReasonText from DiplomacyStatements WHERE Type = ? AND SubType = ? AND Initiator = ? AND Leader = ? AND Mood = 'ANY'", statementTypeName, statementSubTypeName, initiatorName, fromLeaderName );
		if (not GetStatementFromQuery(handler, q, fromLeaderName, fromLeaderMoodName, kOutputTable)) then
			q = DB.Query("SELECT StatementText, LeaderAnimation, Selections, SceneEffect, ReasonText from DiplomacyStatements WHERE Type = ? AND SubType = ? AND Initiator = ? AND Leader = 'ANY' AND Mood = ?", statementTypeName, statementSubTypeName, initiatorName, fromLeaderMoodName );
			if (not GetStatementFromQuery(handler, q, fromLeaderName, fromLeaderMoodName, kOutputTable)) then
				q = DB.Query("SELECT StatementText, LeaderAnimation, Selections, SceneEffect, ReasonText from DiplomacyStatements WHERE Type = ? AND SubType = ? AND Initiator = ? AND Leader = 'ANY' AND Mood = 'ANY'", statementTypeName, statementSubTypeName, initiatorName );
				GetStatementFromQuery(handler, q, fromLeaderName, fromLeaderMoodName, kOutputTable);
			end
		end
	end

	if (kOutputTable.Selections ~= nil) then
		table.sort(kOutputTable.Selections, function(a,b) return a.Sort < b.Sort; end);
	end

	return kOutputTable;
end

-------------------------------------------------------------------------------
function DiplomacySupport_RemoveInvalidSelections(kParsedStatement : table, localPlayerID : number, otherPlayerID : number)

	-- Loop through the selections and remove any common choices that are not valid to choose at this time.
	if (kParsedStatement.Selections ~= nil) then
		local pLocalPlayer = Players[localPlayerID];
		if (pLocalPlayer ~= nil) then
			local i = 1;
			while (i <= #kParsedStatement.Selections) do
				local selection = kParsedStatement.Selections[i];
				local bValidAction = false;

				local tResults = nil;
				if (selection.DiplomaticActionType == nil) then
					bValidAction = true;
				else
					bValidAction, tResults = pLocalPlayer:GetDiplomacy():IsDiplomaticActionValid(selection.DiplomaticActionType, otherPlayerID, true);
				end

				if (not bValidAction) then
					if (tResults == nil or tResults.FailureReasons == nil) then
						table.remove(kParsedStatement.Selections, i);
					else
						-- We have 'reasons' for the action not being available that we want to tell the user about.
						kParsedStatement.Selections[i].IsDisabled = true;
						kParsedStatement.Selections[i].FailureReasons = tResults.FailureReasons;
						i = i + 1;
					end
				else
					i = i + 1;
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
function DiplomacySupport_RemoveSelectionByKey(kParsedStatement : table, removeKey : string)

	if (kParsedStatement.Selections ~= nil) then
		local i = 1;
		while (i <= #kParsedStatement.Selections) do
			local selection = kParsedStatement.Selections[i];

			if (selection.Key == removeKey) then
				table.remove(kParsedStatement.Selections, i);
			else
				i = i + 1;
			end
		end
	end
end
