-------------------------------------------------
-- Player Setup Logic
-------------------------------------------------
include( "InstanceManager" );
include( "GameSetupLogic" );
include( "SupportFunctions" );
include( "Civ6Common" ); --GetLeaderUniqueTraits

g_PlayerParameters = {};
local m_currentInfo = {											--m_currentInfo is a duplicate of the data which is currently selected for the local player
		CivilizationIcon = "ICON_CIVILIZATION_UNKNOWN",
		LeaderIcon = "ICON_LEADER_DEFAULT",
		CivilizationName = "LOC_RANDOM_CIVILIZATION",
		LeaderName = "LOC_RANDOM_LEADER"
	};

local m_tooltipControls = {};

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
--	LeaderType							-- The type name of the leader (to derive the standing portrait/background images)
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
			info.LeaderType = leader_type;
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

-- ===========================================================================
--	Correctly displays a special flyout for the leader selection dropdown.
--	info:				The leader and civ info that we will use to set the data
--	tooltipControls:	All of the data required for generating the tooltip.  Includes:
--							InfoStack			table	- The primary stack which holds all the data for the panel
--							InfoScrollPanel		table	- The scrollpanel for the flyout
--							UniqueIconIM		table	- Instance manager for the unique civ abilities/units
--							HeaderIconIM		table	- Instance manager for the header icon (has a different backing)
--							HeaderIM			table	- Instance manager for the headers 
--							CivToolTipSlide		table	- Flyout animation slide
--							CivToolTipAlpha		table	- Flyout animation alpha
--							HasLeaderPlacard	boolean - Indicates whether or not this tooltip should also display the leader placard flyout
--							LeaderBG			table	- The background image displayed behind the leader
--							LeaderImage			table	- The leader image
--							DummyImage			table	- This dummy image is used so that we can calculate the ratio of the original leader image.  
--														  We use this to determine how to position the leader within the placard.
--							CivLeaderSlide		table	- Flyout leader placard slide
--							CivLeaderAlpha		table	- Flyout leader placard alpha
--						<< This data is passed from the contexts where we pick leaders - AdvancedSetup and StagingRoom >>
--	alwaysHide:			A boolean indicating that we should always hide both flyouts.  The "Random" leader selection will always be hidden for example
-- ===========================================================================
function DisplayCivLeaderToolTip(info:table, tooltipControls:table, alwaysHide:boolean)
	if(info.CivilizationName ~= "LOC_RANDOM_CIVILIZATION" and not alwaysHide) then --If we are showing leader data flyouts, then make sure we are playing forwards, and play until shown
		if (tooltipControls.CivToolTipAlpha:IsReversing()) then
			tooltipControls.CivToolTipAlpha:Reverse();
			tooltipControls.CivToolTipSlide:Reverse();
			if(tooltipControls.HasLeaderPlacard) then
				tooltipControls.CivLeaderAlpha:Reverse();
				tooltipControls.CivLeaderSlide:Reverse();
			end
		else
			tooltipControls.CivToolTipAlpha:Play();
			tooltipControls.CivToolTipSlide:Play();
			if(tooltipControls.HasLeaderPlacard) then
				tooltipControls.CivLeaderAlpha:Play();
				tooltipControls.CivLeaderSlide:Play();
			end
		end
		SetUniqueCivLeaderData(info, tooltipControls);
	else
		if (not tooltipControls.CivToolTipAlpha:IsReversing()) then --If we are hiding the leader data flyouts, make sure we are playing backwards, and play until hidden
			tooltipControls.CivToolTipAlpha:Reverse();
			tooltipControls.CivToolTipSlide:Reverse();
			if(tooltipControls.HasLeaderPlacard) then
				tooltipControls.CivLeaderAlpha:Reverse();
				tooltipControls.CivLeaderSlide:Reverse();
			end
		else
			tooltipControls.CivToolTipAlpha:Play();
			tooltipControls.CivToolTipSlide:Play();
			if(tooltipControls.HasLeaderPlacard) then
				tooltipControls.CivLeaderAlpha:Play();
				tooltipControls.CivLeaderSlide:Play();
			end
		end
	end	
