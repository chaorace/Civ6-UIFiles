include("PopupDialogSupport");

-------------------------------------------------
-- Event Handler: FrontEndPopup
-------------------------------------------------
function OnFrontEndPopup( string )
	local pPopupDialog:table = PopupDialog:new("PlayerKicked");
	pPopupDialog:AddText(Locale.Lookup(string));
	pPopupDialog:AddButton(Locale.Lookup("LOC_CLOSE"));
	pPopupDialog:Open();
end
Events.FrontEndPopup.Add( OnFrontEndPopup );