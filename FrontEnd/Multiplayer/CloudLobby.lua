-------------------------------------------------
-- Cloud Lobby Screen
-------------------------------------------------

local function BackButtonClick()
	UIManager:DequeuePopup(ContextPtr)
end

Controls.BackButton:RegisterCallback(Mouse.eLClick, BackButtonClick)

--FiraxisLive.GetCloudGameDetails()
