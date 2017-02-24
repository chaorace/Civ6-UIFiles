-------------------------------------------------------------------------------
-- SetupParameters.lua
-- Logic that visualizes data-defined parameters and updates a variant map with 
-- their values.
-------------------------------------------------------------------------------
QueryChanges = 0;
QueryCache = {};

function CachedQuery(sql, arg1, arg2, arg3, arg4)

	-- If the database has been updated.  Invalidate the cache.
	local changes = DB.ConfigurationChanges();
	if(changes ~= QueryChanges) then
		QueryCache = {};
		QueryChanges = changes;
	end

	-- Is there a cached entry for this?
	local cache = QueryCache[sql];
	if(cache == nil) then
		cache = {};
		QueryCache[sql] = cache;
	end

	-- Obtain the cached results.
	local results;
	for i, v in ipairs(cache) do
		if(v[1] == arg1 and v[2] == arg2 and v[3] == arg3 and v[4] == arg4) then
			results = v[0];
			break;
		end
	end

	-- Otherwise query ourselves.
	if(results == nil) then
		local entry = {arg1, arg2, arg3, arg4};
		results = DB.ConfigurationQuery(sql, arg1, arg2, arg3, arg4);
		entry[0] = results;
		table.insert(cache, entry);
	end

	return results;
end


SetupParameters = {};

-------------------------------------------------------------------------------
-- Constructs a new instance of the SetupParameters object.
-------------------------------------------------------------------------------
function SetupParameters.new(playerId)
	local o = {
		PlayerId = playerId,
		Controls = {}
	};
	setmetatable(o, {__index = SetupParameters});

	return o;
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Allocates any needed resources, such as cached queries.
-- Should be called before use.
-------------------------------------------------------------------------------
function SetupParameters:Initialize()
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Releases any resources (such as cached queries) that were created.
-------------------------------------------------------------------------------
function SetupParameters:Shutdown()

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Perform a full refresh on all parameters.  This will update both config 
-- and UI.
-------------------------------------------------------------------------------
function SetupParameters:FullRefresh()
	self:Refresh(self:Data_DiscoverParameters());
end

-------------------------------------------------------------------------------
-- Resets parameters to their default values.
-------------------------------------------------------------------------------
function SetupParameters:ResetDefaults()
	-- Removes all parameters and nils out values.
	self:Refresh(nil);	

	-- Discovers all parameters under the normal config
	-- Because config values are null, supplies them with a default value.
	self:Refresh(self:Data_DiscoverParameters());
end

