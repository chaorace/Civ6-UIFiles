-- ===========================================================================
--	ReportScreen
--	All the data
--
-- ===========================================================================
include("CitySupport");
include("Civ6Common");
include("InstanceManager");
include("SupportFunctions");
include("TabSupport");


-- ===========================================================================
--	DEBUG
--	Toggle these for temporary debugging help.
-- ===========================================================================
local m_debugFullHeight				:boolean = true;		-- (false) if the screen area should resize to full height of the available space.
local m_debugNumResourcesStrategic	:number = 0;			-- (0) number of extra strategics to show for screen testing.
local m_debugNumBonuses				:number = 0;			-- (0) number of extra bonuses to show for screen testing.
local m_debugNumResourcesLuxuries	:number = 0;			-- (0) number of extra luxuries to show for screen testing.


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local DARKEN_CITY_INCOME_AREA_ADDITIONAL_Y		:number = 6;
local DATA_FIELD_SELECTION						:string = "Selection";
local SIZE_HEIGHT_BOTTOM_YIELDS					:number = 135;
local SIZE_HEIGHT_PADDING_BOTTOM_ADJUST			:number = 85;	-- (Total Y - (scroll area + THIS PADDING)) = bottom area

-- Mapping of unit type to cost.
local UnitCostMap:table = {};
do
	for row in GameInfo.Units() do
		UnitCostMap[row.UnitType] = row.Maintenance;
	end
end


-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local m_groupIM				:table = InstanceManager:new("GroupInstance",			"Top",		Controls.Stack);				-- Collapsable
local m_simpleIM			:table = InstanceManager:new("SimpleInstance",			"Top",		Controls.Stack);				-- Non-Collapsable, simple
local m_tabIM				:table = InstanceManager:new("TabInstance",				"Button",	Controls.TabContainer);
local m_bonusResourcesIM	:table = InstanceManager:new("ResourceAmountInstance",	"Info",		Controls.BonusResources);
local m_luxuryResourcesIM	:table = InstanceManager:new("ResourceAmountInstance",	"Info",		Controls.LuxuryResources);
local m_strategicResourcesIM:table = InstanceManager:new("ResourceAmountInstance",	"Info",		Controls.StrategicResources);

local m_tabs				:table;
local m_kCityData			:table = nil;
local m_kCityTotalData		:table = nil;
local m_kUnitData			:table = nil;	-- TODO: Show units by promotion class
local m_kResourceData		:table = nil;
local m_kDealData			:table = nil;
local m_uiGroups			:table = nil;	-- Track the groups on-screen for collapse all action.


-- ===========================================================================
--	Single exit point for display
-- ===========================================================================
function Close()
	UIManager:DequeuePopup(ContextPtr);
	UI.PlaySound("UI_Screen_Close");
end


-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnCloseButton()
	Close();
end

-- ===========================================================================
--	Single entry point for display
-- ===========================================================================
function Open()
	UIManager:QueuePopup( ContextPtr, PopupPriority.Normal );
	Controls.ScreenAnimIn:SetToBeginning();
	Controls.ScreenAnimIn:Play();
	UI.PlaySound("UI_Screen_Open");

	m_kCityData, m_kCityTotalData, m_kResourceData, m_kUnitData, m_kDealData = GetData();
	
	m_tabs.SelectTab( 1 );
end

-- ===========================================================================
--	LUA Events
--	Opened via the top panel
-- ===========================================================================
function OnTopOpenReportsScreen()
	Open();
end

-- ===========================================================================
--	LUA Events
--	Closed via the top panel
-- ===========================================================================
function OnTopCloseReportsScreen()
	Close();	
end

-- ===========================================================================
--	UI Callback
--	Collapse all the things!
-- ===========================================================================
function OnCollapseAllButton()
	if m_uiGroups == nil or table.count(m_uiGroups) == 0 then
		return;
	end

	for i,instance in ipairs( m_uiGroups ) do
		if instance["isCollapsed"] == false then
			instance["isCollapsed"] = true;
			instance.CollapseAnim:Reverse();
			RealizeGroup( instance );
		end
	end
end

