----------------------------------------------------------------
-- A set of standard automation tests. 
----------------------------------------------------------------

-- The table of tests
Tests = {};

-----------------------------------------------------------------
-- A test to start a new game an autoplay it for a set number of turns.
-----------------------------------------------------------------

function PlayGame_OnSaveComplete()
	-- Signal that the test is complete.  Do not call LuaEvents.AutomationTestComplete() directly.  The Automation system will do that at a safe time.
	Automation.SendTestComplete();
end

-----------------------------------------------------------------
-- Handle the autoplay end for the "PlayGame" test
function PlayGame_OnAutoPlayEnd()

	local saveGame = {};
	saveGame.Name = Automation.GenerateSaveName();
	saveGame.Location = SaveLocations.LOCAL_STORAGE;
	saveGame.Type= SaveTypes.SINGLE_PLAYER;
	saveGame.IsAutosave = false;
	saveGame.IsQuicksave = false;

	Network.SaveGame(saveGame);

	-- Saves are not immediate, wait for the completion event.
	Events.SaveComplete.Add( PlayGame_OnSaveComplete );

end

-----------------------------------------------------------------
function UpdatePlayerCounts()

	local defaultPlayers = nil;
	local mapSize = MapConfiguration.GetMapSize();
	local def = GameInfo.Maps[mapSize];
	if (def) then
		defaultPlayers = def.DefaultPlayers;
	end

	if (defaultPlayers ~= nil) then
		MapConfiguration.SetMaxMajorPlayers(defaultPlayers);
		GameConfiguration.SetParticipatingPlayerCount(defaultPlayers + GameConfiguration.GetHiddenPlayerCount());
	end
end

-----------------------------------------------------------------
function GetTrueOrFalse(value)
	if (value ~= nil) then
		local asString = string.upper(tostring(value));
		if (asString == "FALSE") then
			return false;
		elseif (asString == "TRUE") then
			return true;
		elseif (value >= 0) then
			return true;
		end
	end
	return false;
end

-----------------------------------------------------------------
function ReadUserConfigOptions()

	local quickMoves = Automation.GetSetParameter("CurrentTest", "QuickMovement");
	if (quickMoves ~= nil) then		
		UserConfiguration.SetLockedValue("QuickMovement", GetTrueOrFalse(quickMoves));
	end

	local quickCombat = Automation.GetSetParameter("CurrentTest", "QuickCombat");
	if (quickCombat ~= nil) then		
		UserConfiguration.SetLockedValue("QuickCombat", GetTrueOrFalse(quickCombat));
	end

end

-----------------------------------------------------------------
function RestoreUserConfigOptions()

	UserConfiguration.LockValue("QuickMovement", false);
	UserConfiguration.LockValue("QuickCombat", false);

end

-----------------------------------------------------------------
Tests["PlayGame"] = {};

