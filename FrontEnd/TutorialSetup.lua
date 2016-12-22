
-------------------------------------------------
-- Tutorial Setup Screen
-------------------------------------------------
include("SetupParameters");

g_TutorialModId = "17462E0F-1EE1-4819-AAAA-052B5896B02A";
g_GameParameters = nil;		-- Game Parameters.

-------------------------------------------------------------------------------
-- Setup Parameter overrides.
-------------------------------------------------------------------------------
function SinglePlayerGameParameters(o, parameter)

	-- Ignore player specific parameters.
	if(parameter.ConfigurationGroup == "Player") then
		return false;
	end

	-- Single-Player only.
	return parameter.SupportsSinglePlayer;
end

-------------------------------------------------------------------------------
-- Event Listeners
-------------------------------------------------------------------------------
Events.FinishedGameplayContentConfigure.Add(function(result)
	if(result.Success) then
		if(ConstructParameters()) then
			Controls.StatusPanel:SetHide(true);
			Controls.TutorialPanel:SetHide(false);		
		end
	else
		 Controls.Status:SetText("[COLOR_RED]There was an error loading the tutorial.[ENDCOLOR]");	
	end
end);

------------------------------------------------------------------    
function EnsureTutorialIsEnabled()

	 --Configure UI first
	 Controls.TutorialPanel:SetHide(true);
	 Controls.StatusPanel:SetHide(false);
	 Controls.Status:SetText("Enabling the Tutorial Mod...");

	 -- Configure Mods
	local tutorialHandle = Modding.GetModHandle(g_TutorialModId);
	if(tutorialHandle == nil) then
		 Controls.Status:SetText("[COLOR_RED]The tutorial mod could not be found.[ENDCOLOR]");
	else
		if(not tutorialEnabled) then
			GameConfiguration.AddEnabledMods(tutorialHandle, true);
		end
	end
end

function ConstructParameters()
	
	-- Construct new parameters.
	g_GameParameters = SetupParameters.new();	
	g_GameParameters.Parameter_GetRelevant = SinglePlayerGameParameters;


	g_GameParameters:Initialize();		-- Perform any initialization.
	g_GameParameters:FullRefresh();		-- Perform a full refresh before configuring.

	-- Obtain the parameter 'Ruleset' and set it to the value 'RULESET_TUTORIAL'.
	local ruleset = g_GameParameters.Parameters["Ruleset"];

	if(ruleset == nil) then
		print("Cannot find Tutorial ruleset :( :( ");
		return false;
	end

	local tutorial_ruleset;
	if(ruleset) then
		for i,v in ipairs(ruleset.Values) do
			if(v.Value == "RULESET_TUTORIAL") then
				tutorial_ruleset = v;
			end
		end
	end
	
	-- Set the ruleset to be the tutorial.
	if(ruleset and tutorial_ruleset) then
		g_GameParameters:SetParameterValue(ruleset, tutorial_ruleset);

		-- We've set the new value, now refresh and reconcile.
		g_GameParameters:FullRefresh();

		-- KLUDGE CODE
		-- The map size change in setup parameters is not executing this properly.
		-- Ideally, setting the map size will also set min,max, and default players.
		-- The parameter code will then call the proper methods to adjust.
		MapConfiguration.SetMaxMajorPlayers(2);
		GameConfiguration.SetParticipatingPlayerCount(2);
		-- END KLUDGE CODE
			
		return true;
	else
		return false;
	end
end

function TeardownParameters()
	-- Destroy the parameter scaffolding and release any cached data.
	if(g_GameParameters) then
		g_GameParameters:Shutdown();
		g_GameParameters = nil;
	end
end

------------------------------------------------------------------    
function OnShow()
	EnsureTutorialIsEnabled();
	Controls.IntroMovieContainer:RegisterCallback(  Mouse.eLClick, OnClickStopMovie );
	Controls.IntroMovieContainer:SetHide( false );

    UI.StartStopMenuMusic(false);
	Controls.IntroMovie:SetMovieFinishedCallback( OnFinishMoviePlayback );	
	Controls.IntroMovie:SetMovie("TUT_INTRO.bk2");	
	Controls.IntroMovie:Play();	
	UI.PlaySound("Play_Cinematic_Tutorial_Intro");
end

------------------------------------------------------------------    
function OnHide()
	TeardownParameters();
end