-- ===========================================================================
--	Populate with all data required for any/all report tabs.
-- ===========================================================================
function GetData()
	local kResources	:table = {};
	local kCityData		:table = {};
	local kCityTotalData:table = {
		Income	= {},
		Expenses= {},
		Net		= {},
		Treasury= {}
	};
	local kUnitData		:table = {};


	kCityTotalData.Income[YieldTypes.CULTURE]	= 0;
	kCityTotalData.Income[YieldTypes.FAITH]		= 0;
	kCityTotalData.Income[YieldTypes.FOOD]		= 0;
	kCityTotalData.Income[YieldTypes.GOLD]		= 0;
	kCityTotalData.Income[YieldTypes.PRODUCTION]= 0;
	kCityTotalData.Income[YieldTypes.SCIENCE]	= 0;
	kCityTotalData.Income["TOURISM"]			= 0;
	kCityTotalData.Expenses[YieldTypes.GOLD]	= 0;
	
	local playerID	:number = Game.GetLocalPlayer();
	if playerID == PlayerTypes.NONE then
		UI.DataError("Unable to get valid playerID for report screen.");
		return;
	end

	local player	:table  = Players[playerID];
	local pCulture	:table	= player:GetCulture();
	local pTreasury	:table	= player:GetTreasury();
	local pReligion	:table	= player:GetReligion();
	local pScience	:table	= player:GetTechs();
	local pResources:table	= player:GetResources();		

	local pCities = player:GetCities();
	for i, pCity in pCities:Members() do	
		local cityName	:string = pCity:GetName();
			
		-- Big calls, obtain city data and add report specific fields to it.
		local data		:table	= GetCityData( pCity );
		data.Resources			= GetCityResourceData( pCity );					-- Add more data (not in CitySupport)			
		data.WorkedTileYields	= GetWorkedTileYieldData( pCity, pCulture );	-- Add more data (not in CitySupport)

		-- Add to totals.
		kCityTotalData.Income[YieldTypes.CULTURE]	= kCityTotalData.Income[YieldTypes.CULTURE] + data.CulturePerTurn;
		kCityTotalData.Income[YieldTypes.FAITH]		= kCityTotalData.Income[YieldTypes.FAITH] + data.FaithPerTurn;
		kCityTotalData.Income[YieldTypes.FOOD]		= kCityTotalData.Income[YieldTypes.FOOD] + data.FoodPerTurn;
		kCityTotalData.Income[YieldTypes.GOLD]		= kCityTotalData.Income[YieldTypes.GOLD] + data.GoldPerTurn;
		kCityTotalData.Income[YieldTypes.PRODUCTION]= kCityTotalData.Income[YieldTypes.PRODUCTION] + data.ProductionPerTurn;
		kCityTotalData.Income[YieldTypes.SCIENCE]	= kCityTotalData.Income[YieldTypes.SCIENCE] + data.SciencePerTurn;
		kCityTotalData.Income["TOURISM"]			= kCityTotalData.Income["TOURISM"] + data.WorkedTileYields["TOURISM"];
			
		kCityData[cityName] = data;

		-- Add outgoing route data
		data.OutgoingRoutes = pCity:GetTrade():GetOutgoingRoutes();

		-- Add resources
		if m_debugNumResourcesStrategic > 0 or m_debugNumResourcesLuxuries > 0 or m_debugNumBonuses > 0 then
			for debugRes=1,m_debugNumResourcesStrategic,1 do
				kResources[debugRes] = {
					CityList	= { CityName="Kangaroo", Amount=(10+debugRes) },
					Icon		= "[ICON_"..GameInfo.Resources[debugRes].ResourceType.."]",
					IsStrategic	= true,
					IsLuxury	= false,
					IsBonus		= false,
					Total		= 88
				};
			end
			for debugRes=1,m_debugNumResourcesLuxuries,1 do
				kResources[debugRes] = {
					CityList	= { CityName="Kangaroo", Amount=(10+debugRes) },
					Icon		= "[ICON_"..GameInfo.Resources[debugRes].ResourceType.."]",
					IsStrategic	= false,
					IsLuxury	= true,
					IsBonus		= false,
					Total		= 88
				};
			end
			for debugRes=1,m_debugNumBonuses,1 do
				kResources[debugRes] = {
					CityList	= { CityName="Kangaroo", Amount=(10+debugRes) },
					Icon		= "[ICON_"..GameInfo.Resources[debugRes].ResourceType.."]",
					IsStrategic	= false,
					IsLuxury	= false,
					IsBonus		= true,
					Total		= 88
				};
			end
		end

		for eResourceType,amount in pairs(data.Resources) do
			AddResourceData(kResources, eResourceType, cityName, "LOC_HUD_REPORTS_TRADE_OWNED", amount);
		end
	end

	kCityTotalData.Expenses[YieldTypes.GOLD] = pTreasury:GetTotalMaintenance();

	-- NET = Income - Expense
	kCityTotalData.Net[YieldTypes.GOLD]			= kCityTotalData.Income[YieldTypes.GOLD] - kCityTotalData.Expenses[YieldTypes.GOLD];
	kCityTotalData.Net[YieldTypes.FAITH]		= kCityTotalData.Income[YieldTypes.FAITH];

	-- Treasury
	kCityTotalData.Treasury[YieldTypes.CULTURE]		= Round( pCulture:GetCultureYield(), 0 );
	kCityTotalData.Treasury[YieldTypes.FAITH]		= Round( pReligion:GetFaithBalance(), 0 );
	kCityTotalData.Treasury[YieldTypes.GOLD]		= Round( pTreasury:GetGoldBalance(), 0 );
	kCityTotalData.Treasury[YieldTypes.SCIENCE]		= Round( pScience:GetScienceYield(), 0 );
	kCityTotalData.Treasury["TOURISM"]				= Round( kCityTotalData.Income["TOURISM"], 0 );


	-- Units (TODO: Group units by promotion class and determine total maintenance cost)
	local MaintenanceDiscountPerUnit:number = pTreasury:GetMaintDiscountPerUnit();
	local pUnits :table = player:GetUnits(); 	
	for i, pUnit in pUnits:Members() do
		local pUnitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
		local TotalMaintenanceAfterDiscount:number = pUnitInfo.Maintenance - MaintenanceDiscountPerUnit;
		if TotalMaintenanceAfterDiscount > 0 then
			if kUnitData[pUnitInfo.UnitType] == nil then
				local UnitEntry:table = {};
				UnitEntry.Name = pUnitInfo.Name;
				UnitEntry.Count = 1;
				UnitEntry.Maintenance = TotalMaintenanceAfterDiscount;
				kUnitData[pUnitInfo.UnitType] = UnitEntry;
			else
				kUnitData[pUnitInfo.UnitType].Count = kUnitData[pUnitInfo.UnitType].Count + 1;
				kUnitData[pUnitInfo.UnitType].Maintenance = kUnitData[pUnitInfo.UnitType].Maintenance + TotalMaintenanceAfterDiscount;
			end
		end
	end
	
	local kDealData	:table = {};
	local kPlayers	:table = PlayerManager.GetAliveMajors();
	for _, pOtherPlayer in ipairs(kPlayers) do
		local otherID:number = pOtherPlayer:GetID();
		if  otherID ~= playerID then			
			
			local pPlayerConfig	:table = PlayerConfigurations[otherID];
			local pDeals		:table = DealManager.GetPlayerDeals(playerID, otherID);
			
			if pDeals ~= nil then
				for i,pDeal in ipairs(pDeals) do
					if pDeal:IsValid() then
						-- Add outgoing gold deals
						local pOutgoingDeal :table	= pDeal:FindItemsByType(DealItemTypes.GOLD, DealItemSubTypes.NONE, playerID);
						if pOutgoingDeal ~= nil then
							for i,pDealItem in ipairs(pOutgoingDeal) do
								local duration		:number = pDealItem:GetDuration();
								if duration ~= 0 then
									local gold :number = pDealItem:GetAmount();
									table.insert( kDealData, {
										Type		= DealItemTypes.GOLD,
										Amount		= gold,
										Duration	= duration,
										IsOutgoing	= true,
										PlayerID	= otherID,
										Name		= Locale.Lookup( pPlayerConfig:GetCivilizationDescription() )
									});						
								end
							end
						end

						-- Add outgoing resource deals
						pOutgoingDeal = pDeal:FindItemsByType(DealItemTypes.RESOURCES, DealItemSubTypes.NONE, playerID);
						if pOutgoingDeal ~= nil then
							for i,pDealItem in ipairs(pOutgoingDeal) do
								local duration		:number = pDealItem:GetDuration();
								if duration ~= 0 then
									local amount		:number = pDealItem:GetAmount();
									local resourceType	:number = pDealItem:GetValueType();
									table.insert( kDealData, {
										Type			= DealItemTypes.RESOURCES,
										ResourceType	= resourceType,
										Amount			= amount,
										Duration		= duration,
										IsOutgoing		= true,
										PlayerID		= otherID,
										Name			= Locale.Lookup( pPlayerConfig:GetCivilizationDescription() )
									});
									
									local entryString:string = Locale.Lookup("LOC_HUD_REPORTS_ROW_DIPLOMATIC_DEALS") .. " (" .. Locale.Lookup(pPlayerConfig:GetPlayerName()) .. ")";
									AddResourceData(kResources, resourceType, entryString, "LOC_HUD_REPORTS_TRADE_EXPORTED", -1 * amount);				
								end
							end
						end
					
						-- Add incoming gold deals
						local pIncomingDeal :table = pDeal:FindItemsByType(DealItemTypes.GOLD, DealItemSubTypes.NONE, otherID);
						if pIncomingDeal ~= nil then
							for i,pDealItem in ipairs(pIncomingDeal) do
								local duration		:number = pDealItem:GetDuration();
								if duration ~= 0 then
									local gold :number = pDealItem:GetAmount()
									table.insert( kDealData, {
										Type		= DealItemTypes.GOLD;
										Amount		= gold,
										Duration	= duration,
										IsOutgoing	= false,
										PlayerID	= otherID,
										Name		= Locale.Lookup( pPlayerConfig:GetCivilizationDescription() )
									});						
								end
							end
						end

						-- Add incoming resource deals
						pIncomingDeal = pDeal:FindItemsByType(DealItemTypes.RESOURCES, DealItemSubTypes.NONE, otherID);
						if pIncomingDeal ~= nil then
							for i,pDealItem in ipairs(pIncomingDeal) do
								local duration		:number = pDealItem:GetDuration();
								if duration ~= 0 then
									local amount		:number = pDealItem:GetAmount();
									local resourceType	:number = pDealItem:GetValueType();
									table.insert( kDealData, {
										Type			= DealItemTypes.RESOURCES,
										ResourceType	= resourceType,
										Amount			= amount,
										Duration		= duration,
										IsOutgoing		= false,
										PlayerID		= otherID,
										Name			= Locale.Lookup( pPlayerConfig:GetCivilizationDescription() )
									});
									
									local entryString:string = Locale.Lookup("LOC_HUD_REPORTS_ROW_DIPLOMATIC_DEALS") .. " (" .. Locale.Lookup(pPlayerConfig:GetPlayerName()) .. ")";
									AddResourceData(kResources, resourceType, entryString, "LOC_HUD_REPORTS_TRADE_IMPORTED", amount);				
								end
							end
						end
					end	
				end							
			end

		end
	end

	-- Add resources provided by city states
	for i, pMinorPlayer in ipairs(PlayerManager.GetAliveMinors()) do
		local pMinorPlayerInfluence:table = pMinorPlayer:GetInfluence();		
		if pMinorPlayerInfluence ~= nil then
			local suzerainID:number = pMinorPlayerInfluence:GetSuzerain();
			if suzerainID == playerID then
				for row in GameInfo.Resources() do
					local resourceAmount:number =  pMinorPlayer:GetResources():GetExportedResourceAmount(row.Index);
					if resourceAmount > 0 then
						local pMinorPlayerConfig:table = PlayerConfigurations[pMinorPlayer:GetID()];
						local entryString:string = Locale.Lookup("LOC_HUD_REPORTS_CITY_STATE") .. " (" .. Locale.Lookup(pMinorPlayerConfig:GetPlayerName()) .. ")";
						AddResourceData(kResources, row.Index, entryString, "LOC_CITY_STATES_SUZERAIN", resourceAmount);
					end
				end
			end
		end
	end

	-- Assume that resources not yet accounted for have come from Great People
	if pResources then
		for row in GameInfo.Resources() do
			local internalResourceAmount:number = pResources:GetResourceAmount(row.Index);
			if (internalResourceAmount > 0) then
				if (kResources[row.Index] ~= nil) then
					if (internalResourceAmount > kResources[row.Index].Total) then
						AddResourceData(kResources, row.Index, "LOC_GOVT_FILTER_GREAT_PERSON", "-", internalResourceAmount - kResources[row.Index].Total);
					end
				else
					AddResourceData(kResources, row.Index, "LOC_GOVT_FILTER_GREAT_PERSON", "-", internalResourceAmount);
				end
			end
		end
	end

	return kCityData, kCityTotalData, kResources, kUnitData, kDealData;
