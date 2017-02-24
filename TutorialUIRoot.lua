-- ===========================================================================
--	 _______ _     _ _______  _____   ______ _____ _______       
--      |    |     |    |    |     | |_____/   |   |_____| |     
--      |    |_____|    |    |_____| |    \_ __|__ |     | |_____	
--
-- ===========================================================================

include("TutorialScenarioBase");	-- The base tutorial scenario.


-- ===========================================================================
--	DEBUGGING
-- ===========================================================================

local isDebugInfoShowing		:boolean = (not UI.IsFinalRelease());	-- (false in retail builds) Set to true if working on building/debugging the tutorial for more information prompts around the screen
local isDebugVerbose			:boolean = false;						-- (false) when true, lots of logging will be output


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local COLOR_DEBUG_SEEN_ID		:number = 0xff909090;
local COLOR_DEBUG_ACTIVE		:number = 0xff99ffff;
local COLOR_DEBUG_NORMAL		:number = 0xfff0c8c8;
local DEBUG_CACHE_NAME			:string = "TutorialUIRoot";	--debug: hotload value restoring
local NOT_CHAINED				:number = -1;
local TUTORIAL_LEVEL_DISABLED	:number = -1;
local m_MovieStopEvent          :string;
local m_MovieBankGroup          :number = 0;

-- ===========================================================================
--	ENUMS
-- ===========================================================================

-- Type of item that appears in the advisor dialog
hstructure AdvisorItem
	Message			: string;		-- TXT key to look up for advisor message (if raised via an advisor)
	MessageAudio	: string;		-- Name of the accompanying audio to play with the message.
	Image			: string;		-- (optional) Name of texture used in image.
	OptionsNum		: number;		-- Number of options.
	Button1Text		: string;		-- TXT key to look up for button 1
	Button2Text		: string;		-- " " " 2
	Button1Func		: ifunction;	-- Callback on button 1
	Button2Func		: ifunction;	-- " " " 2
	CalloutHeader	: string;		-- TXT key to look up for callout header
	CalloutBody		: string;		-- TXT key to look up for callout body
	PlotCallback	: ifunction;	-- Function to return the ID of a world plot to which dialog will be anchored
	ShowPortrait	: boolean;		-- Whether or not the advisor portrait should appear in the dialog (expected when VO is played)
	UITriggers		: table;		-- IDs and/or Trigger names for the UI when advisor item is up.
end

-- Goals for the Goal dialog.
hstructure GoalItem
	Id				: string;		-- Id of item
	Text			: string;		-- Text to always display
	Tooltip			: string;		-- (optional) tooltip text
	IsCompleted		: boolean;		-- Is the goal completed?
	ItemId			: string;		-- For debugging, the id of the item that is setting the goal
	CompletedOnTurn	: number;		-- Which tutorial # this was completed on (required for auto-remove)
end

-- Overall tutorial definition           
hstructure TutorialDefinition
	Id				: string;		-- Id of scenario
	Bank			: table;		-- array of functions that when called populate tutorial items
end


hstructure TutorialItemMeta
	__index					: TutorialItemMeta		-- Pointer back to itself.  Required for lookup.

	new						: ifunction;
	destroy					: ifunction;
	Initialize				: ifunction;

	SetTutorialLevel		: ifunction;
	SetIsQueueable			: ifunction;
	SetIsEndOfChain			: ifunction;
	SetShouldMarkSeen		: ifunction;
	SetPrereqs				: ifunction;
	SetRaiseEvents			: ifunction;
	SetRaiseFunction		: ifunction;
	SetOpenFunction			: ifunction;
	SetAdvisorMessage		: ifunction;
	SetAdvisorAudio			: ifunction;
	SetAdvisorImage			: ifunction;
	SetShowPortrait			: ifunction;
	AddAdvisorButton		: ifunction;
	SetAdvisorCallout		: ifunction;
	SetAdvisorUITriggers	: ifunction;
	SetUITriggers			: ifunction;
	SetEnabledControls		: ifunction;
	SetDisabledControls		: ifunction;
	SetIsDoneEvents			: ifunction;
	SetIsDoneFunction		: ifunction;
	SetCleanupFunction		: ifunction;
	SetNextTutorialItemId	: ifunction;
	SetOverlayEnabled		: ifunction;
	AddGoal					: ifunction;
	SetCompletedGoals		: ifunction;
end

hstructure TutorialItem
	meta				: TutorialItemMeta;

	ScenarioName		: string;		-- Name for set of tutorials in this "scenario"
	ID					: string;		-- Tutorial enum ID
	TutorialLevel		: number;		-- At which player experience level does this message appear?
	IsQueueable			: boolean;		-- Whether or not this item can be queued for display at the end of the current chain.
	IsEndOfChain		: boolean;		-- If this item is the end of a chain, check for queued items.
	ShouldMarkSeen		: boolean;		-- Whether or not this item should be marked seen when being cleared.
	PrereqIDs			: table;		-- enum IDs of any prerequisite tutorial items
	RaiseListeners		: table;		-- Notifications which activate this Tutorial item
	IsRaisedFunc		: ifunction;	-- Function that evaulates if the tutorial should be raised
	OpenFunc			: ifunction;	-- Function that executes when the tutorial pops up
	AdvisorInfo			: AdvisorItem;	-- Information for the advisor pop-up which first occurs.
	UITriggers			: table;		-- IDs and/or Trigger names for the UI
	EnabledControls		: table;		-- IDs or tag hashes of enabled controls
	DisabledControls	: table;		-- IDs or tag hashes of disabled controls (guarnateed called after enable controls)
	LensTriggers		: table;		-- Which lenses to turn on	
	DoneListeners		: table;		-- Notification which trigger a check for being done (or blank for any listener)
	IsDoneFunc			: ifunction;	-- Function to evaluate when this is done.	
	CleanupFunc			: ifunction;	-- Function to signal after active tutorial item is removed from being active
	NextID				: string;		-- For chained messages
	OverlayEnabled		: boolean;		-- enable the overlay behind raised items
	Goals				: table;		-- Persistant goals (much like an RPG missions) which are set by this item
	GoalCompletedIDs	: table;		-- IDs of goals that are completed when this tutorial item is finished
end

-- Create one instance of the meta object as a global variable with the same name as the data structure portion.  
-- This allows us to do a TutorialItem:new, so the naming looks consistent.
TutorialItem = hmake TutorialItemMeta{};
TutorialItem.__index = TutorialItem;


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_isLoadScreenUp			: boolean		= true;
local m_preLoadEvents			: table			= {};								-- Table of events fired before player hits start button
local m_tutorialLevel			: number		= TutorialLevel.LEVEL_TBS_FAMILIAR;	-- Less than 0, it's off!
local m_isTutorialLevelLocked	: boolean		= false;							-- Is the tutorial level being forced to a value.
local m_queue					: table			= {};								-- Items queued until end of current chain.
local m_active					: TutorialItem	= nil;								-- Currently raised tutorial item
local m_unseen					: table			= {};								-- All unseen tutorial items
local m_listeners				: table			= {};
local m_lastRaiseListener		: string		= "";								-- Last listener to raise the tutorial
local m_currentScenarioName		: string;											-- Scenario currently active or being added to.
local m_isTutorialCheckDisabled	: boolean		= false;							-- Has a tutorial item forced checks to be (temporarly disabled)
local m_debugAddOrder			: table			= {};								-- DEBUG MODE ONLY: order of tutorial items added
local m_debugSeenItems			: table			= {};								-- DEBUG      ONLY: track seen items (so they can again become unseen)
local m_uiDebugItemList			: table			= {};								-- DEBUG MODE ONLY: ui list of instances
local m_isGoalsAutoRemove		: boolean		= false;							-- Are goals automatically removed (1 turn after completing)
local m_MovieStopCallback		: ifunction		= nil;								-- Function to callback once movie is stopped (or click stopped).
local m_beforeEveryOpen			: ifunction		= nil;								-- Function to run before every Open() is called
local m_turn					: number		= -1;									-- Track the current turn; required to prevent edge case where local player turn can be re-signaled with same turn when there are remaining moves for a unit.

local m_LockedProductionHash	:number = -1;	-- cached production type hash value for when production is locked during the tutorial
local m_LockedResearchHash		:number = -1;	-- cached research type hash value for when research is locked during the tutorial
local m_LockedUnitID			:number = -1;	-- cached unitID for when we want to lock a unit from selection


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function TutorialItem.new( self:TutorialItemMeta, ID:string )
    local o = hmake TutorialItem { };
    setmetatable( o, self );
	o:Initialize( ID, m_currentScenarioName );

	-- First time an item is added for this scenario; allocate table for it.
	if m_unseen[m_currentScenarioName] == nil then
		m_unseen[m_currentScenarioName] = {};
	end
	m_unseen[m_currentScenarioName][ ID ] = o;
	m_debugAddOrder[table.count(m_debugAddOrder)+1] = ID;
	return o;
end

-- ===========================================================================
function TutorialItem.destroy( self : TutorialItem )
	m_unseen[scenarioName][ self.ID ] = nil;
end

-- ===========================================================================
function TutorialItem.Initialize( self : TutorialItem, ID:string, scenarioName:string )

	if ID == nil then
		UI.DataError("Cannot create tutorial item, missing ID passed in.");
		return;
	end
	if scenarioName == nil or scenarioName == "" then
		UI.DataError("Cannot create tutorial item '"..ID.."', scenario has not been set yet with SetScenarioName().");
		return;
	end

	self.ID				= ID;
	self.ScenarioName	= scenarioName;
	self.TutorialLevel	= TutorialLevel.LEVEL_TBS_FAMILIAR;	-- for all by default
	self.IsQueueable	= false;
	self.IsEndOfChain	= false;
	self.ShouldMarkSeen = true;
	self.PrereqIDs		= {};
	self.RaiseListeners	= {};
	self.IsRaisedFunc	= function() return true; end;	-- By default, raises as soon as event is heard
	self.OpenFunc		= function() end;
	self.AdvisorInfo	= hmake AdvisorItem {
									Message			= ID.." message text not set",
									MessageAudio	= nil,
									OptionsNum		= 0,
									Button1Text		= ID.." button1 text not set",
									Button2Text		= nil,
									Button1Func		= nil,
									Button2Func		= nil,
									CalloutHeader   = ID.." header text not set",
									CalloutBody		= ID.." body text not set",
									PlotCallback	= nil,
									ShowPortrait	= false,
									UITriggers		= {} 
									};
	self.UITriggers		= {};
	self.EnabledControls= {};
	self.DisabledControls= {};
	self.LensTriggers	= {};
	self.DoneListeners	= {};
	self.IsDoneFunc		= function() return true; end;
	self.CleanupFunc	= function() return true; end;
	self.NextID			= "";
	self.OverlayEnabled = true;
end

-- ===========================================================================
function SetScenarioName( scenarioName:string )
	m_currentScenarioName = scenarioName;
end

-- ===========================================================================
function TutorialItem:SetTutorialLevel( tutorialLevel:number ) 
	self.TutorialLevel = tutorialLevel;
end

-- ===========================================================================
function TutorialItem:SetIsQueueable( isQueueable : boolean )
	self.IsQueueable = isQueueable;
end

-- ===========================================================================
function TutorialItem:SetIsEndOfChain( isEndOfChain : boolean )
	self.IsEndOfChain = isEndOfChain;
end

-- ===========================================================================
function TutorialItem:SetShouldMarkSeen( shouldMarkSeen : boolean )
	self.ShouldMarkSeen = shouldMarkSeen;
end

-- ===========================================================================
function TutorialItem:SetOverlayEnabled( enabled:boolean ) 
	self.OverlayEnabled = enabled;
end

-- ===========================================================================
--	Add goals to the existing list.
--	If not goals exist, this will create and raise the goal list.
-- ===========================================================================
function TutorialItem:AddGoal( goalId:string, goalText:string, goalTooltip:string )

	if self.Goals == nil then
		self.Goals = {};	-- Generate container in item if it doesn't exist
	else
		-- Make sure this item isn't inserting a goal twice.
		for _,goalItem in ipairs(self.Goals) do
			if goalItem.Id == goalId then
				UI.DataError("Tutorial item '"..self.ID.."' is attempting to define goal '"..goalId.."' to the tutorial but it already exists.  Text: '"..goalText.."'");
				return;
			end
		end
	end

	-- Add item
	local goalItem:GoalItem = hmake GoalItem {
		Id			= goalId,
		Text		= Locale.Lookup(goalText),
		Tooltip		= Locale.Lookup(goalTooltip),
		IsCompleted	= false,
		ItemId		= self.ID };

	table.insert( self.Goals, goalItem );
end


-- ===========================================================================
--	Set the ID(s) of the goals which will be considered completed if this
--	tutorial item is done.
-- ===========================================================================
function TutorialItem:SetCompletedGoals( ... )
	if self.GoalCompletedIDs == nil then 
		self.GoalCompletedIDs = {};
	end
	for i,v in ipairs(arg) do
		table.insert(self.GoalCompletedIDs,v);
	end
	return self;
end

-- ===========================================================================
--	Which tutorial item(s) must have been completely before this is
--	elidgible.
-- ===========================================================================
function TutorialItem:SetPrereqs( ... ) 	
	if self.PrereqIDs == nil then 
		self.PrereqIDs = {};
	end
	for i,v in ipairs(arg) do
		table.insert(self.PrereqIDs,v);
	end
	return self;
end

-- ===========================================================================
--	Which events to listen on that could raise this tutorial item.
-- ===========================================================================
function TutorialItem:SetRaiseEvents( ... ) 
	for i,v in ipairs(arg) do
		table.insert(self.RaiseListeners, v);
	end
	return self;
end

-- ===========================================================================
function TutorialItem:SetRaiseFunction( func : ifunction )
	self.IsRaisedFunc = func;
	return self;
end

-- ===========================================================================
function TutorialItem:SetOpenFunction( func : ifunction )
	self.OpenFunc = func;
	return self;
end

-- ===========================================================================
-- ===========================================================================
function TutorialItem:SetAdvisorMessage( text : string )
	self.AdvisorInfo.Message = Locale.Lookup(text);
	return self;
end

-- ===========================================================================
-- ===========================================================================
function TutorialItem:SetAdvisorAudio( audioName : string )
	self.AdvisorInfo.MessageAudio = audioName;
	return self;
end



-- ===========================================================================
-- ===========================================================================
function TutorialItem:SetAdvisorImage( textureName : string )
	self.AdvisorInfo.Image = textureName;
	return self;
end

-- ===========================================================================
function TutorialItem:SetShowPortrait( showPortrait : boolean )
	self.AdvisorInfo.ShowPortrait = showPortrait;
	return self;
end

-- ===========================================================================
--	Sets an advisor info box that points to a hex in the 3d world
--	header				What appears on the title of the box
--	body				Main context of the box
--	getPlotIDFunction	A function, that when called, will determine the plot
--						index to show the callout pointer.
-- ===========================================================================
function TutorialItem:SetAdvisorCallout( header :string, body :string, getPlotIDFunction :ifunction )
	self.AdvisorInfo.CalloutHeader = Locale.Lookup(header);
	self.AdvisorInfo.CalloutBody = Locale.Lookup(body);
	self.AdvisorInfo.PlotCallback = getPlotIDFunction;
end

-- ===========================================================================
function TutorialItem:AddAdvisorButton( text : string, callback : ifunction )
	self.AdvisorInfo.OptionsNum = self.AdvisorInfo.OptionsNum + 1;
	if self.AdvisorInfo.OptionsNum < 3 then
		self.AdvisorInfo["Button"..tostring(self.AdvisorInfo.OptionsNum).."Text"]= Locale.Lookup(text);
		self.AdvisorInfo["Button"..tostring(self.AdvisorInfo.OptionsNum).."Func"]= callback;
	else
		UI.DataError("Attempt to add advisor option #"..tostring(self.AdvisorInfo.OptionsNum).." is higher than the max.  Text of option: \""..tostring(text).."\"");
	end
	return self.AdvisorInfo;
end

-- ===========================================================================
--	The IDs of general UI elements or tutorial-specifc IDs to activate when
--	this item's advisor box is up.
-- ===========================================================================
function TutorialItem:SetAdvisorUITriggers( ... )
	for i,v in ipairs(arg) do
		table.insert(self.AdvisorInfo.UITriggers, v);
	end
	return self;
end

-- ===========================================================================
--	The IDs of general UI elements or tutorial-specifc IDs to activate when
--	this tutorial goes up.
-- ========================================================================
function TutorialItem:SetUITriggers( ... )
	for i,v in ipairs(arg) do
		table.insert(self.UITriggers, v);
	end
	return self;
end

