------------------------------------------------------------------------------------------------
-- CITY-STATES POPUP
------------------------------------------------------------------------------------------------

include("InstanceManager");
include("SupportFunctions");

local g_CityStateInstanceManager = InstanceManager:new( "CityStateInstance", "CityStateBase", Controls.CityStateStack);

local declareWarStr : string = Locale.Lookup("LOC_DECLARE_WAR_BUTTON");
local makePeaceStr : string = Locale.Lookup("LOC_MAKE_PEACE_BUTTON");
local envoysStr : string = "Sending Envoys will award bonuses. These bonuses will be disabled when you are at war with the City-State, or if the City-State is destroyed.";
local highlightPlayerColor : number = 0xffffffff;
local normalPlayerColor : number = 0xff555555;

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function RefreshDisplay(highlightPlayerID:number)

	g_CityStateInstanceManager:ResetInstances();

	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	if (pLocalPlayer == nil) then
		return;
	end
	local bCanGiveInfluence = false;
	local pLocalPlayerInfluence:table = pLocalPlayer:GetInfluence();
	if (pLocalPlayerInfluence ~= nil) then
		if (pLocalPlayerInfluence:CanGiveInfluence() and pLocalPlayerInfluence:GetTokensToGive() > 0) then
			bCanGiveInfluence = true;
		end
	end

	local iTurnsOfPeace = GameInfo.GlobalParameters["DIPLOMACY_PEACE_MIN_TURNS"].Value;
	local iTurnsOfWar = GameInfo.GlobalParameters["DIPLOMACY_WAR_MIN_TURNS"].Value;

	-- SCREEN TITLE
	local szHeaderString = "City-State Relations for " .. Locale.Lookup(PlayerConfigurations[pLocalPlayer:GetID()]:GetCivilizationShortDescription());
	Controls.MainHeader:SetText(szHeaderString);

	-- POINTS INFO
	local szPointsString = "";
	if (pLocalPlayerInfluence ~= nil) then
		local pointsEarned:number = Round(pLocalPlayerInfluence:GetPointsEarned(), 1);
		local pointsPerTurn:number = Round(pLocalPlayerInfluence:GetPointsPerTurn(), 1);
		local pointsThreshold:number = pLocalPlayerInfluence:GetPointsThreshold();
		local tokensPerThreshold:number = pLocalPlayerInfluence:GetTokensPerThreshold();
		local tokensToGive:number = pLocalPlayerInfluence:GetTokensToGive();
		szPointsString = szPointsString .. tokensToGive .. " Envoy(s) Available";
		szPointsString = szPointsString .. "[NEWLINE]" .. pointsEarned .. " / " .. pointsThreshold .. " Influence Points towards earning another " .. tokensPerThreshold .. " Envoy(s)";
		szPointsString = szPointsString .. "[NEWLINE]+" .. pointsPerTurn .. " Influence Points per turn from Government";
	end
	Controls.PointsLabel:SetText(szPointsString);

	-- HEADER ENTRY
	local headerInstance = g_CityStateInstanceManager:GetInstance();
	headerInstance.NameLabel:SetText("City-State");
	headerInstance.TypeLabel:SetText("Type");
	headerInstance.QuestsLabel:SetText("Quests");
	headerInstance.CurrentTokensLabel:SetText("Envoys Sent");
	headerInstance.CurrentTokensLabel:SetToolTipString(envoysStr);
	headerInstance.TypeBonusLabel:SetText("Type Bonuses");
	headerInstance.TypeBonusLabel:SetToolTipString(envoysStr);
	headerInstance.UniqueBonusLabel:SetText("Suzerain Bonus");
	headerInstance.UniqueBonusLabel:SetToolTipString(envoysStr);
	headerInstance.CityStateBase:SetDisabled(true);
	headerInstance.LevyMilitaryButton:SetHide(true);
	headerInstance.ChangeWarStateButton:SetHide(true);
	headerInstance.GiveTokenButton:SetHide(true);

	for iI = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local pPlayer = Players[iI];
		local bAlive = pPlayer:IsAlive();
		local bCanReceiveInfluence = false;
		local pPlayerInfluence:table = pPlayer:GetInfluence();
		if (pPlayerInfluence ~= nil) then
			bCanReceiveInfluence = pPlayerInfluence:CanReceiveInfluence();
		end

		if (iI ~= pLocalPlayer:GetID() and bAlive and bCanReceiveInfluence) then

			local cityStateInstance = g_CityStateInstanceManager:GetInstance();
		
			-- Get Info on relationship with this player
			local iPlayer = pPlayer:GetID();
			local bHasMet = pLocalPlayer:GetDiplomacy():HasMet(iI);
			local bIsAtWarWith = pLocalPlayer:GetDiplomacy():IsAtWarWith(iI); 
			local bCanDeclareWarOn = pLocalPlayer:GetDiplomacy():CanDeclareWarOn(iI);
			local bCanMakePeaceWith = pLocalPlayer:GetDiplomacy():CanMakePeaceWith(iI);
			local iTurnChanged = pLocalPlayer:GetDiplomacy():GetAtWarChangeTurn(iI);
			local iVisibility = pLocalPlayer:GetDiplomacy():GetVisibilityOn(iI);
			local iScore = pPlayer:GetDiplomaticAI():GetDiplomaticScore(pLocalPlayer:GetID());
			local iState = pPlayer:GetDiplomaticAI():GetDiplomaticStateIndex(pLocalPlayer:GetID());
			local iGameScore = pPlayer:GetScore();
			local eGovernment = pPlayer:GetCulture():GetCurrentGovernment();

			cityStateInstance.CityStateBase:SetColor(normalPlayerColor);
			cityStateInstance.CityStateBase:RegisterCallback( Mouse.eLClick, OnCityStateClick );
			cityStateInstance.CityStateBase:SetVoid1(iPlayer);

			cityStateInstance.LevyMilitaryButton:RegisterCallback( Mouse.eLClick, OnLevyMilitaryClick );
			cityStateInstance.LevyMilitaryButton:SetVoid1(iPlayer);

			cityStateInstance.ChangeWarStateButton:RegisterCallback( Mouse.eLClick, OnChangeWarStateClick );
			cityStateInstance.ChangeWarStateButton:SetVoid1(iPlayer);

			cityStateInstance.GiveTokenButton:RegisterCallback( Mouse.eLClick, OnGiveTokenClick );
			cityStateInstance.GiveTokenButton:SetVoid1(iPlayer);

			if (bHasMet == true) then
				
				if (highlightPlayerID ~= nil and highlightPlayerID == pPlayer:GetID()) then
					cityStateInstance.CityStateBase:SetColor(highlightPlayerColor);

					local pCity = nil;
					local pCities = pPlayer:GetCities();
					for i, p in pCities:Members() do
						pCity = p;
						break;
					end
					if (pCity ~= nil) then
						local pPlot = Map.GetPlot(pCity:GetX(), pCity:GetY());
						UI.LookAtPlot(pPlot);
					end
				end

				local typeInfoStr = GetTypeText(iPlayer);
				local bonusInfoStr = GetAllBonusText(iPlayer);
				local questInfoStr, numActiveQuests = GetActiveQuestsText(iPlayer);
				local fullInfoStr = envoysStr .. "[NEWLINE][NEWLINE]" .. bonusInfoStr .. "[NEWLINE][NEWLINE]" .. questInfoStr;
				cityStateInstance.GiveTokenButton:SetToolTipString(fullInfoStr);

				-- Name
				local cityStateString = Locale.Lookup(PlayerConfigurations[iPlayer]:GetCivilizationShortDescription());
				cityStateInstance.NameLabel:SetText(cityStateString);
				cityStateInstance.NameLabel:SetToolTipString(bonusInfoStr);
				
				-- Type
				cityStateInstance.TypeLabel:SetText(typeInfoStr);
				cityStateInstance.TypeLabel:SetToolTipString(bonusInfoStr);

				-- Quests
				if (numActiveQuests > 0) then
					cityStateInstance.QuestsLabel:SetText("[COLOR_GREEN]" .. numActiveQuests .. "[ENDCOLOR]");
				else
					cityStateInstance.QuestsLabel:SetText(numActiveQuests);
				end
				cityStateInstance.QuestsLabel:SetToolTipString(questInfoStr);

				-- Give Token Button
				cityStateInstance.GiveTokenButton:SetHide(false);
				cityStateInstance.GiveTokenButton:SetDisabled(pLocalPlayerInfluence == nil or not bCanGiveInfluence);

				-- Current Tokens
				local tokens = pPlayerInfluence:GetTokensReceived(pLocalPlayer:GetID());
				cityStateInstance.CurrentTokensLabel:SetText(tokens);
				cityStateInstance.CurrentTokensLabel:SetToolTipString(fullInfoStr);

				-- Type Bonus
				local bonusesEarned = 0;
				if (tokens >= 1) then
					bonusesEarned = bonusesEarned + 1;
				end
				if (tokens >= 3) then
					bonusesEarned = bonusesEarned + 1;
				end
				if (tokens >= 6) then
					bonusesEarned = bonusesEarned + 1;
				end
				nextBonusStr = bonusesEarned .. " / 3";
				cityStateInstance.TypeBonusLabel:SetText(nextBonusStr);
				cityStateInstance.TypeBonusLabel:SetToolTipString(GetTypeBonusText(pPlayer:GetID()));

				-- Unique Bonus (Suzerain)
				local highestTokensStr = "-";
				if (pPlayerInfluence:GetSuzerain() == pLocalPlayer:GetID()) then
					highestTokensStr = "YES";
				else
					highestTokensStr = "NO";
					--[[
					local tokensNeededForSuzerain = pPlayerInfluence:GetMostTokensReceived() + 1;
					if (tokensNeededForSuzerain < GlobalParameters.INFLUENCE_TOKENS_MINIMUM_FOR_SUZERAIN) then
						tokensNeededForSuzerain = GlobalParameters.INFLUENCE_TOKENS_MINIMUM_FOR_SUZERAIN;
					end
					highestTokensStr = "need " .. tokensNeededForSuzerain .. " Envoys";
					--]]
				end
				cityStateInstance.UniqueBonusLabel:SetText(highestTokensStr);
				cityStateInstance.UniqueBonusLabel:SetToolTipString(GetSuzerainBonusText(pPlayer:GetID()));

				-- Levy Military
				local canLevyMilitary = pLocalPlayerInfluence:CanLevyMilitary(pPlayer:GetID());
				local levyMilitaryCost = pLocalPlayerInfluence:GetLevyMilitaryCost(pPlayer:GetID());
				cityStateInstance.LevyMilitaryButton:SetHide(false);
				cityStateInstance.LevyMilitaryButton:SetDisabled(not canLevyMilitary);
				cityStateInstance.LevyMilitaryButton:SetToolTipString("The Suzerain may temporarily take control of all the City-State's current military units by paying " .. levyMilitaryCost .. " [ICON_Gold] Gold, which is 25% of the amount it would take to purchase the units yourself. This lasts for 30 turns (Standard speed) or until the Suzerain changes, whichever comes first.");

				-- War State Button and Relationship Status
				local szState = "";
				local stateDef = GameInfo.DiplomaticStates[iState];
				if (stateDef ~= nil) then
					szState = Locale.Lookup(stateDef.Name);
				end;

				local szRelationship = "";
				if (bIsAtWarWith == true) then
					if (iTurnChanged > -1 and bCanMakePeaceWith == false) then
						szRelationship = Locale.Lookup("LOC_DIPLOPANEL_AT_WAR_TURNS", iTurnsOfWar + iTurnChanged - Game.GetCurrentGameTurn());					
					else
						szRelationship = szState;
					end
				else
					if (iTurnChanged > -1 and bCanDeclareWarOn == false) then
						szRelationship = Locale.Lookup("LOC_DIPLOPANEL_AT_PEACE_TURNS", iTurnsOfPeace + iTurnChanged - Game.GetCurrentGameTurn());		
					else
						szRelationship = szState;
					end
				end
				if (iVisibility > 0) then
					szRelationship = szRelationship .. " (" .. tostring(iScore) .. ")";
				end
				cityStateInstance.ChangeWarStateButton:SetHide(false);
				if(bIsAtWarWith) then
					cityStateInstance.ChangeWarStateButton:SetText(makePeaceStr);
					cityStateInstance.ChangeWarStateButton:SetDisabled(not bCanMakePeaceWith);
				else
					cityStateInstance.ChangeWarStateButton:SetText(declareWarStr);
					cityStateInstance.ChangeWarStateButton:SetDisabled(not bCanDeclareWarOn);
				end
				cityStateInstance.ChangeWarStateButton:SetToolTipString("Current Relationship: " .. szRelationship);

			-- Unmet civ
			else
				cityStateInstance.NameLabel:LocalizeAndSetText("LOC_DIPLOPANEL_UNMET_PLAYER");
				cityStateInstance.TypeLabel:SetText("");
				cityStateInstance.QuestsLabel:SetText("");
				cityStateInstance.CurrentTokensLabel:SetText("");
				cityStateInstance.TypeBonusLabel:SetText("");
				cityStateInstance.UniqueBonusLabel:SetText("");
				cityStateInstance.LevyMilitaryButton:SetHide(true);
				cityStateInstance.ChangeWarStateButton:SetHide(true);
				cityStateInstance.GiveTokenButton:SetHide(true);
			end
		end
	end
	Controls.CityStateStack:ReprocessAnchoring();
	Controls.CityStateStack:CalculateSize();
