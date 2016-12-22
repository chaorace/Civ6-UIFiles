
include("InstanceManager")
include("EndGameReplayLogic")
include( "ChatLogic" );

---------------------------------------------------------------
-- Globals
----------------------------------------------------------------
g_GraphVerticalMarkers = {
	Controls.VerticalLabel1,
	Controls.VerticalLabel2,
	Controls.VerticalLabel3,
	Controls.VerticalLabel4,
	Controls.VerticalLabel5
};

g_GraphHorizontalMarkers = {
	Controls.HorizontalLabel1,
	Controls.HorizontalLabel2,
	Controls.HorizontalLabel3,
	Controls.HorizontalLabel4,
	Controls.HorizontalLabel5
};

local g_HasPlayerPortrait;	-- Whether or not a player portrait has been set.
local g_Movie;				-- The movie which has been set.
local g_SoundtrackStart;    -- Wwise start event for the movie's audio
local g_SoundtrackStop;     -- Wwise stop event for the movie's audio
local g_SavedMusicVol;      -- Saved music volume around movie play

-- Chat Panel Data
local m_playerTarget = { targetType = ChatTargetTypes.CHATTARGET_ALL, targetID = GetNoPlayerTargetID() };
local m_playerTargetEntries = {};
local m_ChatInstances		= {};

local PlayerConnectedChatStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED_CHAT" );
local PlayerDisconnectedChatStr = Locale.Lookup( "LOC_MP_PLAYER_DISCONNECTED_CHAT" );
local PlayerHostMigratedChatStr = Locale.Lookup( "LOC_MP_PLAYER_HOST_MIGRATED_CHAT" );
local PlayerKickedChatStr = Locale.Lookup( "LOC_MP_PLAYER_KICKED_CHAT" );

local g_HideLeaderPortrait = false;

local m_bAllowBack = true;

local m_MovieWasPlayed = false;

local g_RankIM = InstanceManager:new( "RankEntry", "Root", Controls.RankingStack );
local g_GraphLegendInstanceManager = InstanceManager:new("GraphLegendInstance", "GraphLegend", Controls.GraphLegendStack);
local g_LineSegmentInstanceManager = InstanceManager:new("GraphLineInstance","LineSegment", Controls.GraphCanvas);