end

-- ===========================================================================
function AddResourceData( kResources:table, eResourceType:number, EntryString:string, ControlString:string, InAmount:number)
	local kResource :table = GameInfo.Resources[eResourceType];

	if kResources[eResourceType] == nil then
		kResources[eResourceType] = {
			EntryList	= {},
			Icon		= "[ICON_"..kResource.ResourceType.."]",
			IsStrategic	= kResource.ResourceClassType == "RESOURCECLASS_STRATEGIC",
			IsLuxury	= GameInfo.Resources[eResourceType].ResourceClassType == "RESOURCECLASS_LUXURY",
			IsBonus		= GameInfo.Resources[eResourceType].ResourceClassType == "RESOURCECLASS_BONUS",
			Total		= 0
		};
	end

	table.insert( kResources[eResourceType].EntryList, 
	{
		EntryText	= EntryString,
		ControlText = ControlString,
		Amount		= InAmount,					
	});

	kResources[eResourceType].Total = kResources[eResourceType].Total + InAmount;
end

-- ===========================================================================
--	Obtain the total resources for a given city.
-- ===========================================================================
function GetCityResourceData( pCity:table )

	-- Loop through all the plots for a given city; tallying the resource amount.
	local kResources : table = {};
	local cityPlots : table = Map.GetCityPlots():GetPurchasedPlots(pCity)
	for _, plotID in ipairs(cityPlots) do
		local plot			: table = Map.GetPlotByIndex(plotID)
		local plotX			: number = plot:GetX()
		local plotY			: number = plot:GetY()
		local eResourceType : number = plot:GetResourceType();

		-- TODO: Account for trade/diplomacy resources.
		if eResourceType ~= -1 and Players[pCity:GetOwner()]:GetResources():IsResourceExtractableAt(plot) then
			if kResources[eResourceType] == nil then
				kResources[eResourceType] = 1;
			else
				kResources[eResourceType] = kResources[eResourceType] + 1;
			end
		end
	end
	return kResources;
end

-- ===========================================================================
--	Obtain the yields from the worked plots
-- ===========================================================================
function GetWorkedTileYieldData( pCity:table, pCulture:table )

	-- Loop through all the plots for a given city; tallying the resource amount.
	local kYields : table = {
		YIELD_PRODUCTION= 0,
		YIELD_FOOD		= 0,
		YIELD_GOLD		= 0,
		YIELD_FAITH		= 0,
		YIELD_SCIENCE	= 0,
		YIELD_CULTURE	= 0,
		TOURISM			= 0,
	};
	local cityPlots : table = Map.GetCityPlots():GetPurchasedPlots(pCity);
	local pCitizens	: table = pCity:GetCitizens();	
	for _, plotID in ipairs(cityPlots) do		
		local plot	: table = Map.GetPlotByIndex(plotID);
		local x		: number = plot:GetX();
		local y		: number = plot:GetY();
		isPlotWorked = pCitizens:IsPlotWorked(x,y);
		if isPlotWorked then
			for row in GameInfo.Yields() do			
				kYields[row.YieldType] = kYields[row.YieldType] + plot:GetYield(row.Index);				
			end
		end

		-- Support tourism.
		-- Not a common yield, and only exposure from game core is based off
		-- of the plot so the sum is easily shown, but it's not possible to 
		-- show how individual buildings contribute... yet.
		kYields["TOURISM"] = kYields["TOURISM"] + pCulture:GetTourismAt( plotID );
	end
	return kYields;
end



