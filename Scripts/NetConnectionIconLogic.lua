-------------------------------------------------
-- Network Connection Logic
-- 
-- Common scripting logic used for updating player network connection status.
-- IE, network connection icons, labels, etc.
-------------------------------------------------
-- Connection Icon Strings
local PlayerConnectedStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED" );
local PlayerConnectingStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTING" );
local PlayerNotConnectedStr = Locale.Lookup( "LOC_MP_PLAYER_NOTCONNECTED" );
local PlayerNotModReadyStr = Locale.Lookup( "LOC_MP_PLAYER_NOT_MOD_READY" );

-- Connection Label Strings.
local PlayerConnectedSummaryStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED_SUMMARY" );
local PlayerConnectingSummaryStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTING_SUMMARY" );
local PlayerNotConnectedSummaryStr = Locale.Lookup( "LOC_MP_PLAYER_NOTCONNECTED_SUMMARY" );

-- Ping Time Strings
local secondsStr = Locale.Lookup( "LOC_TIME_SECONDS" );
local millisecondsStr = Locale.Lookup( "LOC_TIME_MILLISECONDS" );

----------------------------------------------------------------
-- UpdateNetConnectionIcon
-- Remember to call UpdateNetConnectionIcon when...
-- * Creating a new icon.
-- * For all icons on a MultiplayerPingTimesChanged event.
----------------------------------------------------------------
function UpdateNetConnectionIcon(playerID :number, connectIcon)
	-- Update network connection status
	local pPlayerConfig = PlayerConfigurations[playerID];
	local slotStatus = pPlayerConfig:GetSlotStatus();
	if(slotStatus == SlotStatus.SS_TAKEN or slotStatus == SlotStatus.SS_OBSERVER) then
		-- build ping string
		local iPingTime = Network.GetPingTime( playerID );
		local pingStr = "";
		if(playerID ~= Network.GetLocalPlayerID()) then
			if (iPingTime < 1000) then
				pingStr = " " .. tostring(iPingTime) .. millisecondsStr;
			else
				pingStr = " " .. tostring(iPingTime/1000) .. secondsStr;
			end
		end

		connectIcon:SetHide(false);
		if(Network.IsPlayerHotJoining(playerID)) then
			-- Player is hot joining.
			--connectIcon:SetTextureOffsetVal(0,32);
			connectIcon:SetToolTipString( PlayerConnectingStr ..  pingStr);
		elseif(Network.IsPlayerConnected(playerID)) then
			if(not pPlayerConfig:GetModReady()) then
				-- Player is not mod ready yet
				--connectIcon:SetTextureOffsetVal(0,96);
				connectIcon:SetToolTipString( PlayerNotModReadyStr .. pingStr );
			else
				-- fully connected
				-- icon changes based on ping time
				--[[
				if(iPingTime < 100) then -- green
					connectIcon:SetTextureOffsetVal(0,64);
				elseif(iPingTime < 200) then -- yellow
					connectIcon:SetTextureOffsetVal(0,96);
				else -- red
					connectIcon:SetTextureOffsetVal(0,128);
				end
				--]]
				
				connectIcon:SetToolTipString( PlayerConnectedStr .. pingStr );
			end
		else
			-- Not connected
			--connectIcon:SetTextureOffsetVal(0,0);
			connectIcon:SetToolTipString( PlayerNotConnectedStr );		
		end		
  else
		connectIcon:SetHide(true);
  end
end

----------------------------------------------------------------
-- UpdateNetConnectionLabel
-- Remember to call UpdateNetConnectionLabel when...
-- * Creating a network connection label.
----------------------------------------------------------------
function UpdateNetConnectionLabel(playerID :number, connectLabel :table)
	-- Update network connection status
	local pPlayerConfig = PlayerConfigurations[playerID];
	local slotStatus = pPlayerConfig:GetSlotStatus();
	if(slotStatus == SlotStatus.SS_TAKEN or slotStatus == SlotStatus.SS_OBSERVER) then
		local statusString :string;
		local tooltipString :string;
		if(Network.IsPlayerHotJoining(playerID)) then
			-- Player is hot joining.
			statusString = PlayerConnectingSummaryStr;
			tooltipString = PlayerConnectingStr;
		elseif(Network.IsPlayerConnected(playerID)) then
			-- Player is fully connected.
			statusString = PlayerConnectedSummaryStr;
			tooltipString = PlayerConnectedStr;
		else
			-- Not connected
			statusString = PlayerNotConnectedSummaryStr;
			tooltipString = PlayerNotConnectedStr;
		end	
		
		connectLabel:SetText(statusString);
		connectLabel:SetToolTipString(tooltipString);
	end
end