-- TODO: Move this into the database.
local Styles = {
	["GENERIC_DEFEAT"] ={
		RibbonIcon = nil,
		Ribbon = "EndGame_Ribbon_Defeat",
		RibbonTile = "EndGame_RibbonTile_Defeat",
		Background = "EndGame_BG_Defeat",
		Movie = "Defeat.bk2",
        SndStart = "Play_Cinematic_Endgame_Defeat",
        SndStop = "Stop_Cinematic_Endgame_Defeat",
	},
	["GENERIC_VICTORY"] = {
		RibbonIcon = "ICON_VICTORY_SCORE",
		Ribbon = "EndGame_Ribbon_Time",
		RibbonTile = "EndGame_RibbonTile_Time",
		Background = "EndGame_BG_Time",
	},
	["VICTORY_SCORE"] = {
		RibbonIcon = "ICON_VICTORY_SCORE",
		Ribbon = "EndGame_Ribbon_Time",
		RibbonTile = "EndGame_RibbonTile_Time",
		Background = "EndGame_BG_Time",
		Movie = "Time.bk2",
        SndStart = "Play_Cinematic_Endgame_Time",
        SndStop = "Stop_Cinematic_Endgame_Time",
	},
	["VICTORY_DEFAULT"] = {
		RibbonIcon = "ICON_VICTORY_DEFAULT",
		Ribbon = "EndGame_Ribbon_Domination",
		RibbonTile = "EndGame_RibbonTile_Domination",
		Background = "EndGame_BG_Domination",
		Movie = "Domination.bk2",
        SndStart = "Play_Cinematic_Endgame_Domination",
        SndStop = "Stop_Cinematic_Endgame_Domination",
	},
	["VICTORY_CONQUEST"] = {
		RibbonIcon = "ICON_VICTORY_CONQUEST",
		Ribbon = "EndGame_Ribbon_Domination",
		RibbonTile = "EndGame_RibbonTile_Domination",
		Background = "EndGame_BG_Domination",
		Movie = "Domination.bk2",
        SndStart = "Play_Cinematic_Endgame_Domination",
        SndStop = "Stop_Cinematic_Endgame_Domination",
	},
	["VICTORY_CULTURE"] = {
		RibbonIcon = "ICON_VICTORY_CULTURE",
		Ribbon = "EndGame_Ribbon_Culture",
		RibbonTile = "EndGame_RibbonTile_Culture",
		Background = "EndGame_BG_Culture",
		Movie = "Culture.bk2",
        SndStart = "Play_Cinematic_Endgame_Culture",
        SndStop = "Stop_Cinematic_Endgame_Culture",
	},
	["VICTORY_RELIGIOUS"] = {
		RibbonIcon = "ICON_VICTORY_RELIGIOUS",
		Ribbon = "EndGame_Ribbon_Religion",
		RibbonTile = "EndGame_RibbonTile_Religion",
		Background = "EndGame_BG_Religion",
		Movie = "Religion.bk2",
        SndStart = "Play_Cinematic_Endgame_Religion",
        SndStop = "Stop_Cinematic_Endgame_Religion",
	},
	["VICTORY_TECHNOLOGY"] = {
		RibbonIcon = "ICON_VICTORY_TECHNOLOGY",
		Ribbon = "EndGame_Ribbon_Science",
		RibbonTile = "EndGame_RibbonTile_Science",
		Background = "EndGame_BG_Science",
		Movie = "Science.bk2",
        SndStart = "Play_Cinematic_Endgame_Science",
        SndStop = "Stop_Cinematic_Endgame_Science",
	},
};

----------------------------------------------------------------
-- Utility function that lets me pass an icon string or
-- an array of icons to attempt to use.
-- Upon success, show the control.  Failure, hide the control.  
----------------------------------------------------------------  
function SetIcon(control, icon) 
	control:SetHide(false);

	if(icon == nil) then
		control:SetHide(true);
		return;
	else
		if(type(icon) == "string") then
			if(control:SetIcon(icon)) then
				return;
			end

		elseif(type(icon) == "table") then
			for i,v in ipairs(icon) do
				if(control:SetIcon(v)) then
					return;
				end
			end	
		end
		control:SetHide(true);
	end
end

----------------------------------------------------------------  
----------------------------------------------------------------  
function PopulateRankingResults()
	g_RankIM:ResetInstances();

	local player = Players[Game.GetLocalPlayer()];
	local score = player:GetScore();
	
	local playerAdded = false;
	local count = 1;
	for row in GameInfo.HistoricRankings() do
		local instance = g_RankIM:GetInstance();
	
		instance.Number:LocalizeAndSetText("LOC_UI_ENDGAME_NUMBERING_FORMAT", count);
		instance.LeaderName:LocalizeAndSetText(row.HistoricLeader);
		
		if(score >= row.Score and not playerAdded)then
			instance.LeaderScore:SetText(Locale.ToNumber(score));
			instance.LeaderQuote:LocalizeAndSetText(row.Quote);
			instance.LeaderQuote:SetHide(false);
			Controls.RankingTitle:LocalizeAndSetText("LOC_UI_ENDGAME_RANKING_STATEMENT", row.HistoricLeader);
			playerAdded = true;
		else
			instance.LeaderScore:SetText(Locale.ToNumber(row.Score));
			instance.LeaderQuote:SetHide(true);
		end

		count = count + 1;
	end

	Controls.RankingScrollPanel:SetScrollValue(0);
	
	Controls.RankingStack:CalculateSize();
	Controls.RankingStack:ReprocessAnchoring();
	Controls.RankingScrollPanel:CalculateInternalSize();
end