------------------------------------------------------------------    
---- Button Handlers
------------------------------------------------------------------    
function OnLeader1()
	local player0 = PlayerConfigurations[0];
	if(player0) then
		player0:SetLeaderTypeName("LEADER_CLEOPATRA");
	end

	-- Kludge.
	-- Ideally, Player slot 1 would be set to "RANDOM_UNIQUE".
	local player1 = PlayerConfigurations[1];
	if(player1) then
		player1:SetLeaderTypeName("LEADER_GILGAMESH");
	end

	Network.HostGame(ServerType.SERVER_TYPE_NONE);
end
Controls.Leader1Start:RegisterCallback( Mouse.eLClick, OnLeader1 );
----------------------------------------------------------------   
function OnLeader2()
	local player0 = PlayerConfigurations[0];
	if(player0) then
		player0:SetLeaderTypeName("LEADER_GILGAMESH");
	end

	-- Kludge.
	-- Ideally, Player slot 1 would be set to "RANDOM_UNIQUE".
	local player1 = PlayerConfigurations[1];
	if(player1) then
		player1:SetLeaderTypeName("LEADER_CLEOPATRA");
	end

	Network.HostGame(ServerType.SERVER_TYPE_NONE);
end

----------------------------------------------------------------    
function OnBackButton()
	
	-- We are exiting out of the tutorial setup menu.
	-- Let's make sure the game config matches what the 
	-- user enabled.
	GameConfiguration.UpdateEnabledMods();
	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================
function StopMovie()
	Controls.IntroMovieContainer:ClearCallback(  Mouse.eLClick );	
	Controls.IntroMovieContainer:SetHide( true );
    UI.StartStopMenuMusic(true);
	UI.PlaySound("Stop_Cinematic_Tutorial_Intro");
end

-- ===========================================================================
--	Stopping movie by clicking it.
-- ===========================================================================
function OnClickStopMovie()
	StopMovie();
end

-- ===========================================================================
--	Stopping movie because it finished playing.
-- ===========================================================================
function OnFinishMoviePlayback()
	StopMovie();
end

-- ===========================================================================
function IsMovieHandling( pInputStruct:table)

	if Controls.IntroMovie:IsPlaying() then
		local uiMsg = pInputStruct:GetMessageType();	
		if uiMsg == KeyEvents.KeyUp then
			local uiKey = pInputStruct:GetKey();
			if uiKey == Keys.VK_ESCAPE or uiKey == Keys.VK_RETURN then
				StopMovie();
				return true;			
			end
		elseif uiMsg == MouseEvents.LButtonUp then
			StopMovie();
			return true;			
		end
	end
	return false;		
end

-- ===========================================================================
-- Input handling
-- ===========================================================================
function InputHandler( pInputStruct:table )

	local uiMsg = pInputStruct:GetMessageType();

	if Controls.IntroMovie:IsPlaying() then
		if uiMsg == KeyEvents.KeyUp then
			local uiKey = pInputStruct:GetKey();
			if uiKey == Keys.VK_ESCAPE or uiKey == Keys.VK_RETURN then
				StopMovie();
				return true;
			end
		end
	end


	if uiMsg == KeyEvents.KeyUp then
		local uiKey = pInputStruct:GetKey();
		if(uiKey == Keys.VK_ESCAPE) then
			OnBackButton();
			return true;
		end
	end
	
	return false;
end


-- ===========================================================================
--	Handle Window Sizing
-- ===========================================================================
function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	local hideLogo = true;
	if(screenY >= Controls.MainWindow:GetSizeY() + (Controls.LogoContainer:GetSizeY()+ Controls.LogoContainer:GetOffsetY())*2) then
		hideLogo = false;
	end
	Controls.LogoContainer:SetHide(hideLogo);
	Controls.MainGrid:ReprocessAnchoring();
end

-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end


-- ===========================================================================
function Initialize()	

	Resize();
	
	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetHideHandler( OnHide );
	ContextPtr:SetInputHandler(InputHandler, true );
	
	-- Static information we don't need to change later.
	Controls.Leader1Portrait:SetIcon("ICON_LEADER_CLEOPATRA");
	Controls.Leader2Portrait:SetIcon("ICON_LEADER_GILGAMESH");
	Controls.Leader2Start:RegisterCallback( Mouse.eLClick, OnLeader2 );
	Controls.Leader1Start:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.Leader2Start:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnBackButton );
	Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Events.SystemUpdateUI.Add( OnUpdateUI );
end
Initialize();