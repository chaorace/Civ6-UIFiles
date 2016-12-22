-------------------------------------------------
-- Game Setup Logic
-------------------------------------------------
include( "InstanceManager" );
include ("SetupParameters");

-- Instance managers for dynamic game options.
g_PullDownParameterManager = InstanceManager:new("PullDownParameterInstance", "Root", Controls.PullDownParent);
g_BooleanParameterManager = InstanceManager:new("BooleanParameterInstance", "CheckBox", Controls.CheckBoxParent);
g_StringParameterManager = InstanceManager:new("StringParameterInstance", "StringRoot", Controls.EditBoxParent);

g_ParameterFactories = {};

-- This is a mapping of instanced controls to their parameters.
-- It's used to cross reference the parameter from the control
-- in order to sort that control.
local g_SortingMap = {};

-------------------------------------------------------------------------------
-- Determine which UI stack the parameters should be placed in.
-------------------------------------------------------------------------------
function GetControlStack(group)
	local triage = {
		["GameOptions"] = Controls.PrimaryParametersStack,
		["MapOptions"] = Controls.PrimaryParametersStack,
		["Victories"] = Controls.VictoryParameterStack,
		["AdvancedOptions"] = Controls.SecondaryParametersStack,
	};

	-- Triage or default to advanced.
	return triage[group];
end


-------------------------------------------------------------------------------
-- Parameter Hooks
-------------------------------------------------------------------------------
function Parameters_Config_EndWrite(o, config_changed)
	SetupParameters.Config_EndWrite(o, config_changed);


	-- Dispatch a Lua event notifying that the configuration has changed.
	-- This will eventually be handled by the configuration layer itself.
	if(config_changed) then
		print("Marking Configuration as Changed.");
		LuaEvents.GameSetup_ConfigurationChanged();
	end
end

function GameParameters_WriteParameterValues(o, parameter)

	-- Only write game parameters if you are the host.
	if(Network.IsInSession() and not Network.IsHost()) then
		return false;
	end

	local result = SetupParameters.Config_WriteParameterValues(o, parameter);
	if(result) then
		if(parameter.ParameterId == "MapSize") then	
			if(MapSize_ValueChanged) then
				MapSize_ValueChanged(parameter);
			end
		end
	end

	return result;
end

-------------------------------------------------------------------------------
-- Hook to determine whether a parameter is relevant to this setup.
-- Parameters not relevant will be completely ignored.
-------------------------------------------------------------------------------
function GetRelevantParameters(o, parameter)

	-- If we have a player id, only care about player parameters.
	if(o.PlayerId ~= nil and parameter.ConfigurationGroup ~= "Player") then
		return false;

	-- If we don't have a player id, ignore any player parameters.
	elseif(o.PlayerId == nil and parameter.ConfigurationGroup == "Player") then
		return false;

	elseif(not GameConfiguration.IsAnyMultiplayer()) then
		return parameter.SupportsSinglePlayer;

	elseif(GameConfiguration.IsHotseat()) then
		return parameter.SupportsHotSeat;

	elseif(GameConfiguration.IsLANMultiplayer()) then
		return parameter.SupportsLANMultiplayer;

	elseif(GameConfiguration.IsInternetMultiplayer()) then
		return parameter.SupportsInternetMultiplayer;
	end
	
	return true;
end