function UpdateButtonStates()
	-- Display a continue button if there are other players left in the game
	local player = Players[Game.GetLocalPlayer()];

	-- If there are living human players in a hot-seat game, do not display the main menu button.
	-- Instead go to the next player's turn.
	local nextPlayer = false;
	if(GameConfiguration.IsHotseat()) then
		local humans = GameConfiguration.GetHumanPlayerIDs();
		for i,v in ipairs(humans) do
			local human = Players[v];
			if(human and human:IsAlive()) then
				nextPlayer = true;
				break;
			end
		end
	end

	local noExtendedGame = GameConfiguration.GetValue("NO_EXTENDED_GAME");
	local canExtendGame = noExtendedGame == nil or (noExtendedGame ~= 1 and noExtendedGame ~= true);
	
	canExtendGame = canExtendGame and player and player:IsAlive();
	
	-- Don't show next player button if Just One More Turn will be shown as the functionality is the same.
	nextPlayer = nextPlayer and not canExtendGame;

	-- Always show the main menu button.
	Controls.MainMenuButton:SetHide(false);
	
	-- Enable just one more turn if we can extend the game.	
	-- Show the just one more turn button if we're not showing the next player button.	
	Controls.BackButton:SetDisabled(not canExtendGame);
	Controls.BackButton:SetHide(nextPlayer);

	-- Show the next player button only if in a hot-seat match and just one more turn is disabled.
	Controls.NextPlayerButton:SetHide(not nextPlayer);
	
	Controls.ButtonStack:CalculateSize();
	Controls.ButtonStack:ReprocessAnchoring();
end

----------------------------------------------------------------
----------------------------------------------------------------
function OnNextPlayer()
    UI.UnloadSoundBankGroup(5);
	UIManager:DequeuePopup( ContextPtr );
	UI.RequestAction(ActionTypes.ACTION_ENDTURN);
end
Controls.NextPlayerButton:RegisterCallback( Mouse.eLClick, OnNextPlayer );
Controls.NextPlayerButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

----------------------------------------------------------------
----------------------------------------------------------------
function OnMainMenu()
    UI.UnloadSoundBankGroup(5);
	Events.ExitToMainMenu();
end
Controls.MainMenuButton:RegisterCallback( Mouse.eLClick, OnMainMenu );
Controls.MainMenuButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

----------------------------------------------------------------
----------------------------------------------------------------
function OnBack()
    UI.UnloadSoundBankGroup(5);
	UIManager:DequeuePopup( ContextPtr );
	LuaEvents.EndGameMenu_OneMoreTurn();
end
Controls.BackButton:RegisterCallback( Mouse.eLClick, OnBack );
Controls.BackButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

----------------------------------------------------------------
----------------------------------------------------------------
function OnInfo()
    Controls.InfoPanel:SetHide(false);
	Controls.RankingPanel:SetHide(true);
    Controls.GraphPanel:SetHide(true);
	Controls.ChatPanel:SetHide(true);
	Controls.PlayerPortrait:SetHide(g_HideLeaderPortrait);


	Controls.InfoButtonSelected:SetHide(false);
	Controls.RankingButtonSelected:SetHide(true);
	Controls.ReplayButtonSelected:SetHide(true);
	Controls.ChatButtonSelected:SetHide(true);

end
Controls.InfoButton:RegisterCallback( Mouse.eLClick, OnInfo );
Controls.InfoButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

----------------------------------------------------------------
----------------------------------------------------------------
function OnRanking()
    Controls.InfoPanel:SetHide(true);
	Controls.RankingPanel:SetHide(false);
    Controls.GraphPanel:SetHide(true);
	Controls.ChatPanel:SetHide(true);
	Controls.PlayerPortrait:SetHide(g_HideLeaderPortrait);

	Controls.InfoButtonSelected:SetHide(true);
	Controls.RankingButtonSelected:SetHide(false);
	Controls.ReplayButtonSelected:SetHide(true);
	Controls.ChatButtonSelected:SetHide(true);

	PopulateRankingResults();
end
Controls.RankingButton:RegisterCallback( Mouse.eLClick, OnRanking );
Controls.RankingButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

