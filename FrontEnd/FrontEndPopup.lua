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
-- Events.FrontEndPopup has 256 character limit.
-- LuaEvents.MultiplayerPopup should have unlimited character size.
Events.FrontEndPopup.Add( OnFrontEndPopup );
LuaEvents.MultiplayerPopup.Add( OnFrontEndPopup );