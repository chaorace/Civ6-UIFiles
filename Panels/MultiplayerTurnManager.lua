----------------------------------------------------------------------------
-- Ingame Turn Banner
----------------------------------------------------------------------------
local BANNER_INITIAL_OFFSET_X:number = -460;
local m_WaitingOnYou:boolean = false;

-------------------------------------------------------------------------------

function AnimateIn(automaticallyAnimateOut:boolean)
	if automaticallyAnimateOut then
		Controls.YourTurnBannerIn:RegisterEndCallback(function()
			Controls.YourTurnBannerOutTimer:RegisterEndCallback(AnimateOut);
			Controls.YourTurnBannerOutTimer:SetToBeginning();
			Controls.YourTurnBannerOutTimer:Play();
		end);
	else
		Controls.YourTurnBannerIn:RegisterEndCallback(function() end);
	end
	Controls.YourTurnBannerIn:SetToBeginning();
	Controls.YourTurnBannerIn:Play();
end

function AnimateOut()
	Controls.YourTurnBannerIn:RegisterEndCallback(function() end);
	Controls.YourTurnBannerIn:SetToEnd();
	Controls.YourTurnBannerIn:Reverse();
end

function OnLocalPlayerTurnBegin()
	
	Controls.YourTurnLabel:LocalizeAndSetText("LOC_YOUR_TURN_BANNER");
	Controls.YourTurnBanner:SetOffsetX(BANNER_INITIAL_OFFSET_X + Controls.YourTurnLabel:GetSizeX());

	-- Play phase begin sound ding.
	local phaseBeginSound:string = Game.GetPhaseSound();
	if(phaseBeginSound ~= nil) then
		UI.PlaySound(phaseBeginSound);
	end

	AnimateIn(true);
end

function OnLocalPlayerTurnEnd()
	if m_WaitingOnYou then
		m_WaitingOnYou = false;
		AnimateOut();
	end
end

-- Display message if we're the remaining turn active player.
function CheckWaitingForYou()
	 
	local localPlayer = Players[Game.GetLocalPlayer()];
	if (GameConfiguration.IsNetworkMultiplayer() 
		and localPlayer ~= nil 
		and localPlayer:IsTurnActive() 
		and Game.GetActivePlayerCount() == 1) then

		m_WaitingOnYou = true;

		Controls.YourTurnLabel:LocalizeAndSetText("LOC_WAITING_ON_YOU_BANNER");
		Controls.YourTurnBanner:SetOffsetX(BANNER_INITIAL_OFFSET_X + Controls.YourTurnLabel:GetSizeX());

		UI.PlaySound("Play_MP_Game_Waiting_For_Player");

		AnimateIn(false);
	end
end

function Initialize()
	Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
	Events.LocalPlayerTurnEnd.Add(OnLocalPlayerTurnEnd);
	Events.RemotePlayerTurnEnd.Add(CheckWaitingForYou);
	
end
Initialize();