----------------------------------------------------------------
----------------------------------------------------------------
function OnReplay()
    Controls.InfoPanel:SetHide(true);
	Controls.RankingPanel:SetHide(true);
    Controls.GraphPanel:SetHide(false);
	Controls.ChatPanel:SetHide(true);
	Controls.PlayerPortrait:SetHide(true);

	Controls.InfoButtonSelected:SetHide(true);
	Controls.RankingButtonSelected:SetHide(true);
	Controls.ReplayButtonSelected:SetHide(false);
	Controls.ChatButtonSelected:SetHide(true);

	ReplayInitialize();

end
Controls.ReplayButton:RegisterCallback( Mouse.eLClick, OnReplay );
Controls.ReplayButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

----------------------------------------------------------------
----------------------------------------------------------------
function OnChat()
    Controls.InfoPanel:SetHide(true);
	Controls.RankingPanel:SetHide(true);
    Controls.GraphPanel:SetHide(true);
	Controls.ChatPanel:SetHide(false);
	Controls.PlayerPortrait:SetHide(true);

	Controls.InfoButtonSelected:SetHide(true);
	Controls.RankingButtonSelected:SetHide(true);
	Controls.ReplayButtonSelected:SetHide(true);
	Controls.ChatButtonSelected:SetHide(false);
end
Controls.ChatButton:RegisterCallback( Mouse.eLClick, OnChat );
Controls.ChatButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

----------------------------------------------------------------        
----------------------------------------------------------------   
function OnReplayMovie()
	if(g_Movie) then
		if Controls.Movie:SetMovie(g_Movie) then
    		Controls.MovieFill:SetHide(false);
    		Controls.Movie:Play();
            UI.StopInGameMusic();
            UI.PlaySound(g_SoundtrackStart);
            g_SavedMusicVol = Options.GetAudioOption("Sound", "Music Volume"); 
            Options.SetAudioOption("Sound", "Music Volume", 0, 0);
            m_MovieWasPlayed = true;
        end
	end

	-- If in Network MP, release the pause event, so our local machine continues processing
	if (GameConfiguration.IsNetworkMultiplayer()) then
		UI.ReleasePauseEvent();
	end
end
Controls.ReplayMovieButton:RegisterCallback(Mouse.eLClick, OnReplayMovie);
Controls.ReplayMovieButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

----------------------------------------------------------------        
----------------------------------------------------------------   
function OnMovieExitOrFinished()
	--Controls.Movie:Stop();
	Controls.Movie:Close();
	Controls.MovieFill:SetHide(true);
    if (m_MovieWasPlayed) then
        UI.PlaySound(g_SoundtrackStop);
        Options.SetAudioOption("Sound", "Music Volume", g_SavedMusicVol, 0);
        UI.SkipSong();
        m_MovieWasPlayed = false;
    end

	-- If in Network MP, release the pause event, so our local machine continues processing
	if (GameConfiguration.IsNetworkMultiplayer()) then
		UI.ReleasePauseEvent();
	end
end
Controls.Movie:SetMovieFinishedCallback(OnMovieExitOrFinished);
Controls.MovieFill:RegisterCallback(Mouse.eLClick, OnMovieExitOrFinished);

-- ===========================================================================
function OnInputHandler( input )
	local msg = input:GetMessageType();
	if (msg == KeyEvents.KeyUp) then
		local key = input:GetKey();
		if (key == Keys.VK_ESCAPE) then
			if(not Controls.MovieFill:IsHidden()) then
				OnMovieExitOrFinished();
			end

			-- Always trap the escape key here.
			return true;
		end
	end
	return false;
end
ContextPtr:SetInputHandler( OnInputHandler, true );

