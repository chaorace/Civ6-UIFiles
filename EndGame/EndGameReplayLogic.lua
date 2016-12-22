-- Requires InstanceManager

-------------------------------------------------------------------
-- Color Utilities
-------------------------------------------------------------------
local function ColorIsWhite(color)
	return color.Red == 1 and color.Blue == 1 and color.Green == 1;
end

local function ColorIsBlack(color)
	return color.Red == 0 and color.Blue == 0 and color.Green == 0;
end

local function GetBrightness(c)
	local r = c.Red;
	if(r <= 0.03928) then
		r = r / 12.92;
	else
		r = ((r + 0.055) / 1.055)^2.4;
	end
	
	r = r * 0.2126;
	
	local g = c.Green
	if(g <= 0.03928) then
		g = g / 12.92;
	else
		g = ((g + 0.055) / 1.055)^2.4;
	end
	
	g = g * 0.7152;
	
	local b = c.Blue;
	if(b <= 0.03928) then
		b = b / 12.92;
	else
		b = ((b + 0.055) / 1.055)^2.4;
	end
	
	b = b * 0.0722;
	
	return r + g + b;

end

local function HSLFromColor(r,g,b)
		
	local h,s,l;
	
	local minV = math.min(r,g,b);
	local maxV = math.max(r,g,b);

	l = (maxV + minV) / 2;

	if(minV == maxV) then
		h = 0;
		s = 0;
	else
		if(l < 0.5) then
			s = (maxV - minV) / (maxV + minV);
		else
			s = (maxV - minV) / (2 - maxV - minV); 
		end
		
		if(r == maxV) then
			h = (g - b)/(maxV - minV);
		elseif(g == maxV) then
			h = 2 + (b - r)/(maxV - minV);
		elseif(b == maxV) then
			h = 4 + (r - g)/(maxV - minV);
		end
	end
	
	return h,s,l;
end

local function ColorFromHSL(hue, sat, lum)
	local function Clamp(value, minValue, maxValue)
		if (value < minValue) then return minValue;
		elseif(value > maxValue) then return maxValue;
		else return value;
		end
	end

	hue = Clamp(hue, 0, 1.0);
	sat = Clamp(sat, 0, 1.0);
	lum = Clamp(lum, 0, 1.0);

    local r = 0;
    local g = 0
    local b = 0;
  
  
    if (lum == 0) then
        r = 0;
        g = 0;
        b = 0;
        
    elseif (sat == 0) then
        r = lum;
        g = lum;
        b = lum;
        
	else
        local temp1;
        if(lum < 0.5) then 
			temp1 = lum * (1 + sat) 
		else 
			temp1 = lum + sat - lum * sat; 
		end
        
        local temp2 = 2.0 * lum - temp1;

        local t3 = { hue + 1 / 3, hue, hue - 1 / 3 };
        local clr = {0, 0, 0};
        for i, t in ipairs(t3) do
        
            if (t < 0) then
                t = t + 1;
            end
            
            if (t > 1) then
                t = t - 1;
            end

            if (6 * t < 1) then
                clr[i] = temp2 + (temp1 - temp2) * t * 6;
            elseif (2 * t < 1) then
                clr[i] = temp1;
            elseif (3 * t < 2) then
                clr[i] = (temp2 + (temp1 - temp2) * ((2 / 3) - t) * 6);
            else
                clr[i] = temp2;
            end
        end
        
        r = clr[1];
        g = clr[2];
        b = clr[3];
    end
    
    return {Red = r, Green = g, Blue = b, Alpha = 1};
end

---------------------------------------------------------------
-- Globals
----------------------------------------------------------------
g_GraphLegendInstanceManager = InstanceManager:new("GraphLegendInstance", "GraphLegend", Controls.GraphLegendStack);

g_InitialTurn = 0;
g_FinalTurn = 0;
g_GraphData = nil;
g_PlayerInfos = {};
g_PlayerDataSets = {};
g_GraphLegendsByPlayer = {};
g_PlayerGraphColors = {};

g_NumVerticalMarkers = 5;
g_NumHorizontalMarkers = 5;


