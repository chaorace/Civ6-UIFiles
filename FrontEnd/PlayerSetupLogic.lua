-------------------------------------------------
-- Player Setup Logic
-------------------------------------------------
include( "InstanceManager" );
include( "GameSetupLogic" );
include( "SupportFunctions" );

g_PlayerParameters = {};

-------------------------------------------------------------------------------
-- Parameter Hooks
-------------------------------------------------------------------------------
function Player_ReadParameterValues(o, parameter)
	
	-- This is a bit of a hack.   First, obtain the player's type ID to see if it's -1.
	-- If not -1, then use typename.
	if(parameter.ParameterId == "PlayerLeader") then	
		local playerConfig = PlayerConfigurations[o.PlayerId];
		if(playerConfig) then

			local value = playerConfig:GetLeaderTypeID();
			if(value ~= -1) then
				value = playerConfig:GetLeaderTypeName();
			else
				value = "RANDOM";
			end


			return value;
		end
	else
		return SetupParameters.Config_ReadParameterValues(o, parameter);
	end
end

function Player_WriteParameterValues(o, parameter)

	-- This is a hack.  Right now changing a player's leader requires many explicit calls in a specific order.
	-- Ultimately, this *should* be a matter of setting a single key that represents the player.
	-- This was pulled from PlayerSetupLogic.
	if(parameter.ParameterId == "PlayerLeader" and o:Config_CanWriteParameter(parameter)) then	
		local playerConfig = PlayerConfigurations[o.PlayerId];
		if(playerConfig) then
			if(parameter.Value ~= nil) then
				local value = parameter.Value.Value;
				if(value == -1 or value == "RANDOM") then
					playerConfig:SetLeaderName(nil);
					playerConfig:SetLeaderTypeName(nil);
				else
					local leaderType:string = parameter.Value.Value;

					playerConfig:SetLeaderName(parameter.Value.Name);


					playerConfig:SetLeaderTypeName(leaderType);
				end
			else
				playerConfig:SetLeaderName(nil);
				playerConfig:SetLeaderTypeName(nil);
			end

			o:Config_WriteAuxParameterValues(parameter);					
			
			Network.BroadcastPlayerInfo(o.PlayerId);
			return true;
		end
	else
		local result = SetupParameters.Config_WriteParameterValues(o, parameter);
		if(result and o.PlayerId ~= nil) then
			Network.BroadcastPlayerInfo(o.PlayerId);
		end
		return result;
	end
end


-- The method used to create a UI control associated with the parameter.
function Player_UI_CreateParameter(o, parameter)
	-- Do nothing for now.  Player controls are explicitly instantiated in the UIs.
end


-- Called whenever a parameter is no longer relevant and should be destroyed.
function Player_UI_DestroyParameter(o, parameter)
	-- Do nothing for now.  Player controls are explicitly instantiated in the UIs.
end