----------------------------------------------------------------        
----------------------------------------------------------------        
function ShowHideHandler( bIsHide, bIsInit )

	if( not bIsInit ) then
	    if( not bIsHide ) then
			LuaEvents.EndGameMenu_Shown();

			print("Showing EndGame Menu");


			-- Verify we're scaled properly.
			Resize();

			-- Always start with the info panel.
			OnInfo();

			-- Noop if no movie is set.
			OnReplayMovie();

		 	-- Update the state of the lower buttons.
			UpdateButtonStates();

			-- Setup Chat Player Target Pulldown.
			PopulateTargetPull(Controls.ChatPull, Controls.ChatEntry, m_playerTargetEntries, m_playerTarget, false, OnChatPulldownChanged);
        else

			print("Hiding EndGame Menu");
			-- Release any event we might have been holding on to.
			UI.ReleasePauseEvent();

			-- Unload instances.
			g_RankIM:ResetInstances();
			ReplayShutdown();

			-- Unload movie
			Controls.Movie:Close();

			-- NOTE: We cannot unload these textures because at present there are situations
			-- where the popup manager shows then hides then shows the UI again.
			-- Once this issue has been addressed, then we can add this.
			-- Unload large textures.
			--Controls.Background:UnloadTexture();
			--Controls.PlayerPortrait:UnloadTexture();

			LuaEvents.EndGameMenu_Closed();
		end
		
		HandlePauseGame(bIsHide);
    end
end
----------------------------------------------------------------        
---------------------------------------------------------------- 
-- When should the End Game screen pause the game?
-- If the player can "One More Turn" and the game has a turn timer, 
-- to prevent the game from progressing while players are looking at the screen.
function ShouldPauseGame()
	if(not GameConfiguration.IsAnyMultiplayer() or GameConfiguration.GetTurnTimerType() == TurnTimerTypes.NO_TURNTIMER) then
		return false;
	end

	-- Only pause the game if this player is still alive (and not totally defeated)
	local pLocalPlayer = Players[Game.GetLocalPlayer()];
	if(pLocalPlayer and pLocalPlayer:IsAlive()) then
		return true;
	end
	
	return false;	
end

function HandlePauseGame( bIsHide : boolean )
	if(ShouldPauseGame()) then
		local localPlayerID = Network.GetLocalPlayerID();
		local localPlayerConfig = PlayerConfigurations[localPlayerID];
		if(localPlayerConfig) then
			localPlayerConfig:SetWantsPause(not bIsHide);
			Network.BroadcastPlayerInfo();
		end
	end
end
     
function Resize()
	local screenX, screenY = UIManager:GetScreenSizeVal();

	g_HideLeaderPortrait = screenX < 1280;

	Controls.Background:Resize(screenX,screenY);
	Controls.RankingStack:CalculateSize();
	Controls.RankingStack:ReprocessAnchoring();
	Controls.RankingScrollPanel:CalculateInternalSize();

	local portraitOffsetY = math.min(0, screenY-1024);
	Controls.PlayerPortrait:SetOffsetVal(-420, portraitOffsetY);

	-- Show/Hide the chat panel button
	Controls.ChatButton:SetHide(not GameConfiguration.IsNetworkMultiplayer()); 

end

function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if (type == SystemUpdateUI.ScreenResize) then
    Resize();
  end
end

----------------------------------------------------------------
-- The primary method for updating the UI.
----------------------------------------------------------------
function View(icon, name, blurb, playerIcon, playerName, playerPortrait, style)
	
	SetIcon(Controls.RibbonIcon, icon);
	SetIcon(Controls.PlayerIcon, playerIcon);

	Controls.VictoryName:LocalizeAndSetText(name);
	Controls.Blurb:LocalizeAndSetText(blurb);

	print(style.Background);
	Controls.Background:SetTexture(style.Background);
	Controls.Ribbon:SetTexture(style.Ribbon);
	Controls.RibbonTile:SetTexture(style.RibbonTile);

	Controls.PlayerName:LocalizeAndSetText(playerName);
	if(playerPortrait) then
		g_HasPlayerPortrait = true;
		Controls.PlayerPortrait:SetTexture(playerPortrait);
		Controls.PlayerPortrait:SetHide(false);
	else
		g_HasPlayerPortrait = false;
		Controls.PlayerPortrait:UnloadTexture();
		Controls.PlayerPortrait:SetHide(true);
	end

	Resize();

	if(g_HideLeaderPortrait) then
		Controls.PlayerPortrait:SetHide(true);
		Controls.PlayerPortrait:UnloadTexture();
	end

	-- Movie begins play-back when UI is shown.
	g_Movie = style.Movie;
    g_SoundtrackStart = style.SndStart;
    g_SoundtrackStop = style.SndStop;

    if g_Movie ~= nil then
        UI.LoadSoundBankGroup(5);   -- BANKS_FMV, must teach Lua these constants
    end

	Controls.ReplayMovieButton:SetHide(g_Movie == nil);
	Controls.MovieFill:SetHide(true);
	Controls.Movie:Close();

	UpdateButtonStates();

	if(ContextPtr:IsHidden()) then
		UIManager:QueuePopup( ContextPtr, PopupPriority.High );
	end	
