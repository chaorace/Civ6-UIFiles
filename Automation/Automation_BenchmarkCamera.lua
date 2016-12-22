-------------------------------------------------------------------------------
-- A set of activities for the automated oberver to do with the camera.
-------------------------------------------------------------------------------

hstructure Entry
	player : number;
	id : number;
	x : number;
	y : number;
end

-- List of the visible cities
local ms_VisibleCities = {};

-- Camera zoom level to use
local ZOOM = 0.95

-------------------------------------------------------------------------------
-- Add an object to a list of things to look at
function AddToList(objects : table , player : number, id : number)
	-- See if it is in the list already
	for _, v in ipairs(objects) do
		if (v.id == id and v.player == player) then
			return v;
		end
	end

	local o = hmake Entry { };
	o.id = id;
	o.player = player;

	table.insert(objects, o);
	local nLast = #objects;
	return objects[ nLast ];
end

-------------------------------------------------------------------------------
-- Remove an object from a list of things to look at
function RemoveFromList(objects : table , player : number, id : number)
	for i, v in ipairs(objects) do
		if (v.id == id and v.player == player) then
			table.remove(objects, i);
			return;
		end
	end
end

-------------------------------------------------------------------------------
-- See if an entry is in the list
function GetEntryForPlayer(objects : table , player : number, id : number)
	for i, v in ipairs(objects) do
		if (v.id == id and v.player == player) then
			return v;
		end
	end
end

-------------------------------------------------------------------------------
-- The visibility of a city has changed, update our look at lists.
function OnCityVisibilityChanged(player, id, eVisibility)
	if (eVisibility == 2) then
		local o = AddToList(ms_VisibleCities, player, id);
		local pCity = CityManager.GetCity(player, id);
		if (pCity ~= nil) then
			o.x = pCity:GetX();
			o.y = pCity:GetY();
		end
	else
		RemoveFromList(ms_VisibleCities, player, id);
	end
end
Events.CityVisibilityChanged.Add( OnCityVisibilityChanged );

-------------------------------------------------------------------------------
-- A players turn has started
function OnPlayerTurnActivated( player, bFirstTime )
	if (bFirstTime) then
		local pPlayer = Players[player];
		if (pPlayer:IsMajor()) then
			local pPlayerCities = pPlayer:GetCities();
			local pCapital = pPlayerCities:GetCapitalCity();
			if (pCapital ~= nil) then
				-- Check if it is in the list of visible cities
				local kEntry = GetEntryForPlayer(ms_VisibleCities, player, pCapital:GetID());
				if (kEntry ~= nil) then
					UI.LookAtPlot(kEntry.x, kEntry.y, ZOOM);
				end
			end
		end
	end
end
Events.PlayerTurnActivated.Add( OnPlayerTurnActivated );

-------------------------------------------------------------------------------
function OnCombatVisBegin(combatMembers)
	local attacker = combatMembers[1];
	if (attacker.componentType == ComponentType.UNIT) then
		local pUnit = UnitManager.GetUnit(attacker.playerID, attacker.componentID);
		if (pUnit ~= nil) then
			UI.LookAtPlot(pUnit:GetX(), pUnit:GetY(), ZOOM);
		end			
	end
end
Events.CombatVisBegin.Add( OnCombatVisBegin );


-------------------------------------------------------------------------------
-- TODO consider adding more events to look at
--		Improvement added
--		Building added
--		District added
--		Great person activated
--		Great work completed
--		City religion changed
--		more?
-------------------------------------------------------------------------------
function OnAutomationGameStarted()
	-- Look at the local observer's capitol
	OnPlayerTurnActivated(Game:GetLocalObserver(), true);
end
LuaEvents.AutomationGameStarted.Add( OnAutomationGameStarted );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
local OldTODSpeed : number = 0;
local OldAmbientTOD : boolean = false;
function OnBenchmarkStart()

	OldTODSpeed = UI.GetAmbientTimeOfDaySpeed();
	OldAmbientTOD = UI.IsAmbientTimeOfDayAnimating();

	-- Enable TOD
	UI.SetAmbientTimeOfDayAnimating( true );
	UI.SetAmbientTimeOfDaySpeed(50);
end
Events.BenchmarkStart.Add( OnBenchmarkStart );

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnBenchmarkEnd()
	UI.SetAmbientTimeOfDaySpeed(OldTODSpeed);
	UI.SetAmbientTimeOfDayAnimating(OldAmbientTOD);
end
Events.BenchmarkEnd.Add(OnBenchmarkEnd);

-------------------------------------------------------------------------------
-- Toggle the current lookat
-------------------------------------------------------------------------------
local g_Current : number = -1; --The ID of the next item to look at
function OnBenchmarkToggleLookAt()
	g_Current = g_Current + 1;
	if( g_Current > #ms_VisibleCities ) then
		g_Current = 0;
	end

	for i, v in ipairs(ms_VisibleCities) do
		if( i == g_Current ) then
			UI.LookAtPlot(v.x, v.y, ZOOM);
			return;
		end
	end
end
Events.BenchmarkToggleLookAt.Add( OnBenchmarkToggleLookAt );

