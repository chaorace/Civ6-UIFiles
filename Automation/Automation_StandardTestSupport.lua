-----------------------------------------------------------------------------------------------------------------------
-- Common framework code for "standard" automated tests.
-- This uses a table called Tests along with the the automation startup parameters to drive a set of automation tests.
--
-- The top key for the Tests table should be the name of the test with the table entries for each test that point to
-- functions to run.  Each test should support the Run function and the Stop funciton.  There is also a GameStarted
-- function.
--
-- Please remember that if your automation test starts or load a new game, you should NOT rely on local script variables
-- as the whole Lua context may get rebuilt if DLC/Mods are activated/deactivated.
-- Use the Automation parameter containers which are store on the C++ side.
-----------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------
-- Get the observer for the current test
-----------------------------------------------------------------
function LookAtCapital(ePlayer)
	if (ePlayer ~= -1) then
		local pPlayer = Players[ePlayer];
		-- Look at their capital
		local pPlayerCities = pPlayer:GetCities();
		local pCapital = pPlayerCities:GetCapitalCity();
		if (pCapital ~= nil) then
			UI.LookAtPlot(pCapital:GetX(), pCapital:GetY());
			return true;
		end
	end
	return false;
end

-----------------------------------------------------------------
-- Get the observer for the current test
-----------------------------------------------------------------
function GetCurrentTestObserver()

	local observeAs = Automation.GetSetParameter("CurrentTest", "ObserveAs", 0);
	if (observeAs == "OBSERVER") then
		observeAs = PlayerTypes.OBSERVER;
	end
	if (observeAs == "NONE") then
		observeAs = PlayerTypes.NONE;
	end
	if (observeAs >= 0 and observeAs <= GameDefines.MAX_PLAYERS) then
		if (not PlayerManager.IsAlive(observerAs)) then
			observeAs = PlayerTypes.OBSERVER;
		end
	end	

	return observeAs;
end

-----------------------------------------------------------------
-- Move the camera to something the observer can see.
-----------------------------------------------------------------
function StartupObserverCamera(observeAs)

	local eLookAtPlayer = observeAs;
	if (eLookAtPlayer >= PlayerTypes.OBSERVER) then
		eLookAtPlayer = 0;
	end

	if PlayerManager.IsValid(eLookAtPlayer) then
		local bFound = LookAtCapital(eLookAtPlayer);

		-- Else look at one of their units
		if (not bFound) then
			local pPlayer = Players[eLookAtPlayer];
			local pPlayerUnits = pPlayer:GetUnits();
			for i, pUnit in pPlayerUnits:Members() do
				if (not pUnit:IsDead()) then
					UI.LookAtPlot(pUnit:GetX(), pUnit:GetY());
					bFound = true;
					break;
				end
			end
		end
	end
end			
-----------------------------------------------------------------
-- Test Quiting the Application
-----------------------------------------------------------------
Tests["QuitApp"] = {};

-- Startup function for "QuitApp"
Tests["QuitApp"].Run = function()

	-- Just set a flag, the common code will do the actual quitting.
	Automation.SetLocalParameter("QuitApp", true);

	Automation.SendTestComplete();

end

-----------------------------------------------------------------
-- Test Quiting the Game
-----------------------------------------------------------------
Tests["QuitGame"] = {};

-- Startup function for "QuitGame"
Tests["QuitGame"].Run = function()

	if (not UI.IsInFrontEnd()) then
		-- Exit back to the main menu
		Events.ExitToMainMenu();
		return;
	end

	Automation.SendTestComplete();

end

-----------------------------------------------------------------
-- Pause the Game
-----------------------------------------------------------------
Tests["PauseGame"] = {};

-- Startup function for "PauseGame"
Tests["PauseGame"].Run = function()

	if (UI.IsInFrontEnd()) then
		Automation.SendTestComplete();
		return;
	end

	Automation.Pause(true);

end

-----------------------------------------------------------------
function GetCurrentTestHandler()
	-- Get the list of test the caller requested to be performed
	local aTests = Automation.GetStartupParameter("RunTests");
	if (aTests ~= nil) then
		-- Get our local index from the Automation system.  We can't rely on Lua global because of context swaps.
		local testIndex = Automation.GetLocalParameter("TestIndex", 1);

		if (Tests ~= nil) then
			if (testIndex <= table.maxn(aTests)) then
				local testName = aTests[testIndex];

				if (type(testName) == "table") then
					testName = testName.Test;
				end

				if (testName ~= nil) then
					return Tests[ testName ], testName;
				end
			end
		end
	end

	return nil;