end

----------------------------------------------------------------
-- Collect additional data that will be provided to the view 
-- method.
----------------------------------------------------------------
function Data(playerId, victory_or_defeat_type)
	
	local p = Players[playerId];
	local pc = PlayerConfigurations[playerId];

	local civType = pc:GetCivilizationTypeName();
	local leaderType = pc:GetLeaderTypeName();

	local victory = GameInfo.Victories[victory_or_defeat_type];
	local defeat = GameInfo.Defeats[victory_or_defeat_type];


	local playerName = pc:GetPlayerName();
	local playerIcon = "ICON_" .. civType;
	local playerPortrait = leaderType .. "_NEUTRAL";

	local name, blurb, icon, style;
	
	if(defeat) then
		name = defeat.Name;
		blurb = defeat.Blurb;	
		fallbackIcon = nil;
		style = Styles[defeat.DefeatType];
		if(style == nil) then
			style = Styles["GENERIC_DEFEAT"];
		end

		icon = style.RibbonIcon;
	
	elseif(victory) then
		name = victory.Name;
		blurb = victory.Blurb;
		style = Styles[victory.VictoryType];
		if(style == nil) then
			style = Styles["GENERIC_VICTORY"];
		end

		icon = {style.RibbonIcon, "ICON_" .. victory.VictoryType, "ICON_VICTORY_GENERIC"};
	end

	return icon, name, blurb, playerIcon, playerName, playerPortrait, style;
end


