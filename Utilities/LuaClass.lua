--[[
-- Created by Samuel Batista on Friday Apr 19 2017
-- Copyright (c) Firaxis Games
--]]

LuaClass = {}

function LuaClass:new(o:table)
	--
	-- The new instance of the object needs an index table.
	-- This next statement prefers to use "o" as the
	-- index table, but will fall back to self.
	-- Without the proper index table, your new object will
	-- not have the proper behavior.
	--
	o = o or self;
	
	--
	-- This call to setmetatable does 3 things:
	-- 1. Makes a new table.
	-- 2. Sets its metatable to the "index" table
	-- 3. Returns that table.
	--
	local object = setmetatable({}, o);
	
	--
	-- Obtain the metatable of the newly instantiated table.
	-- Make sure that if the user attempts to access newObject[key]
	-- and newObject[key] is nil, that it will actually fall
	-- back to looking up template[key]...and so on, because template
	-- should also have a metatable with the correct __index metamethod.
	--
	local mt = getmetatable(object);
	mt.__index = o;
	
	return object;
end

function LuaClass:Extend()
	--
	-- This is just a convenience function/semantic extension
	-- so that objects which need to inherit from a base object
	-- use a clearer function name to describe what they are doing.
	--
	return setmetatable({}, {__index = self})
end