-- ===========================================================================
--	The IDs hash or tag of general UI elements to activate when
--	this tutorial goes up.
-- ========================================================================
function TutorialItem:SetEnabledControls( ... )
	for i,v in ipairs(arg) do
		table.insert(self.EnabledControls, v);
	end
	return self;
end

-- ===========================================================================
--	The IDs hash or tag of general UI elements to de-activate when
--	this tutorial goes up. (Such as input shields that enable controls above
--	might has activated.)
-- ===========================================================================
function TutorialItem:SetDisabledControls( ... )
	for i,v in ipairs(arg) do
		table.insert(self.DisabledControls, v);
	end
	return self;
end

-- ===========================================================================
function TutorialItem:SetIsDoneEvents( ... )
	for i,v in ipairs(arg) do
		table.insert(self.DoneListeners, v);
	end
	return self;
end

-- ===========================================================================
function TutorialItem:SetIsDoneFunction( func : ifunction )
	self.IsDoneFunc = func;
	return self;
end

-- ===========================================================================
function TutorialItem:SetCleanupFunction( func : ifunction )
	self.CleanupFunc = func;
	return self;
end

-- ===========================================================================
function TutorialItem:SetNextTutorialItemId( ID : string )
	self.NextID = ID;
	return self;
end


-- ===========================================================================
--	Interactive portion of a tutorial where the advisor box should be
--	hidden and the player is to interact with a particular item on the screen.
-- ===========================================================================
function RaiseDetailedTutorial( item:TutorialItem )
	if table.count(item.UITriggers) < 1 then
		DeActivateItem( item, true );
		return;
	end
	
	for _,trigger:string in ipairs(item.UITriggers) do
		UITutorialManager:ShowControlsByID( trigger, true );	
	end

	-- Explicitly enable a tree of controls (common)
	for _,value in ipairs(item.EnabledControls) do
		if type(value) == "number" then
			UITutorialManager:EnableControlsByIdOrTag( nil, value, true );		-- via hash
		else
			UITutorialManager:EnableControlsByIdOrTag( value, nil, true );		-- via ID
		end
	end
	
	-- Explicitly disable a tree of controls (uncommon, such as controls used as "input shields")
	for _,hashVal:number in ipairs(item.DisabledControls) do
		UITutorialManager:EnableControlsByIdOrTag( nil, hashVal, false );	
	end
	UITutorialManager:EnableOverlay( item.OverlayEnabled );

	-- ====================================
	-- ====================================
	function RealizeDebugTutorialHeader( instance:table)
		instance.TutorialID:SetText("2D Overlay enabled: " .. (UITutorialManager:IsOverlayEnabled() and "TRUE" or "false") );
	end
	
	if isDebugInfoShowing then
		RealizeDebugTutorialHeader(m_uiDebugItemList["_HEADER_OVERLAY"]);		
		m_uiDebugItemList["_HEADER_OVERLAY"].TutorialID:RegisterCallback( Mouse.eLClick, 
			function() 
				UITutorialManager:EnableOverlay( not UITutorialManager:IsOverlayEnabled() ); 
				RealizeDebugTutorialHeader(m_uiDebugItemList["_HEADER_OVERLAY"]);				
			end );
	end
end

-- ===========================================================================
function RemoveLoadScreenClosedWatch()
	m_isLoadScreenUp = false;
	Events.LoadScreenClose.Remove( OnLoadScreenClose );

	-- Check if any of the events fired before the tutorial raises are suppose
	-- to raise a tutorial event...
	if m_active == nil then 
		for _,eventName in ipairs(m_preLoadEvents) do
			TutorialCheck(eventName);
			if m_active ~= nil then 
				break;
			end
		end
	end
	m_preLoadEvents = {};
end

-- ===========================================================================
--	Force the system into a certain tutorial level.
-- ===========================================================================
function ForceEnableTutorialLevel()
	m_isTutorialLevelLocked = true;
	m_tutorialLevel			= TutorialLevel.LEVEL_TBS_FAMILIAR;
	UserConfiguration.TutorialLevel(m_tutorialLevel);
end


-- ===========================================================================
--	Functions called by scenario that may change default UI behavior in
--	other screens.
-- ===========================================================================
function ActivateInputFiltering()		LuaEvents.TutorialUIRoot_FilterKeysActive();					end	-- Guard againt unwanted input
function CloseGoals()					LuaEvents.TutorialUIRoot_CloseGoals();							end	-- Close the tutorial goals window
function DisableInputFiltering()		LuaEvents.TutorialUIRoot_FilterKeysDisabled();					end	-- Allow normal input processing
function DisableSettleHintLens()		LuaEvents.TutorialUIRoot_DisableSettleHintLens();				end	-- Do not show lens (overlay) when settler is settling
function DisableTechAndCivicPopups()	LuaEvents.TutorialUIRoot_DisableTechAndCivicPopups();			end	-- Turn off the popups that occur when obtaining a civic, tech (or boost)
function DisableTutorialCheck()			m_isTutorialCheckDisabled = true;								end	-- Temporary turn off tutorial checks; usually to minimize side-effects during an open/close operation.
function EnableTechAndCivicPopups()		LuaEvents.TutorialUIRoot_EnableTechAndCivicPopups();			end	-- Turn back on popups which occur when obtaining a civic, tech (or boost)
function EnableTutorialCheck()			m_isTutorialCheckDisabled = false;								end	-- Set to default state, so tutorial checks can occur.
function GoalsAutoRemove()				m_isGoalsAutoRemove = true;										end -- Auto-remove goals 1 turn after completed
function OpenGoals()					LuaEvents.TutorialUIRoot_OpenGoals();							end	-- (Re-)opens goals if they were previously closed AND there are goals remaining.
function SetSimpleInGameMenu(isSimple)	LuaEvents.TutorialUIRoot_SimpleInGameMenu(isSimple);			end	-- Signal to have a simplified in-game pause menu.


-- ===========================================================================
--	Next turn button clicking (mainly/only throught the action panel) should
--	consume input for a frame or two in order for the tutorial to have a
--	chance to raise any blockers.  
-- ===========================================================================
function SetSlowNextTurnEnable( isEnabled:boolean )
	LuaEvents.Tutorial_SlowNextTurnEnable( isEnabled );
end


-- ===========================================================================
-- (nil) Set the function called before every item is opened
-- ===========================================================================
function SetFunctionBeforeEveryOpen(func) 
	m_beforeEveryOpen = func;
end	

-- ===========================================================================
-- Disable unit commands/operations for one or all units
-- ===========================================================================
function DisableUnitAction( actionType:string, unitType:string )	
	WriteDisabledUnitAction(actionType, unitType);
	if unitType == nil then
		LuaEvents.TutorialUIRoot_DisableActionForAll( actionType );
	else
		LuaEvents.TutorialUIRoot_DisableActions( actionType, unitType );
	end
end	

-- ===========================================================================
--	Enable Disable unit commands/operations for one or all units
-- ===========================================================================
function EnableUnitAction( actionType:string, unitType:string )		
	EraseDisabledUnitAction(actionType, unitType);
	if unitType == nil then
		LuaEvents.TutorialUIRoot_EnableActionForAll( actionType );
	else
		LuaEvents.TutorialUIRoot_EnableActions( actionType, unitType );
	end
end	

-- ===========================================================================
--	Prevent a unit type from going to a particular hex
-- ===========================================================================
function AddUnitHexRestriction( unitType:string, plotX:number, plotY:number )
	local plotId:number = Map.GetPlot( plotX, plotY ):GetIndex();
	WriteUnitHex( "UnitHexRestrictions", unitType, plotX, plotY );
	LuaEvents.Tutorial_AddUnitHexRestriction( unitType, {plotId} );
end

-- ===========================================================================
function RemoveUnitHexRestriction( unitType:string, plotX:number, plotY:number )
	local plotId:number = Map.GetPlot( plotX, plotY ):GetIndex();
	EraseUnitHex( "UnitHexRestrictions", unitType, plotX, plotY );
	LuaEvents.Tutorial_RemoveUnitHexRestriction( unitType,  {plotId} );
end

-- ===========================================================================
function ClearAllUnitHexRestrictions()	
	EraseUnitHex( "UnitHexRestrictions" );
	LuaEvents.Tutorial_ClearAllUnitHexRestrictions();
end

-- ===========================================================================
--	Prevent a specific unit type from being moved via 
-- ===========================================================================
function AddMapUnitMoveRestriction( unitType:string )
	LuaEvents.Tutorial_AddUnitMoveRestriction( unitType );
	WriteUnitHex( "UnitMoveRestrictions", unitType, -1, -1 );
end

-- ===========================================================================
--	Prevent a specific unit type from being selected.
-- ===========================================================================
function RemoveMapUnitMoveRestriction( unitType:string )
	LuaEvents.Tutorial_RemoveUnitMoveRestrictions( unitType );
	EraseUnitHex( "UnitMoveRestrictions", unitType, -1, -1 );
end


-- ===========================================================================
--	SERIALIZE
--	Write a blocked action for a unit.
-- ===========================================================================
function WriteDisabledUnitAction( actionName:string, optionalUnitType:string)
	local unitTypeName:string = optionalUnitType ~= nil and optionalUnitType or "_ALL";
	
	local pParameters :table = UI.GetGameParameters():Get("UnitActionRestrictions");
	if pParameters == nil then 
		pParameters = UI.GetGameParameters():Add("UnitActionRestrictions");
	end
	
	if pParameters ~= nil then

		local pData:table = pParameters:Get( unitTypeName );
		if pData == nil then
			pData = pParameters:Add( unitTypeName );
		end
		for i,v in ipairs(pData) do
			if v == actionName then
				UI.DataError("Could not WriteDisabledUnitAction 'UnitActionRestrictions' since it is already set!: "..actionName.." for "..unitTypeName);
				return;
			end
		end		
		if isDebugVerbose then print("TUTSERIALIZE Write: [UnitActionRestrictions]> ["..unitTypeName.."]= "..actionName); end
		pData:AppendValue( actionName );
	else		
		UI.DataError("Could not WriteDisabledUnitAction 'UnitActionRestrictions': "..actionName.." for "..unitTypeName);
	end
end

-- ===========================================================================
--	SERIALIZE
--	Clear a blocked action for a unit.
-- ===========================================================================
function EraseDisabledUnitAction( actionName:string, optionalUnitType:string)
	local unitTypeName:string = optionalUnitType ~= nil and optionalUnitType or "_ALL";
	
	local pParameters :table = UI.GetGameParameters():Get("UnitActionRestrictions");
	if pParameters ~= nil then 
		local pData:table = pParameters:Get( unitTypeName );
		if pData == nil then
			UI.DataError("Could not EraseDisabledUnitAction 'UnitActionRestrictions', unitType never serialized: "..actionName.." for "..unitTypeName);
			return
		end
		local count :number = pData:GetCount();
		for i=0,count-1,1 do
			if pData:GetValueAt(i) == actionName then
				if isDebugVerbose then print("TUTSERIALIZE Erase: [UnitActionRestrictions]> ["..unitTypeName.."]% "..actionName.."  @"..tostring(i)); end
				pData:RemoveAt( i );
				return;
			end
		end		
	else		
		UI.DataError("Could not EraseDisabledUnitAction 'UnitActionRestrictions': "..actionName.." for "..unitTypeName);
	end
end


-- ===========================================================================
--	SERIALIZE
--	Add a unit's hex to disk
-- ===========================================================================
function WriteUnitHex( name:string, unitType:string, plotX:number, plotY:number )
	local pParameters :table = UI.GetGameParameters():Get(name);
	if pParameters == nil then 
		pParameters = UI.GetGameParameters():Add(name);
	end	
	if pParameters ~= nil then
		local pData:table = pParameters:Get( unitType );
		if pData == nil then
			pData = pParameters:Add( unitType );
		end
		pData:AppendValue( plotX );
		pData:AppendValue( plotY );
	else
		UI.DataError("Could not WriteUnitHex '"..name.."': "..unitType..",   plot: "..tostring(plotX)..", "..tostring(plotY));
	end
end

-- ===========================================================================
--	SERIALIZE
--	Erase a serialize value for a unit/hex relationship from disk
-- ===========================================================================k
function EraseUnitHex( name:string, unitType:string, plotX:number, plotY:number )
	local pParameters :table = UI.GetGameParameters():Get(name);
	if pParameters ~= nil then
		if unitType == nil then
			UI.GetGameParameters():Remove(name);
			return;
		end
		local pData:table = pParameters:Get( unitType );
		if pData ~= nil then
			if plotX == -1 and plotY == -1 then
				pParameters:Remove( unitType );
				return;
			end
			local count:number = pData:GetCount();
			for i=1,count,2 do
				if plotX == pData[i] and plotY == pData[i+1] then	-- 1 based
					pData:RemoveAt(i);								-- 0 based
					pData:RemoveAt(i-1);
					return;
				end
			end
		end
	else
		UI.DataError("Could not EraseUnitHex '"..name.."': "..unitType..",   plot: "..tostring(plotX)..", "..tostring(plotY));
	end
end

-- ===========================================================================
--	SERIALIZE
--	Serialize unit hexes restrictions from disk
-- ===========================================================================
function ReadUnitHexRestrictions()
	local pParameters :table = UI.GetGameParameters():Add("UnitHexRestrictions");
	if pParameters ~= nil then
		for i:number = 0, pParameters:GetCount()-1, 1 do
		local unitType		:string = pParameters:GetKeyAt(i);
		local kCoordinates	:table  = pParameters:GetValueAt(i);
			if kCoordinates ~= nil then				
				local count :number = table.count(kCoordinates);
				for coor = 1,count,2 do
					local plotX :number = kCoordinates[coor];
					local plotY :number = kCoordinates[coor+1];
					local plotId:number = Map.GetPlot( plotX, plotY ):GetIndex();
					LuaEvents.Tutorial_AddUnitHexRestriction( unitType, {plotId} );
				end				
			else
				UI.DataError("Missing coordinates while deseralizing Unit hex restrictions for '"..unitType.."'");
			end
		end
	end
end

-- ===========================================================================
--	SERIALIZE
--	Serialize unit move restrictions from disk
-- ===========================================================================
function ReadUnitMoveRestrictions()
	local pParameters :table = UI.GetGameParameters():Get("UnitMoveRestrictions");
	if pParameters ~= nil then
		for i:number = 0, pParameters:GetCount()-1, 1 do
		local unitType = pParameters:GetKeyAt(i);
			LuaEvents.Tutorial_AddUnitMoveRestriction( unitType );
		end
	end
end

-- ===========================================================================
-- Locked Research Handlers
-- ===========================================================================
function LockResearch()
	local ePlayerID = Game.GetLocalPlayer();
	local kPlayer:table = Players[ePlayerID];
	if (kPlayer ~= nil) then
		local playerTechs = kPlayer:GetTechs();
		local eCurrentResearch = playerTechs:GetResearchingTech();
		m_LockedResearchHash = GameInfo.Technologies[eCurrentResearch].Hash;
	end	
end

------------------------------------------------------------------------------
function UnlockResearch()
	m_LockedResearchHash = -1;
end

------------------------------------------------------------------------------
function ResetResearch()
	if (m_LockedResearchHash ~= -1) then
		local tParameters :table = {};
		tParameters[PlayerOperations.PARAM_TECH_TYPE] = m_LockedResearchHash;
		tParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE;
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.RESEARCH, tParameters);
	end
end

------------------------------------------------------------------------------
function CheckLockedResearch()
	if (m_LockedResearchHash ~= -1) then
		local ePlayerID = Game.GetLocalPlayer();
		local kPlayer:table = Players[ePlayerID];
		if (kPlayer ~= nil) then
			local playerTechs = kPlayer:GetTechs();
			local eCurrentResearch = playerTechs:GetResearchingTech();
			local currentResearchHash = GameInfo.Technologies[eCurrentResearch].Hash;
			if (currentResearchHash ~= m_LockedResearchHash) then
				TutorialCheck("IllegalResearchChange")
			end
		end	
	end
end

-- ===========================================================================
-- Locked Production Handlers
-- ===========================================================================
function LockProduction()
	local ePlayerID = Game.GetLocalPlayer();
	local kPlayer:table = Players[ePlayerID];
	if (kPlayer ~= nil) then
		if (kPlayer ~= nil) then
			local playerCities	= kPlayer:GetCities();
			local capitalCity	= playerCities:GetCapitalCity();
			if capitalCity ~= nil then
				local pBuildQueue = capitalCity:GetBuildQueue();
				m_LockedProductionHash = pBuildQueue:GetCurrentProductionTypeHash();
			end
		end
	end	
end