-- ===========================================================================
--	Set a group to it's proper collapse/open state
--	Set + - in group row
-- ===========================================================================
function RealizeGroup( instance:table )
	local v :number = (instance["isCollapsed"]==false and instance.RowExpandCheck:GetSizeY() or 0);
	instance.RowExpandCheck:SetTextureOffsetVal(0, v);

	instance.ContentStack:CalculateSize();	
	instance.CollapseScroll:CalculateSize();
	
	local groupHeight	:number = instance.ContentStack:GetSizeY();
	instance.CollapseAnim:SetBeginVal(0, -(groupHeight - instance["CollapsePadding"]));
	instance.CollapseScroll:SetSizeY( groupHeight );				

	instance.Top:ReprocessAnchoring();
end

-- ===========================================================================
--	Callback
--	Expand or contract a group based on its existing state.
-- ===========================================================================
function OnToggleCollapseGroup( instance:table )
	instance["isCollapsed"] = not instance["isCollapsed"];
	instance.CollapseAnim:Reverse();
	RealizeGroup( instance );
end

-- ===========================================================================
--	Toggle a group expanding / collapsing
--	instance,	A group instance.
-- ===========================================================================
function OnAnimGroupCollapse( instance:table)
		-- Helper
	function lerp(y1:number,y2:number,x:number)
		return y1 + (y2-y1)*x;
	end
	local groupHeight	:number = instance.ContentStack:GetSizeY();
	local collapseHeight:number = instance["CollapsePadding"]~=nil and instance["CollapsePadding"] or 0;
	local startY		:number = instance["isCollapsed"]==true  and groupHeight or collapseHeight;
	local endY			:number = instance["isCollapsed"]==false and groupHeight or collapseHeight;
	local progress		:number = instance.CollapseAnim:GetProgress();
	local sizeY			:number = lerp(startY,endY,progress);

	instance.CollapseAnim:SetSizeY( groupHeight );		
	instance.CollapseScroll:SetSizeY( sizeY );	
	instance.ContentStack:ReprocessAnchoring();	
	instance.Top:ReprocessAnchoring()

	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();			
end


-- ===========================================================================
function SetGroupCollapsePadding( instance:table, amount:number )
	instance["CollapsePadding"] = amount;
end


-- ===========================================================================
function ResetTabForNewPageContent()
	m_uiGroups = {};
	m_simpleIM:ResetInstances();
	m_groupIM:ResetInstances();
	Controls.Scroll:SetScrollValue( 0 );	
end


-- ===========================================================================
--	Instantiate a new collapsable row (group) holder & wire it up.
--	ARGS:	(optional) isCollapsed
--	RETURNS: New group instance
-- ===========================================================================
function NewCollapsibleGroupInstance( isCollapsed:boolean )
	if isCollapsed == nil then
		isCollapsed = false;
	end
	local instance:table = m_groupIM:GetInstance();	
	instance.ContentStack:DestroyAllChildren();
	instance["isCollapsed"]		= isCollapsed;
	instance["CollapsePadding"] = nil;				-- reset any prior collapse padding

	instance.CollapseAnim:SetToBeginning();
	if isCollapsed == false then
		instance.CollapseAnim:SetToEnd();
	end	

	instance.RowHeaderButton:RegisterCallback( Mouse.eLClick, function() OnToggleCollapseGroup(instance); end );			
  	instance.RowHeaderButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	instance.CollapseAnim:RegisterAnimCallback(               function() OnAnimGroupCollapse( instance ); end );

	table.insert( m_uiGroups, instance );

	return instance;
end


-- ===========================================================================
--	debug - Create a test page.
-- ===========================================================================
function ViewTestPage()

	ResetTabForNewPageContent();

	local instance:table = NewCollapsibleGroupInstance();	
	instance.RowHeaderButton:SetText( "Test City Icon 1" );
	instance.Top:SetID("foo");
	
	local pHeaderInstance:table = {}
	ContextPtr:BuildInstanceForControl( "CityIncomeHeaderInstance", pHeaderInstance, instance.ContentStack ) ;	

	local pCityInstance:table = {};
	ContextPtr:BuildInstanceForControl( "CityIncomeInstance", pCityInstance, instance.ContentStack ) ;

	for i=1,3,1 do
		local pLineItemInstance:table = {};
		ContextPtr:BuildInstanceForControl("CityIncomeLineItemInstance", pLineItemInstance, pCityInstance.LineItemStack );
	end

	local pFooterInstance:table = {};
	ContextPtr:BuildInstanceForControl("CityIncomeFooterInstance", pFooterInstance, instance.ContentStack  );
	
	SetGroupCollapsePadding(instance, pFooterInstance.Top:GetSizeY() );
	RealizeGroup( instance );
	
	Controls.BottomYieldTotals:SetHide( true );
	Controls.BottomResourceTotals:SetHide( true );
	Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - (Controls.BottomYieldTotals:GetSizeY() + SIZE_HEIGHT_PADDING_BOTTOM_ADJUST ) );
