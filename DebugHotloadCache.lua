-- ===========================================================================
--	Provides in-game debug functionality including:
--		- Caching UI held values (useful across hotloads)
-- ===========================================================================


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_cachedValues	:table = {};	--	Hold a table of "context tables", each holding key/value pairs (to utilize between hotloads)


-- ===========================================================================
--	Adds a value to the LUA cache
--	Great for storing values across hotloading when debugging/editing.
--
--	usage:	
--		LuaEvents.GameDebug_AddValue( "MyContextName", "foo", bar );
--		
-- ===========================================================================
function OnAddValue( context:string, key:string, value )
	local contextTable :table = m_cachedValues[context];
	if contextTable == nil then contextTable={}; end		-- create table for context values, if it doesn't exist
	contextTable[key] = value;
	m_cachedValues[context] = contextTable;
end

-- ===========================================================================
--	Obtain a value to the LUA cache
--	Great for storing values across hotloading when debugging/editing.
--
--	usage:	
--		LuaEvents.GameDebug_GetValues( "MyContextName" );
--		function OnGameDebugReturn( context, contextTable )
--			if context=="MyContextName" then
--				m_internalBar = contextTable["foo"];
--			end
--		end
--		LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );
--		
-- ===========================================================================
function OnGetValues( context:string )	
	local contextTable :table = m_cachedValues[context];
	LuaEvents.GameDebug_Return( context, contextTable );
end


-- ===========================================================================
-- ===========================================================================
function Initialize()
	print("GameDebug initialized!");
	LuaEvents.GameDebug_AddValue.Add( OnAddValue );
	LuaEvents.GameDebug_GetValues.Add( OnGetValues );
end
Initialize();

