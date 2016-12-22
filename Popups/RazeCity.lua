local g_pSelectedCity;

function OnButton1()
	local tParameters = {};
	tParameters[UnitOperationTypes.PARAM_FLAGS] = 0;
	if (CityManager.CanStartCommand( g_pSelectedCity, CityCommandTypes.DESTROY, tParameters)) then
		UI.DeselectAllCities();
		CityManager.RequestCommand( g_pSelectedCity, CityCommandTypes.DESTROY, tParameters);
	end
	ContextPtr:SetHide(true);
end
function OnButton2()
	local tParameters = {};
	tParameters[UnitOperationTypes.PARAM_FLAGS] = 1;
	if (CityManager.CanStartCommand( g_pSelectedCity, CityCommandTypes.DESTROY, tParameters)) then
		UI.DeselectAllCities();
		CityManager.RequestCommand( g_pSelectedCity, CityCommandTypes.DESTROY, tParameters);
	end
	ContextPtr:SetHide(true);
end
function OnButton3()
	local tParameters = {};
	tParameters[UnitOperationTypes.PARAM_FLAGS] = 2;
	if (CityManager.CanStartCommand( g_pSelectedCity, CityCommandTypes.DESTROY, tParameters)) then
		CityManager.RequestCommand( g_pSelectedCity, CityCommandTypes.DESTROY, tParameters);
	end
	ContextPtr:SetHide(true);
end
function OnButton4()
	local tParameters = {};
	tParameters[UnitOperationTypes.PARAM_FLAGS] = 3;
	if (CityManager.CanStartCommand( g_pSelectedCity, CityCommandTypes.DESTROY, tParameters)) then
		UI.DeselectAllCities();
		CityManager.RequestCommand( g_pSelectedCity, CityCommandTypes.DESTROY, tParameters);
       UI.PlaySound("RAZE_CITY");
	end
	ContextPtr:SetHide(true);
end