end

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewYieldsPage()	

	ResetTabForNewPageContent();

	local instance:table = nil;
	instance = NewCollapsibleGroupInstance();
	instance.RowHeaderButton:SetText( Locale.Lookup("LOC_HUD_REPORTS_ROW_CITY_INCOME") );
	
	local pHeaderInstance:table = {}
	ContextPtr:BuildInstanceForControl( "CityIncomeHeaderInstance", pHeaderInstance, instance.ContentStack ) ;	

	local goldCityTotal		:number = 0;
	local faithCityTotal	:number = 0;
	local scienceCityTotal	:number = 0;
	local cultureCityTotal	:number = 0;
	local tourismCityTotal	:number = 0;
	

	-- ========== City Income ==========

	for cityName,kCityData in pairs(m_kCityData) do
		local pCityInstance:table = {};
		ContextPtr:BuildInstanceForControl( "CityIncomeInstance", pCityInstance, instance.ContentStack ) ;
		pCityInstance.LineItemStack:DestroyAllChildren();
		pCityInstance.CityName:SetText( Locale.Lookup(kCityData.CityName) );

		-- Current Production
		local kCurrentProduction:table = kCityData.ProductionQueue[1];
		pCityInstance.CurrentProduction:SetHide( kCurrentProduction == nil );
		if kCurrentProduction ~= nil then
			local tooltip:string = Locale.Lookup(kCurrentProduction.Name);
			if kCurrentProduction.Description ~= nil then
				tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup(kCurrentProduction.Description);
			end
			pCityInstance.CurrentProduction:SetToolTipString( tooltip )

			if kCurrentProduction.Icon then
				pCityInstance.CityBannerBackground:SetHide( false );
				pCityInstance.CurrentProduction:SetIcon( kCurrentProduction.Icon );
				pCityInstance.CityProductionMeter:SetPercent( kCurrentProduction.PercentComplete );
				pCityInstance.CityProductionNextTurn:SetPercent( kCurrentProduction.PercentCompleteNextTurn );			
				pCityInstance.ProductionBorder:SetHide( kCurrentProduction.Type == ProductionType.DISTRICT );
			else
				pCityInstance.CityBannerBackground:SetHide( true );
			end
		end

		pCityInstance.Production:SetText( toPlusMinusString(kCityData.ProductionPerTurn) );
		pCityInstance.Food:SetText( toPlusMinusString(kCityData.FoodPerTurn) );
		pCityInstance.Gold:SetText( toPlusMinusString(kCityData.GoldPerTurn) );
		pCityInstance.Faith:SetText( toPlusMinusString(kCityData.FaithPerTurn) );
		pCityInstance.Science:SetText( toPlusMinusString(kCityData.SciencePerTurn) );
		pCityInstance.Culture:SetText( toPlusMinusString(kCityData.CulturePerTurn) );
		pCityInstance.Tourism:SetText( toPlusMinusString(kCityData.WorkedTileYields["TOURISM"]) );

		-- Add to all cities totals
		goldCityTotal	= goldCityTotal + kCityData.GoldPerTurn;
		faithCityTotal	= faithCityTotal + kCityData.FaithPerTurn;
		scienceCityTotal= scienceCityTotal + kCityData.SciencePerTurn;
		cultureCityTotal= cultureCityTotal + kCityData.CulturePerTurn;
		tourismCityTotal= tourismCityTotal + kCityData.WorkedTileYields["TOURISM"];
		
		-- Compute tiles worked by setting to total and subtracting all the things...
		local productionTilesWorked :number = kCityData.ProductionPerTurn;
		local foodTilesWorked		:number = kCityData.FoodPerTurn;
		local goldTilesWorked		:number = kCityData.GoldPerTurn;
		local faithTilesWorked		:number = kCityData.FaithPerTurn;
		local scienceTilesWorked	:number = kCityData.SciencePerTurn;
		local cultureTilesWorked	:number = kCityData.CulturePerTurn;

		for i,kDistrict in ipairs(kCityData.BuildingsAndDistricts) do			
			for i,kBuilding in ipairs(kDistrict.Buildings) do
				local pLineItemInstance:table = {};
				ContextPtr:BuildInstanceForControl("CityIncomeLineItemInstance", pLineItemInstance, pCityInstance.LineItemStack );
				pLineItemInstance.LineItemName:SetText( kBuilding.Name );

				pLineItemInstance.Production:SetText( toPlusMinusNoneString(kBuilding.ProductionPerTurn) );
				pLineItemInstance.Food:SetText( toPlusMinusNoneString(kBuilding.FoodPerTurn) );
				pLineItemInstance.Gold:SetText( toPlusMinusNoneString(kBuilding.GoldPerTurn) );
				pLineItemInstance.Faith:SetText( toPlusMinusNoneString(kBuilding.FaithPerTurn) );
				pLineItemInstance.Science:SetText( toPlusMinusNoneString(kBuilding.SciencePerTurn) );
				pLineItemInstance.Culture:SetText( toPlusMinusNoneString(kBuilding.CulturePerTurn) );
				
				productionTilesWorked	= productionTilesWorked - kBuilding.ProductionPerTurn;
				foodTilesWorked			= foodTilesWorked		- kBuilding.FoodPerTurn;
				goldTilesWorked			= goldTilesWorked		- kBuilding.GoldPerTurn;
				faithTilesWorked		= faithTilesWorked		- kBuilding.FaithPerTurn;
				scienceTilesWorked		= scienceTilesWorked	- kBuilding.SciencePerTurn;
				cultureTilesWorked		= cultureTilesWorked	- kBuilding.CulturePerTurn;
			end
		end

		-- Display wonder yields
		if kCityData.Wonders then
			for _, wonder in ipairs(kCityData.Wonders) do
				if wonder.Yields[1] ~= nil then
					local pLineItemInstance:table = {};
					ContextPtr:BuildInstanceForControl("CityIncomeLineItemInstance", pLineItemInstance, pCityInstance.LineItemStack );
					pLineItemInstance.LineItemName:SetText( wonder.Name );

					-- Show yields
					for _, yield in ipairs(wonder.Yields) do
						if (yield.YieldType == "YIELD_FOOD") then
							pLineItemInstance.Food:SetText( toPlusMinusNoneString(yield.YieldChange) );
						elseif (yield.YieldType == "YIELD_PRODUCTION") then
							pLineItemInstance.Production:SetText( toPlusMinusNoneString(yield.YieldChange) );
						elseif (yield.YieldType == "YIELD_GOLD") then
							pLineItemInstance.Gold:SetText( toPlusMinusNoneString(yield.YieldChange) );
						elseif (yield.YieldType == "YIELD_SCIENCE") then
							pLineItemInstance.Science:SetText( toPlusMinusNoneString(yield.YieldChange) );
						elseif (yield.YieldType == "YIELD_CULTURE") then
							pLineItemInstance.Culture:SetText( toPlusMinusNoneString(yield.YieldChange) );
						elseif (yield.YieldType == "YIELD_FAITH") then
							pLineItemInstance.Faith:SetText( toPlusMinusNoneString(yield.YieldChange) );
						end
					end
				end
			end
		end

		-- Display route yields
		if kCityData.OutgoingRoutes then
			for i,route in ipairs(kCityData.OutgoingRoutes) do
				if route ~= nil then
					if route.OriginYields then
						-- Find destination city
						local pDestPlayer:table = Players[route.DestinationCityPlayer];
						local pDestPlayerCities:table = pDestPlayer:GetCities();
						local pDestCity:table = pDestPlayerCities:FindID(route.DestinationCityID);

						local pLineItemInstance:table = {};
						ContextPtr:BuildInstanceForControl("CityIncomeLineItemInstance", pLineItemInstance, pCityInstance.LineItemStack );
						pLineItemInstance.LineItemName:SetText( Locale.Lookup("LOC_HUD_REPORTS_TRADE_WITH", Locale.Lookup(pDestCity:GetName()) ));

						for j,yield in ipairs(route.OriginYields) do
							local yieldInfo = GameInfo.Yields[yield.YieldIndex];
							if yieldInfo then
								if (yieldInfo.YieldType == "YIELD_FOOD") then
									pLineItemInstance.Food:SetText( toPlusMinusNoneString(yield.Amount) );
								elseif (yieldInfo.YieldType == "YIELD_PRODUCTION") then
									pLineItemInstance.Production:SetText( toPlusMinusNoneString(yield.Amount) );
								elseif (yieldInfo.YieldType == "YIELD_GOLD") then
									pLineItemInstance.Gold:SetText( toPlusMinusNoneString(yield.Amount) );
								elseif (yieldInfo.YieldType == "YIELD_SCIENCE") then
									pLineItemInstance.Science:SetText( toPlusMinusNoneString(yield.Amount) );
								elseif (yieldInfo.YieldType == "YIELD_CULTURE") then
									pLineItemInstance.Culture:SetText( toPlusMinusNoneString(yield.Amount) );
								elseif (yieldInfo.YieldType == "YIELD_FAITH") then
									pLineItemInstance.Faith:SetText( toPlusMinusNoneString(yield.Amount) );
								end
							end
						end
					end
				end
			end
		end

		local pLineItemInstance:table = {};
		ContextPtr:BuildInstanceForControl("CityIncomeLineItemInstance", pLineItemInstance, pCityInstance.LineItemStack );
		pLineItemInstance.LineItemName:SetText( Locale.Lookup("LOC_HUD_REPORTS_WORKED_TILES") );
		pLineItemInstance.Production:SetText( toPlusMinusNoneString(kCityData.WorkedTileYields["YIELD_PRODUCTION"]) );
		pLineItemInstance.Food:SetText( toPlusMinusNoneString(kCityData.WorkedTileYields["YIELD_FOOD"]) );
		pLineItemInstance.Gold:SetText( toPlusMinusNoneString(kCityData.WorkedTileYields["YIELD_GOLD"]) );
		pLineItemInstance.Faith:SetText( toPlusMinusNoneString(kCityData.WorkedTileYields["YIELD_FAITH"]) );
		pLineItemInstance.Science:SetText( toPlusMinusNoneString(kCityData.WorkedTileYields["YIELD_SCIENCE"]) );
		pLineItemInstance.Culture:SetText( toPlusMinusNoneString(kCityData.WorkedTileYields["YIELD_CULTURE"]) );

		local iYieldPercent = (Round(1 + (kCityData.HappinessNonFoodYieldModifier/100), 2)*.1);
		pLineItemInstance = {};
		ContextPtr:BuildInstanceForControl("CityIncomeLineItemInstance", pLineItemInstance, pCityInstance.LineItemStack );
		pLineItemInstance.LineItemName:SetText( Locale.Lookup("LOC_HUD_REPORTS_HEADER_AMENITIES") );
		pLineItemInstance.Production:SetText( toPlusMinusNoneString((kCityData.WorkedTileYields["YIELD_PRODUCTION"] * iYieldPercent) ) );
		pLineItemInstance.Food:SetText( "" );
		pLineItemInstance.Gold:SetText( toPlusMinusNoneString((kCityData.WorkedTileYields["YIELD_GOLD"] * iYieldPercent)) );
		pLineItemInstance.Faith:SetText( toPlusMinusNoneString((kCityData.WorkedTileYields["YIELD_FAITH"] * iYieldPercent)) );
		pLineItemInstance.Science:SetText( toPlusMinusNoneString((kCityData.WorkedTileYields["YIELD_SCIENCE"] * iYieldPercent)) );
		pLineItemInstance.Culture:SetText( toPlusMinusNoneString((kCityData.WorkedTileYields["YIELD_CULTURE"] * iYieldPercent)) );

		pCityInstance.LineItemStack:CalculateSize();
		pCityInstance.Darken:SetSizeY( pCityInstance.LineItemStack:GetSizeY() + DARKEN_CITY_INCOME_AREA_ADDITIONAL_Y );
		pCityInstance.Top:ReprocessAnchoring();
	end

	local pFooterInstance:table = {};
	ContextPtr:BuildInstanceForControl("CityIncomeFooterInstance", pFooterInstance, instance.ContentStack  );
	pFooterInstance.Gold:SetText( "[Icon_GOLD]"..toPlusMinusString(goldCityTotal) );
	pFooterInstance.Faith:SetText( "[Icon_FAITH]"..toPlusMinusString(faithCityTotal) );
	pFooterInstance.Science:SetText( "[Icon_SCIENCE]"..toPlusMinusString(scienceCityTotal) );
	pFooterInstance.Culture:SetText( "[Icon_CULTURE]"..toPlusMinusString(cultureCityTotal) );
	pFooterInstance.Tourism:SetText( "[Icon_TOURISM]"..toPlusMinusString(tourismCityTotal) );

	SetGroupCollapsePadding(instance, pFooterInstance.Top:GetSizeY() );
	RealizeGroup( instance );


	-- ========== Building Expenses ==========

	instance = NewCollapsibleGroupInstance();
	instance.RowHeaderButton:SetText( Locale.Lookup("LOC_HUD_REPORTS_ROW_BUILDING_EXPENSES") );

	local pHeader:table = {};
	ContextPtr:BuildInstanceForControl( "BuildingExpensesHeaderInstance", pHeader, instance.ContentStack ) ;

	local iTotalBuildingMaintenance :number = 0;
	for cityName,kCityData in pairs(m_kCityData) do
		for i,kBuilding in ipairs(kCityData.Buildings) do
			if kBuilding.Maintenance > 0 then
				local pBuildingInstance:table = {};		
				ContextPtr:BuildInstanceForControl( "BuildingExpensesEntryInstance", pBuildingInstance, instance.ContentStack ) ;		
				pBuildingInstance.CityName:SetText( Locale.Lookup(cityName) );
				pBuildingInstance.BuildingName:SetText( Locale.Lookup(kBuilding.Name) );
				pBuildingInstance.Gold:SetText( "-"..tostring(kBuilding.Maintenance));
				iTotalBuildingMaintenance = iTotalBuildingMaintenance - kBuilding.Maintenance;
			end
		end
	end
	local pBuildingFooterInstance:table = {};		
	ContextPtr:BuildInstanceForControl( "GoldFooterInstance", pBuildingFooterInstance, instance.ContentStack ) ;		
	pBuildingFooterInstance.Gold:SetText("[ICON_Gold]"..tostring(iTotalBuildingMaintenance) );

	SetGroupCollapsePadding(instance, pBuildingFooterInstance.Top:GetSizeY() );
	RealizeGroup( instance );

	-- ========== Unit Expenses ==========

	instance = NewCollapsibleGroupInstance();
	instance.RowHeaderButton:SetText( Locale.Lookup("LOC_HUD_REPORTS_ROW_UNIT_EXPENSES") );

	-- Header
	local pHeader:table = {};
	ContextPtr:BuildInstanceForControl( "UnitExpensesHeaderInstance", pHeader, instance.ContentStack ) ;

	-- Units
	local iTotalUnitMaintenance:number = 0;
	for UnitType,kUnitData in pairs(m_kUnitData) do
		local pUnitInstance:table = {};
		ContextPtr:BuildInstanceForControl( "UnitExpensesEntryInstance", pUnitInstance, instance.ContentStack );
		pUnitInstance.UnitName:SetText(Locale.Lookup( kUnitData.Name ));
		pUnitInstance.UnitCount:SetText(kUnitData.Count);
		pUnitInstance.Gold:SetText("-" .. kUnitData.Maintenance);
		iTotalUnitMaintenance = iTotalUnitMaintenance + kUnitData.Maintenance;
	end

	-- Footer
	local pUnitFooterInstance:table = {};		
	ContextPtr:BuildInstanceForControl( "GoldFooterInstance", pUnitFooterInstance, instance.ContentStack ) ;		
	pUnitFooterInstance.Gold:SetText("[ICON_Gold]-"..tostring(iTotalUnitMaintenance) );

	SetGroupCollapsePadding(instance, pUnitFooterInstance.Top:GetSizeY() );
	RealizeGroup( instance );
	
	-- ========== Diplomatic Deals Expenses ==========
	
	instance = NewCollapsibleGroupInstance();	
	instance.RowHeaderButton:SetText( Locale.Lookup("LOC_HUD_REPORTS_ROW_DIPLOMATIC_DEALS") );

	local pHeader:table = {};
	ContextPtr:BuildInstanceForControl( "DealHeaderInstance", pHeader, instance.ContentStack ) ;

	local iTotalDealGold :number = 0;
	for i,kDeal in ipairs(m_kDealData) do
		if kDeal.Type == DealItemTypes.GOLD then
			local pDealInstance:table = {};		
			ContextPtr:BuildInstanceForControl( "DealEntryInstance", pDealInstance, instance.ContentStack ) ;		

			pDealInstance.Civilization:SetText( kDeal.Name );
			pDealInstance.Duration:SetText( kDeal.Duration );
			if kDeal.IsOutgoing then
				pDealInstance.Gold:SetText( "-"..tostring(kDeal.Amount) );
				iTotalDealGold = iTotalDealGold - kDeal.Amount;
			else
				pDealInstance.Gold:SetText( "+"..tostring(kDeal.Amount) );
				iTotalDealGold = iTotalDealGold + kDeal.Amount;
			end
		end
	end
	local pDealFooterInstance:table = {};		
	ContextPtr:BuildInstanceForControl( "GoldFooterInstance", pDealFooterInstance, instance.ContentStack ) ;		
	pDealFooterInstance.Gold:SetText("[ICON_Gold]"..tostring(iTotalDealGold) );

	SetGroupCollapsePadding(instance, pDealFooterInstance.Top:GetSizeY() );
	RealizeGroup( instance );


	-- ========== TOTALS ==========

	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();

	-- Totals at the bottom
	Controls.GoldIncome:SetText( toPlusMinusNoneString( m_kCityTotalData.Income[YieldTypes.GOLD] ));
	Controls.FaithIncome:SetText( toPlusMinusNoneString( m_kCityTotalData.Income[YieldTypes.FAITH] ));
	Controls.ScienceIncome:SetText( toPlusMinusNoneString( m_kCityTotalData.Income[YieldTypes.SCIENCE] ));
	Controls.CultureIncome:SetText( toPlusMinusNoneString( m_kCityTotalData.Income[YieldTypes.CULTURE] ));
	Controls.TourismIncome:SetText( toPlusMinusNoneString( m_kCityTotalData.Income["TOURISM"] ));	
	Controls.GoldExpense:SetText( toPlusMinusNoneString( -m_kCityTotalData.Expenses[YieldTypes.GOLD] ));	-- Flip that value!
	Controls.GoldNet:SetText( toPlusMinusNoneString( m_kCityTotalData.Net[YieldTypes.GOLD] ));
	Controls.FaithNet:SetText( toPlusMinusNoneString( m_kCityTotalData.Net[YieldTypes.FAITH] ));
	
	Controls.GoldBalance:SetText( m_kCityTotalData.Treasury[YieldTypes.GOLD] );
	Controls.FaithBalance:SetText( m_kCityTotalData.Treasury[YieldTypes.FAITH] );
	Controls.ScienceBalance:SetText( m_kCityTotalData.Treasury[YieldTypes.SCIENCE] );
	Controls.CultureBalance:SetText( m_kCityTotalData.Treasury[YieldTypes.CULTURE] );
	Controls.TourismBalance:SetText( m_kCityTotalData.Treasury["TOURISM"] );
	
	Controls.BottomYieldTotals:SetHide( false );
	Controls.BottomYieldTotals:SetSizeY( SIZE_HEIGHT_BOTTOM_YIELDS );
	Controls.BottomResourceTotals:SetHide( true );
	Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - (Controls.BottomYieldTotals:GetSizeY() + SIZE_HEIGHT_PADDING_BOTTOM_ADJUST ) );	
