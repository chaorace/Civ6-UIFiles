-- ===========================================================================
--	TutorialGoals
--	Show goals to be completed during the tutorial
-- ===========================================================================
include( "InstanceManager" );


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID:string = "TutorialGoals"; -- Must be unique (usually the same as the file name)


-- ===========================================================================
--	VARIABLES
-- ===========================================================================

-- Goals for the Goal dialog.
hstructure GoalItem
	Id				: string;		-- Id of item
	Text			: string;		-- Text to always display
	Tooltip			: string;		-- (optional) tooltip text
	IsCompleted		: boolean;		-- Is the goal completed?
	ItemId			: string;		-- For debugging, the id of the item that is setting the goal
	CompletedOnTurn	: number;		-- Which turn # the tutorial goal was completed on (required for auto-remove)
end

local m_goalIM				: table = InstanceManager:new( "GoalInstance", "Top", Controls.GoalList );
local m_kGoals				: table = {};
local m_uiGoals				: table = {};
local m_kCompletedGoalIds	: table = {};



-- ===========================================================================
--	MEMBERS
-- ===========================================================================


-- ===========================================================================
function CreateGoalUI( goal:GoalItem )
	local inst:table = m_goalIM:GetInstance();
	inst.Top:GetTextButton():SetText( goal.Text );
	inst.Top:SetToolTipString( goal.Tooltip );
	inst.Top:SetCheck( m_kCompletedGoalIds[goal.Id] ~= nil );
	m_uiGoals[goal.Id] = inst;	
end


-- ===========================================================================
function WriteGoalField( pWriter:table, fieldName:string, value )
	local writeValue:table = pWriter:Add( fieldName );
	writeValue:AppendValue( value );
end

-- ===========================================================================
--	Write's a goal to save system.
-- ===========================================================================
function WriteGoal( goal:GoalItem )
	local pParameters :table = UI.GetGameParameters():Get("TutorialGoals");
	if pParameters == nil then
		pParameters = UI.GetGameParameters():Add("TutorialGoals");
	end
		
	if pParameters ~= nil then
		local pGoal :table = pParameters:Get(goal.Id);
		if pGoal ~= nil then
			pParameters:Remove( goal.Id );
		end
		pGoal = pParameters:Add( goal.Id );		
				
		WriteGoalField( pGoal, "Id",				goal.Id );
		WriteGoalField( pGoal, "Text",				goal.Text );
		WriteGoalField( pGoal, "Tooltip",			goal.Tooltip );
		WriteGoalField( pGoal, "IsCompleted",		goal.IsCompleted );
		WriteGoalField( pGoal, "ItemId",			goal.ItemId );
		WriteGoalField( pGoal, "CompletedOnTurn",	goal.CompletedOnTurn );
	else
		UI.DataError("Could not write Tutorial Goal: ", goal.Id);
	end
end

-- ===========================================================================
function ReadGoal( pValues:table )
	local goal:GoalItem = hmake GoalItem {
		Id				= pValues["Id"][1],
		Text			= pValues["Text"][1],
		Tooltip			= pValues["Tooltip"][1],
		IsCompleted		= pValues["IsCompleted"][1], 
		ItemId			= pValues["ItemId"][1],
		CompletedOnTurn	= pValues["CompletedOnTurn"][1]
	}
	return goal;
end


-- ===========================================================================
--	Reads all goals save on disk to the running goal system.
-- ===========================================================================
function OnGoalsLoadFromDisk()
	local pParameters :table = UI.GetGameParameters():Get("TutorialGoals");
	if pParameters == nil then
		return;	-- No goals written.
	end

	local count:number = pParameters:GetCount();
	if count == 0 then
		return;
	end
	for i = 0, count-1, 1 do
		local pGoalAsData:table = pParameters:GetValueAt(i);
		if pGoalAsData ~= nil then
			local pGoal	:GoalItem = ReadGoal( pGoalAsData );
			if pGoal.IsCompleted then
				m_kCompletedGoalIds[pGoal.Id] = true;
			else
				m_kGoals[pGoal.Id] = pGoal;
				CreateGoalUI( pGoal );
			end
		end
	end
	Controls.GoalList:CalculateSize();
	ContextPtr:SetHide( table.count(m_kGoals) < 1 )
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnAdd( goal:GoalItem )
	if m_kGoals[goal.Id] ~= nil then
		local existingGoal : GoalItem = m_kGoals[goal.Id];
		UI.DataError("TutorialGoal cannot add '"..goal.Id.."' from item '"..goal.ItemId.."' because it was already added by item '"..existingGoal.ItemId.."'");	
		return;
	end
	m_kGoals[goal.Id] = goal;
	CreateGoalUI( goal );
	WriteGoal( goal );
	Controls.GoalList:CalculateSize();
	ContextPtr:SetHide( table.count(m_kGoals) < 1 )
