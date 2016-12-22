-------------------------------------------------
-- InGame Game Settings Screen
-------------------------------------------------
include("LobbyTypes");		--MPLobbyTypes
include("PlayerSetupLogic");


-------------------------------------------------
-- Globals
-------------------------------------------------


-------------------------------------------------
-- Helper Functions
-------------------------------------------------


----------------------------------------------------------------        
-- Input Handler
----------------------------------------------------------------        
function InputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			HandleExitRequest();
		end
	end

	-- TODO: Is this needed?
	return true;
end
ContextPtr:SetInputHandler( InputHandler );

-------------------------------------------------
-- Show Hide Handler
-------------------------------------------------
function ShowHideHandler( bIsHide, bIsInit )
	if( not isHide ) then
		BuildGameSetup();
	else
		HideGameSetup();
	end
end
ContextPtr:SetShowHideHandler( ShowHideHandler )

-------------------------------------------------
-- Back Button Handler
-------------------------------------------------
function CloseButtonClick()
	HandleExitRequest();
end
Controls.CloseButton:RegisterCallback( Mouse.eLClick, CloseButtonClick );
		
-------------------------------------------------
-- Leave the screen
-------------------------------------------------
function HandleExitRequest()
    UIManager:DequeuePopup( ContextPtr );
end

-------------------------------------------------------------------------------
-- Guess what this function does...
-------------------------------------------------------------------------------
function Initialize()

	-- If in hotseat mode; make background 100% hidden
	if GameConfiguration.IsHotseat() then
		Controls.BGBlock:SetColor(0xff000000);
	end

end

Initialize();