-- This method will pad the horizontal values if they are too small so that they show up correctly
function ReplayGraphPadHorizontalValues(minTurn, maxTurn)
	local range = maxTurn - minTurn;
	local numHorizontalMarkers = g_NumHorizontalMarkers - 1;
	if(range < numHorizontalMarkers) then
		return (minTurn - (numHorizontalMarkers - range)), maxTurn;
	else
		return minTurn, maxTurn;
	end
end
		
function ReplayGraphDrawGraph()
				
	local graphWidth, graphHeight = Controls.ResultsGraph:GetSizeVal();
	local initialTurn = g_InitialTurn;
	local finalTurn = g_FinalTurn;
	local playerInfos = g_PlayerInfos;
	local graphData = g_GraphData;
		
	local function RefreshVerticalScales(minValue, maxValue)
		local increments = math.floor((maxValue - minValue) / (g_NumVerticalMarkers - 1));
		Controls.ResultsGraph:SetYTickInterval(increments / 4.0);
		Controls.ResultsGraph:SetYNumberInterval(increments);
	end
	
	function DrawGraph(data, pDataSet, minX, maxX)
		turnData = {};
		for i, value in pairs(data) do
			if(value ~= nil and i <= maxX and i >= minX) then
				turnData[i - minX] = value;
			end
		end
		
		pDataSet:Clear();
		for turn = minX, maxX + 1, 1 do
			local y = turnData[turn - minX];
			if (y == nil) then
				pDataSet:BreakLine();
			else
				pDataSet:AddVertex(turn, y);
			end
		end
	end
			
	-- Determine the maximum score for all players
	local maxScore = 0;
	local minScore = nil;

	-- Using pairs here because there may be intentional "holes" in the data.
	if(graphData) then
		for player, turnData in pairs(graphData) do
			-- Ignore barbarian data.
			local playerInfo = Players[player];
			if(playerInfo and not playerInfo:IsBarbarian()) then
				for turn, value in pairs(turnData) do
					if(value > maxScore) then
						maxScore = value;
					end

					if(minScore == nil or value < minScore) then
						minScore = value;
					end
				end
			end
		end
	end

	-- If the data is flat lined, set the range accordingly
	if(minScore == maxScore) then
		minScore = minScore - 10;
		maxScore = maxScore + 10;
	end
	
	Controls.ResultsGraph:DeleteAllDataSets();
	g_PlayerDataSets = {};

	if(minScore ~= nil) then	-- this usually means that there were no values for that dataset.
				
		Controls.NoGraphData:SetHide(true);

		-- Lower minScore by 10% of the range so that we can see the base line.
		minScore = minScore - math.ceil((maxScore - minScore) * 0.1);
				
		--We want a value that is nicely divisible by the number of vertical markers
		local numSegments = g_NumVerticalMarkers - 1;

		local range = maxScore - minScore;

		local newRange = range + numSegments - range % numSegments;		
								
		maxScore = newRange + minScore;
				
		local YScale = graphHeight / (maxScore - minScore);
				
		RefreshVerticalScales(minScore, maxScore);
				
		local minTurn, maxTurn = ReplayGraphPadHorizontalValues(initialTurn, finalTurn);

		Controls.ResultsGraph:SetDomain(minTurn, maxTurn);
		Controls.ResultsGraph:SetRange(minScore, maxScore);
		Controls.ResultsGraph:ShowXNumbers(true);
		Controls.ResultsGraph:ShowYNumbers(true);
			
		for i,v in ipairs(playerInfos) do
			local data = graphData[v.Id];
			if(data) then
				local graphLegend = g_GraphLegendsByPlayer[i];
				local isHidden = not graphLegend.ShowHide:IsChecked();
				local color = g_PlayerGraphColors[i];

				local pDataSet = Controls.ResultsGraph:CreateDataSet(v.Name);
				pDataSet:SetColor(color.Red, color.Green, color.Blue, color.Alpha);
				pDataSet:SetWidth(2.0);
				pDataSet:SetVisible(not isHidden);

				DrawGraph(graphData[v.Id], pDataSet, minTurn, maxTurn);
				g_PlayerDataSets[i] = pDataSet;
			end
		end		
	else
		Controls.ResultsGraph:ShowXNumbers(false);
		Controls.ResultsGraph:ShowYNumbers(false);
		Controls.NoGraphData:SetHide(false);
	end
end
		
