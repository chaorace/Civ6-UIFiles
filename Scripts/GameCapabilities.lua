-------------------------------------------------------------------------------
-- GameCapabilities.lua
-- This lua script contains a few utility functions to simplify/abstract
-- the logic necessary to test whether a capability exists in game.
-------------------------------------------------------------------------------

function HasCapability(c)
	return GameInfo.GameCapabilities[c] ~= nil;
end