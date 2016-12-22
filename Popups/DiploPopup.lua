------------------------------------------------------------------------------------------------
---- CIVICS PANEL ----
------------------------------------------------------------------------------------------------
include( "ToolTipHelper" );		-- ToolTipHelper
include( "InstanceManager" );	--InstanceManager

------------------------------------------------------------------------------------------------
-- GLOBALS
------------------------------------------------------------------------------------------------
local g_CivInstanceManager = InstanceManager:new( "CivInst", "CivInstBase", Controls.CivInstStack);

local declareWarStr : string = Locale.Lookup("LOC_DECLARE_WAR_BUTTON");
local makePeaceStr : string = Locale.Lookup("LOC_MAKE_PEACE_BUTTON");


-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function RefreshDisplay()

	g_CivInstanceManager:ResetInstances();

	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	if (pLocalPlayer == nil) then
		return;
	end

	local iTurnsOfPeace = GameInfo.GlobalParameters["DIPLOMACY_PEACE_MIN_TURNS"].Value;
	local iTurnsOfWar = GameInfo.GlobalParameters["DIPLOMACY_WAR_MIN_TURNS"].Value;

	-- SCREEN TITLE
	local szHeaderString = Locale.Lookup("LOC_DIPLOPANEL_PANEL_HEADER", PlayerConfigurations[pLocalPlayer:GetID()]:GetCivilizationShortDescription());
	Controls.DiploPopupHeader:SetText(szHeaderString);

	-- HEADER ENTRY
	local civInst = g_CivInstanceManager:GetInstance();
	civInst.CivName:LocalizeAndSetText("LOC_DIPLOPANEL_CIV_HEADER");
	civInst.CapitalName:LocalizeAndSetText("LOC_DIPLOPANEL_CAPITAL_HEADER");
	civInst.GovernmentName:LocalizeAndSetText("LOC_DIPLOPANEL_GOVERNMENT_HEADER");
	civInst.RelationshipStatus:LocalizeAndSetText("LOC_DIPLOPANEL_RELATION_HEADER");
	civInst.Visibility:LocalizeAndSetText("LOC_DIPLOPANEL_VISIBILITY_HEADER");
	civInst.Score:LocalizeAndSetText("LOC_DIPLOPANEL_SCORE_HEADER");
	civInst.CivInstBase:SetDisabled(true);

	for iI = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local pPlayer = Players[iI];
		local bAlive = pPlayer:IsAlive();
		local bMajor = pPlayer:IsMajor();

		if (iI == pLocalPlayer:GetID()) then

			local iGameScore = pPlayer:GetScore();
			Controls.ScoreLabel:SetText("Your Score:     " .. tostring(iGameScore));
			civInst.ChangeWarStateButton:SetHide(true);

		elseif (bAlive == true and bMajor == true) then

			local civInst = g_CivInstanceManager:GetInstance();
		
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

			civInst.CivInstBase:RegisterCallback( Mouse.eLClick, OnCivClick );
			civInst.CivInstBase:SetVoid1(iPlayer);

			civInst.ChangeWarStateButton:RegisterCallback( Mouse.eLClick, OnChangeWarStateClick );
			civInst.ChangeWarStateButton:SetVoid1(iPlayer);

			if (bHasMet == true) then
				
				-- Civ
				local civString = Locale.Lookup(PlayerConfigurations[iPlayer]:GetCivilizationShortDescription());
				civInst.CivName:SetText(civString);
				
				-- Capital
				local pCapitalCity = nil;
				local cities = pPlayer:GetCities();
				for i, city in cities:Members() do
				    pCapitalCity = city;
					break;
				end
				if (pCapitalCity ~= nil) then
					local capitalString = pCapitalCity:GetName();
					civInst.CapitalName:LocalizeAndSetText(capitalString);
				else
					civInst.CapitalName:SetText("");
				end

				-- Government
				govtString = GameInfo.Governments[eGovernment].Name
				civInst.GovernmentName:LocalizeAndSetText(govtString);
				
				-- Relationship status
				local szState = Locale.Lookup(GameInfo.DiplomaticStates[iState].Name);
				local szRelationship = "";
				local szRelationshipTooltip = "";
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

					pPlayer:GetDiplomaticAI():GenerateToolTips(pLocalPlayer:GetID());
					local iNum = pPlayer:GetDiplomaticAI():GetNumToolTips();
					for i=0, iNum-1, 1 do
						szRelationshipTooltip = szRelationshipTooltip .. pPlayer:GetDiplomaticAI():GetToolTip(i);
						if i < iNum - 1 then
							szRelationshipTooltip = szRelationshipTooltip .. "[NEWLINE]";
						end
					end
				end
				civInst.RelationshipStatus:SetToolTipString(szRelationshipTooltip); 
				civInst.RelationshipStatus:SetText(szRelationship);	
				
				-- War State Button
				civInst.ChangeWarStateButton:SetHide(not pPlayer:IsHuman());
				if(bIsAtWarWith) then
					civInst.ChangeWarStateButton:SetText(makePeaceStr);
					civInst.ChangeWarStateButton:SetDisabled(not bCanMakePeaceWith);
				else
					civInst.ChangeWarStateButton:SetText(declareWarStr);
					civInst.ChangeWarStateButton:SetDisabled(not bCanDeclareWarOn);
				end	

				-- DiplomaticVisibility
				civInst.Visibility:LocalizeAndSetText(GameInfo.Visibilities[iVisibility].Name);
				local szTooltipString = "";
				szTooltipString = "You may increase your visibility into other civilizations as follows:[NEWLINE]";
				szTooltipString = szTooltipString .. "- create a trade route to any city of the other civilization[NEWLINE]"; 
				szTooltipString = szTooltipString .. "- send a delegation (requires an explored path to capital and 25 Gold)[NEWLINE]"; 
				szTooltipString = szTooltipString .. "- completing research on the Renaissance tech Printing[NEWLINE]"; 
				szTooltipString = szTooltipString .. "- establish a resident embassy (requires Civil Service civic and 50 Gold)[NEWLINE]"; 
				szTooltipString = szTooltipString .. "- making an alliance (requires Diplomatic Service civic and a Declaration of Friendship)"; 
				civInst.Visibility:SetToolTipString(szTooltipString); 		

				-- Score
				civInst.Score:SetText(tostring(iGameScore));

			-- Unmet civ
			else
				civInst.CivName:LocalizeAndSetText("LOC_DIPLOPANEL_UNMET_PLAYER");
				civInst.CapitalName:SetText("");
				civInst.GovernmentName:SetText("");
				civInst.RelationshipStatus:SetText("");
				civInst.ChangeWarStateButton:SetHide(true);
				civInst.Visibility:LocalizeAndSetText("");
				civInst.Visibility:SetToolTipString(""); 		
				civInst.Score:SetText("");
			end
		end
	end
	Controls.CivInstStack:ReprocessAnchoring();
	Controls.CivInstStack:CalculateSize();
end
------------------------------------------------------------------------------------------------
function OnCivClick( playerID )
	local pPlayer = Players[playerID];
	if (pPlayer == nil) then
		return;
	end

	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	if (pLocalPlayer == nil) then
		return;
	end

	if (not GameConfiguration.IsNetworkMultiplayer() -- disabling diplomacy in multiplayer until we have support for it.
		and pLocalPlayer:GetDiplomacy():HasMet(playerID) 
		-- Disabling human-human diplo until we've implemented support for it.
		and not pPlayer:IsHuman()) then

		OnClose();
		LuaEvents.DiploPopup_TalkToLeader(playerID);
		print("clicked player " .. playerID );
	end
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
            UI.PlaySound("Notification_War_Declared");
		end
	end
	-- Close panel so that we don't have to worry about refreshing the screen when the war status changes.
	OnClose();
end

------------------------------------------------------------------------------------------------
function OnClose()
	ContextPtr:SetHide(true);
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);

------------------------------------------------------------------------------------------------
---- 
-- EVENTS
---- 
------------------------------------------------------------------------------------------------
function OnOpen()
	ContextPtr:SetHide(false);
	RefreshDisplay();
end
LuaEvents.OpenDiplomacyPanel.Add(OnOpen);