end

-- ===========================================================================
function UpdateCivLeaderToolTip()
	if m_currentInfo.LeaderType ~= nil then
		SetUniqueCivLeaderData(m_currentInfo, m_tooltipControls);
	end
end

-- ===========================================================================
--	Sets all of the data for the Unique Civilization/Leader flyout and sizes the controls accordingly
--	info				The leader and civ info that we will use to set the data
--	tooltipControls		The controls that the info data will be attached to
-- ===========================================================================
function SetUniqueCivLeaderData(info:table, tooltipControls:table)

	tooltipControls.HeaderIconIM:ResetInstances();
	tooltipControls.UniqueIconIM:ResetInstances();
	tooltipControls.HeaderIM:ResetInstances();

	-- Check to make sure this player panel has the leader placard
	if tooltipControls.HasLeaderPlacard then
		-- Unload leader textures
		tooltipControls.LeaderImage:UnloadTexture();
		tooltipControls.LeaderBG:UnloadTexture();
		tooltipControls.DummyImage:UnloadTexture();

		-- Set leader placard
		local leaderImageName = info.LeaderType.."_NEUTRAL";
		local leaderName = string.gsub(info.LeaderType, "LEADER_","")
	
		tooltipControls.DummyImage:SetTexture(leaderImageName);
		local imageRatio = tooltipControls.DummyImage:GetSizeX()/tooltipControls.DummyImage:GetSizeY();
		if(imageRatio > .51) then
 			tooltipControls.LeaderImage:SetTextureOffsetVal(30,10)
		else
			tooltipControls.LeaderImage:SetTextureOffsetVal(10,50)
		end
		tooltipControls.LeaderImage:SetTexture(leaderImageName);
		tooltipControls.LeaderBG:SetTexture(info.LeaderType.."_BACKGROUND");
	end

	-- Set Leader unique data
	local leaderHeader = tooltipControls.HeaderIM:GetInstance();
	leaderHeader.Header:SetText(Locale.ToUpper(Locale.Lookup(info.LeaderName)));
	local leaderAbility = tooltipControls.HeaderIconIM:GetInstance();
	leaderAbility.Icon:SetIcon(info.LeaderIcon);
	leaderAbility.Header:SetText(Locale.ToUpper(Locale.Lookup(info.LeaderAbility.Name)));
	leaderAbility.Description:LocalizeAndSetText(info.LeaderAbility.Description);
	
	-- Set Civ unique data
	local civHeader = tooltipControls.HeaderIM:GetInstance();
	civHeader.Header:SetText(Locale.ToUpper(Locale.Lookup(info.CivilizationName)));
	local civAbility = tooltipControls.HeaderIconIM:GetInstance();
	civAbility.Icon:SetIcon(info.CivilizationIcon);
	civAbility.Header:SetText(Locale.ToUpper(Locale.Lookup(info.CivilizationAbility.Name)));
	civAbility.Description:LocalizeAndSetText(info.CivilizationAbility.Description);
	
	-- Set Civ unique units data
	for _, item in ipairs(info.Uniques) do
		local instance:table = {};
		instance = tooltipControls.UniqueIconIM:GetInstance();
		instance.Icon:SetIcon(item.Icon);
		local headerText:string = Locale.ToUpper(Locale.Lookup( item.Name ));
		instance.Header:SetText( headerText );
		instance.Description:SetText(Locale.Lookup(item.Description));
	end

	tooltipControls.InfoStack:CalculateSize();
	tooltipControls.InfoStack:ReprocessAnchoring();
	tooltipControls.InfoScrollPanel:CalculateSize();
end

