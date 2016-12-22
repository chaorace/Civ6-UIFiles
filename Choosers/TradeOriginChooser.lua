-- ===========================================================================
--
--	Slideout panel that allows the player to move their trade units to other city centers
--
-- ===========================================================================
include("InstanceManager");
include("AnimSidePanelSupport");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID:string = "TradeOriginChooser"; -- Must be unique (usually the same as the file name)

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_AnimSupport:table; --AnimSidePanelSupport

local m_cityIM:table = InstanceManager:new("CityInstance", "CityButton", Controls.CityStack);

-- ===========================================================================
function Refresh()
	-- Find the selected trade unit
	local selectedUnit:table = UI.GetHeadSelectedUnit();
	if selectedUnit == nil then
		Close();
		return;
	end

	-- Find the current city
	local originCity = Cities.GetCityInPlot(selectedUnit:GetX(), selectedUnit:GetY());
	if originCity == nil then
		Close();
		return;
	end

	-- Reset Instance Manager
	m_cityIM:ResetInstances();

	-- Add all other cities to city stack
	local localPlayer = Players[Game.GetLocalPlayer()];
	local playerCities:table = localPlayer:GetCities();
	for _, city in playerCities:Members() do
		if city ~= originCity and CanTeleportToCity(city) then
			AddCity(city);
		end
	end

	-- Calculate Control Size
	Controls.CityScrollPanel:CalculateInternalSize();
	Controls.CityStack:CalculateSize();
	Controls.CityStack:ReprocessAnchoring();
end

-- ===========================================================================
function AddCity(city:table)
	local cityInstance:table = m_cityIM:GetInstance();
	cityInstance.CityButton:SetText(Locale.ToUpper(city:GetName()));
	cityInstance.CityButton:RegisterCallback(Mouse.eLClick, function() TeleportToCity(city); end);
end

-- ===========================================================================
function CanTeleportToCity(city:table)
	local tParameters = {};
	tParameters[UnitOperationTypes.PARAM_X] = city:GetX();
	tParameters[UnitOperationTypes.PARAM_Y] = city:GetY();

	local eOperation = UI.GetInterfaceModeParameter(UnitOperationTypes.PARAM_OPERATION_TYPE);

	local pSelectedUnit = UI.GetHeadSelectedUnit();
	if (UnitManager.CanStartOperation( pSelectedUnit, eOperation, nil, tParameters)) then
		return true;
	end

	return false;
end

-- ===========================================================================
function TeleportToCity(city:table)
	local tParameters = {};
	tParameters[UnitOperationTypes.PARAM_X] = city:GetX();
	tParameters[UnitOperationTypes.PARAM_Y] = city:GetY();

	local eOperation = UI.GetInterfaceModeParameter(UnitOperationTypes.PARAM_OPERATION_TYPE);

	local pSelectedUnit = UI.GetHeadSelectedUnit();
	if (UnitManager.CanStartOperation( pSelectedUnit, eOperation, nil, tParameters)) then
		UnitManager.RequestOperation( pSelectedUnit, eOperation, tParameters);
		Close();
	end
end

-- ===========================================================================
function OnInterfaceModeChanged( oldMode:number, newMode:number )
	if (oldMode == InterfaceModeTypes.TELEPORT_TO_CITY) then
		-- Only close if already open
		if m_AnimSupport:IsVisible() then
			Close();
		end
	end
	if (newMode == InterfaceModeTypes.TELEPORT_TO_CITY) then
		-- Only open if selected unit is a trade unit
		local pSelectedUnit:table = UI.GetHeadSelectedUnit();
		local pSelectedUnitInfo:table = GameInfo.Units[pSelectedUnit:GetUnitType()];
		if pSelectedUnitInfo.MakeTradeRoute then
			Open();
		end
	end
end

-- ===========================================================================
function OnCitySelectionChanged(owner, ID, i, j, k, bSelected, bEditable)
	-- Close if we select a city
	if m_AnimSupport:IsVisible() and owner == Game.GetLocalPlayer() and owner ~= -1 then
		Close();
	end
end

-- ===========================================================================
function OnUnitSelectionChanged( playerID : number, unitID : number, hexI : number, hexJ : number, hexK : number, bSelected : boolean, bEditable : boolean)
	-- Close if we select a unit
	if m_AnimSupport:IsVisible() and owner == Game.GetLocalPlayer() and owner ~= -1 then
		Close();
	end
end

------------------------------------------------------------------------------------------------
function OnLocalPlayerTurnEnd()
	if(GameConfiguration.IsHotseat()) then
		Close();
	end
end

-- ===========================================================================
function Open()
	LuaEvents.TradeOriginChooser_SetTradeUnitStatus("LOC_HUD_UNIT_PANEL_CHOOSING_ORIGIN_CITY");
	m_AnimSupport:Show();
	Refresh();
end

-- ===========================================================================
function Close()
	LuaEvents.TradeOriginChooser_SetTradeUnitStatus("");
	m_AnimSupport:Hide();
end

-- ===========================================================================
function OnOpen()
	Open();
end

-- ===========================================================================
function OnClose()
	Close();
end

-- ===========================================================================
--	HOT-RELOADING EVENTS
-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isVisible", m_AnimSupport:IsVisible());
end
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID and contextTable["isVisible"] ~= nil and contextTable["isVisible"] then
		OnOpen();
	end
end

-- ===========================================================================
--	INIT
-- ===========================================================================
function Initialize()
	Controls.Title:SetText(Locale.ToUpper(Locale.Lookup("LOC_UNITOPERATION_MOVE_TO_DESCRIPTION")));

	-- Hot-reload events
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);

	-- Game Engine Events	
	Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
	Events.CitySelectionChanged.Add( OnCitySelectionChanged );
	Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );	
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );

	-- Animation controller
	m_AnimSupport = CreateScreenAnimation(Controls.SlideAnim);

	-- Animation controller events
	Events.SystemUpdateUI.Add(m_AnimSupport.OnUpdateUI);
	ContextPtr:SetInputHandler(m_AnimSupport.OnInputHandler, true);

	-- Control Events
	Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
end
Initialize();