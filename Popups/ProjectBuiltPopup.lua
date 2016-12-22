-- ProjectBuiltPopup
-- Triggered from game event Event.CityProjectCompleted
-- Very similar in form and function to WonderBuiltPopup

--	***************************************************************************
--	MEMBERS
--	***************************************************************************
local ms_eventID = 0;

function OnProjectComplete(playerID, cityID, projectIndex, buildingIndex, locX, locY, bCanceled)

	local localPlayer = Game.GetLocalPlayer();
	if (localPlayer == PlayerTypes.NONE) then
		return;	-- Nobody there to click on it, just exit.
	end

	-- No project popup if it is not YOU
	if (localPlayer ~= playerID) then
		return;	
	end

	-- No project popups in multiplayer games.
	if(GameConfiguration.IsAnyMultiplayer()) then
		return;
	end

	local projectInfo = GameInfo.Projects[projectIndex];
	if (projectInfo ~= nil and not bCanceled) then
		local projectType = projectInfo.ProjectType;
		local projectPopupText = projectInfo.PopupText;
		if (projectType ~= nil and projectPopupText ~= nil and projectPopupText ~= "") then
			Controls.ProjectName:SetText(Locale.ToUpper(Locale.Lookup(projectInfo.Name)));
			Controls.ProjectIcon:SetIcon("ICON_"..projectType);
			if(Locale.Lookup(projectInfo.Description) ~= nil) then
				Controls.ProjectQuote:SetText(Locale.Lookup(projectInfo.Description));
			else
				UI.DataError("The field 'Description' has not been initialized for "..projectInfo.ProjectType);
			end

			AutoSizeControls();

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
			UI.PlaySound("Mute_Narrator_Advisor_All");
		end
	end
end

function AutoSizeControls()
	Controls.ProjectQuote:ReprocessAnchoring();
	Controls.ProjectQuoteContainer:ReprocessAnchoring();
	Controls.ProjectName:ReprocessAnchoring();
	Controls.ProjectNameContainer:ReprocessAnchoring();
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
	Controls.ProjectCompletedHeader:ReprocessAnchoring();
	Controls.Close:ReprocessAnchoring();

	AutoSizeControls();
end

function Close()
	-- Release our hold on the event
	ReleaseGameCoreEvent( ms_eventID );
	ms_eventID = 0;
	UIManager:DequeuePopup( ContextPtr );
	UI.PlaySound("Stop_Rocket_Launches");
	UI.PlaySound("UnMute_Narrator_Advisor_All");
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
		Events.CityProjectCompleted.Add( OnProjectComplete );	
		Events.SystemUpdateUI.Add( OnUpdateUI );
	end
end
Initialize();