end

-----------------------------------------------------------------
function StoreCurrentTestParameters()

	-- Get the list of test the caller requested to be performed
	local aTests = Automation.GetStartupParameter("RunTests");
	if (aTests ~= nil) then
		-- Get our local index from the Automation system.  We can't rely on Lua global because of context swaps.
		local testIndex = Automation.GetLocalParameter("TestIndex", 1);

		if (Tests ~= nil) then
			if (testIndex <= table.maxn(aTests)) then
				local testName = aTests[testIndex];

				Automation.ClearParameterSet("CurrentTest");
				if (type(testName) == "table") then
					Automation.SetParameterSet("CurrentTest", testName);
				else
					Automation.SetSetParameter("CurrentTest", "Test", testName);
				end
			end
		end
	end
end

-----------------------------------------------------------------
-- Run the current test, or send a AutomationComplete event if there
-- are no more tests 
function OnAutomationRunTest(option)

	local handler, handlerName = GetCurrentTestHandler();
	if (handler ~= nil and handler.Run ~= nil) then
		if (option == nil or option ~= "Restart") then
			Automation.LogDivider();
			StoreCurrentTestParameters();
			Automation.Log("Running Test:" ..tostring( handlerName ));
		end
		handler.Run();
	else
		LuaEvents.AutomationComplete();
	end

end

LuaEvents.AutomationRunTest.Add( OnAutomationRunTest );

-----------------------------------------------------------------
-- Call the currents test's Stop handler.
function OnAutomationStopTest()

	local handler = GetCurrentTestHandler();
	if (handler ~= nil and handler.Stop ~= nil) then
		handler.Stop();
	end

end

LuaEvents.AutomationStopTest.Add( OnAutomationStopTest );

-----------------------------------------------------------------
-- Call the current test's GameStarted handler.
function OnAutomationGameStarted()

	local handler = GetCurrentTestHandler();
	if (handler ~= nil and handler.GameStarted ~= nil) then
		handler.GameStarted();
	end

end

LuaEvents.AutomationGameStarted.Add( OnAutomationGameStarted );

-----------------------------------------------------------------
-- Call the current test's PostGameInitialization handler.
function OnAutomationPostGameInitialization(bWasLoad)

	local handler = GetCurrentTestHandler();
	if (handler ~= nil and handler.PostGameInitialization ~= nil) then
		handler.PostGameInitialization(bWasLoad);
	end

end

LuaEvents.AutomationPostGameInitialization.Add( OnAutomationPostGameInitialization );

-----------------------------------------------------------------
-- Handle the AutomationComplete event.
function OnAutomationComplete()
	Automation.SetActive(false);

	if (Automation.GetLocalParameter("QuitApp", false) == true) then
		-- Quit the application
		Events.UserConfirmedClose();
	else
		if (not UI.IsInFrontEnd()) then
			Events.ExitToMainMenu();
		end
	end

end

LuaEvents.AutomationComplete.Add( OnAutomationComplete );

-----------------------------------------------------------------
-- Handle the AutomationTestComplete event
function OnAutomationTestComplete()

	-- Tell the test to stop, just in case the event was not triggered by the test itself.
	LuaEvents.AutomationStopTest();

	-- Get our local index from the Automation system.  We can't rely on Lua global because of context swaps.
	local testIndex = Automation.GetLocalParameter("TestIndex", 1);
	-- Increment the index
	Automation.SetLocalParameter("TestIndex", testIndex + 1);

	-- Run the next test
    LuaEvents.AutomationRunTest();

end

LuaEvents.AutomationTestComplete.Add( OnAutomationTestComplete );

-----------------------------------------------------------------
-- Handle the request for automation to start
function OnAutomationStart()

	LuaEvents.AutomationRunTest();

end

LuaEvents.AutomationStart.Add( OnAutomationStart );

-----------------------------------------------------------------
-- The main menu has started, start any automation.
function OnAutomationMainMenuStarted()

	-- Check our local parameter so that we don't try and re-start automation if
	-- is has already been started.
	local bStarted = Automation.GetLocalParameter("AutomationStarted", false);
	if (not bStarted) then
		-- Start the automation tests
		Automation.SetLocalParameter("AutomationStarted", true);
		LuaEvents.AutomationStart();
	else
		-- Run the current test
		LuaEvents.AutomationRunTest("Restart");
	end

end

LuaEvents.AutomationMainMenuStarted.Add( OnAutomationMainMenuStarted );

