function GetTeamColor( teamID:number )
	return UI.GetColorValue("COLOR_TEAM_" .. tostring(teamID));
end

function IsAliveAndMajor( playerID:number )
	local pPlayer:table = Players[playerID];
	return (pPlayer:IsAlive() == true and pPlayer:IsMajor() == true);
end