-------------------------------------------------------------------------------
-- Create parameters for all players.
-------------------------------------------------------------------------------
function CreatePlayerParameters(playerId)
	print("Creating player parameters for Player " .. tonumber(playerId));

	-- Don't create player parameters for minor city states.  The configuration database doesn't know city state parameter values (like city state leader types) so it will stomp on them.
	local playerConfig = PlayerConfigurations[playerId];
	--if(playerConfig == nil or playerConfig:GetCivilizationLevelTypeID() ~= CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV) then
	--	return nil;
	--end

	local parameters = SetupParameters.new(playerId);
	
	-- Setup hooks.
	parameters.Parameter_GetRelevant = GetRelevantParameters;
	parameters.Config_EndWrite = Parameters_Config_EndWrite;

	-- Player specific hooks.
	-- This player logic is a bit weird due to some assumptions made in the staging room.
	-- Right now player-based parameters are not dynamically generated :(
	-- Instead, the leader pulldown, optional team pulldown and optional handicap pulldown
	-- are all allocated by the UI explicitly.
	-- Team pulldown is entirely managed in the staging room =\
	-- For now, the UI logic looks for predefined controls and populates but does not generate.
	-- In the future, I hope this can be more like the GameSetup and allow for unique player parameters to be created.
	parameters.Config_ReadParameterValues = Player_ReadParameterValues;
	parameters.Config_WriteParameterValues = Player_WriteParameterValues;
	parameters.UI_CreateParameter = Player_UI_CreateParameter;
	parameters.UI_DestroyParameter = Player_UI_DestroyParameter;
	parameters.UI_SetParameterPossibleValues = UI_SetParameterPossibleValues;
	parameters.UI_SetParameterValue = UI_SetParameterValue;
	parameters.UI_SetParameterEnabled = UI_SetParameterEnabled;
	parameters.UI_SetParameterVisible = UI_SetParameterVisible;

	parameters:Initialize();

	-- Treat g_PlayerParameters as an array to guarantee order of operations.
	table.insert(g_PlayerParameters, {playerId, parameters});
	table.sort(g_PlayerParameters, function(a,b) 
		return a[1] < b[1];
	end);

	return parameters;
end

function GetPlayerParameters(player_id)
	for i, v in ipairs(g_PlayerParameters) do
		if(v[1] == player_id) then
			return v[2];
		end
	end
end

function RebuildPlayerParameters()
	g_PlayerParameters = {};

	local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
	print("There are " .. #player_ids .. " participating players.");
	for i, player_id in ipairs(player_ids) do	
		CreatePlayerParameters(player_id);
	end
end

function RefreshPlayerParameters()
	print("Refresh Player Parameters");
	for i,v in ipairs(g_PlayerParameters) do
		v[2]:FullRefresh();
	end
	print("End Refresh Player Parameters");
end

function ResetPlayerParameters()
	print("Resetting Player Parameters");
	for i,v in ipairs(g_PlayerParameters) do
		v[2]:ResetDefaults();
	end
end

function ReleasePlayerParameters()
	print("Releasing Player Parameters");
	for i,v in ipairs(g_PlayerParameters) do
		v[2]:Shutdown();
	end

	g_PlayerParameters = {};
end

function GetPlayerParameterError(playerId)
	for i, pp in ipairs(g_PlayerParameters) do
		local id = pp[1];
		if(id == playerId) then

			local p = pp[2];	
			if(p and p.Parameters) then
				-- For now, test a specific parameter.
				-- This could probably be generalized to enumerate all
				-- parameters.
				local playerLeader = p.Parameters["PlayerLeader"];
				if(playerLeader) then
					return playerLeader.Error;
				end
			end
		end
	end
end

-- Obtain additional information about a specific player value.
-- Returns a table containing the following fields:
--	CivilizationIcon					-- The icon id representing the civilization.
--	LeaderIcon							-- The icon id representing the leader.
--	CivilizationName					-- The name of the Civilization.
--	LeaderName							-- The name of the Leader.
--  LeaderAbility = {					-- (nullable) A table containing details about the Leader's primary ability.
--		Name							-- The name of the Leader's primary ability.
--		Description						-- The description of the Leader's primary ability.
--		Icon							-- The icon of the Leader's primary ability.
--  },
--  CivilizationAbility = {				-- (nullable) A table containing details about the Civilization's primary ability.
--		Name							-- The name of the Civilization's primary ability.
--		Description						-- The description of the Civilization's primary ability.
--		Icon							-- The icon of the Civilization's primary ability.
--  },
--	Uniques = {							-- (nullable) An array of unique items.
--		{
--			Name,						-- The name of the unique item.
--			Description,				-- The description of the unique item.
--			Icon,						-- The icon of the unique item.
--		}
--	},
function GetPlayerInfo(domain, leader_type)
	-- Kludge:  We're special casing random for now.
	-- this will eventually change and 'RANDOM' will
	-- be just another row in the players entry.
	-- This can't happen until GameCore supports 
	-- multiple 'random' pools.
	if(leader_type ~= "RANDOM") then
		local info_query = "SELECT CivilizationIcon, LeaderIcon, LeaderName, CivilizationName, LeaderAbilityName, LeaderAbilityDescription, LeaderAbilityIcon, CivilizationAbilityName, CivilizationAbilityDescription, CivilizationAbilityIcon from Players where Domain = ? and LeaderType = ? LIMIT 1";
		local item_query = "SELECT Name, Description, Icon from PlayerItems where Domain = ? and LeaderType = ? ORDER BY SortIndex";
		local info_results = DB.ConfigurationQuery(info_query, domain, leader_type);
		local item_results = DB.ConfigurationQuery(item_query, domain, leader_type);
		
		if(info_results and item_results) then
			local info = {};

			for i,row in ipairs(info_results) do
				-- This is a hack! We need to find a better way to handle multiple civs with different leaders
				if (row.LeaderIcon == "ICON_LEADER_GORGO") then
					info.CivilizationIcon= "ICON_CIVILIZATION_GREECE_GORGO";
				else
					info.CivilizationIcon= row.CivilizationIcon;
				end
				info.LeaderIcon= row.LeaderIcon;
				info.LeaderName = row.LeaderName;
				info.CivilizationName = row.CivilizationName;
				if(row.LeaderAbilityName and row.LeaderAbilityDescription and row.LeaderAbilityIcon) then
					info.LeaderAbility = {
						Name = row.LeaderAbilityName,
						Description = row.LeaderAbilityDescription,
						Icon = row.LeaderAbilityIcon
					};
				end

				if(row.CivilizationAbilityName and row.CivilizationAbilityDescription and row.CivilizationAbilityIcon) then
					info.CivilizationAbility = {
						Name = row.CivilizationAbilityName,
						Description = row.CivilizationAbilityDescription,
						Icon = row.CivilizationAbilityIcon
					};
				end
			end

			info.Uniques = {};
			for i,row in ipairs(item_results) do
				table.insert(info.Uniques, {
					Name = row.Name,
					Description = row.Description,
					Icon = row.Icon
				});
			end

			return info;
		end
	end

	return {
		CivilizationIcon = "ICON_CIVILIZATION_UNKNOWN",
		LeaderIcon = "ICON_LEADER_DEFAULT",
		CivilizationName = "LOC_RANDOM_CIVILIZATION",
		LeaderName = "LOC_RANDOM_LEADER",
	};
end

function GenerateToolTipFromPlayerInfo(info)
	local lines = {};
	table.insert(lines, Locale.Lookup(info.LeaderName));
	table.insert(lines, Locale.Lookup(info.CivilizationName));
	if(info.CivilizationAbility) then
		local ability = info.CivilizationAbility;
		table.insert(lines, "--------------------------------");
		table.insert(lines, Locale.Lookup(ability.Name));
		table.insert(lines, Locale.Lookup(ability.Description));
	end

	if(info.LeaderAbility) then
		local ability = info.LeaderAbility;
		table.insert(lines, "--------------------------------");
		table.insert(lines, Locale.Lookup(ability.Name));
		table.insert(lines, Locale.Lookup(ability.Description));
	end

	if(info.Uniques and #info.Uniques > 0) then
		table.insert(lines, "--------------------------------");
		for i,v in ipairs(info.Uniques) do
			table.insert(lines, Locale.Lookup(v.Name));
			table.insert(lines, Locale.Lookup(v.Description) .. "[NEWLINE]");

		end
	end
	
	return table.concat(lines, "[NEWLINE]");
end


-------------------------------------------------------------------------------
-- Setup Player Interface
-- This gets or creates player parameters for a given player id.
-- It then appends a driver to the setup parameter to control a visual 
-- representation of the parameter
-------------------------------------------------------------------------------
function SetupLeaderPulldown(playerId:number, instance:table, pulldownControlName:string, civIconControlName, leaderIconControlName)
	local parameters = GetPlayerParameters(playerId);
	if(parameters == nil) then
		parameters = CreatePlayerParameters(playerId);
	end

	-- Defaults
	if(civIconControlName == nil) then
		civIconControlName = "CivIcon";
	end

	if(leaderIconControlName == nil) then
		leaderIconControlName = "LeaderIcon";
	end
		
	local control = instance[pulldownControlName];
	local civIcon = instance[civIconControlName];
	local leaderIcon = instance[leaderIconControlName];

	local controls = parameters.Controls["PlayerLeader"];
	if(controls == nil) then
		controls = {};
		parameters.Controls["PlayerLeader"] = controls;
	end

	table.insert(controls, {
		UpdateValue = function(v)
			local button = control:GetButton();
			button:SetText( v and v.Name or nil);

			if(v) then
				local info = GetPlayerInfo(v.Domain, v.Value);
				local tooltip = GenerateToolTipFromPlayerInfo(info);

				if(civIcon) then
					civIcon:SetIcon(info.CivilizationIcon);
				end
				if(leaderIcon) then
					leaderIcon:SetIcon(info.LeaderIcon);
				end
			end
		end,
		UpdateValues = function(values)
			control:ClearEntries();
			for i,v in ipairs(values) do
				if(v.Invalid ~= true) then
					local info = GetPlayerInfo(v.Domain, v.Value);
					local tooltip = GenerateToolTipFromPlayerInfo(info);

					local entry = {};
					control:BuildEntry( "InstanceOne", entry );
					entry.Button:SetText(v.Name);
					entry.CivIcon:SetIcon(info.CivilizationIcon);
					entry.LeaderIcon:SetIcon(info.LeaderIcon);
					entry.Button:SetToolTipString(tooltip);			
					entry.Button:RegisterCallback(Mouse.eLClick, function()
						local parameter = parameters.Parameters["PlayerLeader"];
						parameters:SetParameterValue(parameter, v);
					end);
				end
			end
			control:CalculateInternals();
		end,
		SetEnabled = function(enabled)
			control:SetDisabled(not enabled);
		end,
	--	SetVisible = function(visible)
	--		control:SetHide(not visible);
	--	end
	});
end

function SetupHandicapPulldown(playerId, control)
	local parameters = GetPlayerParameters(playerId);
	if(parameters == nil) then
		parameters = CreatePlayerParameters(playerId);
	end

	parameters.Controls["PlayerDifficulty"] = {
		UpdateValue = function(value)
			local button = control:GetButton();
			button:SetText( value and value.Name or nil);
		end,
		UpdateValues = function(values)
			control:ClearEntries();
			for i,v in ipairs(values) do
				local entry = {};
				control:BuildEntry( "InstanceOne", entry );
				entry.Button:SetText(v.Name);
				entry.Button:SetToolTipString(v.Description);			
				entry.Button:RegisterCallback(Mouse.eLClick, function()
					local parameter = parameters.Parameters["PlayerDifficulty"];
					parameters:SetParameterValue(parameter, v);
				end);
			end
			control:CalculateInternals();
		end,
	};
end

function PlayerConfigurationValuesToUI(playerId)
	local parameters = GetPlayerParameters(playerId);
	if(parameters == nil) then
		parameters = CreatePlayerParameters(playerId);
	end

	if(parameters ~= nil) then
		parameters:FullRefresh();
	end
end

function UpdatePlayerEntry(playerId)
	local parameters = GetPlayerParameters(playerId);
	if(parameters) then
		parameters:FullRefresh();
	end
end

-- This event listener may be called during the act of refreshing parameters.
-- This commonly happens if the setup parameters need to update default values.
-- When this happens, simply mark that we need to do an additional refresh afterwards.
g_Refreshing = false;
g_NeedsAdditionalRefresh = false;
function GameSetup_RefreshParameters()
	print("Configuration Changed!");
	if(g_Refreshing) then
		print("Configuration changed while refreshing!");
		g_NeedsAdditionalRefresh = true;
	else
		g_Refreshing = true;
		print("Refreshing all parameters");
		if(g_GameParameters) then
			g_GameParameters:FullRefresh();
		end
		RefreshPlayerParameters();
		g_Refreshing = false;
		print("Finished Refreshing");

		if(g_NeedsAdditionalRefresh) then
			g_NeedsAdditionalRefresh = false;
			print("Refreshing again, to be sure.")
			return GameSetup_RefreshParameters();
		end
	end
end
LuaEvents.GameSetup_ConfigurationChanged.Add(GameSetup_RefreshParameters);

