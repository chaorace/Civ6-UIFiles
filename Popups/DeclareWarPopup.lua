--	DeclareWarPopup
--	Triggered by walking into enemy territory. WorldInput.lua - MoveUnitToPlot
include( "InstanceManager" );
include( "DiplomacyStatementSupport" );
include( "SupportFunctions" );				--DarkenLightenColor
--	******************************************************************************************************
--	CONSTANTS
--	******************************************************************************************************
local CONSEQUENCE_TYPES = {WARMONGER = 1, DEFENSIVE_PACT = 2, CITY_STATE = 3, TRADE_ROUTE = 4, DEALS = 5 };
--	******************************************************************************************************
--	MEMBERS
--	******************************************************************************************************
local m_ConsequenceItemIM :table	= InstanceManager:new( "ConsequenceItem",  "Root" );

function OnClose()
	Controls.ConsequencesStack:SetHide(true);
	Controls.WarmongerContainer:SetHide(true);
	Controls.DefensivePactContainer:SetHide(true);
	Controls.CityStateContainer:SetHide(true);
	Controls.TradeRouteContainer:SetHide(true);
	Controls.DealsContainer:SetHide(true);
	ContextPtr:SetHide(true);
end

-- ===========================================================================
function DeclareWar(eAttackingPlayer:number, eDefendingPlayer:number, eWarType:number)
	local pPlayerConfig:table = PlayerConfigurations[eDefendingPlayer];
	if( pPlayerConfig:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV ) then

		if (eWarType == WarTypes.SURPRISE_WAR) then 
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_SURPRISE_WAR");
			
		elseif (eWarType == WarTypes.FORMAL_WAR) then
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_FORMAL_WAR");
				
		elseif (eWarType == WarTypes.HOLY_WAR) then
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_HOLY_WAR");
				
		elseif (eWarType == WarTypes.LIBERATION_WAR) then
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_LIBERATION_WAR");
			
		elseif (eWarType == WarTypes.RECONQUEST_WAR) then
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_RECONQUEST_WAR");
			
		elseif (eWarType == WarTypes.PROTECTORATE_WAR) then
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_PROTECTORATE_WAR");
			
		elseif (eWarType == WarTypes.COLONIAL_WAR) then
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_COLONIAL_WAR");
			
		elseif (eWarType == WarTypes.TERRITORIAL_WAR) then
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_TERRITORIAL_WAR");

		else
			DiplomacyManager.RequestSession(eAttackingPlayer, eDefendingPlayer, "DECLARE_SURPRISE_WAR");

		end

	else
		local parameters :table = {};
		parameters[ PlayerOperations.PARAM_PLAYER_ONE ] = eAttackingPlayer;
		parameters[ PlayerOperations.PARAM_PLAYER_TWO ] = eDefendingPlayer;
		UI.RequestPlayerOperation(eAttackingPlayer, PlayerOperations.DIPLOMACY_DECLARE_WAR, parameters);
		UI.PlaySound("Notification_War_Declared");
	end
end

