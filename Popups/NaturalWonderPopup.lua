-- ===========================================================================
--	Popups when a Natural Wonder has been discovered
-- ===========================================================================

-- ===========================================================================
--	CONSTANTS / MEMBERS
-- ===========================================================================
local m_isWaitingToShowPopup:boolean = false;
local m_kQueuedPopups		:table	 = {};
local m_eCurrentFeature		:number  = -1;


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
--	Closes the immediate popup, will raise more if queued.
-- ===========================================================================
function Close()
	
	-- Dequeue popup from UI mananger (will re-queue if another is about to show).
	ShowNaturalWonderLens(false);
	UIManager:DequeuePopup( ContextPtr );
	UI.PlaySound("Stop_Speech_NaturalWonders");
	local isNewOneSet = false;

	-- Find first entry in table, display that, then remove it from the internal queue
	for i, entry in ipairs(m_kQueuedPopups) do
		ShowPopup(entry);
		table.remove(m_kQueuedPopups, i);
		isNewOneSet = true;
		break;
	end

	if not isNewOneSet then
		m_isWaitingToShowPopup = false;	
		m_eCurrentFeature = -1;
		LuaEvents.NaturalWonderPopup_Closed();	-- Signal other systems (e.g., bulk show UI)
	end
		
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnClose()
	Close();
end


function ShowNaturalWonderLens(isShowing: boolean)
	if isShowing then
		if(UI.GetInterfaceMode() ~= InterfaceModeTypes.NATURAL_WONDER) then
			UI.SetInterfaceMode(InterfaceModeTypes.NATURAL_WONDER);	-- Enter mode
		end
	else		
		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);		
	end
end

-- ===========================================================================
function ShowPopup( kData:table )
	UIManager:QueuePopup( ContextPtr, PopupPriority.Medium );
	ShowNaturalWonderLens(true);
	m_isWaitingToShowPopup = true;
	m_eCurrentFeature = kData.Feature;

	if kData.plotx ~= nil and kData.ploty ~= nil then
		UI.LookAtPlot(kData.plotx, kData.ploty);
	end

	UI.PlaySound(kData.QuoteAudio);
	Controls.WonderName:SetText( kData.Name );
	Controls.WonderQuote:SetHide( kData.Quote == nil );
	Controls.WonderIcon:SetIcon( "ICON_".. kData.TypeName);
	if kData.Quote ~= nil then
		Controls.WonderQuote:SetText( kData.Quote );
	end
	if kData.Description ~= nil then
		Controls.WonderIcon:SetToolTipString( kData.Description );
	end

	Controls.DropShadow:ReprocessAnchoring();
end

-- ===========================================================================
--
-- ===========================================================================
function OnNaturalWonderRevealed( plotx:number, ploty:number, eFeature:number, isFirstToFind:boolean )
	local localPlayer = Game.GetLocalPlayer();	
	if (localPlayer < 0) then
		return;	-- autoplay
	end

	-- Only human players and NO hotseat
	if Players[localPlayer]:IsHuman() and not GameConfiguration.IsHotseat() then
		local info:table = GameInfo.Features[eFeature];
		if info ~= nil then

			local quote :string = nil;
			if info.Quote ~= nil then
				quote = Locale.Lookup(info.Quote);
			end

			local description :string = nil;
			if info.Description ~= nil then
				description = Locale.Lookup(info.Description);
			end

			local kData:table = { 
				Feature		= eFeature,
				Name		= Locale.ToUpper(Locale.Lookup(info.Name)),
				Quote		= quote,
				QuoteAudio	= info.QuoteAudio,
				Description	= description,
				TypeName	= info.FeatureType,
				plotx		= plotx,
				ploty		= ploty
			}

			-- Add to queue if already showing a popup
			if not m_isWaitingToShowPopup then				
				ShowPopup( kData );
				LuaEvents.NaturalWonderPopup_Shown();	-- Signal other systems (e.g., bulk hide UI)
				UI.OnNaturalWonderRevealed(plotx, ploty);
			else		
			
				-- Prevent DUPES when bulk showing; only happen during force reveal?
				for _,kExistingData in ipairs(m_kQueuedPopups) do
					if kExistingData.Feature == eFeature then
						return;		-- Already have a popup for this feature queued then just leave.
					end
				end
				if m_eCurrentFeature ~= eFeature then
					table.insert(m_kQueuedPopups, kData);	
				end
			end
			
		end
	end
end

-- ===========================================================================
function OnLocalPlayerTurnEnd()
	if (not ContextPtr:IsHidden()) and GameConfiguration.IsHotseat() then
		OnClose();
	end
end

-- ===========================================================================
--	Native Input / ESC support
-- ===========================================================================
function KeyHandler( key:number )
    if key == Keys.VK_ESCAPE then
		Close();
		return true;
    end
    return false;
end
function OnInputHander( pInputStruct:table )
	local uiMsg :number = pInputStruct:GetMessageType();
	if (uiMsg == KeyEvents.KeyUp) then return KeyHandler( pInputStruct:GetKey() ); end;
	return false;
end

-- ===========================================================================
--	Initialize the context
-- ===========================================================================
function Initialize()

	ContextPtr:SetInputHandler( OnInputHander, true );

	Controls.Close:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.WonderRevealedHeader:SetText( Locale.ToUpper( Locale.Lookup("LOC_UI_FEATURE_NATURAL_WONDER_DISCOVERY")) )
	
	Events.NaturalWonderRevealed.Add(OnNaturalWonderRevealed);
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
end
Initialize();