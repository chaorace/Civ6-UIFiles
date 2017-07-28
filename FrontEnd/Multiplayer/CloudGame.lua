-------------------------------------------------
-- Cloud Game Screen
-------------------------------------------------

include("InstanceManager")
include("PopupDialog")

local instanceManager = InstanceManager:new("ListingButtonInstance", "Button", Controls.ListingStack)

local function CloudListButtonClick()
	FiraxisLive.CloudMatchList()
end

local function CloudTemplateButtonClick()
	FiraxisLive.CloudMatchTemplate()
end

local function CloudHostButtonClick()
	FiraxisLive.CloudMatchHost()
end

local function CloudStartButtonClick()
	FiraxisLive.CloudMatchStart(432614675)
end

local function BackButtonClick()
	UIManager:DequeuePopup(ContextPtr)
end

local function InputHandler(uiMsg, wParam, lParam)
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			BackButtonClick()
		end
	end

	return true
end

local function SelectGame(void1, void2)
	print("SelectGame: "..void1..", "..void2)
	FiraxisLive.CloudMatchGetInfo(void1)
	-- TODO(asherburne): Present spinner and wait for status callback.
end

local function ServerListingButtonClick(void1, void2)
	print("ServerListingButtonClick: "..void1..", "..void2)
	FiraxisLive.CloudMatchJoin(void1)
end

local function OnCloudGameListUpdated()
	if(ContextPtr:IsVisible()) then
		instanceManager:ResetInstances()
		local games = FiraxisLive.GetCloudGames()

		for key, value in ipairs(games) do
			local controlTable = instanceManager:GetInstance()
			controlTable.ServerNameLabel:SetText(value[1])
			controlTable.ServerNameLabel:SetColorByName("Beige_Black")

			controlTable.RuleSetBoxLabel:SetText(value[2])
			controlTable.RuleSetBoxLabel:SetColorByName("Beige_Black")

			controlTable.MembersLabel:SetText(value[3])
			controlTable.MembersLabel:SetColorByName("Beige_Black")

			controlTable.Button:SetVoid1(value[2])
			controlTable.Button:RegisterCallback(Mouse.eLClick, SelectGame)

			controlTable.JoinButton:SetVoid1(value[2])
			controlTable.JoinButton:RegisterCallback(Mouse.eLClick, ServerListingButtonClick)
		end

		Controls.ListingStack:CalculateSize()
		Controls.ListingStack:ReprocessAnchoring()
		Controls.ListingScrollPanel:CalculateInternalSize()
	end
end

local function OnCloudGameInfoUpdated()
	if(ContextPtr:IsVisible()) then
		-- TODO(asherburne): Ensure message has expected matchID, then queue popup of lobby setup menu.
		-- Upon presentation of the lobby setup menu, call get match details with selected matchID to
		-- get details for view.
		print("OnCloudGameInfoUpdated")
		UIManager:QueuePopup(Controls.CloudLobbyScreen, PopupPriority.Current)
	end
end

function OnCloudGameJoinResponseOk()
	print("OnCloudGameJoinResponseOk")
end

local function OnCloudGameJoinResponse(matchID, success)
	if(ContextPtr:IsVisible()) then
		if success then
			-- TODO(asherburne): Present staging room
			print("OnCloudGameJoinResponse success for match "..matchID)
		else
			local errorPopupDialog = PopupDialog:new("CloudGamePopupDialog")
			errorPopupDialog:ShowOkDialog("Failed to join match "..matchID, OnCloudGameJoinResponseOk)
		end
	end
end

Controls.CloudListButton:RegisterCallback(Mouse.eLClick, CloudListButtonClick)
Controls.CloudTemplateButton:RegisterCallback(Mouse.eLClick, CloudTemplateButtonClick)
Controls.CloudHostButton:RegisterCallback(Mouse.eLClick, CloudHostButtonClick)
Controls.CloudStartButton:RegisterCallback(Mouse.eLClick, CloudStartButtonClick)
Controls.BackButton:RegisterCallback(Mouse.eLClick, BackButtonClick)
ContextPtr:SetInputHandler(InputHandler)
Events.CloudGameListUpdated.Add(OnCloudGameListUpdated)
Events.CloudGameInfoUpdated.Add(OnCloudGameInfoUpdated)
Events.CloudGameJoinResponse.Add(OnCloudGameJoinResponse)

-- if listbox has no items
	--FiraxisLive.CloudMatchList()
-- end
