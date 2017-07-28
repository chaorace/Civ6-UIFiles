include("PopupDialog");

local ms_kPopupDialog = nil;

-------------------------------------------------
function OnExitToDesktop()
	if (Steam ~= nil) then
		Steam.ClearRichPresence();
	end

	Events.UserConfirmedClose();
	ms_kPopupDialog:Close()
	ms_kPopupDialog = nil;
end

-------------------------------------------------
function OnProceedAnyway()
	ms_kPopupDialog:Close();
	ms_kPopupDialog = nil;
end

-------------------------------------------------
function OnUserSetupWarning( warningType, string )
	if string == nil or string == "" then
		if (warningType == 0) then
			string = "LOC_KNOWN_GRAPHICS_CARD_ISSUES";
		end
	end

	if string ~= nil and string ~= "" then
		ms_kPopupDialog = PopupDialog:new("UserSetupWarning");
		ms_kPopupDialog:AddText(Locale.Lookup(string));
		ms_kPopupDialog:AddButton(Locale.Lookup("LOC_USER_WARNING_PROCEED_ANYWAY"), OnProceedAnyway);
		ms_kPopupDialog:AddButton(Locale.Lookup("LOC_USER_WARNING_QUIT"), OnExitToDesktop);
		ms_kPopupDialog:Open();
	end
end
Events.UserSetupWarning.Add( OnUserSetupWarning );