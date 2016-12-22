-------------------------------------------------
-- Mods Browser Screen
-------------------------------------------------
include( "InstanceManager" );
g_ModListingsManager = InstanceManager:new("ModInstance", "ModInstanceRoot", Controls.ModListingsStack);


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

----------------------------------------------------------------  
function OnInstalledModsTabClick()
	Controls.SubscriptionsTabPanel:SetHide(true);
	Controls.InstalledTabPanel:SetHide(false);
end
----------------------------------------------------------------  
function OnSubscriptionsTabClick()
	Controls.InstalledTabPanel:SetHide(true);
	Controls.SubscriptionsTabPanel:SetHide(false);
end
----------------------------------------------------------------  
function OnOpenWorkshop()

-- TODO:	The default workshop page is not visible until the game is visible to the public.
--			until that happens, use a different URL that will temporarily work.
--	Steam.ActivateGameOverlayToWorkshop();
	Steam.ActivateGameOverlayToUrl("http://steamcommunity.com/workshop/browse/?appid=289070");
end

----------------------------------------------------------------  
function OnWorldBuilder()
	local worldBuilderMenu = ContextPtr:LookUpControl("/FrontEnd/MainMenu/WorldBuilder");
	if (worldBuilderMenu ~= nil) then
		GameConfiguration.SetWorldBuilder(true);
		UIManager:QueuePopup(worldBuilderMenu, PopupPriority.Current);
	end
end

----------------------------------------------------------------    
function OnShow()
	local mods = Modding.GetInstalledMods();
	
	g_ModListingsManager:ResetInstances();
	
	if(mods == nil or #mods == 0) then
		Controls.ModListings:SetHide(true);
		Controls.NoModsInstalled:SetHide(false);
	else
		Controls.ModListings:SetHide(false);
		Controls.NoModsInstalled:SetHide(true);

		for i,v in ipairs(mods) do
			
			local category = Modding.GetModProperty(v.Handle, "ShowInBrowser");
			if(category ~= "AlwaysHidden") then
			
				local instance = g_ModListingsManager:GetInstance();

				--instance.DownloadStatus:SetHide(true);
				--instance.UpdateButton:SetHide(true);
				--instance.DownloadProgress:SetHide(true);
	
				instance.ModTitle:LocalizeAndSetText(v.Name);

				if(#v.Teaser == 0) then
					instance.ModDescription:LocalizeAndSetText(v.Description);
				else
					instance.ModDescription:LocalizeAndSetText(v.Teaser);
				end
	
				instance.ModEnabled:SetCheck(v.Enabled);
		
				if(v.SubscriptionId ~= nil) then
	
				else
		
				end
		
				local enableCheckBox = instance.ModEnabled;
				enableCheckBox:RegisterCallback(Mouse.eLClick, function()
					if(enableCheckBox:IsChecked()) then
						Modding.EnableMod(v.Handle);

					else
						Modding.DisableMod(v.Handle);
					end
				end);
			end
		end

		Controls.ModListingsStack:CalculateSize();
		Controls.ModListingsStack:ReprocessAnchoring();
		Controls.ModListings:CalculateInternalSize();

	end

	if(GameConfiguration.IsAnyMultiplayer() or UI.IsFinalRelease()) then
		Controls.WorldBuilder:SetHide(true);
		Controls.BrowseWorkshop:SetHide(true);
	else
		Controls.WorldBuilder:SetHide(false);
		Controls.BrowseWorkshop:SetHide(false);
	end
end	
----------------------------------------------------------------    
function HandleExitRequest()
	UIManager:DequeuePopup( ContextPtr );
end
----------------------------------------------------------------  
function PostInit()
	if(not ContextPtr:IsHidden()) then
		OnShow();
	end
end
----------------------------------------------------------------  
-- ===========================================================================
--	Handle Window Sizing
-- ===========================================================================
function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	local hideLogo = true;
	if(screenY >= Controls.MainWindow:GetSizeY() + (Controls.LogoContainer:GetSizeY()+ Controls.LogoContainer:GetOffsetY())*2) then
		hideLogo = false;
	end
	Controls.LogoContainer:SetHide(hideLogo);
	Controls.MainGrid:ReprocessAnchoring();
end

function Initialize()

	if(true) then
	 --if(Modding.IsSteamWorkshopEnabled()) then
		Controls.SubscriptionsTab:RegisterCallback(Mouse.eLClick, OnSubscriptionsTabClick);
		Controls.SubscriptionsTab:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
		Controls.BrowseWorkshop:RegisterCallback( Mouse.eLClick, OnOpenWorkshop );
		Controls.BrowseWorkshop:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	else
		Controls.SubscriptionsTab:SetDisabled(true);
		Controls.BrowseWorkshop:SetDisabled(true);
	end
	Resize();
	Controls.InstalledTab:RegisterCallback(Mouse.eLClick, OnInstalledModsTabClick);
	Controls.InstalledTab:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CloseButton:RegisterCallback( Mouse.eLClick, HandleExitRequest );
	Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Controls.WorldBuilder:RegisterCallback(Mouse.eLClick, OnWorldBuilder);
	Controls.WorldBuilder:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetPostInit(PostInit);	
end

Initialize();