-------------------------------------------------------------------------------
-- Perform a refresh with the supplied parameters.
-------------------------------------------------------------------------------
function SetupParameters:Refresh(parameters)
	
	--if(self.Refreshing == true) then
	--	error("Refresh inception! This is bad");
	--end

	self.Refreshing = true;
	

	print("Refreshing Parameters - " .. tostring(self.PlayerId or "Game"));
	local old_params = self.Parameters or {};
	local new_params = parameters or {}; 

	self:UI_BeforeRefresh();

	-- Handle parameters that no longer exist first.
	local params_to_wipe = {};
	for pid, p in pairs(old_params) do
		if(new_params[pid] == nil) then

			-- First, tell UI that the parameter is being destroyed.
			self:UI_DestroyParameter(p);
			
			-- Next, wipe out any configuration values associated with the parameter.
			table.insert(params_to_wipe, p);	
		end
	end

	-- Handle any new parameters.
	local params_by_group = {};
	for pid, p in pairs(new_params) do
		local group = params_by_group[p.GroupId];
		if(group == nil) then
			group = {};
			params_by_group[p.GroupId] = group;
		end

		table.insert(group, p);
	end

	-- Sort individual groups and place group in array to be sorted.
	-- This might be overkill, but we want the order of operations to be consistent across all machines.
	local sorted_groups = {};
	
	for gid, g in pairs(params_by_group) do
		self.Utility_SortValues(g);
		table.insert(sorted_groups, {gid, g});
	end

	table.sort(sorted_groups, function(a,b) return a[1] < b[1] end);
	
	local params_to_write = {};

	for i, group in ipairs(sorted_groups) do
		local gid = group[1];
		local g = group[2];

		self:UI_BeforeRefreshGroup(gid);

		for ii, p in ipairs(g) do
		
			local pid = p.ParameterId;

			local old_param = old_params[pid];
			
			-- Is this a newly added parameter?
			if(old_param == nil) then
				-- Tell UI about the new parameter.
				 self:UI_CreateParameter(p);
			end

			-- This logic needs to be performed for both new and existing parameters.
			-- Fetch the values from configuration and update parameter value.
			-- Sync will return true if the sync'd value doesn't match config.
			local should_write = self:Parameter_SyncConfigurationValues(p);  

			local value = p.Value;
			if(type(value) == "table") then
				value = value.Value;
			end

			print("Parameter - " .. tostring(p.ParameterId) .. " : " .. tostring(value));

			-- If needed, push the parameter value into the configuration.
			if(should_write and self:Config_CanWriteParameter(p)) then
				print("Parameter needs to update config.");
				table.insert(params_to_write, p);
			end
		
			-- With values properly synchronized, it's time to notify UI of the changes.
			self:UI_SetParameterPossibleValues(p);   
			self:UI_SetParameterValue(p);
			self:UI_SetParameterEnabled(p);
			self:UI_SetParameterVisible(p);
 
		end

		self:UI_AfterRefreshGroup(gid);
	end

	self.Parameters = new_params;

	-- Writes are batched to minimize event dispatch.
	if(#params_to_wipe > 0 or #params_to_write > 0) then
		self:Config_BeginWrite();

		local parameters_changed = false;
		for i,p in ipairs(params_to_wipe) do
			print("Wiping parameter - " .. p.ParameterId);
			if(self:Config_ClearParameterValues(p)) then
				parameters_changed = true;
			else
				print("Could not wipe parameter - " .. p.ParameterId);
			end
		end

		for i,p in ipairs(params_to_write) do
			local value = p.Value;
			if(type(value) == "table") then
				value = value.Value;
			end

			print("Writing parameter - " .. p.ParameterId .. " to " .. tostring(value) .. "(" .. type(value) .. ")");
			if(self:Config_WriteParameterValues(p)) then
				parameters_changed = true;
			else
				print("Could not write parameter - " .. p.ParameterId);
			end 
		end

		self:Config_EndWrite(parameters_changed);
	else
		print("Nothing to change.");
	end	

	self.Refreshing = nil;

	self:UI_AfterRefresh();

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Set the value of a parameter.
-- This will update the configuration as well as trigger any UI updates.
-------------------------------------------------------------------------------
function SetupParameters:SetParameterValue(p, v)
	p.Value = v;
	self:Config_BeginWrite();
	local result = self:Config_WriteParameterValues(p);
	self:Config_EndWrite(result);
end
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- DebugPrint()
-- Print out all parameters.
-------------------------------------------------------------------------------
function SetupParameters:DebugPrint()
	for pid, p in pairs(ConfigurationParameters.Parameters) do
		print("Id: " .. pid);
		print("* Name: " .. p.Name);
		print("* Group: " .. p.GroupId);
		print("* Default Value: " .. tostring(p.DefaultValue));

		if(p.Values ~= nil) then
			local value_names = {};
			for i,v in ipairs(p.Values) do
				table.insert(value_names, v.Name);
			end

			print("* Possible Values: " .. table.concat(value_names, ", "));
		end
	end 
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Auxiliary  Methods
-- The methods below are used by  the primary methods.
-- Some of these do not perform any action (namely the UI_* methods).
-- The intent is for these methods to be overridden per-instance to perform
-- the necessary tasks.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Called before configuration values will be written.
-------------------------------------------------------------------------------
function SetupParameters:Config_BeginWrite()
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Determine whether a parameter is allowed to be written to.
-------------------------------------------------------------------------------
function SetupParameters:Config_CanWriteParameter(parameter)
	--TODO: Migrate these checks to a separate predicate.
	-- Check ChangeableAfterGameStart state.
	local gameState = GameConfiguration.GetGameState(); 
	if(not parameter.ChangeableAfterGameStart and gameState ~= GameStateTypes.GAMESTATE_PREGAME) then
		return false;
	end

	if (not Network.IsInSession() or Network.IsHost() or self.PlayerId == Network.GetLocalPlayerID()) then

		-- As long as this isn't hot seat, Human players will provide their own settings (including filtered domains)
		if(self.PlayerId and not GameConfiguration.IsHotseat() and self.PlayerId ~= Network.GetLocalPlayerID()) then
			local playerConfig = PlayerConfigurations[self.PlayerId];
			return not playerConfig:IsHuman();
		else
			return true;
		end 

		
	else
		return false;
	end
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Wipes out any configuration values that the parameter is mapped to.
-------------------------------------------------------------------------------
function SetupParameters:Config_ClearParameterValues(parameter)

	if(self:Config_CanWriteParameter(parameter)) then
		return self:Config_Write(parameter.ConfigurationGroup, parameter.ConfigurationId, nil);
	else
		return false;
	end	
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Called after configuration values have been written.
-------------------------------------------------------------------------------
function SetupParameters:Config_EndWrite()
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Reads in a single value from the configuration.
-------------------------------------------------------------------------------
function SetupParameters:Config_Read(group, id)
	if(group == "Game") then
		return GameConfiguration.GetValue(id);
	elseif(group == "Map") then
		return MapConfiguration.GetValue(id);
	elseif(group == "Player" and self.PlayerId ~= nil) then
		return PlayerConfigurations[self.PlayerId]:GetValue(id);
	end
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Reads and returns configuration values that the parameter is mapped to.
-------------------------------------------------------------------------------
function SetupParameters:Config_ReadParameterValues(parameter)
	local value = self:Config_Read(parameter.ConfigurationGroup, parameter.ConfigurationId);

	-- The value may be a hash value.  Attempt to translate.
	if(value ~= nil and parameter.Values ~= nil) then
		for i, v in ipairs(parameter.Values) do
			if(v.Hash == value) then
				value = v.Value;
				break;
			end
		end
	end

	return value;
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Writes a single value to the configuration.
-------------------------------------------------------------------------------
function SetupParameters:Config_Write(group, id, value)
	if(self.ConfigurationUpdates) then
		for i,v in ipairs(self.ConfigurationUpdates) do
			if(v.SourceGroup == group and v.SourceId == id) then
				if(value == v.SourceValue or value == DB.MakeHash(v.SourceValue) or (type(value) == "boolean" and value == false and v.SourceValue == 0) or (type(value) == "boolean" and value == true and v.SourceValue == 1)) then
					local update_value = v.Hash and DB.MakeHash(v.TargetValue) or v.TargetValue;
					print("Writing additional config values - " .. tostring(v.TargetId) .. " = " .. tostring(v.TargetValue));
					self:Config_Write(v.TargetGroup, v.TargetId, update_value);
				end
			end
		end
	end

	if(group == "Game" and self.PlayerId == nil) then
		GameConfiguration.SetValue(id, value);
		return true;
	elseif(group == "Map" and self.PlayerId == nil) then
		MapConfiguration.SetValue(id, value);
		return true;
	elseif(group == "Player" and self.PlayerId ~= nil) then
		PlayerConfigurations[self.PlayerId]:SetValue(id, value);
		return true;
	else
		return false;
	end
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Writes out the current value of the parameter to configuration.
-------------------------------------------------------------------------------
function SetupParameters:Config_WriteParameterValues(parameter)

	if (self:Config_CanWriteParameter(parameter)) then
		local value = parameter.Value;

		-- If this comes from a multi-value, obtain the inner value.
		if(type(value) == "table") then
			value = value.Value;
		end
		
		if(parameter.Hash and value ~= nil) then
			value = DB.MakeHash(value);
		end

		local result = self:Config_Write(parameter.ConfigurationGroup, parameter.ConfigurationId, value);
		if(result) then
			self:Config_WriteAuxParameterValues(parameter);		
		end
		return result
	else
		return false;
	end
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Writes out the auxiliary values of the parameter to configuration.
-------------------------------------------------------------------------------
function SetupParameters:Config_WriteAuxParameterValues(parameter)
	if(parameter.DomainConfigurationId) then
		self:Config_Write(parameter.ConfigurationGroup, parameter.DomainConfigurationId, parameter.Domain);
	end

	if(parameter.DomainValuesConfigurationId) then
		local values;
		if(type(parameter.Values) == "table") then
				
			local scratch = {};
			for i,v in ipairs(parameter.Values) do
				if(v.Invalid ~= true) then
					table.insert(scratch, tostring(v.Domain) .. "::" .. tostring(v.Value));
				end
			end

			values = table.concat(scratch, ",");
		end

		self:Config_Write(parameter.ConfigurationGroup, parameter.DomainValuesConfigurationId, values);
	end

	if(parameter.ValueNameConfigurationId) then
		local bundle = (parameter.Value ~= nil) and Locale.Bundle(parameter.Value.RawName);
		self:Config_Write(parameter.ConfigurationGroup, parameter.ValueNameConfigurationId, bundle);
	end

	if(parameter.ValueDomainConfigurationId) then
		local domain = (type(parameter.Value) == "table") and parameter.Value.Domain;
		self:Config_Write(parameter.ConfigurationGroup, parameter.ValueDomainConfigurationId, domain);
	end
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Returns a map of all discovered parameters using the latest configuration.
-------------------------------------------------------------------------------
function SetupParameters:Data_DiscoverParameters()

	--Cache data.
	local queries = {};
	for i, row in ipairs(CachedQuery("SELECT * from Queries")) do
		queries[row.QueryId] = row;
	end

	local query_parameters = {};
	for i, row in ipairs(CachedQuery("SELECT * from QueryParameters")) do
		local query = queries[row.QueryId];
		if(query) then
			local parameters = query.Parameters;
			if(parameters == nil) then
				parameters = {};
				query.Parameters = parameters;
			end

			parameters[tonumber(row.Index)] = row;
		end
	end

	local parameter_queries = {};	
	for i, row in ipairs(CachedQuery("SELECT * from ParameterQueries")) do
		parameter_queries[row.ParameterQueryId] = row;
	end

	for i, row in ipairs(CachedQuery("SELECT * from ParameterQueryCriteria")) do
		local pq = parameter_queries[row.ParameterQueryId];
		if(pq) then
			if(pq.Criteria == nil) then pq.Criteria = {}; end
			table.insert(pq.Criteria, row);
		end
	end

	for i, row in ipairs(CachedQuery("SELECT * from ParameterQueryDependencies")) do
		local pq = parameter_queries[row.ParameterQueryId];
		if(pq) then
			if(pq.Dependencies == nil) then pq.Dependencies = {}; end
			table.insert(pq.Dependencies, row);
		end
	end

	local domain_override_queries = {};
	for i, row in ipairs(CachedQuery("SELECT * from DomainOverrideQueries")) do
		table.insert(domain_override_queries, row);
	end

	local domain_range_queries = {};
	for i, row in ipairs(CachedQuery("SELECT * from DomainRangeQueries")) do
		table.insert(domain_range_queries, row);
	end

	local domain_value_union_queries = {};
	local domain_value_intersect_queries = {};
	local domain_value_difference_queries = {};

	for i, row in ipairs(CachedQuery("SELECT * from DomainValueQueries")) do
		if(row.Set == "union") then
			table.insert(domain_value_union_queries, row);
		elseif(row.Set == "intersect") then
			table.insert(domain_value_intersect_queries, row);
		elseif(row.Set == "difference") then
			table.insert(domain_value_difference_queries, row);
		end
	end

	-- Cross reference parameters with criteria and dependencies.
	local parameter_criteria = {};
	for i, query in ipairs(CachedQuery("SELECT * from ParameterCriteriaQueries")) do
		local q = queries[query.QueryId];
		if(q) then
			for _, row in ipairs(self:Data_Query(q)) do
				local criteria = {
					ParameterId = row[query.ParameterIdField],
					ConfigurationGroup = row[query.ConfigurationGroupField],
					ConfigurationId = row[query.ConfigurationIdField],
					Operator = row[query.OperatorField],
					ConfigurationValue = row[query.ConfigurationValueField],
				};

				local c = parameter_criteria[criteria.ParameterId];
				if(c == nil) then
					c = {};
					parameter_criteria[criteria.ParameterId] = c;
				end 
				table.insert(c, criteria);
			end
		end
	end

	local parameter_dependencies = {};
	for i, query in ipairs(CachedQuery("SELECT * from ParameterDependencyQueries")) do
		local q = queries[query.QueryId];
		if(q) then
			for _, row in ipairs(self:Data_Query(q)) do
				local criteria = {
					ParameterId = row[query.ParameterIdField],
					ConfigurationGroup = row[query.ConfigurationGroupField],
					ConfigurationId = row[query.ConfigurationIdField],
					Operator = row[query.OperatorField],
					ConfigurationValue = row[query.ConfigurationValueField],
				};

				local c = parameter_dependencies[criteria.ParameterId];
				if(c == nil) then
					c = {};
					parameter_dependencies[criteria.ParameterId] = c;
				end 
				table.insert(c, criteria);
			end
		end
	end
	
	local configuration_updates = {};
	for i, query in ipairs(CachedQuery("SELECT * from ConfigurationUpdateQueries")) do
		local q = queries[query.QueryId];
		if(q) then
			for _, row in ipairs(self:Data_Query(q)) do
				local config_update = {
					SourceGroup = row[query.SourceGroupField],
					SourceId = row[query.SourceIdField],
					SourceValue = row[query.SourceValueField],
					TargetGroup = row[query.TargetGroupField],
					TargetId = row[query.TargetIdField],
					TargetValue = row[query.TargetValueField],
					Hash = self.Utility_ToBool(row[query.HashField])
				};

				table.insert(configuration_updates, config_update);
			end
		end
	end
	self.ConfigurationUpdates = configuration_updates;

	-- Query for Parameters.
	local parameters = {};
	for pqid, pq in pairs(parameter_queries) do
		if(self:Parameter_MeetsCriteria(pq.Dependencies)) then
			local q = queries[pq.QueryId];
			if(q) then		
				for i, row in ipairs(self:Data_Query(q)) do
					local p = {
						Query = pq,
						ParameterId = row[pq.ParameterIdField],
						RawName = row[pq.NameField],
						Name = Locale.Lookup(row[pq.NameField]),
						Description = Locale.Lookup(row[pq.DescriptionField] or ""),
						Domain = row[pq.DomainField],
						Hash = self.Utility_ToBool(row[pq.HashField]),
						DefaultValue = row[pq.DefaultValueField],
						ConfigurationGroup = row[pq.ConfigurationGroupField],
						ConfigurationId = row[pq.ConfigurationIdField],								
						DomainConfigurationId = row[pq.DomainConfigurationIdField],
						DomainValuesConfigurationId = row[pq.DomainValuesConfigurationIdField],
						ValueNameConfigurationId = row[pq.ValueNameConfigurationIdField],
						ValueDomainConfigurationId = row[pq.ValueDomainConfigurationIdField],
						GroupId = row[pq.GroupField],
						Visible = self.Utility_ToBool(row[pq.VisibleField]),
						ReadOnly = self.Utility_ToBool(row[pq.ReadOnlyField]),
						SupportsSinglePlayer = self.Utility_ToBool(row[pq.SupportsSinglePlayerField]),
						SupportsLANMultiplayer = self.Utility_ToBool(row[pq.SupportsLANMultiplayerField]),
						SupportsInternetMultiplayer = self.Utility_ToBool(row[pq.SupportsInternetMultiplayerField]),
						SupportsHotSeat = self.Utility_ToBool(row[pq.SupportsHotSeatField]),
						ChangeableAfterGameStart = self.Utility_ToBool(row[pq.ChangeableAfterGameStartField]),
						SortIndex = row[pq.SortIndexField],
						Criteria = parameter_criteria[row[pq.ParameterIdField]]
					};	

					local default_value = p.DefaultValue;
					if(default_value ~= nil) then
						if(p.Domain == "bool") then
							p.DefaultValue = self.Utility_ToBool(default_value);		
						elseif(p.Domain == "int" or p.Domain == "uint") then
							p.DefaultValue = tonumber(default_value);
						end
					end				

					if(self:Parameter_MeetsCriteria(parameter_dependencies[p.ParameterId]) and self:Parameter_GetRelevant(p)) then			
						self:Parameter_PostProcess(p);											 
						parameters[p.ParameterId] = p;
					end
				end
			end
		end
	end


	-- Check parameter query criteria then parameter criteria.
	for pqid, pq in pairs(parameter_queries) do
		pq.MeetsCriteria = pq.Criteria == nil or self:Parameter_MeetsCriteria(pq.Criteria);
	end

	for pid, p in pairs(parameters) do
		p.MeetsCriteria = p.Query.MeetsCriteria and (p.Criteria == nil or self:Parameter_MeetsCriteria(p.Criteria));
	end
	-- 

	-- Populate parameter domain (as well as cross-reference default values)
	local pod_domains = {
		["bool"] = true,
		["int"] = true,
		["uint"] = true,
		["text"] = true
	};

	local domains = {};

	-- Query for Domain Ranges.
	for _, drq in ipairs(domain_range_queries) do
		local q = queries[drq.QueryId];
		if(q) then
			for i, row in ipairs(self:Data_Query(q)) do
				local dr = {
					Type = "IntRange",
					Query = drq,
					Domain = row[drq.DomainField],
					MinimumValue = tonumber(row[drq.MinimumValueField]) or 0,
					MaximumValue = tonumber(row[drq.MaximumValueField]) or 0,
				}

				if(dr.MinimumValue ~= nil and dr.MaximumValue ~= nil) then
					domains[dr.Domain] = dr;
				else
					print("Setup Parameter Error! IntRange domain lacks constraints Min: " .. tostring(dr.MinimumValue) .. " Max: " .. tostring(dr.MaximumValue));
				end
			end
		end
	end

	-- Query for Domain Values.
	for _, dvq in ipairs(domain_value_union_queries) do
		local q = queries[dvq.QueryId];
		if(q) then
			
			for i, row in ipairs(self:Data_Query(q)) do

				local dv = {
					Query = dvq,
					Domain = row[dvq.DomainField],
					Value = row[dvq.ValueField],
					RawName  = row[dvq.NameField]  or "",
					Name = Locale.Lookup(row[dvq.NameField]  or ""),
					Description = Locale.Lookup(row[dvq.DescriptionField] or ""),
					SortIndex = row[dvq.SortIndexField],
				};

				dv.Hash = DB.MakeHash(dv.Value);
					
				-- Add domain value.
				local values = domains[dv.Domain];
				if(values == nil) then 
					values = {};
					domains[dv.Domain] = values;	
				end
					 
				table.insert(values, dv);
			end
		end
	end

	-- Populate intersect values per domain
	local intersect_values = {};
	for _, dvq in ipairs(domain_value_intersect_queries) do
		local q = queries[dvq.QueryId];
		if(q) then
			
			for i, row in ipairs(self:Data_Query(q)) do

				local domain = row[dvq.DomainField];
				local value = row[dvq.ValueField];

				-- Add domain value.
				local values = intersect_values[domain];
				if(values == nil) then 
					values = {}; 
					intersect_values[domain] = values;	
				end
				 
				values[value] = true;
			end
		end
	end

	-- Populate difference values per domain	
	local difference_values = {};
	for _, dvq in ipairs(domain_value_difference_queries) do
		local q = queries[dvq.QueryId];
		if(q) then		
			for i, row in ipairs(self:Data_Query(q)) do

				local domain = row[dvq.DomainField];
				local value = row[dvq.ValueField];

				-- Add domain value.
				local values = difference_values[domain];
				if(values == nil) then 
					values = {}; 
					difference_values[domain] = values;	
				end
				 
				values[value] = true;
			end
		end
	end

	-- Perform intersection.
	for domain, values in pairs(intersect_values) do
		local new_values = {};
		
		local domain_values = domains[domain];
		if(domain_values) then		
			for i, dv in ipairs(domain_values) do
				if(values[dv.Value]) then
					table.insert(new_values, dv);
				end
			end
		end

		domains[domain] = new_values;
	end

	-- Perform difference.
	for domain, values in pairs(difference_values) do
		local new_values = {};
		
		local domain_values = domains[domain];
		if(domain_values) then		
			for i, dv in ipairs(domain_values) do
				if(values[dv.Value] == nil) then
					table.insert(new_values, dv);
				end
			end
		end

		domains[domain] = new_values;
	end

	local domain_overrides = {};
	for _, doq in ipairs(domain_override_queries) do
		local q = queries[doq.QueryId];
		if(q) then
			for i, row in ipairs(self:Data_Query(q)) do
				local pid = row[doq.ParameterIdField];
				local domain = row[doq.DomainField]
				if(pid and domain and domains[domain]) then
					domain_overrides[pid] = domain;
				end
			end
		end
	end

	for pid, p in pairs(parameters) do
		
		-- Override, if necessary.
		p.Domain = domain_overrides[pid] or p.Domain;

		-- Is this a multi-value domain?
		if(pod_domains[p.Domain] == nil) then

			local domain = domains[p.Domain];
			if(domain) then
				if(domain.Type == "IntRange") then
					p.Values = domain;
				else
					-- Each parameter gets a unique list of values.
					local values = {};
			
					local domain_values = domains[p.Domain];
					if(domain_values ~= nil) then
						for i, v in ipairs(domain_values) do
							table.insert(values, v);
						end
					end
			
					-- Sort Values.
					self.Utility_SortValues(values);	

					-- Call a hook to filter possible values for the parameter.
					values = self:Parameter_FilterValues(p, values);	

					-- Assign.
					p.Values = values;
				end
			end
		end
		
		p.Enabled = self:Parameter_GetEnabled(p);
	end

	return parameters;

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Execute a database query and return an iterator object.
-- The database query may have arguments mapped to the configuration.
-------------------------------------------------------------------------------
function SetupParameters:Data_Query(query)
	-- This is a bit of hard-coded trickery.
	-- It's to deal with how Lua handles nil values in tables..
	local args = {};

	local parameters = query.Parameters;
	if(parameters ~= nil) then
		for i = 1, 4, 1 do
			local p = parameters[i];
			if(p ~= nil) then
				if(p.ConfigurationGroup == "Player" and p.ConfigurationId == "PLAYER_ID" and self.PlayerId) then
					args[i] = self.PlayerId;
				else			
					args[i] = self:Config_Read(p.ConfigurationGroup, p.ConfigurationId);
				end
			end
		end
	end

	return CachedQuery(query.SQL, args[1], args[2], args[3], args[4]);
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Filter possible values for a given parameter.
-------------------------------------------------------------------------------
function SetupParameters:Parameter_FilterValues(parameter, values)
	if(parameter.ParameterId == "PlayerLeader") then
		local unique_leaders = GameConfiguration.GetValue("NO_DUPLICATE_LEADERS");
		local leaders_in_use;

		-- Populate a table of current leader selections (excluding current player).
		if(unique_leaders) then
			leaders_in_use = {};

			local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
			for i, player_id in ipairs(player_ids) do	
				if(player_id ~= self.PlayerId) then
					local playerConfig = PlayerConfigurations[player_id];
					if(playerConfig) then
						local status = playerConfig:GetSlotStatus();
						local leader = playerConfig:GetLeaderTypeName();
						if(type(leader) == "string") then
							leaders_in_use[leader] = true;
						end
					end
				end
			end
		end

		local new_values = {};
		
		local gameInProgress = GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_PREGAME;
		local checkComputerSlots = Network.IsHost() and not gameInProgress;

		local curPlayerConfig = PlayerConfigurations[self.PlayerId];
		local curSlotStatus = curPlayerConfig:GetSlotStatus();
		local localPlayerId = Network.GetLocalPlayerID();
		local checkOwnership = self.PlayerId == localPlayerId or (checkComputerSlots and curSlotStatus == SlotStatus.SS_COMPUTER);

		for i,v in ipairs(values) do
			local reason;
			if(checkOwnership and not Modding.IsLeaderAllowed(self.PlayerId, v.Value)) then
				reason = "LOC_SETUP_ERROR_LEADER_NOT_OWNED";
			elseif(leaders_in_use and leaders_in_use[v.Value]) then
				reason = "LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS";
			end

			if(reason == nil) then
				table.insert(new_values, v);
			else
				local new_value = {};

				-- Copy data from value.
				for k,v in pairs(v) do
					new_value[k] = v;
				end

				-- Mark value as invalid.
				new_value.Invalid = true;
				new_value.InvalidReason = reason;
				table.insert(new_values, new_value);
			end
		end
		return new_values;
	else
		return values;
	end
end

-------------------------------------------------------------------------------
-- Determine if the parameter should be enabled.
-------------------------------------------------------------------------------
function SetupParameters:Parameter_GetEnabled(parameter)
	
	-- Disable if parameter does not meet criteria or is read-only.
	-- Otherwise, If a game is in session, disable unless you are host.
	-- Otherwise, enable.
	if((not parameter.MeetsCriteria) or parameter.ReadOnly) then
		return false;
	end

	-- Check ChangeableAfterGameStart state.
	local gameState = GameConfiguration.GetGameState(); 
	if(not parameter.ChangeableAfterGameStart and gameState ~= GameStateTypes.GAMESTATE_PREGAME) then
		return false;
	end

	-- Some parameters can only be changed before the network session is created.
	if(parameter.ParameterId == "Ruleset"			-- Can't change because the ruleset cascades to pretty much everything.
		or parameter.ParameterId == "NoTeams") then -- Can't change because the no teams setting cascades to the player configuration team setting.
													-- This should be removed once the player configuration team pulldown is handled like a proper player parameter.
		return not Network.IsInSession();
	else
		return (not Network.IsInSession() or Network.IsHost() or self.PlayerId == Network.GetLocalPlayerID());
	end	
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Determine if the parameter is relevant to this instance.
-- Parameters that are not relevant are completely ignored.
-------------------------------------------------------------------------------
function SetupParameters:Parameter_GetRelevant(parameter)
	return true;
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Returns true if a parameter meets its criteria.
-------------------------------------------------------------------------------
local CriteriaOperators = {
	["Equals"] = function(a,b) return a == b; end,
	["NotEquals"] = function(a,b) return a ~= b; end,
	["LessThan"] = function(a, b) return a < b; end,
	["LessThanEquals"] = function(a,b) return a <= b; end,
	["GreaterThan"] = function(a,b) return a > b; end,
	["GreaterThanEquals"] = function(a,b) return a >= b; end
};

function SetupParameters:Parameter_MeetsCriteria(criteria)
	if(criteria) then
		for i, v in ipairs(criteria) do
			local cmp = CriteriaOperators[v.Operator];
			if(cmp ~= nil) then
				local expected_value = v.ConfigurationValue;
				local actual_value = self:Config_Read(v.ConfigurationGroup, v.ConfigurationId);

				local t = type(actual_value);
				if(t =="boolean") then

					local a = self.Utility_ToBool(actual_value);
					local b = self.Utility_ToBool(expected_value);
					if(not cmp(a, b)) then
						return false;
					end

				elseif(t == "number") then
					-- If expected value was a string, and the config value was a number, use the hash.
					if(type(expected_value) == "string") then
						expected_value = DB.MakeHash(expected_value);					
					end

					local a = tonumber(actual_value);
					local b = tonumber(expected_value);

					if(not cmp(a,b)) then
						return false;
					end		
				else
					if(not cmp(actual_value, expected_value)) then
						return false;
					end
				end
			else
				print("Warning! Could not find criteria operator - " .. tostring(v.Operator));
			end
		end
	end

	return true;
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Perform any additional operations on the parameter after it has been 
-- created.
-------------------------------------------------------------------------------
function SetupParameters:Parameter_PostProcess(parameter)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Determine whether a parameter's auxiliary configuration values are out-of-date.
-------------------------------------------------------------------------------
function SetupParameters:Parameter_SyncAuxConfigurationValues(parameter)

	if(parameter.DomainConfigurationId) then
		local domain = self:Config_Read(parameter.ConfigurationGroup, parameter.DomainConfigurationId);
		if(domain ~= parameter.Domain) then
			return true;
		end
	end

	if(parameter.ValueDomainConfigurationId) then
		local value_domain = self:Config_Read(parameter.ConfigurationGroup, parameter.ValueDomainConfigurationId);
		
		local parameter_domain = (type(parameter.Value) == "table") and parameter.Value.Domain;
		if(parameter_domain ~= value_domain) then
			return true;
		end
	end

	if(parameter.DomainValuesConfigurationId) then
		local values;
		if(type(parameter.Values) == "table") then
				
			local scratch = {};
			for i,v in ipairs(parameter.Values) do
				if(v.Invalid ~= true) then
					table.insert(scratch, tostring(v.Domain) .. "::" .. tostring(v.Value));
				end
			end

			values = table.concat(scratch, ",");
		end
		local config_values = self:Config_Read(parameter.ConfigurationGroup, parameter.DomainValuesConfigurationId);
		if(values ~= config_values) then
			-- NOTE: This could happen if the other player has different DLC ownership rights that result in the set
			-- being smaller or larger than what we've detected.  This should not cause the parameter
			-- to be placed in an error state.
			return true;
		end
	end

	if(parameter.ValueNameConfigurationId) then
		if(parameter.Value.RawName == nil) then
			foo = 5;
		end
		local bundle = (parameter.Value ~= nil) and Locale.Bundle(parameter.Value.RawName);
		local config_bundle = self:Config_Read(parameter.ConfigurationGroup, parameter.ValueNameConfigurationId);
		if(bundle ~= config_bundle) then
			-- NOTE: This could happen if the other player has additional translations that others do not have.
			-- In this situation, if we must update the parameter but cannot, this should not cause the parameter
			-- to be placed in an error state.			
			return true;
		end
	end
end
  
-------------------------------------------------------------------------------
-- Fetches the configuration value for a parameter and attempts to assign it.
-- returns true if the value was constrained in some way and needs to be
-- rewritten.
-- This disregards the present value of the parameter.  
-------------------------------------------------------------------------------
function SetupParameters:Parameter_SyncConfigurationValues(parameter)

	local config_value = self:Config_ReadParameterValues(parameter);

	-- TODO:
	-- Presuming that whether or not we can write to the config is
	-- exposed as it's own method (e.g Config_CanWriteParameter())
	-- When a parameter value is out of sync and cannot be reconciled
	-- if we are unable to write to the config, place the parameter in an error state.
	
	-- Wipe error state.
	parameter.Error = nil;

	if(parameter.Values and parameter.Values.Type == "IntRange") then
		local minValue = parameter.Values.MinimumValue;
		local maxValue = parameter.Values.MaximumValue;

		if(config_value) then
			-- Does the current Value match config_value?
			if(parameter.Value == config_value) then
				-- Only worry about auxiliary values if we can actually write them.
				if(self:Config_CanWriteParameter(parameter)) then
					return self:Parameter_SyncAuxConfigurationValues(parameter); 
				else
					return false;
				end
			else
				-- Is the value between our minimum and maximum value?
				if(config_value >= minValue and config_value <= maxValue) then
					parameter.Value = config_value;

					-- Only worry about auxiliary values if we can actually write them.
					if(self:Config_CanWriteParameter(parameter)) then
						return self:Parameter_SyncAuxConfigurationValues(parameter); 
					else
						return false;
					end
				end
			end
		end

		if(self:Config_CanWriteParameter(parameter)) then
			-- Try default value.
			local default_value = parameter.DefaultValue;
			if(default_value) then
				if(default_value >= minValue and default_value <= maxValue) then
					parameter.Value = default_value;
					return true;
				end
			end

			parameter.Value = minValue;
			return true;
		else
			-- We're in an error state :(
			parameter.Error = {Id = "MissingDomainValue"};
			return false;
		end
	elseif(parameter.Values) then
		if(config_value) then
			-- Does the current Value match config_value?
			if(parameter.Value and parameter.Value.Value == config_value) then
				return self:Parameter_SyncAuxConfigurationValues(parameter);
			else
				-- Does config_value exist in Values?
				for i, v in ipairs(parameter.Values) do
					if(v.Value == config_value) then
						parameter.Value = v;

						if(v.Invalid) then
							parameter.Error = {
								Id = "InvalidDomainValue",
								Reason = v.InvalidReason
							}
						end

						return self:Parameter_SyncAuxConfigurationValues(parameter); 
					end
				end
			end
		end

		if(self:Config_CanWriteParameter(parameter)) then
			-- Try default value.
			local default_value = parameter.DefaultValue;
			for i, v in ipairs(parameter.Values) do
				if(v.Value == default_value) then
					parameter.Value = v;
					return true;
				end
			end

			-- blech! get the first value.
			parameter.Value = parameter.Values[1];
			return true;
		else
			-- We're in an error state :(
			parameter.Error = {Id = "MissingDomainValue"};
			return false;
		end
	else
		-- Start with either the configuration value or the default value.
		local old_value = config_value;
		if(old_value == nil) then
			old_value = parameter.DefaultValue;
		end
	
		-- Use the domain to cast the value to the correct type.
		local domain = parameter.Domain;
		if(domain == "bool") then	
			parameter.Value = self.Utility_ToBool(old_value);	
		elseif(domain == "int" or domain == "uint") then
			parameter.Value = tonumber(old_value);
		else
			parameter.Value = old_value;
		end

		if(parameter.Value == config_value) then
			
			-- Only worry about auxiliary values if we can actually write them.
			if(self:Config_CanWriteParameter(parameter)) then
				return self:Parameter_SyncAuxConfigurationValues(parameter); 
			else
				return false;
			end
		else
			return true;
		end
	end
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Called after all UI update actions have been performed.
-------------------------------------------------------------------------------
function SetupParameters:UI_AfterRefresh()
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Called after a UI group is updated.
-------------------------------------------------------------------------------
function SetupParameters:UI_AfterRefreshGroup(gid)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Called before the UI has been refreshed.
-------------------------------------------------------------------------------
function SetupParameters:UI_BeforeRefresh()
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Called before a UI group is updated.
-- Note: Parameters from this group may have been destroyed prior to this 
-- getting called.
-------------------------------------------------------------------------------
function SetupParameters:UI_BeforeRefreshGroup(gid)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Calls a hook which notifies UI of the new parameter.
-- NOTE: Only the static things need to be initialized.  Other fields will
-- be updated later.
-------------------------------------------------------------------------------
function SetupParameters:UI_CreateParameter(parameter)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Calls a hook which notifies UI that a parameter no longer exists.
-------------------------------------------------------------------------------
function SetupParameters:UI_DestroyParameter(parameter)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Calls a hook which updates the value of the parameter.
-------------------------------------------------------------------------------
function SetupParameters:UI_SetParameterValue(parameter)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Calls a hook which updates whether the parameter is enabled.
-------------------------------------------------------------------------------
function SetupParameters:UI_SetParameterEnabled(parameter)
end

-------------------------------------------------------------------------------
-- Calls a hook which updates whether the parameter is visible.
-------------------------------------------------------------------------------
function SetupParameters:UI_SetParameterVisible(parameter)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Calls a hook which all possible values of a parameter.
-- This is only executed if the parameter is a multi-value parameter.
-------------------------------------------------------------------------------
function SetupParameters:UI_SetParameterPossibleValues(parameter)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- A sort function between two parameters.
-------------------------------------------------------------------------------
function SetupParameters.Utility_SortFunction(a, b)
	if(a.SortIndex ~= b.SortIndex) then
		return (a.SortIndex or 0) < (b.SortIndex or 0);
	else
		return Locale.Compare(a.Name, b.Name) == -1;
	end
end

-------------------------------------------------------------------------------
-- Sorts a table in-place first using SortIndex then using Name.
-------------------------------------------------------------------------------
function SetupParameters.Utility_SortValues(t)
	table.sort(t, SetupParameters.Utility_SortFunction);
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Utility to interpret booleans differently than standard Lua.
-- Nonzero numbers are true, 0 is false.
-- "true" strings are true, any other string is false.
-------------------------------------------------------------------------------
function SetupParameters.Utility_ToBool(v)
	local t = type(v);
	if(t == "boolean") then
		return v;
	elseif(t == "number") then
		return v ~= 0;
	elseif(t == "string") then
		local n = tonumber(v);
		if(n ~= nil) then
			return n ~= 0;
		else
			return v == "true";
		end
	end

	return false;
end
-------------------------------------------------------------------------------
