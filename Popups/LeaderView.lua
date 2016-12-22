
local ms_playerOne, ms_playerTwo;

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function OnContinue()
	ContextPtr:SetHide(true);
	Events.HideLeaderScreen();
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function OnDeclareWar()
	local acceptWar = Locale.Lookup( "LOC_ACCEPT_WAR" );
	Controls.DeclareWarButton:SetHide(true);
	Controls.LeaderText:SetText( acceptWar );

	local parameters = {};
	parameters[ PlayerOperations.PARAM_PLAYER_ONE ] = ms_playerOne;
	parameters[ PlayerOperations.PARAM_PLAYER_TWO] = ms_playerTwo;
	UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.DIPLOMACY_DECLARE_WAR, parameters);
    UI.PlaySound("Notification_War_Declared");
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function ShowWarLeader( actingPlayer, reactingPlayer )
	local localPlayer = Players[Game.GetLocalPlayer()];

	if localPlayer:GetID() == reactingPlayer and actingPlayer ~= -1 then
		ms_playerOne = actingPlayer;
		ms_playerTwo = reactingPlayer;

		ContextPtr:SetHide(false);

        UI.PlaySound("Leader_Screen_Anger_Transition");

		local declareWar = Locale.Lookup( "LOC_DECLARE_WAR" );
		Controls.DeclareWarButton:SetHide(true);
		Controls.LeaderText:SetText( declareWar );
		Events.ShowLeaderScreen( PlayerConfigurations[actingPlayer]:GetLeaderTypeName() );
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function ShowRefusePeaceLeader( actingPlayer, reactingPlayer )
	local localPlayer = Players[Game.GetLocalPlayer()];

	if localPlayer:GetID() == reactingPlayer and actingPlayer ~= -1 then
		ms_playerOne = actingPlayer;
		ms_playerTwo = reactingPlayer;

		ContextPtr:SetHide(false);

        UI.PlaySound("Leader_Screen_Anger_Transition");

		local declareWar = Locale.Lookup( "LOC_REFUSE_PEACE" );
		Controls.DeclareWarButton:SetHide(true);
		Controls.LeaderText:SetText( declareWar );
		Events.ShowLeaderScreen(PlayerConfigurations[actingPlayer]:GetLeaderTypeName());
	end
end

-------------------------------------------------------------------------------
-- Note that this is currently filtered on game core side - bad practice and must be fixed.
--  But, as a result, we do not need to check for matching local player
-------------------------------------------------------------------------------
function ShowFirstMeetingLeader( firstPlayer, secondPlayer )
	local localPlayerID = Game.GetLocalPlayer();

	local firstMeet = Locale.Lookup( "LOC_LEADER_SCREEN_GREETING" );
	Controls.LeaderText:SetText( firstMeet );

	if localPlayerID == firstPlayer then   
		ms_playerOne = firstPlayer;
		ms_playerTwo = secondPlayer;
		ContextPtr:SetHide(false);
		Events.ShowLeaderScreen( PlayerConfigurations[secondPlayer]:GetLeaderTypeName() );
	elseif localPlayerID == secondPlayer then
		ms_playerOne = secondPlayer;
		ms_playerTwo = firstPlayer;
		ContextPtr:SetHide(false);
		Events.ShowLeaderScreen( PlayerConfigurations[firstPlayer]:GetLeaderTypeName() );
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function OnTalkToLeader( playerID )
	local localPlayerID = Game.GetLocalPlayer();
	local localTeam	= Teams[Game.GetLocalTeam()];
	local teamDiplo = localTeam:GetDiplomacy();

	local leaderPlayerConfig = PlayerConfigurations[playerID];
	local leaderTeamID = leaderPlayerConfig:GetTeam(playerID);

	local leaderText :string;
	if (teamDiplo:HasMet(leaderTeamID)) then
		leaderText = "What is it you want of me?";
	else
		leaderText = Locale.Lookup( "LOC_LEADER_SCREEN_GREETING" );
	end
	Controls.LeaderText:SetText( leaderText );

	ContextPtr:SetHide(false);
	Events.ShowLeaderScreen(PlayerConfigurations[playerID]:GetLeaderTypeName());

	if (localPlayerID == firstPlayer) then
		
	elseif (localPlayerID == secondPlayer) then
		
	end
end
-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
Controls.GoodbyeButton:RegisterCallback(Mouse.eLClick, OnContinue);
Controls.DeclareWarButton:RegisterCallback(Mouse.eLClick, OnDeclareWar);
Events.DiplomacyDeclareWar.Add(ShowWarLeader);
Events.DiplomacyRefusePeace.Add(ShowRefusePeaceLeader);
Events.LeaderPopup.Add(ShowFirstMeetingLeader);
Events.DiplomacyMeet.Add(ShowFirstMeetingLeader);

LuaEvents.CityBannerManager_TalkToLeader.Add(OnTalkToLeader);
LuaEvents.DiploPopup_TalkToLeader.Add(OnTalkToLeader);