function OnOpen()
	local localPlayerID = Game.GetLocalPlayer();
	local localPlayer = Players[localPlayerID];
	if (localPlayer == nil) then
		return;
	end 

	g_pSelectedCity = localPlayer:GetCities():GetNextCapturedCity();

	Controls.PanelHeader:LocalizeAndSetText("LOC_RAZE_CITY_HEADER");
    Controls.CityHeader:LocalizeAndSetText("LOC_RAZE_CITY_NAME_LABEL");
    Controls.CityName:LocalizeAndSetText(g_pSelectedCity:GetName());
    Controls.CityPopulation:LocalizeAndSetText("LOC_RAZE_CITY_POPULATION_LABEL");
    Controls.NumPeople:SetText(tostring(g_pSelectedCity:GetPopulation()));
    Controls.CityDistricts:LocalizeAndSetText("LOC_RAZE_CITY_DISTRICTS_LABEL");
	local iNumDistricts = g_pSelectedCity:GetDistricts():GetNumZonedDistrictsRequiringPopulation();
    Controls.NumDistricts:SetText(tostring(iNumDistricts));

	local szWarmongerString;
	local eOriginalOwner = g_pSelectedCity:GetOriginalOwner();
	local originalOwnerPlayer = Players[eOriginalOwner];
	local eOwnerBeforeOccupation = g_pSelectedCity:GetOwnerBeforeOccupation();
	local eConqueredFrom = g_pSelectedCity:GetJustConqueredFrom();
	local bWipedOut = (originalOwnerPlayer:GetCities():GetCount() < 1);

	local iWarmongerPoints = localPlayer:GetDiplomacy():ComputeCityWarmongerPoints(g_pSelectedCity, eConqueredFrom);
	if (eOriginalOwner ~= eOwnerBeforeOccupation and eOriginalOwner ~= Game.GetLocalPlayer() and not localPlayer:GetDiplomacy():IsAtWarWith(eOriginalOwner) and eOriginalOwner ~= eConqueredFrom) then
		Controls.Button1:LocalizeAndSetText("LOC_RAZE_CITY_LIBERATE_FOUNDER_BUTTON_LABEL", PlayerConfigurations[eOriginalOwner]:GetCivilizationShortDescription());
		szWarmongerString = Locale.Lookup("LOC_RAZE_CITY_LIBERATE_WARMONGER_EXPLANATION");
		Controls.Button1:LocalizeAndSetToolTip("LOC_RAZE_CITY_LIBERATE_EXPLANATION", szWarmongerString);
		Controls.Button1:SetHide(false);
	else
		Controls.Button1:SetHide(true);
	end

	if (eOwnerBeforeOccupation ~= Game.GetLocalPlayer() and not localPlayer:GetDiplomacy():IsAtWarWith(eOwnerBeforeOccupation) and eOwnerBeforeOccupation ~= eConqueredFrom) then
		Controls.Button2:LocalizeAndSetText("LOC_RAZE_CITY_LIBERATE_PREWAR_OWNER_BUTTON_LABEL", PlayerConfigurations[eOwnerBeforeOccupation]:GetCivilizationShortDescription());
		szWarmongerString = Locale.Lookup("LOC_RAZE_CITY_LIBERATE_WARMONGER_EXPLANATION");
		Controls.Button2:LocalizeAndSetToolTip("LOC_RAZE_CITY_LIBERATE_EXPLANATION", szWarmongerString);
		Controls.Button2:SetHide(false);
	else
		Controls.Button2:SetHide(true);
	end

	Controls.Button3:LocalizeAndSetText("LOC_RAZE_CITY_KEEP_BUTTON_LABEL");
	if (bWipedOut ~= true) then
		szWarmongerString = Locale.Lookup("LOC_RAZE_CITY_KEEP_WARMONGER_EXPLANATION", localPlayer:GetDiplomacy():GetWarmongerLevel(-iWarmongerPoints));
		Controls.Button3:LocalizeAndSetToolTip("LOC_RAZE_CITY_KEEP_EXPLANATION", szWarmongerString);
	else
		szWarmongerString = Locale.Lookup("LOC_RAZE_CITY_KEEP_LAST_CITY_EXPLANATION");
		Controls.Button3:LocalizeAndSetToolTip(szWarmongerString);
	end

	Controls.Button4:LocalizeAndSetText("LOC_RAZE_CITY_RAZE_BUTTON_LABEL");
	if (g_pSelectedCity:CanRaze()) then
		if (bWipedOut ~= true) then
			szWarmongerString = Locale.Lookup("LOC_RAZE_CITY_RAZE_WARMONGER_EXPLANATION", localPlayer:GetDiplomacy():GetWarmongerLevel(-iWarmongerPoints * 3));
			Controls.Button4:LocalizeAndSetToolTip("LOC_RAZE_CITY_RAZE_EXPLANATION", szWarmongerString);
		else
			szWarmongerString = Locale.Lookup("LOC_RAZE_CITY_RAZE_LAST_CITY_EXPLANATION");
			Controls.Button4:LocalizeAndSetToolTip(szWarmongerString);
		end
		Controls.Button4:SetDisabled(false);
	else
		Controls.Button4:LocalizeAndSetToolTip("LOC_RAZE_CITY_RAZE_DISABLED_EXPLANATION");
		Controls.Button4:SetDisabled(true);

	end
	Controls.PopupStack:CalculateSize();
	Controls.PopupStack:ReprocessAnchoring();
	Controls.RazeCityPanel:ReprocessAnchoring();
	ContextPtr:SetHide(false);
	Controls.PopupAlphaIn:SetToBeginning();
	Controls.PopupAlphaIn:Play();
	Controls.PopupSlideIn:SetToBeginning();
	Controls.PopupSlideIn:Play();
end

function OnInputHandler( uiMsg, wParam, lParam )
    if uiMsg == KeyEvents.KeyUp then
        if wParam == Keys.VK_ESCAPE then
            ContextPtr:SetHide(true); 
        end
    end
    return true;
end

-- ===========================================================================
function Initialize()
	Controls.Button1:RegisterCallback(Mouse.eLClick, OnButton1);
	Controls.Button2:RegisterCallback(Mouse.eLClick, OnButton2);
	Controls.Button3:RegisterCallback(Mouse.eLClick, OnButton3);
	Controls.Button4:RegisterCallback(Mouse.eLClick, OnButton4);
	LuaEvents.NotificationPanel_OpenRazeCityChooser.Add(OnOpen);
end
Initialize();
