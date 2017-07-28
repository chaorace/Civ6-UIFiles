----------------------------------------------------------------------------
-- Ingame Turn Order Panel
----------------------------------------------------------------------------



----------------------------------------------------------------------------
-- Globals
local NO_PLAYER = -1;


----------------------------------------------------------------------------
-- Internal Functions
function StartPanelClose()
	Controls.AlphaOut:Play();
	Controls.SlideOut:Play();
end

-- Play panel opening animations if it is not already open or opening.
function StartPanelOpen()
	if((Controls.SlideIn:IsStopped() and Controls.SlideIn:GetProgress() < 1)	-- SlideIn not fully deployed and not running
		or not Controls.SlideOut:IsStopped()									-- SlideOut is playing
		or Controls.SlideOut:GetProgress() > 0) then							-- SlideOut is partially deployed.
		Controls.AlphaIn:SetToBeginning(); 
		Controls.SlideIn:SetToBeginning();
		Controls.AlphaOut:SetToBeginning();
		Controls.SlideOut:SetToBeginning();
		Controls.AlphaIn:Play(); 
		Controls.SlideIn:Play();
	end
end

function CheckPausedState()
	if(not GameConfiguration.IsPaused()) then
		StartPanelClose();
		return;
	else
		local pausePlayerID : number = GameConfiguration.GetPausePlayer();
		if(pausePlayerID == NO_PLAYER) then
			StartPanelClose();
			return;
		end
				
		Controls.Root:SetHide(false);

		-- Get pause player
		local pausePlayer = PlayerConfigurations[pausePlayerID];
		local pausePlayerName : string = pausePlayer:GetPlayerName();
		Controls.WaitingLabel:LocalizeAndSetText("LOC_GAME_PAUSED_BY", pausePlayerName);

		StartPanelOpen();
	end
end


----------------------------------------------------------------------------
-- Event Handlers
function OnGameConfigChanged()
	CheckPausedState();
end

----------------------------------------------------------------------------
-- Initialization
function Initialize()
	if(not GameConfiguration.IsHotseat()) then
		CheckPausedState();
		Events.GameConfigChanged.Add(CheckPausedState);
		Events.PlayerInfoChanged.Add(CheckPausedState);
		Events.LoadScreenClose.Add(CheckPausedState);
	end
end
Initialize();