-- Startup function for "PlayGame"
Tests["PlayGame"].Run = function()

	-- We must be at the Main Menu to do this test.
	if (not UI.IsInFrontEnd()) then
		-- Exit back to the main menu
		Events.ExitToMainMenu();
		return;
	end

	-- Start a game
	GameConfiguration.SetToDefaults();

	-- Did they specify a ruleset?
	local ruleSet = Automation.GetSetParameter("CurrentTest", "RuleSet");
	if (ruleSet ~= nil) then
		GameConfiguration.SetRuleSet(ruleSet);
	end

	-- Did they have a map script?
	local mapScript = Automation.GetSetParameter("CurrentTest", "MapScript");
	if (mapScript ~= nil) then		
		MapConfiguration.SetScript(mapScript);
		UpdatePlayerCounts();
	end

	-- Did they have a handicap/difficulty level?
	local handicap = Automation.GetSetParameter("CurrentTest", "Handicap");
	if (handicap == nil) then		
		handicap = Automation.GetSetParameter("CurrentTest", "Difficulty");		-- Letting them use an alias
	end
	if (handicap ~= nil) then		
		GameConfiguration.SetHandicapType(handicap);
	end

	-- Did they have a map size?
	local mapSize = Automation.GetSetParameter("CurrentTest", "MapSize");
	if (mapSize ~= nil) then		
		MapConfiguration.SetMapSize(mapSize);
		UpdatePlayerCounts();
	end

	-- Did they have a game speed?
	local gameSpeed = Automation.GetSetParameter("CurrentTest", "GameSpeed");
	if ( gameSpeed ~= nil ) then
		GameConfiguration.SetGameSpeedType(gameSpeed);
	end

	-- Convert any human slots to AI
	local aHumanIDs = GameConfiguration.GetHumanPlayerIDs();
	for _, id in ipairs(aHumanIDs) do
		PlayerConfiguration[id].SetSlotStatus(SlotStatus.SS_COMPUTER);
	end
	
	-- Did they have a map seed?
	local mapSeed = Automation.GetSetParameter("CurrentTest", "MapSeed");
	if (mapSeed ~= nil) then
		MapConfiguration.SetValue("RANDOM_SEED", mapSeed);
	end

	-- Or a Game Seed?
	local gameSeed = Automation.GetSetParameter("CurrentTest", "GameSeed");
	if (gameSeed ~= nil) then
		GameConfiguration.SetValue("GAME_SYNC_RANDOM_SEED", gameSeed);
	end

	-- Or a Start Era?
	local gameStartEra = Automation.GetSetParameter("CurrentTest", "StartEra");
	if (gameStartEra ~= nil) then
		GameConfiguration.SetStartEra(gameStartEra);
	end

	-- Or Max Turns?  This is Max turns for a Score victory, not the number of turns for the test.
	local maxTurns = Automation.GetSetParameter("CurrentTest", "MaxTurns");
	if (maxTurns ~= nil and maxTurns >= 1) then
		GameConfiguration.SetMaxTurns(maxTurns);
		GameConfiguration.SetTurnLimitType(TurnLimitTypes.CUSTOM);
	end
	
	
	ReadUserConfigOptions();

	Network.HostGame(ServerType.SERVER_TYPE_NONE);
end

-----------------------------------------------------------------
-- Respond to the Post Game Initialization for "PlayGame"
-- The game has been initialized (or loaded), but the app
-- side terrain generation, etc. has yet to be performed
Tests["PlayGame"].PostGameInitialization = function(bWasLoaded)
	
	LogCurrentPlayers();

	-- Add a handler for when the autoplay ends
	LuaEvents.AutoPlayEnd.Add( PlayGame_OnAutoPlayEnd );

	-- Get the optional Turns parameter from the CurrentTest parameter set
	local turnCount = Automation.GetSetParameter("CurrentTest", "Turns", 5);

	local observeAs = GetCurrentTestObserver();
		
	AutoplayManager.SetTurns(turnCount);
	AutoplayManager.SetReturnAsPlayer(0);
	AutoplayManager.SetObserveAsPlayer(observeAs);

	AutoplayManager.SetActive(true);

end

-----------------------------------------------------------------
-- Respond to the Game Start for "PlayGame"
-- The player will be able to see the map at this time.
Tests["PlayGame"].GameStarted = function()
	
	local observeAs = GetCurrentTestObserver();
		
	if (Game.GetLocalPlayer() == PlayerTypes.NONE) then
		-- We are starting as PlayerTypes.NONE and are most likely looking at nothing in particular.
		-- Look at who we are going to play.
		StartupObserverCamera(observeAs);
	end

end

-----------------------------------------------------------------
-- Stop handler for "PlayGame"
Tests["PlayGame"].Stop = function()

	-- Clean up anything the test needs to.
	LuaEvents.AutoPlayEnd.RemoveAll();

	Events.SaveComplete.Remove( PlayGame_OnSaveComplete );

	AutoplayManager.SetActive(false);		-- Make sure this is off

	RestoreUserConfigOptions();

end

-----------------------------------------------------------------
-- Test loading a game
-----------------------------------------------------------------
Tests["LoadGame"] = {};