------------------------------------------------------------------------------
function UnlockProduction()
	m_LockedProductionHash = -1;
end

------------------------------------------------------------------------------
function ResetProduction()
	if (m_LockedProductionHash ~= -1) then
		local tParameters = {}; 

		local productionCategory = GameInfo.Types[m_LockedProductionHash].Kind;
		if (productionCategory == "KIND_UNIT") then
			tParameters[CityOperationTypes.PARAM_UNIT_TYPE] = m_LockedProductionHash;  
		elseif (productionCategory == "KIND_BUILDING") then
			tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = m_LockedProductionHash;  	
		elseif (productionCategory == "KIND_DISTRICT") then
			tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = m_LockedProductionHash;  
		end

		tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;

		local ePlayerID = Game.GetLocalPlayer();
		local kPlayer:table = Players[ePlayerID];
		if (kPlayer ~= nil) then
			local playerCities	= kPlayer:GetCities();
			local capitalCity	= playerCities:GetCapitalCity();
			CityManager.RequestOperation(capitalCity, CityOperationTypes.BUILD, tParameters);
		end
	end
end

------------------------------------------------------------------------------
function CheckLockedProduction()
	if (m_LockedProductionHash ~= -1) then
		local ePlayerID = Game.GetLocalPlayer();
		local kPlayer:table = Players[ePlayerID];
		if (kPlayer ~= nil) then
			local playerCities	= kPlayer:GetCities();
			local capitalCity	= playerCities:GetCapitalCity();

			if capitalCity ~= nil then
				local pBuildQueue = capitalCity:GetBuildQueue();
				local hCurrentProduction = pBuildQueue:GetCurrentProductionTypeHash();

				if (hCurrentProduction ~= m_LockedProductionHash) then
					TutorialCheck("IllegalProductionChange");
				end
			end
		end	
	end
end

function SelectAndCenterOnUnit( unitType :string )
	local ePlayerID = Game.GetLocalPlayer();
	local kPlayer:table = Players[ePlayerID];
	if (kPlayer ~= nil) then
		local playerUnits = kPlayer:GetUnits();
		for i, unit in playerUnits:Members() do
			local unitTypeName = UnitManager.GetTypeName(unit)
			if (unitTypeName == unitType) then
				UI.SelectUnit(unit);
				UI.LookAtPlot(unit:GetX(), unit:GetY());
			end
		end
	end
end

-- ===========================================================================
-- Locked Unit Handlers
-- ===========================================================================
function LockUnit( unitID:number )
	m_LockedUnitID = unitID;
end

function UnlockUnit()
	m_LockedUnitID = -1;
end

function CheckLockedUnit()
	if (m_LockedUnitID ~= -1) then
		local ePlayerID = Game.GetLocalPlayer();
		local kPlayer:table = Players[ePlayerID];
		if (kPlayer ~= nil) then
			local pLockedUnit = UnitManager.GetUnit(ePlayerID, m_LockedUnitID);
			if (pLockedUnit ~= nil) then
				UI.DeselectUnit(pLockedUnit);
			end
		end
	end
end

-- ===========================================================================
--	|_|_______|_|
--  |_|       |_|	
--  |_|  . .  |_|	Play a full screen (Bink) movie.
--  |_|  \_/  |_|
--  |_|_______|_|
--  |_|       |_|
-- ===========================================================================
function PlayFullScreenMovie( fileName:string, audioBankGroup:number, audioStart:string, audioStop:string, isSkippable:boolean, finishPlayingCallback:ifunction )
	
	LuaEvents.TutorialUIRoot_CloseGoals();

    m_MovieBankGroup = audioBankGroup;
    if audioBankGroup ~= -1 then
        UI.LoadSoundBankGroup(audioBankGroup);
    end
		
	if isSkippable then
		Controls.TutorialMovieContainer:RegisterCallback( Mouse.eLClick, OnClickStopTutorialMovie );
	else
		Controls.TutorialMovieContainer:ClearCallback( Mouse.eLClick );
	end
	Controls.TutorialMovieContainer:SetHide( false );

	if finishPlayingCallback ~= nil then
		m_MovieStopCallback = finishPlayingCallback;
	else
		m_MovieStopCallback = function() end;
	end
	
	Controls.TutorialMovie:SetMovie( fileName );
	Controls.TutorialMovie:SetMovieFinishedCallback( OnMoviePlaybackFinish );	
	Controls.TutorialMovie:Play();

    m_MovieStopEvent = audioStop;
    UI.PlaySound(audioStart);
end

-- ===========================================================================
function StopMovie()	
	Controls.TutorialMovieContainer:ClearCallback(  Mouse.eLClick );
	Controls.TutorialMovieContainer:SetHide( true );
	LuaEvents.TutorialUIRoot_OpenGoals();
    UI.PlaySound(m_MovieStopEvent);
    if m_MovieBankGroup ~= -1 then
        UI.UnloadSoundBankGroup(m_MovieBankGroup);
    end
end

-- ===========================================================================
function OnMoviePlaybackFinish()
	StopMovie();	
	m_MovieStopCallback();	
end

-- ===========================================================================
function OnClickStopTutorialMovie()
	StopMovie();
	m_MovieStopCallback();
end


-- ===========================================================================
function ShowWorldPointer(plotID:number, direction:string, offset:number, itemHead:string, itemBody:string)
	LuaEvents.TutorialUIRoot_ShowWorldPointer(plotID, direction, offset, itemHead, itemBody);
end
function HideWorldPointer()
	LuaEvents.TutorialUIRoot_HideWorldPointer();
end


-- ===========================================================================
--	Helper for initializing listeners.
--	If a match exists between listenerName and notificationName, the item is
--	added to the listeners.
--
--	listenerName,		Name of the (game) event to listen to.
--	notificationName,	Name of the specific notification from the item.
--	item,				Tutorial item
-- ===========================================================================
function AddWithCheckToListener( listenerName:string, notificationName:string, item:TutorialItem )
	if m_listeners[listenerName] == nil then
		m_listeners[listenerName] = {};
	end
	if notificationName == listenerName then
		-- There is a match, add the table of listeners this item (for the given scenario).
		if m_listeners[listenerName][item.ScenarioName] == nil then
			m_listeners[listenerName][item.ScenarioName] = {};
		end
		m_listeners[listenerName][item.ScenarioName][item.ID] = item;
	end	
end

-- Force an item to be checked on a specific listener.
function AddToListener( listenerName:string, item:TutorialItem )
	AddWithCheckToListener( listenerName, listenerName, item );
end


-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnInit( isHotload )
	if isHotload then
		-- Note: m_unseen will be blown away by the cached version from the hotload...		
		LuaEvents.GameDebug_GetValues( DEBUG_CACHE_NAME );
		m_isLoadScreenUp = false;
	end

	-- Populate listeners with all the unseen tutorial items.
	for scenario,list in pairs( m_unseen ) do
		for id,item in pairs( list ) do

			-- Check if item is raised on a specific listener or ANY listener.
			if item.RaiseListeners == nil or table.count(item.RaiseListeners) == 0 then
				-- Raised on any listener; so add to all...
				AddToListener("CityAddedToMap",					item );
				AddToListener("CityProductionChanged",			item );
				AddToListener("CityProductionChanged_Warrior",	item );
				AddToListener("CityProductionChanged_Builder",  item );
				AddToListener("CityProductionChanged_Monument",	item );
				AddToListener("CityProductionChanged_Settler",	item );
				AddToListener("CityProductionChanged_Slinger",	item );
				AddToListener("CityProductionChanged_Campus",	item );
				AddToListener("CityProductionChanged_Library",	item );
				AddToListener("CityProductionCompleted",		item );
				AddToListener("CapitalCityProductionCompleted",	item );
				AddToListener("CapitalWarriorProductionCompleted",	item );
				AddToListener("CapitalBuilderProductionCompleted",	item );
				AddToListener("CapitalSettlerProductionCompleted",	item );
				AddToListener("CapitalSlingerProductionCompleted",	item );
				AddToListener("CapitalMonumentProductionCompleted",	item );
				AddToListener("CapitalCampusProductionCompleted",	item );
				AddToListener("CapitalWallsProductionCompleted",	item );
				AddToListener("BarracksProductionCompleted",		item );
				AddToListener("StonehengeProductionCompleted",		item );
				AddToListener("RangedUnitProductionCompleted",		item );
				AddToListener("SiegeUnitProductionCompleted",		item );
				AddToListener("CityPopulationFirstChange",		item );
				AddToListener("CityPopulationGreaterThanFive",	item );
				AddToListener("ImprovementAddedToMap",			item );
				AddToListener("BarbarianImprovementActivated",	item );
				AddToListener("DiplomacyStatement",				item );
				AddToListener("DiplomacyMeet",					item );
				AddToListener("DiplomacyMeetMajors",			item );
				AddToListener("DiploScene_SceneClosed",			item );
				AddToListener("DiploActionView",				item );
				AddToListener("ImprovementAddedToSecondCity",	item );
				AddToListener("ImprovementPillaged",			item );
				AddToListener("NaturalWonderPopupClosed",		item );
				AddToListener("WorldRankingsOpened",			item );
				AddToListener("WorldRankingsClosed",			item );
				AddToListener("ResearchChanged",				item );
				AddToListener("EndTurnDirty",					item );
				AddToListener("LocalPlayerTurnEnd",				item );
				AddToListener("LoadScreenClose",				item );
				AddToListener("LocalPlayerTurnBegin",			item );
				AddToListener("GreatPersonPoint",				item );
				AddToListener("Bankrupt",						item );
				AddToListener("ShouldFoundSecondCity",			item );
				AddToListener("HasInfluenceToken",				item );
				AddToListener("ResearchCompleted",				item );
				AddToListener("FaithChanged",					item );
				AddToListener("MoneySurplus",					item );
				AddToListener("PantheonAvailable",				item );
				AddToListener("PantheonFounded",				item );
				AddToListener("DawnOfCivilizationResearchCompleted",	item );
				AddToListener("MiningResearchCompleted",		item );
				AddToListener("PotteryResearchCompleted",		item );
				AddToListener("IrrigationResearchCompleted",	item );
				AddToListener("WritingResearchCompleted",		item );
				AddToListener("ShipbuildingResearchCompleted",	item );
				AddToListener("SailingResearchCompleted",		item );
				AddToListener("ReplaceablePartsResearchCompleted",		item );
				AddToListener("RadioResearchCompleted",		item );
				AddToListener("ScientificTheoryResearchCompleted",		item );
				AddToListener("RocketryResearchCompleted",		item );
				AddToListener("DistrictUnlocked",				item );
				AddToListener("WallsUnlocked",					item );
				AddToListener("CivicCompleted",					item );
				AddToListener("ForeignTradeCivicCompleted",		item );
				AddToListener("CodeOfLawsCivicCompleted",		item );
				AddToListener("PoliticalPhilosophyCivicCompleted", item );
				AddToListener("NationalismCivicCompleted",		item );
				AddToListener("MobilizationCivicCompleted",		item );
				AddToListener("DiplomaticServiceCivicCompleted", item );
				AddToListener("UrbanizationCivicCompleted",		item );
				AddToListener("FeudalismCivicCompleted",		item );
				AddToListener("ConservationCivicCompleted",		item );
				AddToListener("UnitSelectionChanged",			item );
				AddToListener("UnitMoveComplete",				item );
				AddToListener("ZocUnitMoveComplete",			item );
				AddToListener("SettlerMoveComplete",			item );
				AddToListener("WarriorMoveComplete",			item );
				AddToListener("WarriorFoundGoodyHut",			item );
				AddToListener("UnitKilledInCombat",				item );
				AddToListener("ScoutUnitAddedToMap",			item );
				AddToListener("GreatGeneralAddedToMap",			item );
				AddToListener("GreatAdmiralAddedToMap",			item );
				AddToListener("GreatEngineerAddedToMap",		item );
				AddToListener("GreatMerchantAddedToMap",		item );
				AddToListener("GreatProphetAddedToMap",			item );
				AddToListener("GreatScientistAddedToMap",		item );
				AddToListener("GreatWriterAddedToMap",			item );
				AddToListener("GreatArtistAddedToMap",			item );
				AddToListener("GreatMusicianAddedToMap",		item );
				AddToListener("TurnBlockerChooseProduction",	item );
				AddToListener("ResearchChooser_ForceHideWorldTracker", item);
				AddToListener("ProductionPanelClose",			item );
				AddToListener("ProductionPanelOpen",			item );
				AddToListener("BarbarianVillageDiscovered",		item );
				AddToListener("BarbarianDiscovered",			item );
				AddToListener("LowAmenitiesNotificationAdded",	item );
				AddToListener("HousingLimitNotificationAdded",	item );
				AddToListener("RelicCreatedNotificationAdded",	item );
				AddToListener("CitystateQuestGiven",			item );
				AddToListener("GreatPersonAvailable",			item );
				AddToListener("ProductionPanelViaCityOpen",		item );
				AddToListener("GoodyHutDiscovered",				item );
				AddToListener("BuilderChargesDepleted",			item );
				AddToListener("BuilderChargesOneRemaining",		item );
				AddToListener("ImprovementsBuilt3",				item );
				AddToListener("TradeRouteAddedToMap",			item );
				AddToListener("UnitPromotionAvailable",			item );
				AddToListener("BuildingPlacementInterfaceMode",	item );
				AddToListener("DistrictPlacementInterfaceMode",	item );
				AddToListener("ScoutMoved",						item );
				AddToListener("GovernmentScreenOpened",			item );
				AddToListener("GovernmentPoliciesOpened",		item );
				AddToListener("GovernmentPolicyChanged",		item );
				AddToListener("TeamVictory",					item );
				AddToListener("GoodyHutReward",					item );
				AddToListener("CivicsTreeOpened",				item );
				AddToListener("CivicsTreeClosed",				item );
				AddToListener("CivicChanged",					item );
				AddToListener("MultiMoveToCity",				item );
				AddToListener("TechTreeOpened",					item );
				AddToListener("TechTreeClosed",					item );
				AddToListener("ReligionPanelOpened",			item );
				AddToListener("ReligionPanelClosed",			item );
				AddToListener("GreatPeopleOpened",				item );
				AddToListener("GreatPeopleClosed",				item );
				AddToListener("CampusPlaced",					item );
				AddToListener("HangingGardensPlaced",			item );
				AddToListener("WorldRankingsClosed",			item );
				AddToListener("IllegalResearchChange",			item );
				AddToListener("IllegalProductionChange",		item );
				AddToListener("TutorialWarDeclared",			item );
				AddToListener("TradeRouteAdded",				item );
				AddToListener("TradeUnitCreated",				item );
				AddToListener("TradeRouteChooserOpened",		item );
				AddToListener("TradeRouteChooserClosed",		item );
				AddToListener("TradeRouteConsidered",			item );
			else
				-- Raised on a specific listener
				for _,notificationName in ipairs( item.RaiseListeners ) do
					AddWithCheckToListener("CityAddedToMap",				notificationName, item );
					AddWithCheckToListener("CityProductionChanged",			notificationName, item );
					AddWithCheckToListener("CityProductionChanged_Warrior",	notificationName, item );
					AddWithCheckToListener("CityProductionChanged_Builder",	notificationName, item );
					AddWithCheckToListener("CityProductionChanged_Monument", notificationName, item );
					AddWithCheckToListener("CityProductionChanged_Settler",	notificationName, item );
					AddWithCheckToListener("CityProductionChanged_Slinger",	notificationName, item );
					AddWithCheckToListener("CityProductionChanged_Campus",	notificationName, item );
					AddWithCheckToListener("CityProductionChanged_Library",	notificationName, item );
					AddWithCheckToListener("CityProductionCompleted",		notificationName, item );
					AddWithCheckToListener("CapitalCityProductionCompleted",	notificationName, item );
					AddWithCheckToListener("CapitalWarriorProductionCompleted",	notificationName, item );
					AddWithCheckToListener("CapitalBuilderProductionCompleted",	notificationName, item );
					AddWithCheckToListener("CapitalSettlerProductionCompleted",	notificationName, item );
					AddWithCheckToListener("CapitalSlingerProductionCompleted",	notificationName, item );
					AddWithCheckToListener("CapitalMonumentProductionCompleted",notificationName, item );
					AddWithCheckToListener("CapitalCampusProductionCompleted",	notificationName, item );
					AddWithCheckToListener("CapitalWallsProductionCompleted",	notificationName, item );
					AddWithCheckToListener("BarracksProductionCompleted",	notificationName, item );
					AddWithCheckToListener("StonehengeProductionCompleted",	notificationName, item );
					AddWithCheckToListener("RangedUnitProductionCompleted",	notificationName, item );
					AddWithCheckToListener("SiegeUnitProductionCompleted",	notificationName, item );
					AddWithCheckToListener("CityPopulationFirstChange",		notificationName, item );
					AddWithCheckToListener("CityPopulationGreaterThanFive",	notificationName, item );
					AddWithCheckToListener("ImprovementAddedToMap",			notificationName, item );
					AddWithCheckToListener("BarbarianImprovementActivated",	notificationName, item );
					AddWithCheckToListener("DiplomacyStatement",			notificationName, item );
					AddWithCheckToListener("DiplomacyMeet",					notificationName, item );
					AddWithCheckToListener("DiplomacyMeetMajors",			notificationName, item );
					AddWithCheckToListener("DiploScene_SceneClosed",		notificationName, item );
					AddWithCheckToListener("DiploActionView",				notificationName, item );
					AddWithCheckToListener("ImprovementAddedToSecondCity",	notificationName, item );
					AddWithCheckToListener("ImprovementPillaged",			notificationName, item );
					AddWithCheckToListener("NaturalWonderPopupClosed",		notificationName, item );
					AddWithCheckToListener("WorldRankingsOpened",			notificationName, item );
					AddWithCheckToListener("WorldRankingsClosed",			notificationName, item );
					AddWithCheckToListener("ResearchChanged",				notificationName, item );
					AddWithCheckToListener("EndTurnDirty",					notificationName, item );
					AddWithCheckToListener("LocalPlayerTurnEnd",			notificationName, item );
					AddWithCheckToListener("LoadScreenClose",				notificationName, item );
					AddWithCheckToListener("LocalPlayerTurnBegin",			notificationName, item );
					AddWithCheckToListener("GreatPersonPoint",				notificationName, item );
					AddWithCheckToListener("Bankrupt",						notificationName, item );
					AddWithCheckToListener("ShouldFoundSecondCity",			notificationName, item );
					AddWithCheckToListener("HasInfluenceToken",				notificationName, item );
					AddWithCheckToListener("ResearchCompleted",				notificationName, item );
					AddWithCheckToListener("FaithChanged",					notificationName, item );
					AddWithCheckToListener("MoneySurplus",					notificationName, item );
					AddWithCheckToListener("PantheonAvailable",				notificationName, item );
					AddWithCheckToListener("PantheonFounded",				notificationName, item );
					AddWithCheckToListener("DawnOfCivilizationResearchCompleted",	notificationName, item );
					AddWithCheckToListener("MiningResearchCompleted",		notificationName, item );
					AddWithCheckToListener("PotteryResearchCompleted",		notificationName, item );
					AddWithCheckToListener("IrrigationResearchCompleted",	notificationName, item );
					AddWithCheckToListener("WritingResearchCompleted",		notificationName, item );
					AddWithCheckToListener("ShipbuildingResearchCompleted",	notificationName, item );
					AddWithCheckToListener("SailingResearchCompleted",		notificationName, item );
					AddWithCheckToListener("ReplaceablePartsResearchCompleted",		notificationName, item );
					AddWithCheckToListener("RadioResearchCompleted",		notificationName, item );
					AddWithCheckToListener("ScientificTheoryResearchCompleted",		notificationName, item );
					AddWithCheckToListener("RocketryResearchCompleted",		notificationName, item );
					AddWithCheckToListener("DistrictUnlocked",				notificationName, item );
					AddWithCheckToListener("WallsUnlocked",					notificationName, item );
					AddWithCheckToListener("CivicCompleted",				notificationName, item );
					AddWithCheckToListener("ForeignTradeCivicCompleted",	notificationName, item );
					AddWithCheckToListener("CodeOfLawsCivicCompleted",		notificationName, item );
					AddWithCheckToListener("PoliticalPhilosophyCivicCompleted", notificationName, item );
					AddWithCheckToListener("NationalismCivicCompleted",		notificationName, item );
					AddWithCheckToListener("MobilizationCivicCompleted",	notificationName, item );
					AddWithCheckToListener("DiplomaticServiceCivicCompleted", notificationName, item );
					AddWithCheckToListener("UrbanizationCivicCompleted",	notificationName, item );
					AddWithCheckToListener("FeudalismCivicCompleted",	notificationName, item );
					AddWithCheckToListener("ConservationCivicCompleted",	notificationName, item );
					AddWithCheckToListener("UnitSelectionChanged",			notificationName, item );
					AddWithCheckToListener("UnitMoveComplete",				notificationName, item );
					AddWithCheckToListener("ZocUnitMoveComplete",			notificationName, item );
					AddWithCheckToListener("SettlerMoveComplete",			notificationName, item );
					AddWithCheckToListener("WarriorMoveComplete",			notificationName, item );
					AddWithCheckToListener("WarriorFoundGoodyHut",			notificationName, item );
					AddWithCheckToListener("UnitKilledInCombat",			notificationName, item );
					AddWithCheckToListener("ScoutUnitAddedToMap",			notificationName, item );
					AddWithCheckToListener("GreatGeneralAddedToMap",		notificationName, item );
					AddWithCheckToListener("GreatAdmiralAddedToMap",		notificationName, item );
					AddWithCheckToListener("GreatEngineerAddedToMap",		notificationName, item );
					AddWithCheckToListener("GreatMerchantAddedToMap",		notificationName, item );
					AddWithCheckToListener("GreatProphetAddedToMap",		notificationName, item );
					AddWithCheckToListener("GreatScientistAddedToMap",		notificationName, item );
					AddWithCheckToListener("GreatWriterAddedToMap",			notificationName, item );
					AddWithCheckToListener("GreatArtistAddedToMap",			notificationName, item );
					AddWithCheckToListener("GreatMusicianAddedToMap",		notificationName, item );
					AddWithCheckToListener("TurnBlockerChooseProduction",	notificationName, item );
					AddWithCheckToListener("ResearchChooser_ForceHideWorldTracker", notificationName, item);
					AddWithCheckToListener("ProductionPanelClose",			notificationName, item );					
					AddWithCheckToListener("ProductionPanelOpen",			notificationName, item );
					AddWithCheckToListener("BarbarianVillageDiscovered",	notificationName, item );
					AddWithCheckToListener("BarbarianDiscovered",			notificationName, item );
					AddWithCheckToListener("LowAmenitiesNotificationAdded",	notificationName, item );
					AddWithCheckToListener("HousingLimitNotificationAdded",	notificationName, item );
					AddWithCheckToListener("RelicCreatedNotificationAdded",	notificationName, item );
					AddWithCheckToListener("CitystateQuestGiven",			notificationName, item );
					AddWithCheckToListener("GreatPersonAvailable",			notificationName, item );
					AddWithCheckToListener("ProductionPanelViaCityOpen",	notificationName, item );
					AddWithCheckToListener("GoodyHutDiscovered",			notificationName, item );
					AddWithCheckToListener("BuilderChargesDepleted",		notificationName, item );
					AddWithCheckToListener("BuilderChargesOneRemaining",	notificationName, item );
					AddWithCheckToListener("ImprovementsBuilt3",			notificationName, item );
					AddWithCheckToListener("TradeRouteAddedToMap",			notificationName, item );
					AddWithCheckToListener("UnitPromotionAvailable",		notificationName, item );
					AddWithCheckToListener("BuildingPlacementInterfaceMode", notificationName, item );
					AddWithCheckToListener("DistrictPlacementInterfaceMode", notificationName, item );
					AddWithCheckToListener("ScoutMoved",					notificationName, item );
					AddWithCheckToListener("GovernmentScreenOpened",		notificationName, item );
					AddWithCheckToListener("GovernmentPoliciesOpened",		notificationName, item );
					AddWithCheckToListener("GovernmentPolicyChanged",		notificationName, item );
					AddWithCheckToListener("TeamVictory",					notificationName, item );
					AddWithCheckToListener("GoodyHutReward",				notificationName, item );
					AddWithCheckToListener("CivicsTreeOpened",				notificationName, item );
					AddWithCheckToListener("CivicsTreeClosed",				notificationName, item );
					AddWithCheckToListener("CivicChanged",					notificationName, item );
					AddWithCheckToListener("MultiMoveToCity",				notificationName, item );
					AddWithCheckToListener("TechTreeOpened",				notificationName, item );
					AddWithCheckToListener("TechTreeClosed",				notificationName, item );
					AddWithCheckToListener("ReligionPanelOpened",			notificationName, item );
					AddWithCheckToListener("ReligionPanelClosed",			notificationName, item );
					AddWithCheckToListener("GreatPeopleOpened",				notificationName, item );
					AddWithCheckToListener("GreatPeopleClosed",				notificationName, item );
					AddWithCheckToListener("CampusPlaced",					notificationName, item );
					AddWithCheckToListener("HangingGardensPlaced",			notificationName, item );
					AddWithCheckToListener("WorldRankingsClosed",			notificationName, item );
					AddWithCheckToListener("IllegalResearchChange",			notificationName, item );
					AddWithCheckToListener("IllegalProductionChange",		notificationName, item );
					AddWithCheckToListener("TutorialWarDeclared",			notificationName, item );
					AddWithCheckToListener("TradeRouteAdded",				notificationName, item );
					AddWithCheckToListener("TradeUnitCreated",				notificationName, item );
					AddWithCheckToListener("TradeRouteChooserOpened",		notificationName, item );
					AddWithCheckToListener("TradeRouteChooserClosed",		notificationName, item );
					AddWithCheckToListener("TradeRouteConsidered",			notificationName, item );
				end
			end
		end
	end

	MarkSerializedItems();