end

-- ===========================================================================
--	LUA Event
--	goalId	the id of the goal completed
--	currentTurn	the current turn # of the engine
-- ===========================================================================
function OnMarkComplete( goalId:string, currentTurn:number )
	if goalId == nil then
		UI.DataError("A NIL goal id was passed to  mark complete.");
		return;
	end
	if m_kGoals[goalId] == nil then
		UI.DataError("Tutorial could not mark complete '"..goalId.."' as it's not in the goals list.");
		return;
	end
	m_kGoals[goalId].IsCompleted = true;
	m_kGoals[goalId].CompletedOnTurn = currentTurn;	
	m_uiGoals[goalId].Top:SetCheck( true );
	m_kCompletedGoalIds[goalId] = true;
	WriteGoal( m_kGoals[goalId] );
end

-- ===========================================================================
function Remove( goal:GoalItem )
	m_kGoals[goal.Id] = nil;	
	m_goalIM:ReleaseInstance( m_uiGoals[goal.Id] );
	Controls.GoalList:CalculateSize();
	ContextPtr:SetHide( table.count(m_kGoals) < 1 )
end


-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnRemove( goal:GoalItem )
	Remove( goal );
end

-- ===========================================================================
--	LUA Event
--	Only open if goals are populated.
-- ===========================================================================
function OnOpen()
	if table.count(m_kGoals) > 0 then
		ContextPtr:SetHide( false );
	end
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnClose()
	ContextPtr:SetHide( true );
end
-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnGoalAutoRemove( currentTurn:number )
	-- Loop through all goals and remove any that were completed before this turn
	for _,goal in pairs(m_kGoals) do
		if goal.IsCompleted and goal.CompletedOnTurn < currentTurn then
			Remove( goal );
		end
	end
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
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_kGoals",				m_kGoals);
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_kCompletedGoalIds",	m_kCompletedGoalIds);
end
function OnGameDebugReturn(context:string, contextTable:table)	
	if context == RELOAD_CACHE_ID then
		m_kGoals			= contextTable["m_kGoals"];
		m_kCompletedGoalIds	= contextTable["m_kCompletedGoalIds"];
		for k,v in pairs(m_kGoals) do		
			CreateGoalUI(v);
		end
	end
end


-- ===========================================================================
function Test()
	local test:GoalItem = hmake GoalItem {
		Id = "ID_FOO",
		Text = "foo text",
		Tooltip = "tooolyasdfjkl",
		IsCompleted = false,
		ItemId = "ID_ITEM_FOO"
	}
	OnAdd( test );
	test.Id = "ID_BAR";
	test.Text= "akjsdhfkjashfkasl dkajsf kdsah";
	OnAdd( test );
	test.Id = "ID_BAZ";
	test.Text= "ak j s d hfkjashfkasl dkajsf kdsa s d hfkjashfkasl dkajsf kdsa s d hfkjashfkasl dkajsf kdsa s d hfkjashfkasl dkajsf kdsa s d hfkjashfkasl dkajsf kdsa s d hfkjashfkasl dkajsf kdsa h";
	OnAdd( test );
end


-- ===========================================================================
function Initialize()

	-- Static controls:
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetShowHandler( function() LuaEvents.TutorialGoals_Showing(); end );
	ContextPtr:SetHideHandler( function() LuaEvents.TutorialGoals_Hiding(); end );
	
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );
	LuaEvents.TutorialUIRoot_GoalAdd.Add( OnAdd );
	LuaEvents.TutorialUIRoot_GoalMarkComplete.Add( OnMarkComplete );
	LuaEvents.TutorialUIRoot_GoalRemove.Add( OnRemove );
	LuaEvents.TutorialUIRoot_OpenGoals.Add( OnOpen );
	LuaEvents.TutorialUIRoot_CloseGoals.Add( OnClose );
	LuaEvents.TutorialUIRoot_GoalAutoRemove.Add( OnGoalAutoRemove )
	LuaEvents.TutorialUIRoot_GoalsLoadFromDisk.Add( OnGoalsLoadFromDisk )
end
Initialize();
