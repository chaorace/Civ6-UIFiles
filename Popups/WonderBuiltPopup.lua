-- WonderBuiltPopup
-- Triggered from game event Event.WonderCompleted

--	***************************************************************************
--	MEMBERS
--	***************************************************************************
local ms_eventID = 0;

function OnWonderComplete(locX, locY, buildingIndex, playerIndex, iPercentComplete)

	local localPlayer = Game.GetLocalPlayer();
	if (localPlayer == PlayerTypes.NONE) then
		return;	-- Nobody there to click on it, just exit.
	end

	-- No wonder popup if it is not YOU
	if (localPlayer ~= playerIndex ) then
		return;	
	end

	-- No wonder popups in multiplayer games.
	if(GameConfiguration.IsAnyMultiplayer()) then
		return;
	end

	if (GameInfo.Buildings[buildingIndex].RequiresPlacement and iPercentComplete == 100) then
		local currentBuildingType = GameInfo.Buildings[buildingIndex].BuildingType;
		if currentBuildingType ~= nil then
			Controls.WonderName:SetText(Locale.ToUpper(Locale.Lookup(GameInfo.Buildings[buildingIndex].Name)));
			Controls.WonderIcon:SetIcon("ICON_"..currentBuildingType);
			Controls.WonderIcon:SetToolTipString(Locale.Lookup(GameInfo.Buildings[buildingIndex].Description));
			if(Locale.Lookup(GameInfo.Buildings[buildingIndex].Quote) ~= nil) then
				Controls.WonderQuote:SetText(Locale.Lookup(GameInfo.Buildings[buildingIndex].Quote));
			else
				UI.DataError("The field 'Quote' has not been initialized for "..GameInfo.Buildings[buildingIndex].BuildingType);
			end

			AutoSizeControls();

			if(GameInfo.Buildings[buildingIndex].QuoteAudio ~= nil) then
				UI.PlaySound(GameInfo.Buildings[buildingIndex].QuoteAudio);
			end

			if UI.IsInMarketingMode() then
				ContextPtr:SetHide( true );
				Controls.ForceAutoCloseMarketingMode:SetToBeginning();
				Controls.ForceAutoCloseMarketingMode:Play();
				Controls.ForceAutoCloseMarketingMode:RegisterEndCallback( OnClose );
			else
				ContextPtr:SetHide( false );
			end	

			ms_eventID = ReferenceCurrentGameCoreEvent();
			UIManager:QueuePopup( ContextPtr, PopupPriority.Current);
		end
	end
end

function AutoSizeControls()
	Controls.WonderQuote:ReprocessAnchoring();
	Controls.WonderQuoteContainer:ReprocessAnchoring();
	Controls.WonderName:ReprocessAnchoring();
	Controls.WonderNameContainer:ReprocessAnchoring();
	Controls.RibbonBox:ReprocessAnchoring();
	Controls.RibbonDropShadow:ReprocessAnchoring();
	Controls.QuoteContainer:ReprocessAnchoring();
end

function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal()

	Controls.GradientL:SetSizeY(screenY);
	Controls.GradientR:SetSizeY(screenY);
	Controls.GradientT:SetSizeX(screenX);
	Controls.GradientB:SetSizeX(screenX);
	Controls.GradientB2:SetSizeX(screenX);
	Controls.HeaderDropshadow:SetSizeX(screenX);
	Controls.HeaderGrid:SetSizeX(screenX);

	Controls.VignetteRB:ReprocessAnchoring();
	Controls.VignetteRT:ReprocessAnchoring(); 
	Controls.VignetteLT:ReprocessAnchoring();
	Controls.VignetteLB:ReprocessAnchoring();
	Controls.GradientL:ReprocessAnchoring();
	Controls.GradientR:ReprocessAnchoring();
	Controls.GradientT:ReprocessAnchoring();
	Controls.GradientB:ReprocessAnchoring();
	Controls.GradientB2:ReprocessAnchoring();
	Controls.WonderCompletedHeader:ReprocessAnchoring();
	Controls.Close:ReprocessAnchoring();

	AutoSizeControls();
end

function Close()
	-- Release our hold on the event
	ReleaseGameCoreEvent( ms_eventID );
	ms_eventID = 0;
	UIManager:DequeuePopup( ContextPtr );
    UI.PlaySound("Stop_Wonder_Tracks");
end

function OnClose()
	Close();
end

function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
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

function Initialize()	
	if(not GameConfiguration.IsAnyMultiplayer()) then
		ContextPtr:SetInputHandler( OnInputHandler, true );
		Controls.Close:RegisterCallback(Mouse.eLClick, OnClose);
		Events.WonderCompleted.Add( OnWonderComplete );	
		Events.SystemUpdateUI.Add( OnUpdateUI );
	end
end
Initialize();