end

-- ===========================================================================
function KeyHandler( key:number, pInputStruct:table )	
	if isDebugInfoShowing then
		if pInputStruct:IsShiftDown() and pInputStruct:IsAltDown() then
			
			-- *** "R"eload all the stuff.
			if key == Keys.R then 
				LoadItems(); 
				TutorialCheck("LoadScreenClose");	-- Use fake raising of LUA event to start
				return true; 
			end	

			-- *** "T"utorial mode active! ***
			if key == Keys.T then 
				Controls.ListContainer:SetHide( not Controls.ListContainer:IsHidden() ); 
				SetSimpleInGameMenu(false);	-- If showing the secret tutorial menu; turn off simple view of the in game options menu.				
				isDebugVerbose = not isDebugVerbose;
				if isDebugVerbose then
					LuaEvents.Tutorial_PlotToolTipsOn();
				end
				print("TUTORIAL isDebugVerbose: "..tostring(isDebugVerbose));
				return true;
			end
		end	
	end
	return false;
end

-- ===========================================================================
--	UI Event
--	Note: Input events will flow through here twice since UIRoot receives
--		  normal input chain commands AND it's marked to receive all tutorial
--		  events (before the normal input cascade)
-- ===========================================================================
function OnInput( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then 
		return KeyHandler( pInputStruct:GetKey(), pInputStruct ); 
	end;
	return false;
end


-- ===========================================================================
--	RETURNS true if tutorial item has not been shown yet.
-- ===========================================================================
function IsUnseen( item:TutorialItem )
	-- Make sure it's in the unseen list, as listeners may still have references
	-- to wildcard items.  (Tried cleaning them up but this is a necessary evil to support wildcards.)
	return m_unseen[item.ScenarioName] ~= nil and m_unseen[item.ScenarioName][item.ID] ~= nil;
end


-- ===========================================================================
--	RETURNS true/false based on if a tutorial item has any prior prereqs
--			that must be met.
-- ===========================================================================
function IsPrereqsMet( item:TutorialItem )
	-- No prereqs?  Then yes, this tutorial item could be ready to be served.
	if item.PrereqIDs == nil or table.count( item.PrereqIDs ) == 0 then
		return true;
	end
	-- Loop through all, if any are still in unseen list, it's a no-go
	for _,req in pairs( item.PrereqIDs ) do
		if m_unseen[item.ScenarioName][req] ~= nil then
			return false;
		end
	end
	return true;
end

-- ===========================================================================
--	Determine the amount of tutorial a player is receiving.
-- ===========================================================================
function RefreshTutorialLevel()

	if m_isTutorialLevelLocked then
		return;
	end

	m_tutorialLevel = UserConfiguration.TutorialLevel()

	if GameConfiguration.IsAnyMultiplayer() then
		m_tutorialLevel = TUTORIAL_LEVEL_DISABLED
	end

	if Benchmark.IsEnabled() then
		m_tutorialLevel = TUTORIAL_LEVEL_DISABLED
	end
end

-- ===========================================================================
--	RETURNS true/false based on if a tutorial item is appropriate for the player
--			based on their advisor settings
-- ===========================================================================
function IsAppropriate( item:TutorialItem )
	if(m_tutorialLevel < item.TutorialLevel) then
		return false;
	end

	return true;

end

-- ===========================================================================
--	RETURNS true/false based on if a tutorial item is matching a listener
--			that could kick off a "done" (removal) check.
-- ===========================================================================
function IsMatchingDoneListener( item:TutorialItem, listenerName:string )
	if table.count(item.DoneListeners) < 1 then
		return true;
	end
	for _,name in pairs(item.DoneListeners) do
		if listenerName == name then
			return true;
		end
	end
	return false;
end

-- ===========================================================================
--	RETURNS true/false based on if a tutorial item is matching a listener
--			that could kick off a "done" (removal) check.
-- ===========================================================================
function IsMatchingRaiseListener( item:TutorialItem, listenerName:string )
	if table.count(item.RaiseListeners) < 1 then
		return true;
	end
	for _,name in pairs(item.RaiseListeners) do
		if listenerName == name then
			return true;
		end
	end
	return false;
end

function ItemHasUITriggersButNoButtons( item:TutorialItem )
	if item ~= nil then
		if table.count(item.UITriggers) > 0 and item.AdvisorInfo.Button1Func == nil and item.AdvisorInfo.Button2Func == nil then
			return true;
		end
	end
	return false;
end

-- ===========================================================================
function ActivateItem( item:TutorialItem )
	if isDebugVerbose then
		print("  activating item: "..item.ID)
	end

	if m_active ~= nil then
		UI.DataError("Attempt to activate item '"..item.ID.."' ("..item.ScenarioName..") while another item is already active '"..m_active.ID.."' ("..m_active.ScenarioName..")");
		return;
	end
	m_active = item;

	if isDebugInfoShowing then
		m_uiDebugItemList[item.ID].TutorialID:SetColor(	COLOR_DEBUG_ACTIVE );
	end

	-- Prevents potentially clearing a tutorial item during an open.
	DisableTutorialCheck();		
	
		-- A "global" function to run before every item
		if m_beforeEveryOpen ~= nil then
			m_beforeEveryOpen();
		end

		if item.OpenFunc ~= nil then
			item.OpenFunc( item );		
		end

	EnableTutorialCheck();

	-- Goal add/remove functionality...

	if item.Goals ~= nil then
		for _,goal in ipairs(item.Goals) do
			LuaEvents.TutorialUIRoot_GoalAdd( goal );			
		end		
	end
	
	local bImmediateDismissal:boolean = ItemHasUITriggersButNoButtons(item);
	LuaEvents.TutorialUIRoot_AdvisorRaise( item.AdvisorInfo );
	if bImmediateDismissal then
		local item:TutorialItem = m_active;
		MarkTutorialItemSeen( item, true );
		RaiseDetailedTutorial( item );
	end
end

-- ===========================================================================
function ActivateIfChained( item:TutorialItem )
	if m_active ~= nil then
		UI.DataError("Attempt to active a chained item '"..item.ID.."' ("..item.ScenarioName..") but there is an active item '"..m_active.ID.."' ("..m_active.ScenarioName..")");
		return;
	end
	if item.NextID==nil or item.NextID=="" then
		return;
	end
	local nextItem:TutorialItem = m_unseen[item.ScenarioName][item.NextID];
	if nextItem == nil then
		UI.DataError("A NextID was set for item '"..item.ID.."' ("..item.ScenarioName..") but a NIL entry exists in the unseen list!");
		return;
	end
	if not IsPrereqsMet( nextItem ) then
		UI.DataError("A chained tutorial item has prereqs (likely shouldn't) and they aren't met.  Item '"..nextItem.ID.."' ("..nextItem.ScenarioName..")");
		return;
	end
	ActivateItem( nextItem );
end


-- ===========================================================================
function DeActivateItem( item:TutorialItem, bActivateChained:boolean )
	if isDebugVerbose then
		print("deactivating item: "..item.ID)
	end

	-- If the seen tutorial item is the active one, remove it.
	-- If the player went into detailed mode, make sure those items are removed.
	if item == m_active then
		if UITutorialManager:IsActive() then
			for _,id:string in ipairs(m_active.UITriggers) do
				UITutorialManager:HideControlsByID( id, true );
			end
		end

		-- Local copy so active can be zeroed out before signal function runs (listeners may cascade to check if acitve is NIL)
		local item:TutorialItem = m_active;
		m_active = nil;
		if item.CleanupFunc ~= nil then
			item.CleanupFunc( item );
		end
		
		if item.GoalCompletedIDs ~= nil then
			for _,goalId in ipairs(item.GoalCompletedIDs) do
				LuaEvents.TutorialUIRoot_GoalMarkComplete( goalId, Game.GetCurrentGameTurn() );
			end
		end
		LuaEvents.TutorialUIRoot_AdvisorLower( item.AdvisorInfo );
	end

	m_lastRaiseListener = "";

	m_active = nil;

	if( bActivateChained ) then
		-- if the item has been seen - activate the next item if appropriate
		if not IsUnseen( item ) then
			ActivateIfChained( item )
		end
	end

	if item.IsEndOfChain then
		if 0 < #m_queue then
			if isDebugVerbose then
				print("activating queued item: "..m_queue[1].ID)
			end

			ActivateItem(m_queue[1])
			table.remove(m_queue, 1)
		end
	end
end

-- ===========================================================================
--	Removes a tutorial from the unseen list
--	Removes registration with listener(s)
-- ===========================================================================
function MarkTutorialItemSeen( item:TutorialItem, bSerialIzeItem: boolean )
	
	-- NIL out master list
	if IsUnseen( item ) then
		m_unseen[item.ScenarioName][item.ID] = nil;
		m_debugSeenItems[item.ID] = item;	-- Ignore scenario, this is just for debug purposes

		if isDebugInfoShowing then
			local instance:table = m_uiDebugItemList[item.ID];
			if instance ~= nil then
				instance.TutorialID:SetColor( COLOR_DEBUG_SEEN_ID );	-- Change to dark gray to mark being seen
			end
		end

		if bSerialIzeItem then
			SerializeCompletedItem( item );
		end

		-- Actually remove from the listener the entry for the tutorial item
		local index = nil;
		for _,listenerId in pairs( item.RaiseListeners ) do
			repeat
				index = nil;
				for i,v in ipairs(m_listeners[listenerId][item.ScenarioName]) do
					if v.ID == item.ID then
						index = i;
						break;
					end
				end
				if(index ~= nil) then
					table.remove(m_listeners[listenerId][item.ScenarioName], index);
				end
			until(index == nil);	-- Should only be one; but just in case.
		end
	end

end

-- ===========================================================================
--	DEBUG Only
-- ===========================================================================
function OnForceMarkUnseen( scenarioName:string, itemID:string )
	if m_debugSeenItems[itemID] ~= nil then
		m_unseen[scenarioName][itemID] = m_debugSeenItems[itemID];	-- It's alive!
		m_debugSeenItems[itemID] = nil;
		local instance:table = m_uiDebugItemList[itemID];
		if instance ~= nil then
			instance.TutorialID:SetColor( COLOR_DEBUG_NORMAL );
		end
	end
end

-- ===========================================================================
--	DEBUG Only
-- ===========================================================================
function OnForceMarkActive( scenarioName:string, itemID:string )
	if m_debugSeenItems[itemID] ~= nil then
		m_unseen[scenarioName][itemID] = m_debugSeenItems[itemID];	-- It's alive!
		m_debugSeenItems[itemID] = nil;
	end		
	ActivateItem( m_unseen[scenarioName][itemID] );
end

-- ===========================================================================
--	DEBUG Only
-- ===========================================================================
function OnForceMarkDone( scenarioName:string, itemID:string )		
	if m_unseen[scenarioName][itemID] ~= nil then
		if m_unseen[scenarioName][itemID] == m_active then
			DeActivateItem( m_unseen[scenarioName][itemID], true );
			MarkTutorialItemSeen( m_unseen[scenarioName][itemID], true );
		else
			MarkTutorialItemSeen( m_unseen[scenarioName][itemID], true );
		end		
	end
end


-- ===========================================================================
--	listenerName	String representing the name of an event that fired.
--	RETURNS			true if the listener matches to one that can be processed
--					when it's not the player's turn.
-- ===========================================================================
function IsListenerAbleToProcessOnNonPlayerTurn( listenerName:string )
	return listenerName == "LoadScreenClose"
		or listenerName == "LocalPlayerTurnEnd"
		or listenerName == "BarbarianVillageDiscovered"
		or listenerName == "BarbarianDiscovered"
		or listenerName == "GoodyHutDiscovered"
		or listenerName == "SettlerMoveComplete"
		or listenerName == "WarriorMoveComplete"
		or listenerName == "WritingResearchCompleted"
		or listenerName == "DiplomacyMeet"
		or listenerName == "DiplomacyStatement"
		or listenerName == "ImprovementPillaged";
end

-- ===========================================================================
--	Main check function for calling an item to determin if it can be disabled
--	and a new one can be enabled.
-- ===========================================================================
function TutorialCheck( listenerName:string )
	
	if isDebugVerbose then print("checking: "..listenerName); end

	if m_isTutorialCheckDisabled then
		if isDebugVerbose then print("...but not really beacuse tutorial check is disabled."); end
		return;
	end

	-- If game has just started and load screen is still up, save name for later and immediately bail.
	if m_isLoadScreenUp then
		table.insert( m_preLoadEvents, listenerName ); 
		return;
	end

	RefreshTutorialLevel();

	-- Only check for tutorials from events of the current local player(s)
	local playerID = Game.GetLocalPlayer();
	-- Make sure the local player is valid!
	-- If tutorial system is not active, bail.
	if ( playerID < 0 or m_tutorialLevel < 0 ) then
		return;
	end

	local pPlayer:table = Players[playerID];
	if pPlayer:IsTurnActive() or IsListenerAbleToProcessOnNonPlayerTurn( listenerName ) then

		-- Current item?  If so, mark it useen if done matches
		if m_active ~= nil then
			if IsMatchingDoneListener( m_active, listenerName ) and m_active.IsDoneFunc() then
				DeActivateItem( m_active, true );
			end
		end

		-- anything still listening for this
		if m_listeners[listenerName] ~= nil then
			for _,scenario in pairs( m_listeners[listenerName] ) do		
				for _,item in pairs( scenario ) do
					if IsUnseen( item ) and IsMatchingRaiseListener( item, listenerName ) and IsPrereqsMet( item ) and item.IsRaisedFunc() and IsAppropriate( item ) then
						if m_active == nil then
							ActivateItem( item );
							m_lastRaiseListener = listenerName;
						elseif item.IsQueueable then
							-- Ensure item is not already active, in queue, or seen list.
							local itemInQueue = false

							for _,queuedItem in pairs(m_queue) do
								if queuedItem.ID == item.ID then
									itemInQueue = true
								end
							end

							if false == itemInQueue then
								if item.ID ~= m_active.ID then
									print("adding item '"..item.ID.."' to queue because another item is already active: "..m_active.ID)
									table.insert(m_queue, item)
								else
									print("ignoring queue for item which is already active item: "..item.ID)
								end
							else
								print("ignoring item already in queue: "..item.ID)
							end
						else
							if isDebugVerbose then
								print("ignoring check for '"..listenerName.."' because another item is already active: "..m_active.ID)
							end
						end
					end
				end
			end
		else
			if isDebugVerbose then
				print("no listeners registered for: "..listenerName)
			end
		end
	else
		if isDebugVerbose then
			print("ignoring check because local player turn is not active: "..listenerName)
		end
	end
end


-- ===========================================================================
--	Check ENGINE Events
-- ===========================================================================
function OnCityAddedToMap()
	TutorialCheck("CityAddedToMap")
end

-- ===========================================================================
function OnCityProductionChanged(playerID, cityID, orderType, unitType, canceled, typeModifier)
	local localPlayer = Game.GetLocalPlayer()
	if (playerID == localPlayer) then

		CheckLockedProduction();

		local productionName = nil;

		if orderType == 0  then -- OrderTypes.ORDER_TRAIN
			local entry = GameInfo.Units[unitType];
			if entry ~= nil then
				productionName = entry.UnitType;
			end
		elseif orderType == 1  then -- OrderTypes.ORDER_CONSTRUCT
			local entry = GameInfo.Buildings[unitType];
			if entry ~= nil then
				productionName = entry.BuildingType;
			end
		elseif orderType == 2  then -- OrderTypes.ORDER_ZONE
			local entry = GameInfo.Districts[unitType];
			if entry ~= nil then
				productionName = entry.DistrictType;
			end
		end

		if productionName ~= nil then
			if productionName == "UNIT_WARRIOR" then
				TutorialCheck("CityProductionChanged_Warrior")
			elseif productionName == "UNIT_BUILDER" then
				TutorialCheck("CityProductionChanged_Builder")
			elseif productionName == "UNIT_SETTLER" then
				TutorialCheck("CityProductionChanged_Settler")
			elseif productionName == "UNIT_SLINGER" then
				TutorialCheck("CityProductionChanged_Slinger")
			elseif productionName == "BUILDING_MONUMENT" then
				TutorialCheck("CityProductionChanged_Monument")
			elseif productionName == "DISTRICT_CAMPUS" then
				TutorialCheck("CityProductionChanged_Campus")
			elseif productionName == "BUILDING_LIBRARY" then
				TutorialCheck("CityProductionChanged_Library")
			end
		end
	end
	
end

-- ===========================================================================
function OnCityProductionCompleted(playerID, cityID, orderType, unitType, canceled, typeModifier)
	local localPlayer = Game.GetLocalPlayer()

	if playerID == localPlayer then
		UnlockProduction();
		TutorialCheck("CityProductionCompleted");

		local player		= Players[playerID]
		local playerCities	= player:GetCities()
		local capitalCity	= playerCities:GetCapitalCity()

		if capitalCity == nil then
			return;
		end

		if cityID == capitalCity:GetID() then
			TutorialCheck("CapitalCityProductionCompleted")

			if orderType == 0  -- OrderTypes.ORDER_TRAIN
			and GameInfo.Units[unitType].UnitType == "UNIT_WARRIOR" then
				TutorialCheck("CapitalWarriorProductionCompleted")
			elseif orderType == 0  -- OrderTypes.ORDER_TRAIN
			and GameInfo.Units[unitType].UnitType == "UNIT_BUILDER" then
				TutorialCheck("CapitalBuilderProductionCompleted")
			elseif orderType == 0  -- OrderTypes.ORDER_TRAIN
			and GameInfo.Units[unitType].UnitType == "UNIT_SETTLER" then
				TutorialCheck("CapitalSettlerProductionCompleted")
			elseif orderType == 0  -- OrderTypes.ORDER_TRAIN
			and GameInfo.Units[unitType].UnitType == "UNIT_SLINGER" then
				TutorialCheck("CapitalSlingerProductionCompleted")
			elseif orderType == 1  -- OrderTypes.ORDER_CONSTRUCT
			and GameInfo.Buildings[unitType].BuildingType == "BUILDING_MONUMENT" then
				TutorialCheck("CapitalMonumentProductionCompleted")
			elseif orderType == 2  -- OrderTypes.ORDER_ZONE
			and GameInfo.Districts[unitType].DistrictType == "DISTRICT_CAMPUS" then
				TutorialCheck("CapitalCampusProductionCompleted")
			elseif orderType == 1  -- OrderTypes.ORDER_CONSTRUCT
			and GameInfo.Buildings[unitType].BuildingType == "BUILDING_WALLS" then
				TutorialCheck("CapitalWallsProductionCompleted")
			end
		end

		if orderType == 1  -- OrderTypes.ORDER_CONSTRUCT
		and GameInfo.Buildings[unitType].BuildingType == "BUILDING_BARRACKS" then
			TutorialCheck("BarracksProductionCompleted")
		elseif orderType == 1  -- OrderTypes.ORDER_CONSTRUCT
		and GameInfo.Buildings[unitType].BuildingType == "BUILDING_STONEHENGE" then
			TutorialCheck("StonehengeProductionCompleted")
		end

		if orderType == 0 then  -- OrderTypes.ORDER_TRAIN
			if GameInfo.Units[unitType].RangedCombat > 0 then
				TutorialCheck("RangedUnitProductionCompleted")
			elseif GameInfo.Units[unitType].Bombard > 0
			or GameInfo.Units[unitType].UnitType == "UNIT_BATTERING_RAM"
			or GameInfo.Units[unitType].UnitType == "UNIT_SIEGE_TOWER" then
				TutorialCheck("SiegeUnitProductionCompleted");
			elseif (GameInfo.Units[unitType].UnitType == "UNIT_TRADER") then
				TutorialCheck("TradeUnitCreated");
			end
		end
	end
end

-- ===========================================================================
function OnCityPopulationChanged(playerID : number, cityID : number, newPopulation : number )
	if playerID == Game.GetLocalPlayer() then
		if 1 < newPopulation then
			TutorialCheck("CityPopulationFirstChange"); 
		elseif 5 < newPopulation then
			TutorialCheck("CityPopulationGreaterThanFive"); 
		end
	end
end

-- ===========================================================================
function OnImprovementAddedToMap(locationX, locationY, improvementType, eImprovementOwner, resource, isPillaged, isWorked)
	TutorialCheck("ImprovementAddedToMap")

	local playerID = Game.GetLocalPlayer();
	
	if (eImprovementOwner ~= nil) then
		if (playerID == eImprovementOwner) then
			local iNumImprovements = 0;
			local kPlayer = Players[playerID];
			if (kPlayer ~= nil) then

				-- check for 3rd improvement built
				local iNumPlayerImprovements = 0;
				local playerImprovements = kPlayer:GetImprovements();
				local tImprovementLocations:table = playerImprovements:GetImprovementPlots();
				if (table.count(tImprovementLocations) >= 3) then
					TutorialCheck("ImprovementsBuilt3");
				end

				-- check for improvement built in second city
				local playerCities	= kPlayer:GetCities();
				local capitalCity	= playerCities:GetCapitalCity();
				for i, city in playerCities:Members() do
					if city ~= capitalCity then
						local cityPlots : table = Map.GetCityPlots():GetPurchasedPlots(city)

						for _, plotID in ipairs(cityPlots) do
							local plot : table = Map.GetPlotByIndex(plotID)
							local plotX : number = plot:GetX()
							local plotY : number = plot:GetY()

							if plotX == locationX and plotY == locationY then
								TutorialCheck("ImprovementAddedToSecondCity")
							end
						end
					end
				end
			end
		end
	end

	

end

-- ===========================================================================
function OnImprovementChanged(locationX, locationY, improvementType, improvementOwner, resource, isPillaged, isWorked)
	local localPlayer = Game.GetLocalPlayer()

	if improvementOwner == localPlayer and isPillaged == true then
		TutorialCheck("ImprovementPillaged")
	end
end

-- ===========================================================================
function OnImprovementActivated(locationX, locationY, unitOwner, unitID, improvementType, improvementOwner,	activationType, activationValue)
	-- IMPROVEMENT_BARBARIAN_CAMP
	TutorialCheck("BarbarianImprovementActivated")

end

-- ===========================================================================
function OnResearchChanged(player, tech)
	local localPlayer = Game.GetLocalPlayer()

	if player == localPlayer then
		CheckLockedResearch();
		TutorialCheck("ResearchChanged")
	end
end

-- ===========================================================================
function OnEndTurnDirty()					TutorialCheck("EndTurnDirty"); end

-- ===========================================================================
function OnLocalPlayerTurnEnd()				TutorialCheck("LocalPlayerTurnEnd"); end

-- ===========================================================================
function OnLocalPlayerTurnBegin()

	-- Prevent local player turn being re-raised on the same turn.  (Edge case, but can happen when there is remaining movement that is required to move)
	local turn :number= Game.GetCurrentGameTurn();
	if turn == m_turn then		
		return;					-- BAIL
	end
	m_turn = turn;
	WriteCustomData("turn", m_turn);

	TutorialCheck("LocalPlayerTurnBegin")

	local localPlayer = Game.GetLocalPlayer()
	local player = Players[localPlayer]
	local playerGpp = player:GetGreatPeoplePoints()
	
	for row in GameInfo.GreatPersonClasses() do
		if(playerGpp:GetPointsTotal(row.Index) > 0) then
			TutorialCheck("GreatPersonPoint");
		end
	end

	-- If goals are used and set to auto-remove, now is the time to signal
	-- to the goal system that an autoremove check should be performed.
	if m_isGoalsAutoRemove then
		LuaEvents.TutorialUIRoot_GoalAutoRemove( Game.GetCurrentGameTurn() );
	end
end

-- ===========================================================================
function OnInfluenceChanged(player)
	local localPlayer = Game.GetLocalPlayer()

	if player == localPlayer then
		local playerInfluence = Players[player]:GetInfluence()
		local influenceTokens = playerInfluence:GetTokensToGive()

		if 0 < influenceTokens then
			TutorialCheck("HasInfluenceToken")
		end
	end
end

-- ===========================================================================
function OnDiplomacyDeclareWar(actingPlayer, reactingPlayer)
	local localPlayer = Game.GetLocalPlayer();
	if (actingPlayer == localPlayer or reactingPlayer == localPlayer) then
		TutorialCheck("TutorialWarDeclared");
	end
end

-- ===========================================================================
function OnDiplomacyStatement(actingPlayer, reactingPlayer, values)
	-- TODO(asherburne): Ensure values["StatementType"] == DENOUNCE
	print("diplo stmt type="..values["StatementType"])
	TutorialCheck("DiplomacyStatement")
end

-- ===========================================================================
function OnDiplomacyMeet(player1, player2)
	local localPlayer = Game.GetLocalPlayer()

	if player1 == localPlayer
	or player2 == localPlayer then
		if false == Players[player1]:IsMajor()
		or false == Players[player2]:IsMajor() then
			TutorialCheck("DiplomacyMeet")
		end
	end
end

-- ===========================================================================
function OnDiplomacyMeetMajors()
	TutorialCheck("DiplomacyMeetMajors")
end

-- ===========================================================================
function OnDiploScene_SceneClosed()
	local playerID = Game.GetLocalPlayer();
	local player = Players[playerID];
	if (player ~= nil) then
		local playerDiplo = player:GetDiplomacy();
		if (playerDiplo:GetNumPlayersMet() > 0) then
			TutorialCheck("DiploScene_SceneClosed");
		end
	end
end

-- ===========================================================================
function OnOpenDiploActionView(  playerID )
	local localPlayerID = Game.GetLocalPlayer();
	if (playerID ~= localPlayerID) then
		TutorialCheck("DiploActionView");
	end
end

-- ===========================================================================
function OnDistrictAddedToMap( playerID: number, districtID : number, cityID :number, districtX : number, districtY : number, districtType:number, percentComplete:number )
	local localPlayerID = Game.GetLocalPlayer();
	if (playerID == localPlayerID) then
		local campus = GameInfo.Districts["DISTRICT_CAMPUS"];
		if(campus) then
			local eCampus = campus.Index;		
			if (districtType == eCampus) then
				TutorialCheck("CampusPlaced");
			end
		end
	end
end

-- ===========================================================================
function OnBuildingAddedToMap( plotX:number, plotY:number, buildingType:number, misc1, misc2, misc3 )
	--[[ Removed for on rails tutorial.  --??TRON
	local eHangingGardens = GameInfo.Buildings["BUILDING_HANGING_GARDENS"].Index;	
	if buildingType == eHangingGardens then
		TutorialCheck("HangingGardensPlaced");
	end
	]]
end

-- ===========================================================================
function OnResearchCompleted(player, tech, canceled)
	local localPlayer = Game.GetLocalPlayer()

	if player == localPlayer then
		UnlockResearch();
		TutorialCheck("ResearchCompleted")

		local dawnOfCivilizationTech = GameInfo.Technologies["TECH_DAWN_OF_CIVILIZATION"]

		if dawnOfCivilizationTech ~= nil and tech == dawnOfCivilizationTech.Index then
			TutorialCheck("DawnOfCivilizationResearchCompleted")
		end

		local miningTech = GameInfo.Technologies["TECH_MINING"]

		if miningTech ~= nil and tech == miningTech.Index then
			TutorialCheck("MiningResearchCompleted")
		end

		local potteryTech = GameInfo.Technologies["TECH_POTTERY"]

		if potteryTech ~= nil and tech == potteryTech.Index then
			TutorialCheck("PotteryResearchCompleted")
		end

		local irrigationTech = GameInfo.Technologies["TECH_IRRIGATION"]

		if irrigationTech ~= nil and tech == irrigationTech.Index then
			TutorialCheck("IrrigationResearchCompleted")
		end

		local writingTech = GameInfo.Technologies["TECH_WRITING"]

		if writingTech ~= nil and tech == writingTech.Index then
			TutorialCheck("WritingResearchCompleted")
		end

		local shipbuildingTech = GameInfo.Technologies["TECH_SHIPBUILDING"]

		if shipbuildingTech ~= nil and tech == shipbuildingTech.Index then
			TutorialCheck("ShipbuildingResearchCompleted")
		end

		local sailingTech = GameInfo.Technologies["TECH_SAILING"]

		if sailingTech ~= nil and tech == sailingTech.Index then
			TutorialCheck("SailingResearchCompleted")
		end

		local replaceablePartsTech = GameInfo.Technologies["TECH_REPLACEABLE_PARTS"]

		if replaceablePartsTech ~= nil and tech == replaceablePartsTech.Index then
			TutorialCheck("ReplaceablePartsResearchCompleted")
		end
		
		local radioTech = GameInfo.Technologies["TECH_RADIO"]

		if radioTech ~= nil and tech == radioTech.Index then
			TutorialCheck("RadioResearchCompleted")
		end
		
		local scientificTheoryTech = GameInfo.Technologies["TECH_SCIENTIFIC_THEORY"]

		if scientificTheoryTech ~= nil and tech == scientificTheoryTech.Index then
			TutorialCheck("ScientificTheoryResearchCompleted")
		end
		
		local rocketryTech = GameInfo.Technologies["TECH_ROCKETRY"]

		if rocketryTech ~= nil and tech == rocketryTech.Index then
			TutorialCheck("RocketryResearchCompleted")
		end

		local astrologyTech = GameInfo.Technologies["TECH_ASTROLOGY"]
		local bronzeWorkingTech = GameInfo.Technologies["TECH_BRONZE_WORKING"]
		local celestialNavigationTech = GameInfo.Technologies["TECH_CELESTIAL_NAVIGATION"]
		local currencyTech = GameInfo.Technologies["TECH_CURRENCY"]
		local engineeringTech = GameInfo.Technologies["TECH_ENGINEERING"]

		if (astrologyTech ~= nil and tech == astrologyTech.Index)
		or (bronzeWorkingTech ~= nil and tech == bronzeWorkingTech.Index)
		or (celestialNavigationTech ~= nil and tech == celestialNavigationTech.Index)
		or (currencyTech ~= nil and tech == currencyTech.Index)
		or (engineeringTech ~= nil and tech == engineeringTech.Index)
		or (writingTech ~= nil and tech == writingTech.Index) then
			TutorialCheck("DistrictUnlocked")
		end

		local masonryTech = GameInfo.Technologies["TECH_MASONRY"]
		local castlesTech = GameInfo.Technologies["TECH_CASTLES"]
		local siegeTacticsTech = GameInfo.Technologies["TECH_SIEGE_TACTICS"]

		if (masonryTech ~= nil and tech == masonryTech.Index)
		or (castlesTech ~= nil and tech == castlesTech.Index)
		or (siegeTacticsTech ~= nil and tech == siegeTacticsTech.Index) then
			TutorialCheck("WallsUnlocked")
		end
	end
end

-- ===========================================================================
function OnFaithChanged(player, yield, balance)
	local localPlayer = Game.GetLocalPlayer()

	if player == localPlayer then
		TutorialCheck("FaithChanged")
	end
end

-- ===========================================================================
function OnTreasuryChanged(player, yield, balance)
	local localPlayer = Game.GetLocalPlayer()

	if player == localPlayer then
		if balance <= 0 then
			TutorialCheck("Bankrupt")
		end

		local eGameSpeed = GameConfiguration.GetGameSpeedType();
		local iSpeedCostMultiplier = GameInfo.GameSpeeds[eGameSpeed].CostMultiplier;
		local iGoldThreshold = 5 * iSpeedCostMultiplier;

		if (iGoldThreshold <= 0) then
			iGoldThreshold = 500;
		end
		
		if balance >= iGoldThreshold and yield > 0 then
			TutorialCheck("MoneySurplus")
		end
	end
end

-- ===========================================================================
function OnPantheonAvailable(player, belief)
	local localPlayer = Game.GetLocalPlayer()

	if player == localPlayer then
		TutorialCheck("PantheonAvailable");
	end
end

-- ===========================================================================
function OnPantheonFounded(player, belief)
	local localPlayer = Game.GetLocalPlayer()

	if player == localPlayer then
		TutorialCheck("PantheonFounded");
	end
end

-- ===========================================================================
function OnCivicCompleted(player, civic, canceled)
	local localPlayer = Game.GetLocalPlayer()

	if player == localPlayer then
		TutorialCheck("CivicCompleted")

		local codeOfLawsCivic = GameInfo.Civics["CIVIC_CODE_OF_LAWS"];
		if (codeOfLawsCivic ~= nil and civic == codeOfLawsCivic.Index) then
			TutorialCheck("CodeOfLawsCivicCompleted");
		end

		local foreignTradeCivic = GameInfo.Civics["CIVIC_FOREIGN_TRADE"]

		if foreignTradeCivic ~= nil and civic == foreignTradeCivic.Index then
			TutorialCheck("ForeignTradeCivicCompleted")
		end

		local politicalPhilosophyCivic = GameInfo.Civics["CIVIC_POLITICAL_PHILOSOPHY"]

		if politicalPhilosophyCivic ~= nil and civic == politicalPhilosophyCivic.Index then
			TutorialCheck("PoliticalPhilosophyCivicCompleted")
		end

		local nationalismCivic = GameInfo.Civics["CIVIC_NATIONALISM"]

		if nationalismCivic ~= nil and civic == nationalismCivic.Index then
			TutorialCheck("NationalismCivicCompleted")
		end

		local mobilizationCivic = GameInfo.Civics["CIVIC_MOBILIZATION"]

		if mobilizationCivic ~= nil and civic == mobilizationCivic.Index then
			TutorialCheck("MobilizationCivicCompleted")
		end

		local diplomaticServiceCivic = GameInfo.Civics["CIVIC_DIPLOMATIC_SERVICE"]

		if diplomaticServiceCivic ~= nil and civic == diplomaticServiceCivic.Index then
			TutorialCheck("DiplomaticServiceCivicCompleted")
		end

		local urbanizationCivic = GameInfo.Civics["CIVIC_URBANIZATION"]

		if urbanizationCivic ~= nil and civic == urbanizationCivic.Index then
			TutorialCheck("UrbanizationCivicCompleted")
		end
		
		local feudalismCivic = GameInfo.Civics["CIVIC_FEUDALISM"]

		if feudalismCivic ~= nil and civic == feudalismCivic.Index then
			TutorialCheck("FeudalismCivicCompleted")
		end

		local conservationCivic = GameInfo.Civics["CIVIC_CONSERVATION"]

		if conservationCivic ~= nil and civic == conservationCivic.Index then
			TutorialCheck("ConservationCivicCompleted")
		end
		
		local earlyEmpireCivic = GameInfo.Civics["CIVIC_EARLY_EMPIRE"]

		-- When Early Empire civic complete,
		if earlyEmpireCivic ~= nil and civic == earlyEmpireCivic.Index then
			local player = Players[localPlayer]
			local playerCities = player:GetCities()
			local cityCount = playerCities:GetCount()

			-- if only one city,
			if 1 == cityCount then
				local capitalCity = playerCities:GetCapitalCity()
				local buildQueue = capitalCity:GetBuildQueue()
				local settlerType = GameInfo.Units["UNIT_SETTLER"].Index
				local settlerProgress = buildQueue:GetUnitProgress(settlerType)

				-- if no settler in any city production queue.
				if settlerProgress <= 0 then
					local playerUnits = player:GetUnits()
					local hasSettler = false

					for i, unit in playerUnits:Members() do
						local unitTypeName = UnitManager.GetTypeName(unit)

						if "UNIT_SETTLER" == unitTypeName then
							hasSettler = true
						end
					end

					-- if no settler unit in player units,
					if false == hasSettler then
						TutorialCheck("ShouldFoundSecondCity")
					end
				end
			end
		end
	end
end

-- ===========================================================================
function OnLoadScreenClose()				
	TutorialCheck("LoadScreenClose"); 
	RemoveLoadScreenClosedWatch(); 
end

-- ===========================================================================
function OnUnitSelectionChanged()			
	TutorialCheck("UnitSelectionChanged");
	CheckLockedUnit();
end

-- ===========================================================================
function OnUnitMoveComplete(playerID, unitID, x, y, visibleToLocalPlayer, unitState)
	local localPlayer = Game.GetLocalPlayer()

	if playerID == localPlayer then
		TutorialCheck("UnitMoveComplete")
		local player = Players[playerID]
		local playerCities = player:GetCities()
		local capitalCity = playerCities:GetCapitalCity()

		if capitalCity ~= nil then
			local plotX = capitalCity:GetX() + 4  -- NOTE: This special location is taken from the tutorial scenario copy of TutorialScenarioBase.lua
			local plotY = capitalCity:GetY() - 1
			local unitType = GetUnitType(playerID, unitID)

			if unitType == "UNIT_SETTLER" then
				if x == plotX and y == plotY then
					TutorialCheck("SettlerMoveComplete")
				end
			elseif unitType == "UNIT_WARRIOR" then
				if ( x == capitalCity:GetX() and y == capitalCity:GetY() ) then
					-- This branch is for the initial warrior moving back to defend the capital.
					TutorialCheck("WarriorMoveComplete")
				elseif (x == 16 and y == 14) then
					TutorialCheck("WarriorFoundGoodyHut");
				else
					-- This branch works around unit formations not sending individual unit move complete messages for subordinate units of the formation.
					local playerUnits = player:GetUnits()

					for i, unit in playerUnits:Members() do
						local unitTypeName = UnitManager.GetTypeName(unit)

						if "UNIT_SETTLER" == unitTypeName then
							local unitX = unit:GetX()
							local unitY = unit:GetY()

							if unitX == plotX and unitY == plotY then
								TutorialCheck("SettlerMoveComplete")
							end
						end
					end
				end
			end
		end

		-- Zoc
		local playerUnits = player:GetUnits()
		local unit = playerUnits:FindID(unitID)

		if unit ~= nil
		and unit:HasMovedIntoZOC() then
			TutorialCheck("ZocUnitMoveComplete")
		end
	end
end

-- ===========================================================================
function OnUnitKilledInCombat()				TutorialCheck("UnitKilledInCombat"); end

-- ===========================================================================
function OnUnitAddedToMap(player, unit, x, y)
	local localPlayer = Game.GetLocalPlayer()

	if player == localPlayer then
		local unitType = GetUnitType(player, unit)

		if unitType == "UNIT_SCOUT" then
			TutorialCheck("ScoutUnitAddedToMap")
		elseif unitType == "UNIT_GREAT_GENERAL" then
			TutorialCheck("GreatGeneralAddedToMap")
		elseif unitType == "UNIT_GREAT_ADMIRAL" then
			TutorialCheck("GreatAdmiralAddedToMap")
		elseif unitType == "UNIT_GREAT_ENGINEER" then
			TutorialCheck("GreatEngineerAddedToMap")
		elseif unitType == "UNIT_GREAT_MERCHANT" then
			TutorialCheck("GreatMerchantAddedToMap")
		elseif unitType == "UNIT_GREAT_PROPHET" then
			-- Ensure Stonehenge wonder is not built, which has a unique advisor event.
			local stonehengeType = GameInfo.Buildings["BUILDING_STONEHENGE"].Index
			local thePlayer = Players[localPlayer]
			local playerCities = thePlayer:GetCities()
			local playerHasStonehenge = false

			for n, city in playerCities:Members() do
				local buildings = city:GetBuildings()
				local cityHasStonehenge = buildings:HasBuilding(stonehengeType)

				if true == cityHasStonehenge then
					playerHasStonehenge = true
				end
			end

			if false == playerHasStonehenge then
				TutorialCheck("GreatProphetAddedToMap")
			end
		elseif unitType == "UNIT_GREAT_SCIENTIST" then
			TutorialCheck("GreatScientistAddedToMap")
		elseif unitType == "UNIT_GREAT_WRITER" then
			TutorialCheck("GreatWriterAddedToMap")
		elseif unitType == "UNIT_GREAT_ARTIST" then
			TutorialCheck("GreatArtistAddedToMap")
		elseif unitType == "UNIT_GREAT_MUSICIAN" then
			TutorialCheck("GreatMusicianAddedToMap")
		end
	end
end

-- ===========================================================================
function OnTurnBlockerChooseProduction()			TutorialCheck("TurnBlockerChooseProduction"); end

-- ===========================================================================
function OnResearchChooser_ForceHideWorldTracker()	TutorialCheck("ResearchChooser_ForceHideWorldTracker"); end

-- ===========================================================================
function OnNaturalWonderPopupClosed()				TutorialCheck("NaturalWonderPopupClosed"); end

-- ===========================================================================
function OnToggleWorldRankings()					TutorialCheck("WorldRankingsToggled"); end

-- ===========================================================================
function OnProductionPanelClose()					TutorialCheck("ProductionPanelClose");	end

-- ===========================================================================
function OnProductionPanelOpen()					TutorialCheck("ProductionPanelOpen"); end



-- ===========================================================================
function OnImprovementVisibilityChanged( locX :number, locY :number, eImprovementType :number, eVisibility :number )
	if ( eVisibility > 0 ) then
		if( GameInfo.Improvements[eImprovementType].BarbarianCamp ) then
			TutorialCheck("BarbarianVillageDiscovered"); 
		end
		if( GameInfo.Improvements[eImprovementType].Goody ) then
			TutorialCheck("GoodyHutDiscovered"); 
		end
	end
end

-- ===========================================================================
function OnUnitVisibilityChanged( playerID: number, unitID : number, eVisibility : number )
	if( playerID >= 0 and eVisibility > 0 ) then
		if( PlayerManager.IsBarbarian( playerID ) ) then 
			TutorialCheck("BarbarianDiscovered"); 
		end
	end
end

-- ===========================================================================
function OnNotificationAdded(playerID, notificationID)
	local localPlayer = Game.GetLocalPlayer()

	if playerID == localPlayer then
		local notification = NotificationManager.Find(playerID, notificationID)

		if notification ~= nil then
			local notificationType = notification:GetType()
			local lowAmenities = GameInfo.Notifications["NOTIFICATION_CITY_LOW_AMENITIES"]

			if lowAmenities ~= nil and notificationType == lowAmenities.Hash then
				TutorialCheck("LowAmenitiesNotificationAdded")
			end

			local housingLimit = GameInfo.Notifications["NOTIFICATION_HOUSING_PREVENTING_GROWTH"]

			if housingLimit ~= nil and notificationType == housingLimit.Hash then
				TutorialCheck("HousingLimitNotificationAdded")
			end

			local relicCreated = GameInfo.Notifications["NOTIFICATION_RELIC_CREATED"]

			if relicCreated ~= nil and notificationType == relicCreated.Hash then
				TutorialCheck("RelicCreatedNotificationAdded")
			end

			local choosePantheon = GameInfo.Notifications["NOTIFICATION_CHOOSE_PANTHEON"]

			if choosePantheon ~= nil and notificationType == choosePantheon.Hash then
				TutorialCheck("PantheonAvailable")
			end

			local unitPromotionAvailable = GameInfo.Notifications["NOTIFICATION_UNIT_PROMOTION_AVAILABLE"]

			if unitPromotionAvailable ~= nil and notificationType == unitPromotionAvailable.Hash then
				TutorialCheck("UnitPromotionAvailable")
			end

			local citystateQuestGiven = GameInfo.Notifications["NOTIFICATION_CITYSTATE_QUEST_GIVEN"]

			if citystateQuestGiven ~= nil and notificationType == citystateQuestGiven.Hash then
				TutorialCheck("CitystateQuestGiven")
			end

			local claimGreatPerson = GameInfo.Notifications["NOTIFICATION_CLAIM_GREAT_PERSON"]

			if claimGreatPerson ~= nil and notificationType == claimGreatPerson.Hash then
				-- TODO(asherburne): Determine which great person type is available.
				TutorialCheck("GreatPersonAvailable")
			end
		end
	end
end

-- ===========================================================================
function OnTradeRouteCapacityChanged( playerID: number)
	local localPlayer = Game.GetLocalPlayer();
	if (playerID == localPlayer) then
		local pPlayer = Players[playerID];
		if (pPlayer ~= nil) then
			local playerTrade = pPlayer:GetTrade();
			if (playerTrade ~= nil) then
				if (playerTrade:GetOutgoingRouteCapacity() > 0) then
					TutorialCheck("TradeRouteAdded");
				end
			end
		end
	end
end

-- ===========================================================================
function OnUnitChargesChanged( playerID: number, unitID : number, newCharges : number, oldCharges : number )
	local localPlayer = Game.GetLocalPlayer()

	if playerID == localPlayer then
		local unitType = GetUnitType(playerID, unitID)

		if unitType and unitType == "UNIT_BUILDER" then
			if newCharges == 1 then
				TutorialCheck("BuilderChargesOneRemaining");
			end
		end
	end
end

-- ===========================================================================
function OnTradeRouteAddedToMap(player, x, y)
	local localPlayer = Game.GetLocalPlayer()

	if player == localPlayer then
		TutorialCheck("TradeRouteAddedToMap")
	end
end

-- ===========================================================================
function OnUnitPromotionAvailable(player, unit, promotion)
	local localPlayer = Game.GetLocalPlayer()

	if player == localPlayer then
		TutorialCheck("UnitPromotionAvailable")
	end
end

-- ===========================================================================
function OnUnitMoved(player, unit, x, y, locallyVisible, stateChange)
	local localPlayer = Game.GetLocalPlayer()

	if player == localPlayer then
		local unitType = GetUnitType(player, unit)

		if unitType == "UNIT_SCOUT" then
			TutorialCheck("ScoutMoved")
		end
	end
end

-- ===========================================================================
function OnUnitOperationStarted(ownerID, unitID, operationID)
	local localPlayer = Game.GetLocalPlayer()

	if ownerID == localPlayer then
		TutorialCheck("UnitOperationStarted")

		if operationID == UnitOperationTypes.FORTIFY then
			TutorialCheck("UnitFortifyOperationStarted")
		end
	end
end

-- ===========================================================================
function OnUnitEnterFormation()
	TutorialCheck("UnitEnterFormation")
end

-- ===========================================================================
function OnInterfaceModeChanged(oldMode:number, newMode:number)
	if (newMode == InterfaceModeTypes.MOVE_TO) then
		local unit = UI.GetHeadSelectedUnit();
		if (unit ~= nil) then	
			if (unit:GetX() == 16 and unit:GetY() == 14) then
				TutorialCheck("MultiMoveToCity");
			end
		end

	elseif newMode == InterfaceModeTypes.DISTRICT_PLACEMENT then
		TutorialCheck("DistrictPlacementInterfaceMode");

	elseif newMode == InterfaceModeTypes.BUILDING_PLACEMENT then
		TutorialCheck("BuildingPlacementInterfaceMode");	-- aka: wonders!

	end
end

-- ===========================================================================
function OnGovernmentPolicyChanged(player:number, ePolicy:number)
	local localPlayer = Game.GetLocalPlayer();
	if (player == localPlayer) then
		TutorialCheck("GovernmentPolicyChanged");
	end
end

-- ===========================================================================
function OnTeamVictory()
	-- TODO(asherburne): Ensure the local player is victorious.
	TutorialCheck("TeamVictory")
end

-- ===========================================================================
function OnGoodyHutReward()
	TutorialCheck("GoodyHutReward")
end

-- ===========================================================================
function OnCivicChanged(player:number, eCivic:number)
	local localPlayer = Game.GetLocalPlayer();
	if (player == localPlayer) then
		TutorialCheck("CivicChanged");
	end
end

-- ===========================================================================
function ShowYieldIcons( bShow:boolean )
	if bShow then
		LuaEvents.Tutorial_ShowYieldIcons();
	else
		LuaEvents.Tutorial_HideYieldIcons();
	end
end

--[[
-- ===========================================================================
function CloseDiploActionView()
	LuaEvents.Tutorial_CloseDiploActionView();
end

-- ===========================================================================
function  OpenDiploIntelView()
	LuaEvents.Tutorial_ViewDiploIntel();
end

-- ===========================================================================
function  OpenDiploAccessLevelView()
	LuaEvents.Tutorial_ViewDiploAccessLevel();
end

-- ===========================================================================
function  OpenDiploRelationshipView()
	LuaEvents.Tutorial_ViewDiploRelationship();
end
--]]

-- ===========================================================================
-- ===========================================================================
-- ===========================================================================
--	Check LUA Events
-- ===========================================================================
function OnActiveNotification( notification:table )
	TutorialCheck("ActiveNotification")
end

-- ===========================================================================
--	LUA Event
--	LaunchBar_GovernmentOpenGovernments
-- ===========================================================================
function OnGovernmentScreenOpened()
	TutorialCheck("GovernmentScreenOpened");
end

-- ===========================================================================
--	LUA Event
--	GovernmentScreen_PolicyTabOpen
-- ===========================================================================
function OnGovernmentPoliciesOpened()
	TutorialCheck("GovernmentPoliciesOpened");
end

-- ===========================================================================
--	LUA Event
--	LaunchBar_RaiseCivicsTree
-- ===========================================================================
function OnCivicsTreeOpened()
	TutorialCheck("CivicsTreeOpened");
end

-- ===========================================================================
--	LUA Event
--	LaunchBar_CloseCivicsTree
-- ===========================================================================
function OnCivicsTreeClosed()
	TutorialCheck("CivicsTreeClosed");
end

-- ===========================================================================
--	LUA Event
--	LaunchBar_RaiseTechTree
-- ===========================================================================
function OnTechTreeOpened()
	TutorialCheck("TechTreeOpened");
end

-- ===========================================================================
--	LUA Event
--	LaunchBar_OpenReligionPanel
-- ===========================================================================
function OnReligionPanelOpened()
	TutorialCheck("ReligionPanelOpened");
end

-- ===========================================================================
--	LUA Event
--	LaunchBar_CloseReligionPanel
-- ===========================================================================
function OnReligionPanelClosed()
	TutorialCheck("ReligionPanelClosed");
end

-- ===========================================================================
--	LUA Event
--	LaunchBar_OpenGreatPeoplePopup
-- ===========================================================================
function OnGreatPeopleOpened()
	TutorialCheck("GreatPeopleOpened");
end

-- ===========================================================================
--	LUA Event
--	LaunchBar_CloseGreatPeoplePopup
-- ===========================================================================
function OnGreatPeopleClosed()
	TutorialCheck("GreatPeopleClosed");
end

-- ===========================================================================
--	LUA Event
--	TechTree_CloseTechTree
-- ===========================================================================
function OnTechTreeClosed()
	TutorialCheck("TechTreeClosed");
end

-- ===========================================================================
--	LUA Event
--	Advisor Dialog Action
-- ===========================================================================
function OnAdvisorPopupShowDetails( advisorInfo:AdvisorItem )
	if m_active == nil then
		UI.DataError("The advisor popup attempted to switch to detailed mode but an active tutorial item but none is active! info: ".. advisorInfo.Message );
		return;
	end
	if m_active.AdvisorInfo ~= advisorInfo then
		UI.DataError("The advisor popup attempted to switch to detailed mode but there isn't a match.  Active: '" .. tostring(m_active.ID) .."' info: ".. advisorInfo.Message);
		return;
	end
	local item:TutorialItem = m_active;
	MarkTutorialItemSeen( item, true );
	RaiseDetailedTutorial( item );
end

-- ===========================================================================
--	LUA Event
--	Advisor Dialog Action
-- ===========================================================================
function OnAdvisorPopupClearActive( advisorInfo:AdvisorItem )
	if m_active == nil then
		UI.DataError("The advisor popup attempted to clear an active tutorial item but none is active! info: ".. advisorInfo.Message );
		return;
	end
	if m_active.AdvisorInfo ~= advisorInfo then
		UI.DataError("The advisor popup attempted to clear an active tutorial item but there isn't a match.  Active: '" .. tostring(m_active.ID) .."' info: ".. advisorInfo.Message);
		return;
	end

	local item:TutorialItem = m_active;

	if true == item.ShouldMarkSeen then
		MarkTutorialItemSeen( item, true );
	else
		if isDebugVerbose then
			print("should not mark item seen: "..item.ID)
		end
	end

	DeActivateItem( item, true );
end

-- ===========================================================================
--	LUA Event
--	Advisor Dialog Action, turn off the tutorial.
-- ===========================================================================
function OnAdvisorPopupDisableTutorial( advisorInfo:AdvisorItem )
	m_tutorialLevel = TUTORIAL_LEVEL_DISABLED;
	UserConfiguration.TutorialLevel( m_tutorialLevel );
	if( m_active ~= nil ) then
		local item:TutorialItem = m_active;
		DeActivateItem( item, false );
	end
end

-- ===========================================================================
--	LUA Event
--	Set values back after a hotload from the LUA debug cache system.
--	Then make the calls to fix up the scene to how it was pre-hotload
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	if context == DEBUG_CACHE_NAME then	
		local activeItem = nil;
		if contextTable ~= nil then
			if context == DEBUG_CACHE_NAME then		
				m_unseen	= contextTable["m_unseen"];
				activeItem	= contextTable["m_active"];		
				m_lastRaiseListener = contextTable["m_lastRaiseListener"];
			end
			if activeItem ~= nil then 
				ActivateItem(activeItem);
			elseif m_lastRaiseListener ~= "" then
				TutorialCheck( m_lastRaiseListener );
			end
		else
			UI.DataError("WARNING: Failed to retrieve hotload context table; likely previous hotload didn't complete due to an error in the LUA file.");
		end
	end
end

-- ===========================================================================
--	LUA Event
--	ProductionPanel_Open
-- ===========================================================================
function OnProductionPanelViaCityOpen()
	TutorialCheck("ProductionPanelViaCityOpen");
end

-- ===========================================================================
--	LUA Event
--	WorldRankings_Close
-- ===========================================================================
function OnWorldRankingsOpened()
	TutorialCheck("WorldRankingsOpened");
end

-- ===========================================================================
--	LUA Event
--	WorldRankings_Close
-- ===========================================================================
function OnWorldRankingsClosed()
	TutorialCheck("WorldRankingsClosed");
end

-- ===========================================================================
--	LUA Event
--	TradeRouteChooser_Open
-- ===========================================================================
function OnTradeChooserOpened()
	TutorialCheck("TradeRouteChooserOpened");
end

-- ===========================================================================
--	LUA Event
--	TradeRouteChooser_Close
-- ===========================================================================
function OnTradeChooserClosed()
	TutorialCheck("TradeRouteChooserClosed");
end

-- ===========================================================================
--	LUA Event
--	TradeRouteChooser_RouteConsidered
-- ===========================================================================
function OnTradeRouteConsidered()
	TutorialCheck("TradeRouteConsidered");
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnShutdown()
	-- Cache values for hotloading...
	LuaEvents.GameDebug_AddValue(DEBUG_CACHE_NAME, "m_unseen", m_unseen );
	LuaEvents.GameDebug_AddValue(DEBUG_CACHE_NAME, "m_active", m_active );
	LuaEvents.GameDebug_AddValue(DEBUG_CACHE_NAME, "m_lastRaiseListener", m_lastRaiseListener );

	-- Cleanup events
	Events.CityAddedToMap.Remove(			OnCityAddedToMap );
	Events.CityProductionChanged.Remove(	OnCityProductionChanged );
	Events.CityProductionCompleted.Remove(	OnCityProductionCompleted );
	Events.CityPopulationChanged.Remove(	OnCityPopulationChanged );
	Events.CivicCompleted.Remove(			OnCivicCompleted );
	Events.EndTurnDirty.Remove(				OnEndTurnDirty );
	Events.ImprovementAddedToMap.Remove(	OnImprovementAddedToMap );
	Events.ImprovementChanged.Remove(		OnImprovementChanged );
	Events.ImprovementActivated.Remove(		OnImprovementActivated );
	Events.ImprovementVisibilityChanged.Remove(	OnImprovementVisibilityChanged );
	Events.InfluenceChanged.Remove(			OnInfluenceChanged );
	Events.DiplomacyDeclareWar.Remove(		OnDiplomacyDeclareWar );
	Events.DiplomacyStatement.Remove(		OnDiplomacyStatement );
	Events.DiplomacyMeet.Remove(			OnDiplomacyMeet );
	Events.DiplomacyMeetMajors.Remove(		OnDiplomacyMeetMajors );
	Events.InterfaceModeChanged.Remove(		OnInterfaceModeChanged );
	Events.LoadScreenClose.Remove(			OnLoadScreenClose );
	Events.LocalPlayerTurnEnd.Remove(		OnLocalPlayerTurnEnd );
	Events.LocalPlayerTurnBegin.Remove(		OnLocalPlayerTurnBegin );
	Events.ResearchChanged.Remove(			OnResearchChanged );
	Events.ResearchCompleted.Remove(		OnResearchCompleted );
	Events.FaithChanged.Remove(				OnFaithChanged );
	Events.TreasuryChanged.Remove(			OnTreasuryChanged );
	Events.PantheonFounded.Remove(			OnPantheonFounded );
	Events.TradeRouteAddedToMap.Remove(		OnTradeRouteAddedToMap );
	Events.UnitAddedToMap.Remove(			OnUnitAddedToMap );
	Events.UnitChargesChanged.Remove(		OnUnitChargesChanged );
	Events.UnitEnterFormation.Remove(		OnUnitEnterFormation );
	Events.UnitKilledInCombat.Remove(		OnUnitKilledInCombat );
	Events.UnitMoveComplete.Remove(			OnUnitMoveComplete );
	Events.UnitMoved.Remove(				OnUnitMoved );
	Events.UnitOperationStarted.Remove(		OnUnitOperationStarted );
	Events.UnitPromotionAvailable.Remove(	OnUnitPromotionAvailable );
	Events.UnitSelectionChanged.Remove(		OnUnitSelectionChanged );
	Events.UnitVisibilityChanged.Remove(	OnUnitVisibilityChanged );
	Events.NotificationAdded.Remove(		OnNotificationAdded );
	Events.GovernmentPolicyChanged.Remove(	OnGovernmentPolicyChanged );
	Events.TeamVictory.Remove(				OnTeamVictory );
	Events.GoodyHutReward.Remove(			OnGoodyHutReward );
	Events.CivicChanged.Remove(				OnCivicChanged );
	

	LuaEvents.ActionPanel_ActivateNotification.Remove(		OnActiveNotification );
	LuaEvents.AdvisorPopup_ShowDetails.Remove(				OnAdvisorPopupShowDetails );
	LuaEvents.AdvisorPopup_ClearActive.Remove(				OnAdvisorPopupClearActive );
	LuaEvents.AdvisorPopup_DisableTutorial.Remove(			OnAdvisorPopupDisableTutorial );
	LuaEvents.CityPanel_ProductionOpen.Remove(				OnProductionPanelViaCityOpen );
	LuaEvents.CivicsTree_CloseCivicsTree.Remove(			OnCivicsTreeClosed);
	LuaEvents.GameDebug_Return.Remove(						OnGameDebugReturn );		-- hotloading help
	LuaEvents.GovernmentScreen_PolicyTabOpen.Remove(		OnGovernmentPoliciesOpened);
	LuaEvents.LaunchBar_GovernmentOpenMyGovernment.Remove(	OnGovernmentScreenOpened);
	LuaEvents.LaunchBar_RaiseCivicsTree.Remove(				OnCivicsTreeOpened);
	LuaEvents.LaunchBar_CloseCivicsTree.Remove(				OnCivicsTreeClosed);
	LuaEvents.LaunchBar_RaiseTechTree.Remove(				OnTechTreeOpened);
	LuaEvents.TechTree_CloseTechTree.Add(					OnTechTreeClosed);
	LuaEvents.NaturalWonderPopup_Closed.Remove(				OnNaturalWonderPopupClosed );
	LuaEvents.PartialScreenHooks_OpenWorldRankings.Remove(	OnWorldRankingsOpened );
	LuaEvents.PartialScreenHooks_CloseWorldRankings.Remove(	OnWorldRankingsClosed );
	LuaEvents.ProductionPanel_Close.Remove(					OnProductionPanelClose );
	LuaEvents.ProductionPanel_Open.Remove(					OnProductionPanelOpen );	
	LuaEvents.ResearchChooser_ForceHideWorldTracker.Remove(	OnResearchChooser_ForceHideWorldTracker );
	LuaEvents.TurnBlockerChooseProduction.Remove(			OnTurnBlockerChooseProduction );	
	LuaEvents.DiploScene_SceneClosed.Remove(				OnDiploScene_SceneClosed );
end

-- ===========================================================================
function HasBeenSerialized( item:TutorialItem )
	if item ~= nil then
		local pTutorialParameters = UI.GetGameParameters():Get("TutorialMain");
		if pTutorialParameters ~= nil then
			local pScenario = pTutorialParameters:Get( item.ScenarioName );
			if pScenario ~= nil then
				local pCompleted = pScenario:Get("Completed");
				if pCompleted ~= nil then
					for i = 0, pCompleted:GetCount() - 1, 1 do
					local pID = pCompleted:GetValueAt(i);
						if pID ~= nil then
							if pID == item.ID then
								return true;
							end
						end
					end
				end
			end
		end
	end
	return false;
end

-- ===========================================================================
function SerializeCompletedItem( item:TutorialItem )
	if item ~= nil then
		if( not HasBeenSerialized( item ) )then
			local pTutorialParameters = UI.GetGameParameters():Add("TutorialMain");
			if pTutorialParameters ~= nil then
				local pScenario = pTutorialParameters:Add( item.ScenarioName );
				if pScenario ~= nil then
					local pCompleted = pScenario:Add("Completed");
					if pCompleted ~= nil then
						pCompleted:AppendValue( item.ID );
					end
				end
			end
		end
	end
end

-- ===========================================================================
--	Serialize custom data and append to any existing data.
--	key		must be a string
--	value	can be anything
-- ===========================================================================
function AppendCustomData( key:string, value )
	local pParameters :table = UI.GetGameParameters():Add("CustomData");
	if pParameters ~= nil then
		local pData:table = pParameters:Add( key );
		pData:AppendValue( value );
	else
		UI.DataError("Could not append CustomData: ",k,v);
	end
end

-- ===========================================================================
--	Serialize custom data in the custom data table.
--	key		must be a string
--	value	can be anything
-- ===========================================================================
function WriteCustomData( key:string, value )
	local pParameters :table = UI.GetGameParameters():Add("CustomData");
	if pParameters ~= nil then
		pParameters:Remove( key );
		local pData:table = pParameters:Add( key );
		pData:AppendValue( value );
	else
		UI.DataError("Could not write CustomData: ",k,v);
	end
end

-- ===========================================================================
--	Read back custom data, returns NIL if not found.
--	key		must be a string
--	RETURNS: all values from the associated key (or nil if key isn't found)
-- ===========================================================================
function ReadCustomData( key:string )
	local pParameters	:table = UI.GetGameParameters():Get("CustomData");
	local kReturn		:table = {};
	if pParameters ~= nil then
		local pValues:table = pParameters:Get( key );
		
		-- No key or empty key?  Return nil...
		if pValues == nil then
			return nil;
		end
		local count:number = pValues:GetCount();
		if count == 0 then
			return nil;
		end

		for i = 1, count, 1 do
			local value = pValues:GetValueAt(i-1);
			table.insert(kReturn, value);
		end
	else
		return nil;
	end
	return unpack(kReturn);
end

-- ===========================================================================
function MarkSerializedItems()
	for scenario,list in pairs( m_unseen ) do
		for id,item in pairs( list ) do
			if HasBeenSerialized( item ) then
				MarkTutorialItemSeen( item, false ); -- don't reserialize it
			end
		end
	end

	if isDebugInfoShowing then
		for debugId,debugItem in pairs(m_uiDebugItemList) do
			local isSeen:boolean = true;
			local isFound:boolean = false;
			for scenario,list in pairs( m_unseen ) do
				for id,item in pairs( list ) do
					if id == debugId then
						isSeen = false;
						isFound = true;			
						break;
					end
				end
				if isFound then
					break;
				end
			end
			if isSeen and m_active ~= nil and m_active.ID ~= debugId then
				debugItem.TutorialID:SetColor( COLOR_DEBUG_SEEN_ID );
			end
		end
	end
end

-- ===========================================================================
function LoadItems()
	m_unseen = {};		-- Clear
	m_turn	 = -1;

	-- Initialize the tutorial system.
	-- If it's a first run, be sure to initialize first run info; otherwise
	-- deserialize saved information from disk.
	local tutorialDefinition:TutorialDefinition = InitializeTutorial();
	if ReadCustomData("fromSave")==nil then
		InitFirstRun();
		WriteCustomData("fromSave",true);
	else
		LuaEvents.TutorialUIRoot_GoalsLoadFromDisk();		--Serialization issue
		ReadUnitHexRestrictions();
		ReadUnitMoveRestrictions();
	end
		
	local about	  = ReadCustomData("about");	if about ~= nil then print("Tutorial: "..tostring(about)); end
	local version = ReadCustomData("version");	if version ~= nil then print("Version: "..tostring(version)); end
	local turn	  = ReadCustomData("turn");		
	if turn ~= nil then	
		m_turn = turn; 
	end

	print("Loading bank of items for tutorial scenario: '"..tutorialDefinition.Id.."'");
	for _,loadBank in ipairs(tutorialDefinition.Bank) do
		loadBank();
	end

	-- Populate debug panel if supported.
	if isDebugInfoShowing then	
		
		local instance:table = {};

		-- Header				
		ContextPtr:BuildInstanceForControl("TutorialEntryInstance", instance, Controls.TutorialItemStack);
		instance.TutorialID:SetText( "2D Overlay enabled: ...");
		m_uiDebugItemList["_HEADER_OVERLAY"] = instance;

		-- Items
		for i,id in ipairs(m_debugAddOrder) do
			local item:TutorialItem;
			for k,v in pairs(m_unseen) do				
				item = v[id];
				if item ~= nil then break; end
			end
			if item ~= nil then
				instance = {};
				ContextPtr:BuildInstanceForControl("TutorialEntryInstance", instance, Controls.TutorialItemStack);
				instance.TutorialID:SetText( tostring(i)..". " .. item.ID );
				--[[ ??TRON -- Not ready...
				instance.TutorialID:RegisterCallback( Mouse.eLClick, function() OnForceMarkDone( item.ScenarioName, item.ID ); end );
				instance.TutorialID:RegisterCallback( Mouse.eMClick, function() OnForceMarkActive( item.ScenarioName, item.ID ); end );
				instance.TutorialID:RegisterCallback( Mouse.eRClick, function() OnForceMarkUnseen( item.ScenarioName, item.ID ); end );
				]]
				m_uiDebugItemList[item.ID] = instance;							-- store UI control reference for later lookup by id
			end
		end
		Controls.TutorialItemStack:CalculateSize();
		Controls.TutorialScroll:CalculateSize();
	end
end

-- ===========================================================================
function Initialize()

	RefreshTutorialLevel();
	LoadItems();
	
	-- UI Events
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetInputHandler( OnInput, true );

	
	-- Engine Events
	Events.CityAddedToMap.Add(			OnCityAddedToMap );
	Events.CityProductionChanged.Add(	OnCityProductionChanged );
	Events.CityProductionCompleted.Add(	OnCityProductionCompleted );
	Events.CityPopulationChanged.Add(	OnCityPopulationChanged );
	Events.CivicChanged.Add(			OnCivicChanged );
	Events.CivicCompleted.Add(			OnCivicCompleted );
	Events.EndTurnDirty.Add(			OnEndTurnDirty );
	Events.GovernmentPolicyChanged.Add( OnGovernmentPolicyChanged );
	Events.TeamVictory.Add(				OnTeamVictory );
	Events.GoodyHutReward.Add(			OnGoodyHutReward );
	Events.ImprovementAddedToMap.Add(	OnImprovementAddedToMap );
	Events.ImprovementChanged.Add(		OnImprovementChanged );
	Events.ImprovementActivated.Add(	OnImprovementActivated );
	Events.ImprovementVisibilityChanged.Add( OnImprovementVisibilityChanged );
	Events.InfluenceChanged.Add(		OnInfluenceChanged );
	Events.DiplomacyDeclareWar.Add(		OnDiplomacyDeclareWar );
	Events.DiplomacyStatement.Add(		OnDiplomacyStatement );
	Events.DiplomacyMeet.Add(			OnDiplomacyMeet );
	Events.DiplomacyMeetMajors.Add(		OnDiplomacyMeetMajors );
	Events.DistrictAddedToMap.Add(		OnDistrictAddedToMap );
	Events.BuildingAddedToMap.Add(		OnBuildingAddedToMap );
	Events.InterfaceModeChanged.Add(	OnInterfaceModeChanged );
	Events.LocalPlayerTurnBegin.Add(	OnLocalPlayerTurnBegin );
	Events.LocalPlayerTurnEnd.Add(		OnLocalPlayerTurnEnd );
	Events.LoadScreenClose.Add(			OnLoadScreenClose );
	Events.ResearchChanged.Add(			OnResearchChanged );
	Events.ResearchCompleted.Add(		OnResearchCompleted );
	Events.FaithChanged.Add(			OnFaithChanged );
	Events.TreasuryChanged.Add(			OnTreasuryChanged );
	Events.PantheonFounded.Add(			OnPantheonFounded );
	Events.TradeRouteAddedToMap.Add(	OnTradeRouteAddedToMap );
	Events.UnitAddedToMap.Add(			OnUnitAddedToMap );
	Events.UnitChargesChanged.Add(		OnUnitChargesChanged );
	Events.UnitEnterFormation.Add(		OnUnitEnterFormation );
	Events.UnitKilledInCombat.Add(		OnUnitKilledInCombat );
	Events.UnitMoveComplete.Add(		OnUnitMoveComplete );
	Events.UnitMoved.Add(				OnUnitMoved );
	Events.UnitOperationStarted.Add(	OnUnitOperationStarted );
	Events.UnitPromotionAvailable.Add(	OnUnitPromotionAvailable );
	Events.UnitSelectionChanged.Add(	OnUnitSelectionChanged );
	Events.UnitVisibilityChanged.Add(	OnUnitVisibilityChanged );
	Events.NotificationAdded.Add(		OnNotificationAdded );
	Events.TradeRouteCapacityChanged.Add( OnTradeRouteCapacityChanged );
	
	-- LUA Events
	LuaEvents.ActionPanel_ActivateNotification.Add(		OnActiveNotification );
	LuaEvents.AdvisorPopup_ShowDetails.Add(				OnAdvisorPopupShowDetails );
	LuaEvents.AdvisorPopup_ClearActive.Add(				OnAdvisorPopupClearActive );
	LuaEvents.AdvisorPopup_DisableTutorial.Add(			OnAdvisorPopupDisableTutorial );
	LuaEvents.CityPanel_ProductionOpen.Add(				OnProductionPanelViaCityOpen );
	LuaEvents.CivicsTree_CloseCivicsTree.Add(			OnCivicsTreeClosed);
	LuaEvents.DiploScene_SceneClosed.Add(				OnDiploScene_SceneClosed );
	LuaEvents.DiplomacyRibbon_OpenDiplomacyActionView.Add( OnOpenDiploActionView );
	LuaEvents.GameDebug_Return.Add(						OnGameDebugReturn );		-- hotloading help
	LuaEvents.GovernmentScreen_PolicyTabOpen.Add(		OnGovernmentPoliciesOpened);
	LuaEvents.LaunchBar_GovernmentOpenMyGovernment.Add(	OnGovernmentScreenOpened);
	LuaEvents.LaunchBar_RaiseCivicsTree.Add(			OnCivicsTreeOpened);
	LuaEvents.LaunchBar_CloseCivicsTree.Add(			OnCivicsTreeClosed);
	LuaEvents.LaunchBar_RaiseTechTree.Add(				OnTechTreeOpened);
	LuaEvents.LaunchBar_OpenReligionPanel.Add(			OnReligionPanelOpened);
	LuaEvents.LaunchBar_OpenGreatPeoplePopup.Add(		OnGreatPeopleOpened);
	LuaEvents.LaunchBar_CloseGreatPeoplePopup.Add(		OnGreatPeopleClosed);
	LuaEvents.NaturalWonderPopup_Closed.Add(			OnNaturalWonderPopupClosed );
	LuaEvents.PartialScreenHooks_OpenWorldRankings.Add( OnWorldRankingsOpened );
	LuaEvents.PartialScreenHooks_CloseWorldRankings.Add(OnWorldRankingsClosed );
	LuaEvents.ProductionPanel_Close.Add(				OnProductionPanelClose );
	LuaEvents.ProductionPanel_Open.Add(					OnProductionPanelOpen );	
	LuaEvents.Religion_CloseReligion.Add(				OnReligionPanelClosed);
	LuaEvents.ResearchChooser_ForceHideWorldTracker.Add(OnResearchChooser_ForceHideWorldTracker );
	LuaEvents.TechTree_CloseTechTree.Add(				OnTechTreeClosed);
	LuaEvents.TradeRouteChooser_Open.Add(				OnTradeChooserOpened );
	LuaEvents.TradeRouteChooser_Close.Add(				OnTradeChooserClosed );
	LuaEvents.TradeRouteChooser_RouteConsidered.Add(	OnTradeRouteConsidered );
	LuaEvents.TurnBlockerChooseProduction.Add(			OnTurnBlockerChooseProduction );	
	LuaEvents.WorldRankings_Close.Add(					OnWorldRankingsClosed );
end
Initialize();
