include( "PopupDialog" );

-- ===========================================================================
--	Game Engine Event
-- ===========================================================================
function OnUnitCaptured( currentUnitOwner, unit, owningPlayer, capturingPlayer )

	local localPlayer = Game.GetLocalPlayer();	
	if localPlayer == currentUnitOwner or localPlayer == capturingPlayer then
	
		local szOwnerString	:string = "";
		local captureMessage:string = "";

		if ( localPlayer == capturingPlayer ) then
			local pPlayerConfig = PlayerConfigurations[currentUnitOwner];
			if (pPlayerConfig ~= nil) then
				szOwnerString = pPlayerConfig:GetCivilizationShortDescription();
			end		
			captureMessage = "LOC_CAPTURE_UNIT";
		else
			local pPlayerConfig = PlayerConfigurations[capturingPlayer];
			if (pPlayerConfig ~= nil) then
				szOwnerString = pPlayerConfig:GetCivilizationShortDescription();
			end	
			-- If the player had a Settler selected, turn off the Settler lens when the unit is captured.
			if UILens.IsLayerOn(LensLayers.HEX_COLORING_WATER_AVAILABLITY) and UI.GetInterfaceMode() ~= InterfaceModeTypes.VIEW_MODAL_LENS then
				UILens.ToggleLayerOff(LensLayers.HEX_COLORING_WATER_AVAILABLITY);	
			end
			captureMessage = "LOC_UNIT_CAPTURED";
		end

		local msg			:string = Locale.Lookup( captureMessage, szOwnerString )
		local pPopupDialog	:table = PopupDialogInGame:new("UnitCaptured"); 
		pPopupDialog:AddTitle( Locale.ToUpper( Locale.Lookup("LOC_UNIT_CAPTURE_DEFAULT")));	
		pPopupDialog:AddText( msg );
		pPopupDialog:AddButton(Locale.Lookup("LOC_UNIT_CAPTURE_OK"),  function() end );	-- Just lower.
		pPopupDialog:Open();
	end
end

-- ===========================================================================
function Initialize()
	-- hotseat gets unit captured messages via the notification bar as this screen will only show for the 
	-- currently active player which may not be the player that owned the captured unit.
	if(not GameConfiguration.IsHotseat()) then
		Events.UnitCaptured.Add(OnUnitCaptured);
	end
end
Initialize();

