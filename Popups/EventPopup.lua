include( "InstanceManager" );

--	******************************************************************************************************
--	CONSTANTS
--	******************************************************************************************************
local IMAGE_SECTION_HEIGHT:number = 535;
local MIN_DESCRIPTION_HEIGHT:number = 60;

--	******************************************************************************************************
--	MEMBERS
--	******************************************************************************************************
function OnOpen(popupData:table)

	-- Does our data specify a target player?  If so, check to see if it is for us.
	if (popupData.ForPlayer ~= nil and popupData.ForPlayer ~= Game.GetLocalPlayer()) then
		return;
	end

	local eventData = GameInfo.EventPopupData[popupData.EventKey];
	if not eventData then
		UI.DataError("Missing event popup data for event:" .. popupData.EventKey);
		return;
	end
	if not popupData.EventEffect and not eventData.Effects then
		UI.DataError("Missing effects text for event:" .. popupData.EventKey);
		return;
	end

	Controls.Title:SetText(Locale.ToUpper(Locale.Lookup(eventData.Title)));

	if eventData.Description and eventData.Description ~= "" then
		Controls.Description:SetHide(false);
		Controls.Description:SetText(Locale.Lookup(eventData.Description));
	else
		Controls.Description:SetHide(true);
	end

	Controls.Effects:SetText(popupData.EventEffect or Locale.Lookup(eventData.Effects));

	if eventData.ImageText then
		Controls.ImageText:SetText(Locale.Lookup(eventData.ImageText));
		Controls.ImageText:SetHide(false);
	else
		Controls.ImageText:SetHide(true);
	end

	if eventData.BackgroundImage then
		Controls.BackgroundImage:SetTexture(eventData.BackgroundImage);
		Controls.BackgroundImage:SetHide(false);
	else
		Controls.BackgroundImage:SetHide(true);
	end

	if eventData.ForegroundImage then
		Controls.ForegroundImage:SetTexture(eventData.ForegroundImage);
		Controls.ForegroundImage:SetHide(false);
	else
		Controls.ForegroundImage:SetHide(true);
	end

	UIManager:QueuePopup(ContextPtr, PopupPriority.Current);
	Resize();
end

function OnClose()
	UIManager:DequeuePopup(ContextPtr);
end

-- ===========================================================================
--	Handle screen resize/ dynamic popup height
function Resize()
	Controls.DescriptionContainer:SetSizeY(math.max(MIN_DESCRIPTION_HEIGHT, Controls.Description:GetSizeY() + 20));
	Controls.ImageContainer:SetOffsetY(Controls.DescriptionContainer:GetOffsetY() + Controls.DescriptionContainer:GetSizeY());
	Controls.ImageContainer:SetSizeY(IMAGE_SECTION_HEIGHT - Controls.DescriptionContainer:GetSizeY());

	Controls.EffectsScrollPanel:CalculateSize();
	if Controls.EffectsScrollPanel:GetScrollBar():IsVisible() then
		Controls.Effects:SetAnchor("C,T");
	else
		Controls.Effects:SetAnchor("C,C");
	end
	Controls.EffectsScrollPanel:ReprocessAnchoring();
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
		OnClose();
		return true;
	end

	return false;
end
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then return KeyHandler( pInputStruct:GetKey() ); end;
	return false;
end

function Initialize()
	ContextPtr:SetInputHandler(OnInputHandler, true);

	Controls.Continue:RegisterCallback(Mouse.eLClick, OnClose);

	-- Handle open events
	Events.EventPopupRequest.Add( OnOpen );

	Events.SystemUpdateUI.Add(OnUpdateUI);
end
Initialize();