function GameParameters_UI_DefaultCreateParameterDriver(o, parameter)
	local parent = GetControlStack(parameter.GroupId);
	local control;
	
	-- If there is no parent, don't visualize the control.  This is most likely a player parameter.
	if(parent == nil) then
		return;
	end;

	if(parameter.Domain == "bool") then
		local c = g_BooleanParameterManager:GetInstance();	
		
		-- Store the root control, NOT the instance table.
		g_SortingMap[tostring(c.CheckBox)] = parameter;		
			
		--c.CheckBox:GetTextButton():SetText(parameter.Name);
		c.CheckBox:SetText(parameter.Name);
		c.CheckBox:SetToolTipString(parameter.Description);
		c.CheckBox:RegisterCallback(Mouse.eLClick, function()
			o:SetParameterValue(parameter, not c.CheckBox:IsSelected());
			Network.BroadcastGameConfig();
		end);
		c.CheckBox:ChangeParent(parent);

		control = {
			Control = c,
			UpdateValue = function(value)
				--c.CheckBox:SetCheck(value)

				-- We have to invalidate the selection state in order
				-- to trick the button to use the right vis state..
				-- Please change this to a real check box in the future...please
				c.CheckBox:SetSelected(not value);
				c.CheckBox:SetSelected(value);
			end,
			SetEnabled = function(enabled)
				c.CheckBox:SetDisabled(not enabled);
			end,
			SetVisible = function(visible)
				c.CheckBox:SetHide(not visible);
			end,
			Destroy = function()
				g_BooleanParameterManager:ReleaseInstance(c);
			end,
		};

	elseif(parameter.Domain == "int" or parameter.Domain == "text") then
		local c = g_StringParameterManager:GetInstance();		

		-- Store the root control, NOT the instance table.
		g_SortingMap[tostring(c.StringRoot)] = parameter;
				
		c.StringName:SetText(parameter.Name);
		c.StringRoot:SetToolTipString(parameter.Description);

		if(parameter.Domain == "int") then
			c.StringEdit:SetNumberInput(true);
			c.StringEdit:SetMaxCharacters(16);
			c.StringEdit:RegisterCommitCallback(function(textString)
				o:SetParameterValue(parameter, tonumber(textString));	
				Network.BroadcastGameConfig();
			end);
		else
			c.StringEdit:SetNumberInput(false);
			c.StringEdit:SetMaxCharacters(64);
			c.StringEdit:RegisterCommitCallback(function(textString)
				o:SetParameterValue(parameter, textString);	
				Network.BroadcastGameConfig();
			end);
		end

		c.StringRoot:ChangeParent(parent);

		control = {
			Control = c,
			UpdateValue = function(value)
				c.StringEdit:SetText(value);
			end,
			SetEnabled = function(enabled)
				c.StringRoot:SetDisabled(not enabled);
				c.StringEdit:SetDisabled(not enabled);
			end,
			SetVisible = function(visible)
				c.StringRoot:SetHide(not visible);
			end,
			Destroy = function()
				g_StringParameterManager:ReleaseInstance(c);
			end,
		};
	else	-- MultiValue!
		
		-- Get the UI instance
		local c = g_PullDownParameterManager:GetInstance();	

		-- Store the root control, NOT the instance table.
		g_SortingMap[tostring(c.Root)] = parameter;

		c.Root:ChangeParent(parent);
		if c.StringName ~= nil then
			c.StringName:SetText(parameter.Name);
		end

		control = {
			Control = c,
			UpdateValue = function(value)
				local button = c.PullDown:GetButton();
				button:SetText( value and value.Name or nil);
			end,
			UpdateValues = function(values)
				c.PullDown:ClearEntries();

				for i,v in ipairs(values) do
					local entry = {};
					c.PullDown:BuildEntry( "InstanceOne", entry );
					entry.Button:SetText(v.Name);
					entry.Button:SetToolTipString(v.Description);

					entry.Button:RegisterCallback(Mouse.eLClick, function()
						o:SetParameterValue(parameter, v);
						Network.BroadcastGameConfig();
					end);
				end
				c.PullDown:CalculateInternals();
			end,
			SetEnabled = function(enabled)
				c.PullDown:SetDisabled(not enabled);
			end,
			SetVisible = function(visible)
				c.Root:SetHide(not visible);
			end,
			Destroy = function()
				g_PullDownParameterManager:ReleaseInstance(c);
			end,
		};	
	end

	return control;
end

-- The method used to create a UI control associated with the parameter.
-- Returns either a control or table that will be used in other parameter view related hooks.
function GameParameters_UI_CreateParameter(o, parameter)
	local func = g_ParameterFactories[parameter.ParameterId];

	local control;
	if(func)  then
		control = func(o, parameter);
	else
		control = GameParameters_UI_DefaultCreateParameterDriver(o, parameter);
	end

	o.Controls[parameter.ParameterId] = control;
end