function ReplayGraphRefresh() 
		
	local graphWidth, graphHeight = Controls.ResultsGraph:GetSizeVal();
	local initialTurn = g_InitialTurn;
	local finalTurn = g_FinalTurn;
		
	local function RefreshHorizontalScales()
		local minTurn, maxTurn = ReplayGraphPadHorizontalValues(initialTurn, finalTurn);
		local turnIncrements = math.floor((maxTurn - minTurn) / (g_NumHorizontalMarkers - 1));
		Controls.ResultsGraph:SetXTickInterval(turnIncrements / 4.0);
		Controls.ResultsGraph:SetXNumberInterval(turnIncrements);
	end
			
	local function RefreshCivilizations()
			
		local colorDistances = {};
		local pow = math.pow;
		function ColorDistance(color1, color2)
			local distance = nil;
			local colorDistanceTable = colorDistances[color1.Type];
			if(colorDistanceTable == nil) then
				colorDistanceTable = {
					[color1.Type] = 0;	--We can assume the distance of a color to itself is 0.
				};
						
				colorDistances[color1.Type] = colorDistanceTable
			end
					
			local distance = colorDistanceTable[color2.Type];
			if(distance == nil) then
				local r2 = pow((color1.Red - color2.Red)*255, 2);
				local g2 = pow((color1.Green - color2.Green)*255, 2);
				local b2 = pow((color1.Blue - color2.Blue)*255, 2);	
						
				distance = r2 + g2 + b2;
				colorDistanceTable[color2.Type] = distance;
			end
					
			return distance;
		end
				
		local colorNotUnique = {};
		local colorBlack = {Type = "COLOR_BLACK", Red = 0, Green = 0, Blue = 0, Alpha = 1,};
		local function IsUniqueColor(color)
			if(colorNotUnique[color.Type]) then
				return false;
			end
					
			local blackThreshold = 5000;
			local differenceThreshold = 3000;
					
			local distanceAgainstBlack = ColorDistance(color, colorBlack);
			if(distanceAgainstBlack > blackThreshold) then
				for i, v in pairs(g_PlayerGraphColors) do
					local distanceAgainstOtherPlayer = ColorDistance(color, v);
					if(distanceAgainstOtherPlayer < differenceThreshold) then
						colorNotUnique[color.Type] = true;
						return false;
					end
				end
						
				return true;
			end
					
			colorNotUnique[color.Type] = true;
			return false;
		end
					
		local function DetermineGraphColor(playerColor)
			if(IsUniqueColor(GameInfo.Colors[playerColor.PrimaryColor])) then
				return GameInfo.Colors[playerColor.PrimaryColor];
			elseif(IsUniqueColor(GameInfo.Colors[playerColor.SecondaryColor])) then
				return GameInfo.Colors[playerColor.SecondaryColor];
			else
				for color in GameInfo.Colors() do
					if(IsUniqueColor(color)) then
						return color;
					end
				end
			end
										
			--error("Could not find a unique color");
			return GameInfo.Colors[playerColor.PrimaryColor];
		end

		g_PlayerGraphColors = {};
		g_GraphLegendInstanceManager:ResetInstances();
		for i, player in ipairs(g_PlayerInfos) do
					
			local civ = GameInfo.Civilizations[player.Civilization];
					
			local graphLegendInstance = g_GraphLegendInstanceManager:GetInstance();
					
			--IconHookup( civ.PortraitIndex, 32, civ.IconAtlas, graphLegendInstance.LegendIcon );
			local color = DetermineGraphColor(GameInfo.PlayerColors[player.PlayerColor]);
			g_PlayerGraphColors[i] = color;
		
			graphLegendInstance.LegendIcon:SetColor(color.Red, color.Green, color.Blue);
							
			if(player.Name ~= nil) then
				graphLegendInstance.LegendName:LocalizeAndSetText(player.Name);
			end	
					
			-- Default city states to be unchecked.
			local checked = not player.IsMinor;
				
			graphLegendInstance.ShowHide:SetCheck(checked);
					
			graphLegendInstance.ShowHide:RegisterCheckHandler( function(bCheck)
				local pDataSet = g_PlayerDataSets[i];
				if(pDataSet) then
					pDataSet:SetVisible(bCheck);
				end
			end);
			
			g_GraphLegendsByPlayer[i] = graphLegendInstance;
		end
	end
			
	RefreshCivilizations();
	RefreshHorizontalScales();
			
	Controls.GraphLegendStack:CalculateSize();
	Controls.GraphLegendStack:ReprocessAnchoring();
	Controls.GraphLegendScrollPanel:CalculateInternalSize();