end


-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewResourcesPage()	

	ResetTabForNewPageContent();

	local strategicResources:string = "";
	local luxuryResources	:string = "";
	local kBonuses			:table	= {};
	local kLuxuries			:table	= {};
	local kStrategics		:table	= {};
	

	for eResourceType,kSingleResourceData in pairs(m_kResourceData) do
		
		local instance:table = NewCollapsibleGroupInstance();	

		local kResource :table = GameInfo.Resources[eResourceType];
		instance.RowHeaderButton:SetText(  kSingleResourceData.Icon..Locale.Lookup( kResource.Name ) );

		local pHeaderInstance:table = {};
		ContextPtr:BuildInstanceForControl( "ResourcesHeaderInstance", pHeaderInstance, instance.ContentStack ) ;

		local kResourceEntries:table = kSingleResourceData.EntryList;
		for i,kEntry in ipairs(kResourceEntries) do
			local pEntryInstance:table = {};
			ContextPtr:BuildInstanceForControl( "ResourcesEntryInstance", pEntryInstance, instance.ContentStack ) ;
			pEntryInstance.CityName:SetText( Locale.Lookup(kEntry.EntryText) );
			pEntryInstance.Control:SetText( Locale.Lookup(kEntry.ControlText) );
			pEntryInstance.Amount:SetText( (kEntry.Amount<=0) and tostring(kEntry.Amount) or "+"..tostring(kEntry.Amount) );
		end

		local pFooterInstance:table = {};
		ContextPtr:BuildInstanceForControl( "ResourcesFooterInstance", pFooterInstance, instance.ContentStack ) ;
		pFooterInstance.Amount:SetText( tostring(kSingleResourceData.Total) );		

		-- Show how many of this resource are being allocated to what cities
		local localPlayerID = Game.GetLocalPlayer();
		local localPlayer = Players[localPlayerID];
		local citiesProvidedTo: table = localPlayer:GetResources():GetResourceAllocationCities(GameInfo.Resources[kResource.ResourceType].Index);
		local numCitiesProvidingTo: number = table.count(citiesProvidedTo);
		if (numCitiesProvidingTo > 0) then
			pFooterInstance.AmenitiesContainer:SetHide(false);
			pFooterInstance.Amenities:SetText("[ICON_Amenities][ICON_GoingTo]"..numCitiesProvidingTo.." "..Locale.Lookup("LOC_PEDIA_CONCEPTS_PAGEGROUP_CITIES_NAME"));
			local amenitiesTooltip: string = "";
			local playerCities = localPlayer:GetCities();
			for i,city in ipairs(citiesProvidedTo) do
				local cityName = Locale.Lookup(playerCities:FindID(city.CityID):GetName());
				if i ~=1 then
					amenitiesTooltip = amenitiesTooltip.. "[NEWLINE]";
				end
				amenitiesTooltip = amenitiesTooltip.. city.AllocationAmount.." [ICON_".. kResource.ResourceType.."] [Icon_GoingTo] " ..cityName;
			end
			pFooterInstance.Amenities:SetToolTipString(amenitiesTooltip);
		else
			pFooterInstance.AmenitiesContainer:SetHide(true);
		end

		if kSingleResourceData.IsStrategic then
			--strategicResources = strategicResources .. kSingleResourceData.Icon .. tostring( kSingleResourceData.Total );
			table.insert(kStrategics, kSingleResourceData.Icon .. tostring( kSingleResourceData.Total ) );
		elseif kSingleResourceData.IsLuxury then			
			--luxuryResources = luxuryResources .. kSingleResourceData.Icon .. tostring( kSingleResourceData.Total );			
			table.insert(kLuxuries, kSingleResourceData.Icon .. tostring( kSingleResourceData.Total ) );
		else
			table.insert(kBonuses, kSingleResourceData.Icon .. tostring( kSingleResourceData.Total ) );
		end

		SetGroupCollapsePadding(instance, pFooterInstance.Top:GetSizeY() );
		RealizeGroup( instance );
	end
	
	m_strategicResourcesIM:ResetInstances();
	for i,v in ipairs(kStrategics) do
		local resourceInstance:table = m_strategicResourcesIM:GetInstance();	
		resourceInstance.Info:SetText( v );
	end
	Controls.StrategicResources:CalculateSize();
	Controls.StrategicGrid:ReprocessAnchoring();

	m_bonusResourcesIM:ResetInstances();
	for i,v in ipairs(kBonuses) do
		local resourceInstance:table = m_bonusResourcesIM:GetInstance();	
		resourceInstance.Info:SetText( v );
	end
	Controls.BonusResources:CalculateSize();
	Controls.BonusGrid:ReprocessAnchoring();

	m_luxuryResourcesIM:ResetInstances();
	for i,v in ipairs(kLuxuries) do
		local resourceInstance:table = m_luxuryResourcesIM:GetInstance();	
		resourceInstance.Info:SetText( v );
	end
	
	Controls.LuxuryResources:CalculateSize();
	Controls.LuxuryResources:ReprocessAnchoring();
	Controls.LuxuryGrid:ReprocessAnchoring();
	
	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();

	Controls.BottomYieldTotals:SetHide( true );
	Controls.BottomResourceTotals:SetHide( false );
	Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - (Controls.BottomResourceTotals:GetSizeY() + SIZE_HEIGHT_PADDING_BOTTOM_ADJUST ) );	