-------------------------------------------------------------------------------
-- Setup Player Interface
-- This gets or creates player parameters for a given player id.
-- It then appends a driver to the setup parameter to control a visual 
-- representation of the parameter
-------------------------------------------------------------------------------
function SetupLeaderPulldown(playerId:number, instance:table, pulldownControlName:string, civIconControlName, leaderIconControlName, tooltipControls:table)
	local parameters = GetPlayerParameters(playerId);
	if(parameters == nil) then
		parameters = CreatePlayerParameters(playerId);
	end

	-- Need to save our master tooltip controls so that we can update them if we hop into advanced setup and then go back to basic setup
	if (tooltipControls.HasLeaderPlacard) then
		m_tooltipControls = {};
		m_tooltipControls = tooltipControls;
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

	m_currentInfo = {										
		CivilizationIcon = "ICON_CIVILIZATION_UNKNOWN",
		LeaderIcon = "ICON_LEADER_DEFAULT",
		CivilizationName = "LOC_RANDOM_CIVILIZATION",
		LeaderName = "LOC_RANDOM_LEADER"
	};

	table.insert(controls, {
		UpdateValue = function(v)
			local button = control:GetButton();

			local caption = v.Name;
			if(v.Invalid) then
				local err = v.InvalidReason or "LOC_SETUP_ERROR_INVALID_OPTION";
				caption = caption .. "[NEWLINE][COLOR_RED](" .. Locale.Lookup(err) .. ")[ENDCOLOR]";
			end

			button:SetText(caption);
				
			local info = GetPlayerInfo(v.Domain, v.Value);
			local tooltip = GenerateToolTipFromPlayerInfo(info);

			if(civIcon) then
				civIcon:SetIcon(info.CivilizationIcon);
			end
			if(leaderIcon) then
				leaderIcon:SetIcon(info.LeaderIcon);
			end

			if(not tooltipControls.HasLeaderPlacard) then
				button:RegisterCallback( Mouse.eMouseEnter, function() DisplayCivLeaderToolTip(info, tooltipControls, false); end);
				button:RegisterCallback( Mouse.eMouseExit, function() DisplayCivLeaderToolTip(info, tooltipControls, true); end);
			end
		end,
		UpdateValues = function(values)
			control:ClearEntries();
			for i,v in ipairs(values) do
				local info = GetPlayerInfo(v.Domain, v.Value);
				local tooltip = GenerateToolTipFromPlayerInfo(info);

				local entry = {};
				control:BuildEntry( "InstanceOne", entry );

				local caption = v.Name;
				if(v.Invalid) then 
					local err = v.InvalidReason or "LOC_SETUP_ERROR_INVALID_OPTION";
					caption = caption .. "[NEWLINE][COLOR_RED](" .. Locale.Lookup(err) .. ")[ENDCOLOR]";
				end

				entry.Button:SetText(caption);
				entry.CivIcon:SetIcon(info.CivilizationIcon);
				entry.LeaderIcon:SetIcon(info.LeaderIcon);
				entry.Button:RegisterCallback( Mouse.eMouseEnter, function() DisplayCivLeaderToolTip(info, tooltipControls, false); end);
				if(tooltipControls.HasLeaderPlacard) then
					entry.Button:RegisterCallback( Mouse.eMouseExit, function() DisplayCivLeaderToolTip(m_currentInfo, tooltipControls, false); end);	-- When we mouse out, let's show what we currently have selected 
				else
					entry.Button:RegisterCallback( Mouse.eMouseExit, function() DisplayCivLeaderToolTip(m_currentInfo, tooltipControls, true); end);	-- Unless we are not showing the leader placard.. in which case, let's just dismiss
				end
				entry.Button:SetToolTipString(nil);			
				entry.Button:RegisterCallback(Mouse.eLClick, function()
					local parameter = parameters.Parameters["PlayerLeader"];
					parameters:SetParameterValue(parameter, v);
					if(playerId==0) then
						m_currentInfo = info;
					end
				end);
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

		if(UI_PostRefreshParameters) then
			UI_PostRefreshParameters();
		end
	end
end
LuaEvents.GameSetup_ConfigurationChanged.Add(GameSetup_RefreshParameters);