end

function SetCurrentGraphDataSet(dataSetType)
	local initialTurn = g_InitialTurn;
	local finalTurn = g_FinalTurn;
	local dataSetIndex;
	local count = GameSummary.GetDataSetCount();
	for i = 0, count - 1, 1 do
		local name = GameSummary.GetDataSetName(i);
		if(name == dataSetType) then
			dataSetIndex = i;
			dataSetDisplayName = GameSummary.GetDataSetDisplayName(i);
			break;
		end
	end
	
	if(dataSetIndex) then
		local graphDataSetPulldownButton = Controls.GraphDataSetPulldown:GetButton();
		graphDataSetPulldownButton:LocalizeAndSetText(dataSetDisplayName);

		g_GraphData = GameSummary.CoalesceDataSet(dataSetIndex, initialTurn, finalTurn);
		
		--Debug Data, for when you wanna debug.
		--g_GraphData = {
			--[0] = {1,2,3,4,5,6,7,8,9,10},
			--[1] = {10,9,8,7,6,5,4,2,1},
			--[2] = {1,2,3,4,5,6,7,8,9,10},
			--[3] = {1,2,3,4,5,6,7,8,9,10},
			--[4] = {1,2,3,4,5,6,7,8,9,10},
			--[5] = {1,2,3,4,5,6,7,8,9,10},
		--};
		
		ReplayGraphDrawGraph();
	end	
end

----------------------------------------------------------------
-- Static Initialization
----------------------------------------------------------------
local function RefreshGraphDataSets()		
	local graphDataSetPulldown = Controls.GraphDataSetPulldown;
	graphDataSetPulldown:ClearEntries();
	
	local count = GameSummary.GetDataSetCount();
	local dataSets = {};
	for i = 0, count - 1, 1 do
		local visible = GameSummary.GetDataSetVisible(i);
		if(visible) then
			local name = GameSummary.GetDataSetName(i);
			local displayName = GameSummary.GetDataSetDisplayName(i);
			table.insert(dataSets, {i, name, Locale.Lookup(displayName)});
		end

	end
	table.sort(dataSets, function(a,b) return Locale.Compare(a[3], b[3]) == -1; end);
	
	for i,v in ipairs(dataSets) do
		local controlTable = {};
		graphDataSetPulldown:BuildEntry( "InstanceOne", controlTable );
		controlTable.Button:SetText(v[3]);

		controlTable.Button:RegisterCallback(Mouse.eLClick, function()
			SetCurrentGraphDataSet(v[2]);
		end);
	end
	graphDataSetPulldown:CalculateInternals();

	if(#dataSets > 0) then
		SetCurrentGraphDataSet(dataSets[1][2]);
	end
end

function ReplayInitialize()
	g_InitialTurn = GameConfiguration.GetStartTurn();
	g_FinalTurn = Game.GetCurrentGameTurn();
	
	-- Populate Player Info
	g_PlayerInfos = {};	

	for player_num = 0, 63 do -- GameDefines.MAX_CIV_PLAYERS - 1 do
		local player = Players[player_num];
		local playerConfig = PlayerConfigurations[player_num];
		if(player and playerConfig and playerConfig:IsParticipant() and player:WasEverAlive() and not player:IsBarbarian()) then

			local color = GameInfo.PlayerColors[playerConfig:GetColor()];
			if(color == nil) then
				color = GameInfo.PlayerColors[1];
			end

			local playerInfo = {
				Id = player:GetID(),
				PlayerColor = color.Type,
				Name = playerConfig:GetPlayerName(),
				IsMinor = not player:IsMajor(),
			};
					
			table.insert(g_PlayerInfos, playerInfo);
		end	
	end

	ReplayGraphRefresh();
	RefreshGraphDataSets();
end

function ReplayShutdown()
	g_GraphData = nil;
	g_PlayerInfos = {};
	g_PlayerDataSets = {};
	g_GraphLegendsByPlayer = {};
	g_PlayerGraphColors = {};

	g_GraphLegendInstanceManager:ResetInstances();
	Controls.ResultsGraph:DeleteAllDataSets();
end