end

-- ===========================================================================
--	Tab Callback
-- ===========================================================================
function ViewCityStatusPage()	

	ResetTabForNewPageContent();

	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();
	
	local pHeaderInstance:table = {}
	ContextPtr:BuildInstanceForControl( "CityStatusHeaderInstance", pHeaderInstance, instance.Top ) ;	

	-- 
	for cityName,kCityData in pairs(m_kCityData) do

		local pCityInstance:table = {}
		ContextPtr:BuildInstanceForControl( "CityStatusEntryInstance", pCityInstance, instance.Top ) ;	
		pCityInstance.CityName:SetText( Locale.Lookup(kCityData.CityName) );
		pCityInstance.Population:SetText( tostring(kCityData.Population) );

		if kCityData.HousingMultiplier == 0 then
			status = "LOC_HUD_REPORTS_STATUS_HALTED";
		elseif kCityData.HousingMultiplier <= 0.5 then
			status = "LOC_HUD_REPORTS_STATUS_SLOWED";
		else
			status = "LOC_HUD_REPORTS_STATUS_NORMAL";
		end
		pCityInstance.GrowthRateStatus:SetText( Locale.Lookup(status) );

		pCityInstance.Housing:SetText( tostring(kCityData.Housing) );
		pCityInstance.Amenities:SetText( tostring(kCityData.AmenitiesNum).." / "..tostring(kCityData.AmenitiesRequiredNum) );

		local happinessText:string = Locale.Lookup( GameInfo.Happinesses[kCityData.Happiness].Name );
		pCityInstance.CitizenHappiness:SetText( happinessText );

		local warWearyValue:number = kCityData.AmenitiesLostFromWarWeariness;
		pCityInstance.WarWeariness:SetText( (warWearyValue==0) and "0" or "-"..tostring(warWearyValue) );

		pCityInstance.Status:SetText( kCityData.IsUnderSiege and Locale.Lookup("LOC_HUD_REPORTS_STATUS_UNDER_SEIGE") or Locale.Lookup("LOC_HUD_REPORTS_STATUS_NORMAL") );

		pCityInstance.Strength:SetText( tostring(kCityData.Defense) );
		pCityInstance.Damage:SetText( tostring(kCityData.Damage) );			
	end

	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();

	Controls.BottomYieldTotals:SetHide( true );
	Controls.BottomResourceTotals:SetHide( true );
	Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - 88);