-- Called whenever a parameter is no longer relevant and should be destroyed.
function UI_DestroyParameter(o, parameter)
	local control = o.Controls[parameter.ParameterId];
	if(control) then
		if(control.Destroy) then
			control.Destroy();
		end

		for i,v in ipairs(control) do
			if(v.Destroy) then
				v.Destroy();
			end	
		end
		o.Controls[parameter.ParameterId] = nil;
	end
end

-- Called whenever a parameter's possible values have been updated.
function UI_SetParameterPossibleValues(o, parameter)
	local control = o.Controls[parameter.ParameterId];
	if(control) then
		if(control.UpdateValues) then
			control.UpdateValues(parameter.Values);
		end

		for i,v in ipairs(control) do
			if(v.UpdateValues) then
				v.UpdateValues(parameter.Values);
			end	
		end
	end
end

-- Called whenever a parameter's value has been updated.
function UI_SetParameterValue(o, parameter)
	local control = o.Controls[parameter.ParameterId];
	if(control) then
		if(control.UpdateValue) then
			control.UpdateValue(parameter.Value);
		end

		for i,v in ipairs(control) do
			if(v.UpdateValue) then
				v.UpdateValue(parameter.Value);
			end	
		end
	end
end

-- Called whenever a parameter is enabled.
function UI_SetParameterEnabled(o, parameter)
	local control = o.Controls[parameter.ParameterId];
	if(control) then
		if(control.SetEnabled) then
			control.SetEnabled(parameter.Enabled);
		end

		for i,v in ipairs(control) do
			if(v.SetEnabled) then
				v.SetEnabled(parameter.Enabled);
			end	
		end
	end
end

-- Called whenever a parameter is visible.
function UI_SetParameterVisible(o, parameter)
	local control = o.Controls[parameter.ParameterId];
	if(control) then
		if(control.SetVisible) then
			control.SetVisible(parameter.Visible);
		end

		for i,v in ipairs(control) do
			if(v.SetVisible) then
				v.SetVisible(parameter.Visible);
			end	
		end
	end
end

-------------------------------------------------------------------------------
-- Called after a refresh was performed.
-- Update all of the game option stacks and scroll panels.
-------------------------------------------------------------------------------
function GameParameters_UI_AfterRefresh(o)

	-- All parameters are provided with a sort index and are manipulated
	-- in that particular order.
	-- However, destroying and re-creating parameters can get expensive
	-- and thus is avoided.  Because of this, some parameters may be 
	-- created in a bad order.  
	-- It is up to this function to ensure order is maintained as well
	-- as refresh/resize any containers.
	-- FYI: Because of the way we're sorting, we need to delete instances
	-- rather than release them.  This is because releasing merely hides it
	-- but it still gets thrown in for sorting, which is frustrating.
	local sort = function(a,b)
	
		-- ForgUI requires a strict weak ordering sort.

		local ap = g_SortingMap[tostring(a)];
		local bp = g_SortingMap[tostring(b)];

		if(ap == nil and bp ~= nil) then
			return true;
		elseif(ap == nil and bp == nil) then
			return tostring(a) < tostring(b);
		elseif(ap ~= nil and bp == nil) then
			return false;
		else
			return o.Utility_SortFunction(ap, bp);
		end
	end


	Controls.PrimaryParametersStack:SortChildren(sort);
	Controls.SecondaryParametersStack:SortChildren(sort);
	Controls.VictoryParameterStack:SortChildren(sort);

	Controls.PrimaryParametersStack:CalculateSize();
	Controls.PrimaryParametersStack:ReprocessAnchoring();

	Controls.SecondaryParametersStack:CalculateSize();
	Controls.SecondaryParametersStack:ReprocessAnchoring();

	Controls.VictoryParameterStack:CalculateSize();
	Controls.VictoryParameterStack:ReprocessAnchoring();

	Controls.ParametersStack:CalculateSize();
	Controls.ParametersStack:ReprocessAnchoring();

	Controls.ParametersScrollPanel:CalculateInternalSize();
end