end
-------------------------------------------------------------------------------
function GetTypeText(playerID:number)
	local text = "";
	local leader:string = PlayerConfigurations[playerID]:GetLeaderTypeName();
	local leaderInfo = GameInfo.Leaders[leader];
	if (leaderInfo == nil or leaderInfo.InheritFrom == nil) then
		return text;
	end
	if (leader == "LEADER_MINOR_CIV_SCIENTIFIC" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_SCIENTIFIC") then
		text = text .. "[COLOR_FLOAT_SCIENCE][ICON_Science]Scientific[ENDCOLOR]";
	elseif (leader == "LEADER_MINOR_CIV_RELIGIOUS" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_RELIGIOUS") then
		text = text .. "[ICON_Faith]Religious";
	elseif (leader == "LEADER_MINOR_CIV_TRADE" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_TRADE") then
		text = text .. "[COLOR_FLOAT_GOLD][ICON_Gold]Trade[ENDCOLOR]";
	elseif (leader == "LEADER_MINOR_CIV_CULTURAL" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_CULTURAL") then
		text = text .. "[COLOR_FLOAT_CULTURE][ICON_Culture]Cultural[ENDCOLOR]";
	elseif (leader == "LEADER_MINOR_CIV_MILITARISTIC" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_MILITARISTIC") then
		text = text .. "[COLOR_FLOAT_MILITARY][ICON_Strength]Militaristic[ENDCOLOR]";
	elseif (leader == "LEADER_MINOR_CIV_INDUSTRIAL" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_INDUSTRIAL") then
		text = text .. "[COLOR_FLOAT_PRODUCTION][ICON_Production]Industrial[ENDCOLOR]";
	end
	return text;
end
-------------------------------------------------------------------------------
function GetAllBonusText(playerID:number)
	local text = "";
	text = text .. "Type: " .. GetTypeText(playerID);
	text = text .. "[NEWLINE][NEWLINE]";
	text = text .. GetTypeBonusText(playerID);
	text = text .. "[NEWLINE][NEWLINE]";
	text = text .. GetSuzerainBonusText(playerID);
	return text;
end

function GetTypeBonusText(playerID:number)
	local text = "TYPE BONUSES are available to any player:[NEWLINE]";
	local leader:string = PlayerConfigurations[playerID]:GetLeaderTypeName();
	local leaderInfo = GameInfo.Leaders[leader];
	if (leaderInfo == nil or leaderInfo.InheritFrom == nil) then
		return text;
	end
	if (leader == "LEADER_MINOR_CIV_SCIENTIFIC" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_SCIENTIFIC") then
		text = text .. "> 1 Envoy: +2 [ICON_Science]Science in [ICON_Capital]Capital[NEWLINE]> 3 Envoys: +2 [ICON_Science]Science in every Campus district[NEWLINE]> 6 Envoys: Additional +2 [ICON_Science]Science in every Campus district";
	elseif (leader == "LEADER_MINOR_CIV_RELIGIOUS" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_RELIGIOUS") then
		text = text .. "> 1 Envoy: +2 [ICON_Faith]Faith in [ICON_Capital]Capital[NEWLINE]> 3 Envoys: +2 [ICON_Faith]Faith in every Holy Site district[NEWLINE]> 6 Envoys: Additional +2 [ICON_Faith]Faith in every Holy Site district";
	elseif (leader == "LEADER_MINOR_CIV_TRADE" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_TRADE") then
		text = text .. "> 1 Envoy: +4 [ICON_Gold]Gold in [ICON_Capital]Capital[NEWLINE]> 3 Envoys: +4 [ICON_Gold]Gold in every Commercial Hub district[NEWLINE]> 6 Envoys: Additional +4 [ICON_Gold]Gold in every Commercial Hub district";
	elseif (leader == "LEADER_MINOR_CIV_CULTURAL" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_CULTURAL") then
		text = text .. "> 1 Envoy: +2 [ICON_Culture]Culture in [ICON_Capital]Capital[NEWLINE]> 3 Envoys: +2 [ICON_Culture]Culture in every Theater district[NEWLINE]> 6 Envoys: Additional +2 [ICON_Culture]Culture in every Theater district";
	elseif (leader == "LEADER_MINOR_CIV_MILITARISTIC" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_MILITARISTIC") then
		text = text .. "> 1 Envoy: +2 [ICON_Production]Production in [ICON_Capital]Capital[NEWLINE]> 3 Envoys: +2 [ICON_Production]Production in every Encampment district[NEWLINE]> 6 Envoys: Additional +2 [ICON_Production]Production in every Encampment district";
	elseif (leader == "LEADER_MINOR_CIV_INDUSTRIAL" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_INDUSTRIAL") then
		text = text .. "> 1 Envoy: +2 [ICON_Production]Production in [ICON_Capital]Capital[NEWLINE]> 3 Envoys: +2 [ICON_Production]Production in every Industrial Zone district[NEWLINE]> 6 Envoys: Additional +2 [ICON_Production]Production in every Industrial Zone district";
	end
	return text;
end

function GetSuzerainBonusText(playerID:number)
	local text = "SUZERAIN BONUS can only belong to one player, the player with at least 3 Envoys and more than any other player. If there is a tie for most Envoys, then no player gets the bonus.";
	return text;
end

function GetActiveQuestsText(playerID:number)
	local text = "Active Quests for You:";
	local count:number = 0;
	local questsText = "";
	local questsManager:table = Game.GetQuestsManager();
	if (questsManager ~= nil) then
		for questInfo in GameInfo.Quests() do
			if (questsManager:HasActiveQuestFromPlayer(Game.GetLocalPlayer(), playerID, questInfo.Index)) then
				local questName = questsManager:GetActiveQuestName(Game.GetLocalPlayer(), playerID, questInfo.Index);
				local questDescription = questsManager:GetActiveQuestDescription(Game.GetLocalPlayer(), playerID, questInfo.Index);
				questsText = questsText .. "[NEWLINE]" .. questName .. " (" .. questDescription .. ")";
				count = count + 1;
			end
		end
	end
	if (questsText ~= "") then
		text = text .. questsText;
	else
		text = text .. "[NEWLINE]None";
	end
	return text, count;
end

------------------------------------------------------------------------------------------------
function OnCityStateClick(playerID)
	local pPlayer = Players[playerID];
	if (pPlayer == nil) then
		return;
	end

	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	if (pLocalPlayer == nil) then
		return;
	end

	print("clicked player " .. playerID );
	RefreshDisplay(playerID);
end

------------------------------------------------------------------------------------------------
function OnLevyMilitaryClick( otherPlayerID )
	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	if (pLocalPlayer ~= nil) then
		local parameters = {};
		parameters[ PlayerOperations.PARAM_PLAYER_ONE ] = otherPlayerID;
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.LEVY_MILITARY, parameters);
	end
	-- Close panel so that we don't have to worry about refreshing the screen when the war status changes.
	OnClose();
end

------------------------------------------------------------------------------------------------
function OnChangeWarStateClick( otherPlayerID )
	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	if (pLocalPlayer ~= nil) then
		local bIsAtWarWith = pLocalPlayer:GetDiplomacy():IsAtWarWith(otherPlayerID);
		local parameters = {};
		parameters[ PlayerOperations.PARAM_PLAYER_ONE ] = Game.GetLocalPlayer();
		parameters[ PlayerOperations.PARAM_PLAYER_TWO ] = otherPlayerID;
		if(bIsAtWarWith) then
			UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.DIPLOMACY_MAKE_PEACE, parameters);
		else
			UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.DIPLOMACY_DECLARE_WAR, parameters);
		end
	end
	-- Close panel so that we don't have to worry about refreshing the screen when the war status changes.
	OnClose();
end

------------------------------------------------------------------------------------------------
function OnGiveTokenClick( otherPlayerID )
	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	if (pLocalPlayer ~= nil) then
		local parameters = {};
		parameters[ PlayerOperations.PARAM_PLAYER_ONE ] = otherPlayerID;
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.GIVE_INFLUENCE_TOKEN, parameters);
	end
end

------------------------------------------------------------------------------------------------
function OnClose()
	ContextPtr:SetHide(true);
end

------------------------------------------------------------------------------------------------
---- 
-- EVENTS
---- 
------------------------------------------------------------------------------------------------
function OnOpen()
	ContextPtr:SetHide(false);
	RefreshDisplay();
end

function OnRaiseMinorCivicsPanel(playerID:number)
	local pPlayer = Players[playerID];
	if (pPlayer ~= nil and pPlayer:GetInfluence() ~= nil) then
		if (pPlayer:GetInfluence():CanReceiveInfluence()) then
			ContextPtr:SetHide(false);
			RefreshDisplay(playerID);
		end
	end
end

function OnInfluenceChanged()
	RefreshDisplay();
end

function OnQuestChanged()
	RefreshDisplay();
end


-- ===========================================================================
function Initialize()

	Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);

	Events.InfluenceChanged.Add(OnInfluenceChanged);
	Events.InfluenceGiven.Add(OnInfluenceChanged);
	Events.QuestChanged.Add(OnQuestChanged);	
	
	LuaEvents.TopPanel_OpenOldCityStatesPopup.Add( OnOpen );
	LuaEvents.NotificationPanel_OpenOldCityStatesPopup.Add( OnOpen );
end
Initialize();