function OnShow(eAttackingPlayer:number, eDefendingPlayer:number, eWarType:number, confirmCallbackFn)
	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	local pSelectedPlayer = Players[eDefendingPlayer];
	local consequences: table = {};
	local kParams = {};

	-- By default, confirming will do the DeclareWar function we define here. But client could pass in a custom function to call instead (ex. WMDs and ICBMs, which declare war differently).
	if (confirmCallbackFn == nil) then
		confirmCallbackFn = function() DeclareWar(eAttackingPlayer, eDefendingPlayer, eWarType); end;
	end

	-- Prepare data - Record warmongering consequences
	kParams.WarState = eWarType;
	local eFromPlayer = Game.GetLocalPlayer();
	bSuccess, tResults = DiplomacyManager.TestAction(eFromPlayer, eDefendingPlayer, DiplomacyActionTypes.SET_WAR_STATE, kParams);
	local defenderNameString : string;
	local pDefenderCfg = PlayerConfigurations[ eDefendingPlayer ];
	if(GameConfiguration.IsAnyMultiplayer() and pDefenderCfg:IsHuman()) then
		defenderNameString = Locale.Lookup( pDefenderCfg:GetCivilizationShortDescription() ) .. " (" .. pDefenderCfg:GetPlayerName() .. ")";
	else
		defenderNameString = pDefenderCfg:GetCivilizationShortDescription();
	end
	local message = Locale.Lookup("LOC_DIPLO_WARNING_DECLARE_WAR_FROM_UNIT_ATTACK_INFO", defenderNameString)
	local iconName = "ICON_"..pDefenderCfg:GetCivilizationTypeName();

	local backColor, frontColor  = UI.GetPlayerColors( eDefendingPlayer );
	local darkerBackColor = DarkenLightenColor(backColor,(-85),238);
	local brighterBackColor = DarkenLightenColor(backColor,90,255);
	Controls.CivIcon:SetIcon(iconName);
	Controls.CircleBacking:SetColor(backColor);
	Controls.CircleDarker:SetColor(darkerBackColor);
	Controls.CircleLighter:SetColor(brighterBackColor);
	Controls.CivIcon:SetColor(frontColor);

	local iWarmongerPoints = pLocalPlayer:GetDiplomacy():ComputeDOWWarmongerPoints(eDefendingPlayer, kParams.WarState);
	local szWarmongerLevel = pLocalPlayer:GetDiplomacy():GetWarmongerLevel(-iWarmongerPoints);
	local szWarmongerString = Locale.Lookup("LOC_DIPLO_CHOICE_WARMONGER_INFO", szWarmongerLevel);
	table.insert(consequences, {CONSEQUENCE_TYPES.WARMONGER, szWarmongerString});
	-- Display data
	Controls.WarConfirmAlpha:SetToBeginning();
	Controls.WarConfirmAlpha:Play();
	Controls.WarConfirmSlide:SetToBeginning();
	Controls.WarConfirmSlide:Play();
	Controls.Yes:RegisterCallback( Mouse.eLClick, function() confirmCallbackFn(); OnClose(); end );
	Controls.Message:SetText(message);
	m_ConsequenceItemIM:DestroyInstances();
	for i=1,table.count(consequences) do
		local rootStackControl;
		if (consequences[i][1] == CONSEQUENCE_TYPES.WARMONGER) then
			Controls.WarmongerContainer:SetHide(false);
			rootStackControl = Controls.WarmongerStack;
		elseif (consequences[i][1] == CONSEQUENCE_TYPES.DEFENSIVE_PACT) then
			Controls.DefensivePactContainer:SetHide(false);
			rootStackControl = Controls.DefensivePactStack;
		elseif (consequences[i][1] == CONSEQUENCE_TYPES.CITY_STATE) then
			Controls.CityStateContainer:SetHide(false);
			rootStackControl = Controls.CityStateStack;
		elseif (consequences[i][1] == CONSEQUENCE_TYPES.TRADE_ROUTE) then
			Controls.TradeRouteContainer:SetHide(false);
			rootStackControl = Controls.TradeRoutesStack;
		elseif (consequences[i][1] == CONSEQUENCE_TYPES.DEALS) then
			Controls.DealsContainer:SetHide(false);
			rootStackControl = Controls.DealsStack;
		else UI.DataError("Bad CONSEQUENCE_TYPE delivered to the consequence stack to be parsed.[NEWLINE]Types:[NEWLINE]CONSEQUENCE_TYPES = {WARMONGER = 1, DEFENSIVE_PACT = 2, CITY_STATE = 3, TRADE_ROUTE = 4, DEALS = 5 };[NEWLINE]Type Delivered: " .. tostring(consequences[i][1]));
		end
		if (rootStackControl ~= nil) then
			local consequenceItem = m_ConsequenceItemIM:GetInstance(rootStackControl);
			if (consequences[i][2] ~= nil) then
				consequenceItem.Text:SetText(consequences[i][2]);
			else UI.DataError("Consequence string was not initialized for a generated war consequence item.[NEWLINE]Types:[NEWLINE]CONSEQUENCE_TYPES = {WARMONGER = 1, DEFENSIVE_PACT = 2, CITY_STATE = 3, TRADE_ROUTE = 4, DEALS = 5 };[NEWLINE]Type Delivered: " .. tostring(consequences[i][1]));
			end
		end
	end
	if table.count(consequences) > 0 then
		Controls.ConsequencesStack:SetHide(false);
		Controls.ConsequencesStack:CalculateSize();
		Controls.ConsequencesStack:ReprocessAnchoring();
		Resize();
	end
	ContextPtr:SetHide(false);
end

--	Handle screen resize/ dynamic popup height
function Resize()
	Controls.DropShadow:SetSizeY(Controls.Window:GetSizeY()+50);
	Controls.DropShadow:ReprocessAnchoring();
end

function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

function Initialize()
	Controls.No:RegisterCallback( Mouse.eLClick, OnClose );
	LuaEvents.DiplomacyActionView_ConfirmWarDialog.Add(OnShow);
	LuaEvents.CityStates_ConfirmWarDialog.Add(OnShow);
	LuaEvents.Civ6Common_ConfirmWarDialog.Add(OnShow);
	LuaEvents.WorldInput_ConfirmWarDialog.Add(OnShow);
	Events.SystemUpdateUI.Add( OnUpdateUI );
	Resize();
end
Initialize();