include("PopupDialog");

m_kPopupDialog = PopupDialog:new("FrontEndPopup");

-------------------------------------------------
-- Event Handler: FrontEndPopup
-------------------------------------------------
function OnFrontEndPopup( string )
	UIManager:QueuePopup( ContextPtr, PopupPriority.Current );
	
	m_kPopupDialog:Close();
	m_kPopupDialog:AddTitle("");
	m_kPopupDialog:AddText(Locale.Lookup(string));
	m_kPopupDialog:AddButton(Locale.Lookup("LOC_CLOSE"), OnPopupClose);
	m_kPopupDialog:Open();
end

-- ===========================================================================
function OnUserRequestClose()
	UIManager:QueuePopup( ContextPtr, PopupPriority.Current );

	m_kPopupDialog:Close();
	m_kPopupDialog:AddText(Locale.Lookup("LOC_CONFIRM_EXIT_TXT"));
	m_kPopupDialog:AddTitle(Locale.ToUpper(Locale.Lookup("LOC_MAIN_MENU_EXIT_TO_DESKTOP")));
	m_kPopupDialog:AddButton(Locale.Lookup("LOC_CANCEL_BUTTON"), OnPopupClose);
	m_kPopupDialog:AddButton(Locale.Lookup("LOC_OK_BUTTON"), ExitOK, nil, nil, "PopupButtonInstanceRed"); 
	m_kPopupDialog:Open();
end

-- ===========================================================================
function OnPopupClose()
	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================
function ExitOK()
	OnPopupClose();

	if (Steam ~= nil) then
		Steam.ClearRichPresence();
	end

	Events.UserConfirmedClose();
end

-- ===========================================================================
-- ESC handler
-- ===========================================================================
function InputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			if(m_kPopupDialog and m_kPopupDialog:IsOpen()) then
				m_kPopupDialog:Close();
			end
		end
		return true;
	end
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetInputHandler( InputHandler );

	-- Events.FrontEndPopup has 256 character limit.
	-- LuaEvents.MultiplayerPopup should have unlimited character size.
	Events.FrontEndPopup.Add( OnFrontEndPopup );
	LuaEvents.MultiplayerPopup.Add( OnFrontEndPopup );
	LuaEvents.MainMenu_UserRequestClose.Add( OnUserRequestClose );
end
Initialize();
