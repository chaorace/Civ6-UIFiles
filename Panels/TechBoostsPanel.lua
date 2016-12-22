include( "InstanceManager" );	--InstanceManager

local g_InstanceManager = InstanceManager:new( "BoostStackInstance", "InstanceLabel", Controls.BoostStack );

-- This is horrible, Shaun is sorry.
local TechTypeMap = {};
do
	local i = 0;
	for row in GameInfo.Technologies() do
		TechTypeMap[row.TechnologyType] = i;
		i = i + 1;
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function View(data)
	PopulateAvailableBoosts(data.AvailableTechBoosts);
	
	if(#data.AvailableTechBoosts > 0) then
		Controls.BoostStack:CalculateSize();
		local width, height = Controls.BoostStack:GetSizeVal();
		Controls.TechBoostsWindow:SetSizeVal(width + 60, height + 60);
		Controls.TechBoostsPanel:SetHide(false);
	else
		Controls.TechBoostsPanel:SetHide(true);
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function PopulateAvailableBoosts(boosts)

	g_InstanceManager:ResetInstances();
	
	for i, r in ipairs(boosts) do
		local newListing = g_InstanceManager:GetInstance();
		
		local str = Locale.Lookup("{1_Name} +{2_Boost}%", r.TechName, r.Boost);		
		newListing.InstanceLabel:SetText(str);
		
		newListing.InstanceLabel:LocalizeAndSetToolTip(r.TriggerDescription);
		
	end

end
-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function Refresh()

	local localPlayer = Players[Game.GetLocalPlayer()];
	if (localPlayer == nil) then
		return;
	end
	local playerTechs = localPlayer:GetTechs();	
	
	-- Gather list of Tech Boosts
	local techBoosts = {};
	
	for row in GameInfo.Boosts() do

		if (row.TechnologyType ~= nil) then
			local iTech = TechTypeMap[row.TechnologyType];
			local techName;
			local techCost;
		
			--get the base cost of the tech
			local tech = GameInfo.Technologies[row.TechnologyType];

			local techName = tech.Name;
			local techCost = tech.Cost;
		
			techBoosts[iTech] = {
				TechName = techName,
				Boost = math.floor((row.Boost / techCost) * 100),
				TriggerDescription = row.TriggerDescription,
			};
		end
	end
	
	-- Build View Model
	local data = {
		AvailableTechBoosts = {};
	}

	-- Remove boosts for techs we already have
	for techType, techIndex in pairs(TechTypeMap) do
		if(playerTechs:HasTech(techIndex) or playerTechs:HasBoostBeenTriggered(techIndex) or not playerTechs:CanTriggerBoost(techIndex)) then
			techBoosts[techIndex] = nil;
		end
	end
	
	-- Add available boosts to view model.
	for i,v in pairs(techBoosts) do
		table.insert(data.AvailableTechBoosts, {TechName = v.TechName, Boost = v.Boost, TriggerDescription = v.TriggerDescription})
	end

	View(data);
end
-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function SetVisible( visible )
	Controls.TechBoostsPanel:SetHide( visible );
end

-------------------------------------------------------------------------------
function OnTechBoostTriggered( player )

	if (player == Game.GetLocalPlayer()) then
        UI.PlaySound("Receive_Tech_Boost");
		Refresh();
	end

end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
Refresh();
Events.LocalPlayerTurnBegin.Add(Refresh);
Events.TechBoostTriggered.Add(OnTechBoostTriggered);
LuaEvents.RefreshTechBoostList.Add(Refresh);