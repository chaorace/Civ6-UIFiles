-------------------------------------------------
-- Mods Browser Screen
-------------------------------------------------
include( "InstanceManager" );
g_ModListingsManager = InstanceManager:new("ModInstance", "ModInstanceRoot", Controls.ModListingsStack);

function RefreshListings()
	local mods = Modding.GetInstalledMods();

	g_ModListingsManager:ResetInstances();
	
	if(mods == nil or #mods == 0) then
		Controls.ModListings:SetHide(true);
		Controls.NoModsInstalled:SetHide(false);
	else
		Controls.ModListings:SetHide(false);
		Controls.NoModsInstalled:SetHide(true);

		-- Pre-translate name.
		for i,v in ipairs(mods) do
			v.DisplayName = Locale.Lookup(v.Name);
		end

		-- Sort by Name.
		table.sort(mods, function(a,b) 
			return Locale.Compare(a.DisplayName, b.DisplayName) == -1;
		end);

		for i,v in ipairs(mods) do		
			local category = Modding.GetModProperty(v.Handle, "ShowInBrowser");

			-- Hide mods marked as always hidden or hide DLC which is not owned.
			if(category ~= "AlwaysHidden" and not (UI.IsFinalRelease() and v.Allowance == false)) then
			
				local instance = g_ModListingsManager:GetInstance();

				--instance.DownloadStatus:SetHide(true);
				--instance.UpdateButton:SetHide(true);
				--instance.DownloadProgress:SetHide(true);
				if(v.Allowance == false) then
					v.DisplayName = v.DisplayName .. " [COLOR_RED](" .. Locale.Lookup("LOC_MODS_DETAILS_OWNERSHIP_NO") .. ")[ENDCOLOR]";
				end
				instance.ModTitle:LocalizeAndSetText(v.DisplayName);

				if(#v.Teaser == 0) then
					instance.ModDescription:LocalizeAndSetText(v.Description);
				else
					instance.ModDescription:LocalizeAndSetText(v.Teaser);
				end
	
				if(v.SubscriptionId ~= nil) then
	
				else
		
				end
		
				local enabled = v.Enabled;
				local enableCheckBox = instance.ModEnabled;
				enableCheckBox:SetCheck(enabled);

				if(enabled) then
					local err, xtra, sources = Modding.CanDisableMod(v.Handle);
					if(err == "OK") then
						enableCheckBox:SetDisabled(false);
						enableCheckBox:SetToolTipString(Locale.Lookup("LOC_MODS_DISABLE"));
					else
						enableCheckBox:SetDisabled(true);
							
						-- Generate tip w/ list of mods to enable.
						local tip = {};
						local items = xtra or {};
						if(err == "MissingDependencies") then
							tip[1] = Locale.Lookup("LOC_MODS_DISABLE_ERROR_DEPENDS");
							items = sources or {}; -- show sources of errors rather than targets of error.
						else
							tip[1] = Locale.Lookup("LOC_MODS_DISABLE_ERROR") .. err;
						end

						for k,ref in ipairs(items) do
							table.insert(tip, "[ICON_BULLET] " .. Locale.Lookup(ref.Name));
						end

						enableCheckBox:SetToolTipString(table.concat(tip, "[NEWLINE]"));
					end
				else
					local err, xtra = Modding.CanEnableMod(v.Handle);
					if(err == "MissingDependencies") then
						-- Don't replace xtra since we want the old list to enumerate missing mods.
						err, _ = Modding.CanEnableMod(v.Handle, true);
					end

					if(err == "OK") then
						enableCheckBox:SetDisabled(false);

						if(xtra and #xtra > 0) then
							-- Generate tip w/ list of mods to enable.
							local tip = {Locale.Lookup("LOC_MODS_ENABLE_INCLUDE")};
							for k,ref in ipairs(xtra) do
								table.insert(tip, "[ICON_BULLET] " .. Locale.Lookup(ref.Name));
							end

							enableCheckBox:SetToolTipString(table.concat(tip, "[NEWLINE]"));
						else	
							enableCheckBox:SetToolTipString(Locale.Lookup("LOC_MODS_ENABLE"));
						end
					else
						enableCheckBox:SetDisabled(true);
							
						-- Generate tip w/ list of mods to enable.
						local tip = {err};
						for k,ref in ipairs(xtra) do
							table.insert(tip, "[ICON_BULLET] " .. Locale.Lookup(ref.Name));
						end

						enableCheckBox:SetToolTipString(table.concat(tip, "[NEWLINE]"));
					end
				end

				enableCheckBox:RegisterCallback(Mouse.eLClick, function()
					if(enableCheckBox:IsChecked()) then
						Modding.EnableMod(v.Handle, true);
						RefreshListings();
					else
						Modding.DisableMod(v.Handle);
						RefreshListings();
					end
				end);
			end
		end

		Controls.ModListingsStack:CalculateSize();
		Controls.ModListingsStack:ReprocessAnchoring();
		Controls.ModListings:CalculateInternalSize();

	end
end

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

	if (Steam ~= nil) then
	--	Steam.ActivateGameOverlayToWorkshop();
		Steam.ActivateGameOverlayToUrl("http://steamcommunity.com/workshop/browse/?appid=289070");
	end
end

----------------------------------------------------------------  
function OnWorldBuilder()
	local worldBuilderMenu = ContextPtr:LookUpControl("/FrontEnd/MainMenu/WorldBuilder");
	if (worldBuilderMenu ~= nil) then
		GameConfiguration.SetWorldBuilderEditor(true);
		UIManager:QueuePopup(worldBuilderMenu, PopupPriority.Current);
	end
end

----------------------------------------------------------------    
function OnShow()
	RefreshListings();

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