end

-- ===========================================================================
--
-- ===========================================================================
function AddTabSection( name:string, populateCallback:ifunction )
	local kTab		:table				= m_tabIM:GetInstance();	
	kTab.Button[DATA_FIELD_SELECTION]	= kTab.Selection;

	local callback	:ifunction	= function()
		if m_tabs.prevSelectedControl ~= nil then
			m_tabs.prevSelectedControl[DATA_FIELD_SELECTION]:SetHide(true);
		end
		kTab.Selection:SetHide(false);
		populateCallback();
	end

	kTab.Button:GetTextControl():SetText( Locale.Lookup(name) );
	kTab.Button:SetSizeToText( 40, 20 );
    kTab.Button:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	m_tabs.AddTab( kTab.Button, callback );
end


-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg :number = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then 
		local uiKey = pInputStruct:GetKey();
		if uiKey == Keys.VK_ESCAPE then
			if ContextPtr:IsHidden()==false then
				Close();
				return true;
			end
		end		
	end
	return false;
end


-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInit( isReload:boolean )
	if isReload then		
		if ContextPtr:IsHidden()==false then
			Open();
		end
	end
	m_tabs.AddAnimDeco(Controls.TabAnim, Controls.TabArrow);	
end


-- ===========================================================================
function Resize()
	local topPanelSizeY:number = 30;

	if m_debugFullHeight then
		x,y = UIManager:GetScreenSizeVal();
		Controls.Main:SetSizeY( y - topPanelSizeY );
		Controls.Main:SetOffsetY( topPanelSizeY * 0.5 );
	end
end

-- ===========================================================================
--
-- ===========================================================================
function Initialize()

	Resize();	

	m_tabs = CreateTabs( Controls.TabContainer, 42, 34, 0xFF331D05 );
	--AddTabSection( "Test",								ViewTestPage );			--TRONSTER debug
	--AddTabSection( "Test2",								ViewTestPage );			--TRONSTER debug
	AddTabSection( "LOC_HUD_REPORTS_TAB_YIELDS",		ViewYieldsPage );
	AddTabSection( "LOC_HUD_REPORTS_TAB_RESOURCES",		ViewResourcesPage );
	AddTabSection( "LOC_HUD_REPORTS_TAB_CITY_STATUS",	ViewCityStatusPage );	

	m_tabs.SameSizedTabs(50);
	m_tabs.CenterAlignTabs(-10);		

	-- UI Callbacks
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetInputHandler( OnInputHandler, true );
	Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnCloseButton );
	Controls.CloseButton:RegisterCallback(	Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CollapseAll:RegisterCallback( Mouse.eLClick, OnCollapseAllButton );
	Controls.CollapseAll:RegisterCallback(	Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	
	-- Events
	LuaEvents.TopPanel_OpenReportsScreen.Add( OnTopOpenReportsScreen );
	LuaEvents.TopPanel_CloseReportsScreen.Add( OnTopCloseReportsScreen );
end
Initialize();