-- Startup function for "LoadGame"
Tests["LoadGame"].Run = function()

	-- We must be at the Main Menu to do this test.
	if (not UI.IsInFrontEnd()) then
		-- Exit back to the main menu
		Events.ExitToMainMenu();
		return;
	end

	local hasLaunched = Automation.GetSetParameter("CurrentTest", "HasLanunched", 0);

	if (hasLaunched ~= 0) then
		-- Have we already launched?  If so, some error happened.
		Automation.SendTestComplete();
	else
		Automation.SetSetParameter("CurrentTest", "HasLanunched", 1);

		local loadGame = {};

		loadGame.Location = SaveLocations.LOCAL_STORAGE;
		loadGame.Type= SaveTypes.SINGLE_PLAYER;
		loadGame.IsAutosave = false;
		loadGame.IsQuicksave = false;
		loadGame.Directory = SaveDirectories.DEFAULT;

		local saveName = Automation.GetSetParameter("CurrentTest", "SaveName");
		if (saveName ~= nil) then
			loadGame.Name = saveName;
		else
			loadGame.Name = Automation.GetLastGeneratedSaveName();
		end
		local saveDirectory = Automation.GetSetParameter("CurrentTest", "SaveDirectory");
		if (saveDirectory ~= nil) then
			loadGame.Directory = saveDirectory;
		end
		
		ReadUserConfigOptions();

		local bResult = Network.LoadGame(loadGame, ServerType.SERVER_TYPE_NONE);
		if (bResult == false) then
			-- Automation.Log("Failed to load " .. tostring(loadGame.Name));
			Automation.SendTestComplete();
		end
	end
end

-----------------------------------------------------------------
-- Handle the autoplay end for the "LoadGame" test
function LoadGame_OnAutoPlayEnd()

	-- Signal that the test is complete.  Do not call LuaEvents.AutomationTestComplete() directly.  The Automation system will do that at a safe time.
	Automation.SendTestComplete();

end

-----------------------------------------------------------------
-- Respond to the Post Game Initialization for "LoadGame"
-- The game has been initialized (or loaded), but the app
-- side terrain generation, etc. has yet to be performed
Tests["LoadGame"].PostGameInitialization = function(bWasLoaded)
	
	-- Add a handler for when the autoplay ends
	LuaEvents.AutoPlayEnd.Add( LoadGame_OnAutoPlayEnd );

	local observeAs = GetCurrentTestObserver();		
	local turnCount = Automation.GetSetParameter("CurrentTest", "Turns", 1);

	AutoplayManager.SetTurns(turnCount);
	AutoplayManager.SetReturnAsPlayer(0);
	AutoplayManager.SetObserveAsPlayer(observeAs);

	AutoplayManager.SetActive(true);

end

-----------------------------------------------------------------
-- Respond to the Game Start for "LoadGame"
Tests["LoadGame"].GameStarted = function()
	
	local observeAs = GetCurrentTestObserver();
		
	if (Game.GetLocalPlayer() == PlayerTypes.NONE) then
		-- We are starting as PlayerTypes.NONE and are most likely looking at nothing in particular.
		-- Look at who we are going to play.
		StartupObserverCamera(observeAs);
	end

end

Tests["LoadGame"].Stop = function()

	RestoreUserConfigOptions();

end

-- Include the common support code.

include ("Automation_StandardTestSupport")


-----------------------------------------------------------------
-- Some common functions for these tests
-----------------------------------------------------------------

-----------------------------------------------------------------
-- Log the current players
function LogCurrentPlayers()

	Automation.Log("Players:");
	local aPlayers = PlayerManager.GetAlive();
	for _, pPlayer in ipairs(aPlayers) do
		local pPlayerConfig = PlayerConfigurations[pPlayer:GetID()];
						
		if pPlayerConfig ~= nil then
			local szName = pPlayerConfig:GetCivilizationShortDescription();
			if (szName == nil or string.len(szName) == 0) then
				szName = pPlayerConfig:GetCivilizationTypeName();
			end
			if (szName == nil or string.len(szName) == 0) then
				szName = tostring(pPlayerConfig:GetCivilizationTypeID());
			end

			Automation.Log( tostring(pPlayer:GetID()) .. ": " .. szName);
		end
	end

end

