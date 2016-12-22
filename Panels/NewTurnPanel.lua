----------------------------------------------------------------------------
-- Ingame Turn Order Panel
----------------------------------------------------------------------------



----------------------------------------------------------------------------
-- Globals



----------------------------------------------------------------------------
-- Internal Functions
function UpdatePhaseName()
	local phaseName = Game.GetPhaseName();
	if(phaseName == nil) then
		phaseName = "";
	end
	Controls.NewTurnPhase:LocalizeAndSetText(phaseName);
end

function UpdateTurnName()
	local strTurn	:string = tostring( Game.GetCurrentGameTurn() );
	local strDate :string = Calendar.MakeYearStr(Game.GetCurrentGameTurn());
	local strNewTurn = strDate .. " : " .. strTurn;

	Controls.NewTurnLabel:SetText(strNewTurn);
end

----------------------------------------------------------------------------
-- Event Handlers
function ShowNewTurnPanel()
	-- Only display the panel when 
	local phaseName = Game.GetPhaseName();
	if(phaseName ~= nil) then
		Controls.Root:SetHide(false);

		-- Update Text
		UpdatePhaseName();
		UpdateTurnName();

		-- Restart all the animations
		Controls.AlphaIn:SetToBeginning(); 
		Controls.SlideIn:SetToBeginning();
		Controls.AlphaOut:SetToBeginning();
		Controls.SlideOut:SetToBeginning();
		Controls.AlphaIn:Play(); 
		Controls.SlideIn:Play();
		Controls.AlphaOut:Play();
		Controls.SlideOut:Play();
	else
		Controls.Root:SetHide(true);
	end
end



----------------------------------------------------------------------------
-- Initialization
function Initialize()
	Events.LocalPlayerTurnBegin.Add(ShowNewTurnPanel);
	Events.PhaseBegin.Add(ShowNewTurnPanel); 
end
Initialize();
