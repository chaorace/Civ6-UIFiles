include("PopupDialogSupport");

function Initialize()	
	print("Test.LUA loaded!");
	--Controls.foo:LocalizeAndSetText("LOC_GENERIC_TEST");
	
	--[[ test countdown
	local outdatedDriversPopupDialog:table = PopupDialog:new("OutdatedGraphicsDriver");
	outdatedDriversPopupDialog:AddText(Locale.Lookup("LOC_FRONTEND_POPUP_OUTDATED_DRIVER"));
	outdatedDriversPopupDialog:AddCountDown( 15, function() print("yay!"); end );
	outdatedDriversPopupDialog:AddButton(Locale.Lookup("LOC_FRONTEND_POPUP_OUTDATED_DRIVER_QUIET"));
	outdatedDriversPopupDialog:Open();
	]]

	--[[ 
	Controls.s:AddChildAtIndex( Controls.d, 1 );
	Controls.s:CalculateSize();
	]]

end
Initialize();
