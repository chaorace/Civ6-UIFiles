-------------------------------------------------
-- Multiplayer Lobby Types
-------------------------------------------------
MPLobbyTypes = {
	STANDARD_INTERNET = "STANDARD_INTERNET",
	STANDARD_LAN = "STANDARD_LAN",
	PITBOSS_INTERNET = "PITBOSS_INTERNET",
	PITBOSS_LAN = "PITBOSS_LAN",
	HOTSEAT = "HOTSEAT",
	PLAYBYCLOUD = "PLAYBYCLOUD",
};

function ServerTypeForMPLobbyType(mpLobbyType : string)
	local serverType = ServerType.SERVER_TYPE_NONE; --default to local server
	if(mpLobbyType == MPLobbyTypes.STANDARD_INTERNET) then
		serverType = ServerType.SERVER_TYPE_INTERNET;
	elseif(mpLobbyType == MPLobbyTypes.STANDARD_LAN) then
		serverType = ServerType.SERVER_TYPE_LAN;
	elseif(mpLobbyType == MPLobbyTypes.PITBOSS_INTERNET or mpLobbyType == MPLobbyTypes.PITBOSS_LAN) then
		serverType = ServerType.SERVER_TYPE_STEAM;
	elseif(mpLobbyType == MPLobbyTypes.HOTSEAT) then
		serverType = ServerType.SERVER_TYPE_HOTSEAT;
	elseif(mpLobbyType == MPLobbyTypes.PLAYBYCLOUD) then
		serverType = ServerType.SERVER_TYPE_FIRAXIS_CLOUD;
	end
	return serverType;
end

function GameModeTypeForMPLobbyType(mpLobbyType : string)
	local gameMode = GameModeTypes.SINGLEPLAYER;
	if(mpLobbyType == MPLobbyTypes.STANDARD_INTERNET) then
		gameMode = GameModeTypes.INTERNET;
	elseif(mpLobbyType == MPLobbyTypes.STANDARD_LAN) then
		gameMode = GameModeTypes.LAN;
	elseif(mpLobbyType == MPLobbyTypes.PITBOSS_INTERNET or mpLobbyType == MPLobbyTypes.PITBOSS_LAN) then
		gameMode = GameModeTypes.SINGLEPLAYER;
	elseif(mpLobbyType == MPLobbyTypes.HOTSEAT) then
		gameMode = GameModeTypes.HOTSEAT;
	elseif(mpLobbyType == MPLobbyTypes.PLAYBYCLOUD) then
		gameMode = GameModeTypes.PLAYBYCLOUD;
	end
	return gameMode;
end

function LobbyTypeForMPLobbyType(mpLobbyType : string)
	local lobbyType = LobbyTypes.LOBBY_NONE;
	if(mpLobbyType == MPLobbyTypes.STANDARD_INTERNET) then
		lobbyType = LobbyTypes.LOBBY_INTERNET;
	elseif(mpLobbyType == MPLobbyTypes.STANDARD_LAN) then
		lobbyType = LobbyTypes.LOBBY_LAN;
	elseif(mpLobbyType == MPLobbyTypes.PITBOSS_INTERNET or mpLobbyType == MPLobbyTypes.PITBOSS_LAN) then
		lobbyType = LobbyTypes.LOBBY_SERVER;
	elseif(mpLobbyType == MPLobbyTypes.HOTSEAT) then
		lobbyType = LobbyTypes.LOBBY_NONE;
	elseif(mpLobbyType == MPLobbyTypes.PLAYBYCLOUD) then
		lobbyType = LobbyTypes.LOBBY_FIRAXIS_CLOUD;
	end
	return lobbyType;
end
