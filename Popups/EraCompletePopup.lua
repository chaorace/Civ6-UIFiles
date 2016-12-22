-- ===========================================================================
--	EraCompletePopup
--	Full screen message to tell player they've entered a new era.
--
--	NOTE:	currently not using m_eventID since when starting a game at a later
--			era, this will fire twice for the local player, once the era before
--			and then once again after... and when this is on it will queue
--			them back-to-back
-- ===========================================================================

-- ===========================================================================
--	VARIABLES
-- ===========================================================================
local m_eventID		:number = 0;

-- ===========================================================================
--	Game Engine EVENT
-- ===========================================================================
function OnEraComplete( playerIndex:number, eraType:number )	
	-- Only activate if it's for this player and not multiplayer.	
	local localPlayer :number = Game.GetLocalPlayer();
	if	localPlayer ~= playerIndex or 
		localPlayer == PlayerTypes.NONE or 
		GameConfiguration.IsNetworkMultiplayer() or 
		eraType == 0 or
		Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn() then
		return;	
	else
		local eraName :string = GameInfo.Eras[eraType].Name;		
		-- Bring back if blocking; see header note: m_eventID = ReferenceCurrentGameCoreEvent();
		Controls.EraCompletedHeader:SetText( Locale.ToUpper(Locale.Lookup(eraName)) );
		UIManager:QueuePopup( ContextPtr, PopupPriority.High );
		
	end
end

-- ===========================================================================
function OnShow()
    UI.PlaySound("Pause_TechCivic_Speech");
    UI.PlaySound("UI_Era_Change");

	--print("OnShow","-", "-", Controls.EraCompletedHeader:GetText(), Controls.EraCompletedHeader:IsHidden() );	--debug

	Controls.EraPopupAnimation:SetToBeginning();
	Controls.EraPopupAnimation:Play();
	
	Controls.HeaderAlpha:SetToBeginning();
	Controls.HeaderAlpha:Play();

	Controls.HeaderSlide:SetBeginVal(0,50);
	Controls.HeaderSlide:SetEndVal(0,0);
	Controls.HeaderSlide:SetToBeginning();
	Controls.HeaderSlide:Play();	
end

-- ===========================================================================
function OnHeaderAnimationComplete()
	Controls.HeaderSlide:SetBeginVal(0,0);
	Controls.HeaderSlide:SetEndVal(0,-50);
	Controls.HeaderSlide:SetToBeginning();
	Controls.HeaderSlide:SetPauseTime(1);
	Controls.HeaderSlide:Play();
end

-- ===========================================================================
function OnEraPopupAnimationEnd()
	if Controls.EraPopupAnimation:IsReversing() then
		Close();
	else
		Controls.EraPopupAnimation:Reverse();			-- About to bounce back;
	end	
end

-- ===========================================================================
function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal()
	Controls.GradientT:SetSizeX(screenX);
	Controls.GradientB:SetSizeX(screenX);
	Controls.GradientT:ReprocessAnchoring();
	Controls.GradientB:ReprocessAnchoring();
	Controls.EraCompletedHeader:ReprocessAnchoring();
end

-- ===========================================================================
function Close()
	-- Bring back if blocking; see header note:  ReleaseGameCoreEvent( m_eventID );
	m_eventID = 0;
	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================
function OnClose()
	Close();
end

-- ===========================================================================
--	Input
--	UI Event Handler
-- ===========================================================================
function KeyHandler( key:number )
    if key == Keys.VK_ESCAPE then
		Close();
		return true;
    end
    return false;
end
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if (uiMsg == KeyEvents.KeyUp) then return KeyHandler( pInputStruct:GetKey() ); end;
	return false;
end 

-- ===========================================================================
--	Resize Handler
-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

-- ===========================================================================
function Initialize()	
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShowHandler( OnShow );

	Controls.EraPopupAnimation:RegisterStartCallback( function() print("START EraPopupAnimation"); end ); --??TRON debug
	Controls.EraPopupAnimation:RegisterEndCallback( OnEraPopupAnimationEnd );
	Controls.HeaderSlide:RegisterEndCallback( OnHeaderAnimationComplete );

	Events.PlayerEraChanged.Add( OnEraComplete );	
	Events.SystemUpdateUI.Add( OnUpdateUI );
end
Initialize();