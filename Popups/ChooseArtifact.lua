g_ActingPlayerID = -1;
g_TargetPlayerID = -1;

function OnOpen()

	local localPlayer = Players[Game.GetLocalPlayer()];
	if (localPlayer == nil) then
		return;
	end

	local pkArchaeologist = localPlayer:GetUnits():GetNextExtractingArchaeologist();
	local iIndex = Map.GetPlotIndex(pkArchaeologist:GetX(), pkArchaeologist:GetY());
	local kObject = Game.GetArtifactAtPlot(iIndex);
	g_ActingPlayerID = kObject.ActingPlayerID;
	g_TargetPlayerID = kObject.TargetPlayerID;

	local szExplanationString;
	local bNoChoice = false;
	if (kObject.Type == 0) then
	    szExplanationString = "LOC_CHOOSE_ARTIFACT_EXPLANATION_NO_TYPE";
	elseif (kObject.Type == 1) then
	    szExplanationString = "LOC_CHOOSE_ARTIFACT_EXPLANATION_GOODY_HUT";
		bNoChoice = true;
	elseif (kObject.Type == 2) then
	    szExplanationString = "LOC_CHOOSE_ARTIFACT_EXPLANATION_BARBARIAN_CAMP";
		bNoChoice = true;
	elseif (kObject.Type == 3) then
	    szExplanationString = "LOC_CHOOSE_ARTIFACT_EXPLANATION_BATTLE_FOUGHT";
	elseif (kObject.Type == 4) then
	    szExplanationString = "LOC_CHOOSE_ARTIFACT_EXPLANATION_SHIP_SUNK";
	end
	local szEraName = Locale.Lookup(GameInfo.Eras[kObject.ActingPlayerEra].Name);
	Controls.EraString:LocalizeAndSetText("LOC_CHOOSE_ARTIFACT_ERA_STRING", szEraName);

	if (bNoChoice == true) then
		local pActingPlayerConfig :table = PlayerConfigurations[kObject.ActingPlayerID];
		local pTargetPlayerConfig = PlayerConfigurations[kObject.TargetPlayerID];
		Controls.Button1:LocalizeAndSetText("LOC_CHOOSE_ARTIFACT_OK_BUTTON");
		Controls.Button2:SetHide(true);
		Controls.Explanation:LocalizeAndSetText(szExplanationString, pkArchaeologist:GetName(), pActingPlayerConfig:GetPlayerName());
		Controls.ChoiceHeader:LocalizeAndSetText("LOC_CHOOSE_ARTIFACT_NO_CHOICE", pActingPlayerConfig:GetPlayerName());
		Controls.PanelHeader:LocalizeAndSetText("LOC_CHOOSE_ARTIFACT_NO_CHOICE_HEADER");
	else
		local pActingPlayerConfig :table = PlayerConfigurations[kObject.ActingPlayerID];
		local pTargetPlayerConfig :table = PlayerConfigurations[kObject.TargetPlayerID];
		Controls.Button1:LocalizeAndSetText(pActingPlayerConfig:GetPlayerName());
		Controls.Button2:SetHide(false);
		Controls.Button2:LocalizeAndSetText(pTargetPlayerConfig:GetPlayerName());
		Controls.Explanation:LocalizeAndSetText(szExplanationString, pkArchaeologist:GetName(), pActingPlayerConfig:GetPlayerName(), pTargetPlayerConfig:GetPlayerName());
		Controls.ChoiceHeader:LocalizeAndSetText("LOC_CHOOSE_ARTIFACT_MAKE_CHOICE");
		Controls.PanelHeader:LocalizeAndSetText("LOC_CHOOSE_ARTIFACT_HEADER");
    end
	Controls.ContentStack:CalculateSize();
	Controls.ContentStack:ReprocessAnchoring();
	Controls.ButtonStack:CalculateSize();
	Controls.ButtonStack:ReprocessAnchoring();
	Controls.ChooseArtifactPanel:ReprocessAnchoring();
	ContextPtr:SetHide(false);
	Controls.PopupAlphaIn:SetToBeginning();
	Controls.PopupAlphaIn:Play();
	Controls.PopupSlideIn:SetToBeginning();
	Controls.PopupSlideIn:Play();
end
function OnButton1()
	local tParameters = {};
	tParameters[PlayerOperations.PARAM_PLAYER_ONE] = g_ActingPlayerID;
	UI.RequestPlayerOperation( Game.GetLocalPlayer(), PlayerOperations.CHOOSE_ARTIFACT_PLAYER, tParameters);
	ContextPtr:SetHide(true);
end
function OnButton2()
	local tParameters = {};
	tParameters[PlayerOperations.PARAM_PLAYER_ONE] = g_TargetPlayerID;
	UI.RequestPlayerOperation( Game.GetLocalPlayer(), PlayerOperations.CHOOSE_ARTIFACT_PLAYER, tParameters);
	ContextPtr:SetHide(true);
end

-- ===========================================================================
function Initialize()
	Controls.Button1:RegisterCallback(Mouse.eLClick, OnButton1);
	Controls.Button2:RegisterCallback(Mouse.eLClick, OnButton2);
	LuaEvents.NotificationPanel_OpenArtifactPanel.Add(OnOpen);
end
Initialize();