----------------------------------------------------------------
-- Called when a player has been defeated.
-- The UI is only displayed if this player is you.
----------------------------------------------------------------
function OnPlayerDefeat( player, defeat, eventID)
	print("Player " .. tostring(player) .. " has been defeated! (" .. tostring(defeat) .. ")");
	local localPlayer = Game.GetLocalPlayer();
	
	if (localPlayer and localPlayer >= 0) then		-- Check to see if there is any local player
		-- Was it the local player?
		if (localPlayer == player) then
			UI.SetPauseEventID( eventID );
			-- You have been defeated :(
			local defeatInfo = GameInfo.Defeats[defeat];
			defeat = defeatInfo and defeatInfo.DefeatType or "DEFEAT_DEFAULT";
			View(Data(player, defeat));
		end
	end
end

local ruleset = GameConfiguration.GetValue("RULESET");
if(ruleset ~= "RULESET_TUTORIAL") then
	Events.PlayerDefeat.Add(OnPlayerDefeat);
end

----------------------------------------------------------------
-- Called when a player is victorious.
-- The UI is only displayed if this player is you.
----------------------------------------------------------------
function OnPlayerVictory( player, victory, eventID)
	print("Player " .. tostring(player) .. " has achieved a victory! (" .. tostring(victory) .. ")");
	local localPlayer = Game.GetLocalPlayer();

	if (localPlayer and localPlayer >= 0) then		-- Check to see if there is any local player
		if (localPlayer == player) then
			-- You were victorious!!
			UI.SetPauseEventID( eventID );
			local victoryInfo = GameInfo.Victories[victory];
			victory = victoryInfo and victoryInfo.VictoryType or "VICTORY_DEFAULT";
			View(Data(player, victory));
		else
			UI.SetPauseEventID( eventID );
			-- Another player was victorious...
			-- In the future, we'll want to be more specific stating that another player has won.
			-- However we're lacking strings and time.
			local p = Players[localPlayer];

			-- Only show the defeat screen to other living players.  If a player
			-- was defeated, they would receive another notification.
			if(p:IsAlive()) then
				View(Data(localPlayer, "DEFEAT_DEFAULT"));
			end
		end
	end
end

local ruleset = GameConfiguration.GetValue("RULESET");
if(ruleset ~= "RULESET_TUTORIAL") then
	Events.PlayerVictory.Add(OnPlayerVictory);
end

----------------------------------------------------------------
-- Called when the display is to be manually shown.
----------------------------------------------------------------
function OnShowEndGame(playerId)
	if(playerId == nil) then
		playerId = Game.GetLocalPlayer();
	end

	local player = Players[playerId];
	if(player:IsAlive()) then
		local victor, victoryType = Game.GetWinningPlayer();
		if(victor == player:GetID()) then
			local victory = GameInfo.Victories[victoryType];
			if(victory) then
				View(Data(playerId, victory.VictoryType));
				return;
			end		
		end
	end

	View(Data(playerId, "DEFEAT_DEFAULT"));
end


-- ===========================================================================
--	Chat Panel Functionality
-- ===========================================================================
function OnMultiplayerChat( fromPlayer, toPlayer, text, eTargetType )
	OnChat(fromPlayer, toPlayer, text, eTargetType);
end

function OnChat( fromPlayer, toPlayer, text, eTargetType )
	-- EndGameMenu doesn't play sounds for chat events because the ingame chat panel already does so. 
	if(ContextPtr:IsHidden() == false) then
		local pPlayerConfig = PlayerConfigurations[fromPlayer];
		local playerName = pPlayerConfig:GetPlayerName();

		-- Selecting chat text color based on eTargetType	
		local chatColor :string = "[color:ChatMessage_Global]";
		if(eTargetType == ChatTargetTypes.CHATTARGET_TEAM) then
			chatColor = "[color:ChatMessage_Team]";
		elseif(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER) then
			chatColor = "[color:ChatMessage_Whisper]";  
		end
		
		local chatString	= "[color:ChatPlayerName]" .. playerName;

		-- When whispering, include the whisperee's name as well.
		if(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER) then
			local pTargetConfig :table	= PlayerConfigurations[toPlayer];
			if(pTargetConfig ~= nil) then
				local targetName :string = pTargetConfig:GetPlayerName();
				chatString = chatString .. " [" .. targetName .. "]";
			end
		end

		-- Ensure text parsed properly
		text = ParseChatText(text);

		chatString			= chatString .. ": [ENDCOLOR]" .. chatColor;
		chatString			= chatString .. text .. "[ENDCOLOR]";

		AddChatEntry( chatString, Controls.ChatStack, m_ChatInstances, Controls.ChatScroll);
	end
end

-------------------------------------------------
-------------------------------------------------
function SendChat( text )
    if( string.len( text ) > 0 ) then
		-- Parse text for possible chat commands
		local parsedText :string;
		local chatTargetChanged :boolean = false;
		local printHelp :boolean = false;
		parsedText, chatTargetChanged, printHelp = ParseInputChatString(text, m_playerTarget);
		if(chatTargetChanged) then
			ValidatePlayerTarget(m_playerTarget);
			UpdatePlayerTargetPulldown(Controls.ChatPull, m_playerTarget);
			UpdatePlayerTargetEditBox(Controls.ChatEntry, m_playerTarget);
		end

		if(printHelp) then
			ChatPrintHelp(Controls.ChatStack, m_ChatInstances, Controls.ChatScroll);
		end

		if(parsedText ~= "") then
			-- m_playerTarget uses PlayerTargetLogic values and needs to be converted  
			local chatTarget :table ={};
			PlayerTargetToChatTarget(m_playerTarget, chatTarget);
			Network.SendChat( parsedText, chatTarget.targetType, chatTarget.targetID );
			UI.PlaySound("Play_MP_Chat_Message_Sent");
		end
    end
    Controls.ChatEntry:ClearString();
end

-------------------------------------------------
-- ParseChatText - ensures icon tags parsed properly
-------------------------------------------------
function ParseChatText(text)
	startIdx, endIdx = string.find(string.upper(text), "%[ICON_");
	if(startIdx == nil) then
		return text;
	else
		for i = endIdx + 1, string.len(text) do
			character = string.sub(text, i, i);
			if(character=="]") then
				return string.sub(text, 1, i) .. ParseChatText(string.sub(text,i + 1));
			elseif(character==" ") then
				text = string.gsub(text, " ", "]", 1);
				return string.sub(text, 1, i) .. ParseChatText(string.sub(text, i + 1));
			elseif (character=="[") then
				return string.sub(text, 1, i - 1) .. "]" .. ParseChatText(string.sub(text, i));
			end
		end
		return text.."]";
	end
	return text;
end

-------------------------------------------------
-------------------------------------------------

function OnMultplayerPlayerConnected( playerID )
	-- EndGameMenu doesn't play sounds for chat events because the ingame chat panel already does so. 
	if( ContextPtr:IsHidden() == false ) then
		OnChat( playerID, -1, PlayerConnectedChatStr);
	end
end

-------------------------------------------------
-------------------------------------------------

function OnMultiplayerPrePlayerDisconnected( playerID )
	-- EndGameMenu doesn't play sounds for chat events because the ingame chat panel already does so. 
	if( ContextPtr:IsHidden() == false ) then
		if(Network.IsPlayerKicked(playerID)) then
			OnChat( playerID, -1, PlayerKickedChatStr);
		else
    		OnChat( playerID, -1, PlayerDisconnectedChatStr);
		end
	end
end

----------------------------------------------------------------
function OnMultiplayerHostMigrated( newHostID : number )
	-- EndGameMenu doesn't play sounds for chat events because the ingame chat panel already does so. 
	if(ContextPtr:IsHidden() == false) then
		OnChat( newHostID, -1, PlayerHostMigratedChatStr);
	end
end

----------------------------------------------------------------
function OnPlayerInfoChanged(playerID)
	if(ContextPtr:IsHidden() == false) then
		-- Update chat target pulldown.
		PlayerTarget_OnPlayerInfoChanged( playerID, Controls.ChatPull, Controls.ChatEntry, m_playerTargetEntries, m_playerTarget, false);
	end
end

----------------------------------------------------------------
function OnChatPulldownChanged(newTargetType :number, newTargetID :number)
	ChangeChatIcon(Controls.ChatIcon, newTargetType);
	local textControl:table = Controls.ChatPull:GetButton():GetTextControl();
	local text:string = textControl:GetText();
	Controls.ChatPull:SetToolTipString(text);
end

----------------------------------------------------------------
function ChangeChatIcon(iconControl:table, targetType:number)
	if(targetType == ChatTargetTypes.CHATTARGET_ALL) then
		iconControl:SetText("[ICON_Global]");
	elseif(targetType == ChatTargetTypes.CHATTARGET_TEAM) then
		iconControl:SetText("[ICON_Team]");
	else
		iconControl:SetText("[ICON_Whisper]");
	end
end


-- ===========================================================================
--	Initialize screen
-- ===========================================================================
function Initialize()
	ContextPtr:SetShowHideHandler( ShowHideHandler );

	Controls.ChatEntry:RegisterCommitCallback( SendChat );

	LuaEvents.ShowEndGame.Add(OnShowEndGame);
	Events.SystemUpdateUI.Add( OnUpdateUI );
	Events.PlayerInfoChanged.Add(OnPlayerInfoChanged);
	Events.MultiplayerPrePlayerDisconnected.Add( OnMultiplayerPrePlayerDisconnected );
	Events.MultiplayerPlayerConnected.Add( OnMultplayerPlayerConnected );
	Events.MultiplayerChat.Add( OnMultiplayerChat );

	Resize();
end

Initialize();
 