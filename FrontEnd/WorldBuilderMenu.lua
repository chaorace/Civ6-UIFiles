
-- ===========================================================================
-- Button Handlers
-- ===========================================================================
function OnNewWorldBuilderMap()
	GameConfiguration.SetToDefaults();
	GameConfiguration.SetWorldBuilder(true);
	local advancedSetup = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/AdvancedSetup" );
	UIManager:QueuePopup(advancedSetup, PopupPriority.Current);
end
Controls.NewWorldBuilderMap:RegisterCallback( Mouse.eLClick, OnNewWorldBuilderMap );


-- ===========================================================================
function OnLoadWorldBuilderMap()
	GameConfiguration.SetToDefaults();
	LuaEvents.MainMenu_SetLoadGameServerType(ServerType.SERVER_TYPE_NONE);
	GameConfiguration.SetWorldBuilder(true);
	local loadGameMenu = ContextPtr:LookUpControl( "/FrontEnd/MainMenu/LoadGameMenu" );
	UIManager:QueuePopup(loadGameMenu, PopupPriority.Current);	
end
Controls.LoadWorldBuilderMap:RegisterCallback( Mouse.eLClick, OnLoadWorldBuilderMap );

-------------------------------------------------
-- Back Button Handler
-------------------------------------------------
function BackButtonClick()
	GameConfiguration.SetWorldBuilder(false);
	UIManager:DequeuePopup( ContextPtr );
end
Controls.BackButton:RegisterCallback( Mouse.eLClick, BackButtonClick );
Controls.BackButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

-------------------------------------------------
-- Input Handler
-------------------------------------------------
function InputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			BackButtonClick();
		end
	end
	return true;
end
ContextPtr:SetInputHandler( InputHandler );