-------------------------------------------------------------------------------
-- Perform any additional operations on relevant parameters.
-- In this case, adjust the parameter group so that they are sorted properly.
-------------------------------------------------------------------------------
function GameParameters_PostProcess(o, parameter)
	
	local triage = {
		["MapOptions"] = "GameOptions",
	};

	parameter.GroupId = triage[parameter.GroupId] or parameter.GroupId;
end

-- Generate the game setup parameters and populate the UI.
function BuildGameSetup(createParameterFunc:ifunction)

	-- If BuildGameSetup is called twice, call HideGameSetup to reset things.
	if(g_GameParameters) then
		HideGameSetup();
	end

	print("Building Game Setup");

	g_GameParameters = SetupParameters.new();
	g_GameParameters.Config_EndWrite = Parameters_Config_EndWrite;
	g_GameParameters.Config_WriteParameterValues = GameParameters_WriteParameterValues;
	g_GameParameters.Parameter_GetRelevant = GetRelevantParameters;
	g_GameParameters.Parameter_PostProcess = GameParameters_PostProcess;
	g_GameParameters.UI_AfterRefresh = GameParameters_UI_AfterRefresh;
	g_GameParameters.UI_CreateParameter = createParameterFunc ~= nil and createParameterFunc or GameParameters_UI_CreateParameter;
	g_GameParameters.UI_DestroyParameter = UI_DestroyParameter;
	g_GameParameters.UI_SetParameterPossibleValues = UI_SetParameterPossibleValues;
	g_GameParameters.UI_SetParameterValue = UI_SetParameterValue;
	g_GameParameters.UI_SetParameterEnabled = UI_SetParameterEnabled;
	g_GameParameters.UI_SetParameterVisible = UI_SetParameterVisible;
	g_GameParameters:Initialize();
	g_GameParameters:FullRefresh();
end

-- Hide game setup parameters.
function HideGameSetup(hideParameterFunc)
	print("Hiding Game Setup");

	-- Shutdown and nil out the game parameters.
	if(g_GameParameters) then
		g_GameParameters:Shutdown();
		g_GameParameters = nil;
	end

	-- Reset all UI instances.
	if(hideParameterFunc == nil) then
		g_PullDownParameterManager:ResetInstances();
		g_BooleanParameterManager:ResetInstances();
		g_StringParameterManager:ResetInstances();
	else
		hideParameterFunc();
	end
end


function MapSize_ValueChanged(p)
	print("MAP SIZE CHANGED");

	-- The map size has changed!
	-- Adjust the number of players to match the default players of the map size.
	local query = "SELECT * from MapSizes where Domain = ? and MapSizeType = ? LIMIT 1";
	local results = DB.ConfigurationQuery(query, p.Value.Domain, p.Value.Value);

	local minPlayers = 2;
	local maxPlayers = 2;
	local defPlayers = 2;
	local minCityStates = 0;
	local maxCityStates = 0;
	local defCityStates = 0;

	if(results) then
		for i, v in ipairs(results) do
			minPlayers = v.MinPlayers;
			maxPlayers = v.MaxPlayers;
			defPlayers = v.DefaultPlayers;
			minCityStates = v.MinCityStates;
			maxCityStates = v.MaxCityStates;
			defCityStates = v.DefaultCityStates;
		end
	end

	-- TODO: Add Min/Max city states, set defaults.
	MapConfiguration.SetMinMajorPlayers(minPlayers);
	MapConfiguration.SetMaxMajorPlayers(maxPlayers);

	-- Clamp participating player count in network multiplayer so we only ever auto-spawn players up to the supported limit. 
	local mpMaxSupportedPlayers = 8; -- The officially supported number of players in network multiplayer games.
	local participatingCount = defPlayers + GameConfiguration.GetHiddenPlayerCount();
	if GameConfiguration.IsNetworkMultiplayer() then
		participatingCount = math.clamp(participatingCount, 0, mpMaxSupportedPlayers);
	end

	local playerCountChange = GameConfiguration.SetParticipatingPlayerCount(participatingCount);
	Network.BroadcastGameConfig(true);

	print(playerCountChange);
	if (playerCountChange ~= 0) then
		LuaEvents.GameSetup_PlayerCountChanged();
	end
end
