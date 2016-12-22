g_PanelHasFocus = false;

g_MapZoomAdjustAmount = 0.1;

-------------------------------------------------------------------------------

g_SelectedCity =
{
	Active = false,
	OnlyVisible = false,
	Player = -1,
	CityID = -1,
}

-------------------------------------------------------------------------------
function GetSelectedCity()
	if (g_SelectedCity.Player >= 0 and g_SelectedCity.CityID >= 0) then
		local pPlayer = Players[g_SelectedCity.Player];
		if pPlayer ~= nil then
			pCity = pPlayer:GetCities():FindID(g_SelectedCity.CityID);
			return pCity;
		end
	end
	return nil;
end

-------------------------------------------------------------------------------
function LookAtCity(ePlayer, cityID)
	if (ePlayer >= 0 and cityID >= 0) then
		local pPlayer = Players[ePlayer];
		if pPlayer ~= nil then
			pCity = pPlayer:GetCities():FindID(cityID);
			UI.LookAtPlot(pCity:GetX(), pCity:GetY());
		end
	end
end

-------------------------------------------------------------------------------

g_SelectedDistrict =
{
	Active = false,
	OnlyVisible = false,
	Player = -1,
	DistrictID = -1,
}

-------------------------------------------------------------------------------
function GetSelectedDistrict()
	if (g_SelectedDistrict.Player >= 0 and g_SelectedDistrict.DistrictID >= 0) then
		local pPlayer = Players[g_SelectedDistrict.Player];
		if pPlayer ~= nil then
			pDistrict = pPlayer:GetDistricts():FindID(g_SelectedDistrict.DistrictID);
			return pDistrict;
		end
	end
	return nil;
end

-------------------------------------------------------------------------------
function LookAtDistrict(ePlayer, districtID)
	if (ePlayer >= 0 and districtID >= 0) then
		local pPlayer = Players[ePlayer];
		if pPlayer ~= nil then
			pDistrict = pPlayer:GetDistricts():FindID(districtID);
			UI.LookAtPlot(pDistrict:GetX(), pDistrict:GetY());
		end
	end
end

-------------------------------------------------------------------------------

g_SelectedMapPin =
{
	Active = false,
	OnlyVisible = false,
	Player = -1,
	MapPinID = -1,
}

-------------------------------------------------------------------------------
function GetSelectedMapPin()
	if (g_SelectedMapPin.Player >= 0 and g_SelectedMapPin.MapPinID >= 0) then
		local pPlayerConfig = PlayerConfigurations[g_SelectedMapPin.Player];
		local pPlayerPins = pPlayerConfig:GetMapPins();

		pMapPin = pPlayerConfig:GetMapPinID(g_SelectedMapPin.MapPinID);
		return pMapPin;
	end
	return nil;
end

-------------------------------------------------------------------------------
function LookAtMapPin(ePlayer, pinID)
	if (ePlayer >= 0 and pinID >= 0) then
		local pPlayerConfig = PlayerConfigurations[ePlayer];
		local pPlayerPins = pPlayerConfig:GetMapPins();

		pMapPin = pPlayerConfig:GetMapPinID(pinID);
		if (pMapPin ~= nil) then
			UI.LookAtPlot(pMapPin:GetHexX(), pMapPin:GetHexY());
		end
	end
end

-------------------------------------------------------------------------------

g_SelectedUnit =
{
	Active = false,
	OnlyVisible = false,
	Player = -1,
	UnitID = -1,
}

-------------------------------------------------------------------------------
function GetSelectedUnit()
	if (g_SelectedUnit.Player >= 0 and g_SelectedUnit.UnitID >= 0) then
		local pPlayer = Players[g_SelectedUnit.Player];
		if pPlayer ~= nil then
			pUnit = pPlayer:GetUnits():FindID(g_SelectedUnit.UnitID);
			return pUnit;
		end
	end
	return nil;
end

-------------------------------------------------------------------------------
function LookAtUnit(ePlayer, unitID)
	if (ePlayer >= 0 and unitID >= 0) then
		local pPlayer = Players[ePlayer];
		if pPlayer ~= nil then
			pUnit = pPlayer:GetUnits():FindID(unitID);
			UI.LookAtPlot(pUnit:GetX(), pUnit:GetY());
		end
	end
end
