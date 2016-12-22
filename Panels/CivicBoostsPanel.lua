include( "InstanceManager" );	--InstanceManager

local g_CivicInstanceManager = InstanceManager:new( "BoostStackInstance", "InstanceLabel", Controls.CivicBoostStack );

-- This is horrible, Shaun is sorry.
local CivicTypeMap = {};
do
	local i = 0;
	for row in GameInfo.Civics() do
		CivicTypeMap[row.CivicType] = i;
		i = i + 1;
	end
end
-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function View(data)
	PopulateAvailableBoosts(g_CivicInstanceManager, data.AvailableCivicBoosts);
	if(#data.AvailableCivicBoosts > 0) then
		Controls.CivicBoostStack:CalculateSize();
		local width, height = Controls.CivicBoostStack:GetSizeVal();
		Controls.CivicBoostsWindow:SetSizeVal(width + 60, height + 60);
		Controls.CivicBoostsPanel:SetHide(false);
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function PopulateAvailableBoosts(instanceMgr, boosts)

	instanceMgr:ResetInstances();
	
	for i, r in ipairs(boosts) do
		local newListing = instanceMgr:GetInstance();
		
		local str = Locale.Lookup("{1_Name} +{2_Boost}%", r.Name, r.Boost);		
		newListing.InstanceLabel:SetText(str);
		
		newListing.InstanceLabel:LocalizeAndSetToolTip(r.TriggerDescription);
		
	end

end

-- ===========================================================================
function Refresh()

	local localPlayer = Players[Game.GetLocalPlayer()];
	if (localPlayer == nil) then
		return;
	end

	-- Gather list of Tech Boosts
	local civicBoosts = {};
	
	for row in GameInfo.Boosts() do

		local name;
		local cost;

		if (row.CivicType ~= nil) then
			local iCivic = CivicTypeMap[row.CivicType];
		
			--get the base cost of the tech
			local civic = GameInfo.Civics[row.CivicType];

			local name = civic.Name;
			local cost = civic.Cost;
		
			civicBoosts[iCivic] = {
				Name = name,
				Boost = math.floor((row.Boost / cost) * 100),
				TriggerDescription = row.TriggerDescription,
			};

		end
	end
	
	-- Build View Model
	local data = {
		AvailableCivicBoosts = {};
	}

	-- Remove boosts for civics we already have
	local playerCulture = localPlayer:GetCulture();	
	for civicType, civicIndex in pairs(CivicTypeMap) do
		if(playerCulture:HasCivic(civicIndex) or playerCulture:HasBoostBeenTriggered(civicIndex) or not playerCulture:CanTriggerBoost(civicIndex)) then
			civicBoosts[civicIndex] = nil;
		end
	end
	
	-- Add available boosts to view model.
	for i,v in pairs(civicBoosts) do
		table.insert(data.AvailableCivicBoosts, {Name = v.Name, Boost = v.Boost, TriggerDescription = v.TriggerDescription})
	end

	View(data);
end

-- ===========================================================================
function SetVisible( visible )
	Controls.CivicBoostsPanel:SetHide( visible );
end

-- ===========================================================================
function OnCivicBoostTriggered(ePlayer)
	if (ePlayer == Game.GetLocalPlayer()) then
        UI.PlaySound("RECEIVE_CULTURE_BOOST");
		Refresh();
	end
end

-- ===========================================================================
function Initialize()
	Events.CivicBoostTriggered.Add(OnCivicBoostTriggered);
	Events.LocalPlayerTurnBegin.Add(Refresh);	
	LuaEvents.CivicBoostUnlockedPopup_RefreshCivicBoostList.Add(Refresh);
	Refresh();
end
Initialize();

