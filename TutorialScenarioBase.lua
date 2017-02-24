-- ===========================================================================
--
--	Tutorial items meant to be included from TutorialUIRoot
--	"BASE" game scenario 
--
-- ===========================================================================

-- ===========================================================================
-- Overall tutorial definition
-- ===========================================================================
hstructure TutorialDefinition
	Id				: string;		-- Id of scenario
	Bank			: table;		-- array of functions that when called populate tutorial items
end


-- ===========================================================================
--	Setup the tutorial environment.
--	RETURN Number of item bank functions to call.
-- ===========================================================================
function InitializeTutorial()
	local scenarioName:string = "BASE";
	SetScenarioName(scenarioName);

	WriteCustomData("about","Firaxis in game tutorial prompts.");
	WriteCustomData("version",1);
	
	return hmake TutorialDefinition {
		Id	= scenarioName,
		Bank= { TutorialItemBank1 }
	};	
end

-- ===========================================================================
--	If this is not from a save game, run these commands that would typically
--	be serialized out and read back in automatically.
-- ===========================================================================
function InitFirstRun()	
end

-- ===========================================================================
--	The function that the tutorial root will call to add items...
-- ===========================================================================
function TutorialItemBank1()

	-- ello there!
	local item:TutorialItem = TutorialItem:new("FIRST_GREETING");
	-- Setting to -1 to ensure question is always asked, even when user has manually
	-- selected a tutorial level in the options menu before starting their first game.
	item:SetTutorialLevel(-1);
	item:SetIsEndOfChain(true)
	item:SetIsQueueable(true)
	item:SetShowPortrait(true);
	item:SetRaiseEvents("LoadScreenClose");
	item:SetAdvisorMessage("LOC_ADVISOR_LINE_FTUE_1");
	item:SetAdvisorAudio("Play_ADVISOR_LINE_FTUE_1");
	item:AddAdvisorButton("LOC_TUTORIAL_NEW_TO_CIV",
		function(advisorInfo)
			m_tutorialLevel = TutorialLevel.LEVEL_TBS_FAMILIAR;			
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_FTUE_1")
		end);
	item:AddAdvisorButton("LOC_TUTORIAL_NEW_TO_CIV_6",
		function(advisorInfo)			
			m_tutorialLevel = TutorialLevel.LEVEL_CIV_FAMILIAR;			
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_FTUE_1")
		end);
	item:SetCleanupFunction(
		function()			
			UserConfiguration.TutorialLevel( m_tutorialLevel );
			UserConfiguration.CommitToOptions();	-- Force an update of the value to the options
			-- Also, set an option, signaling the user has chosen so we don't show this again.
			Options.SetUserOption("Tutorial", "HasChosenTutorialLevel", 1);
			Options.SaveOptions(OptionFileTypes.User);
		end);
	item:SetRaiseFunction(
		function()
			-- Has the user already chosen?
			if (Options.GetUserOption("Tutorial", "HasChosenTutorialLevel") == 0) then
				return true;
			else
				return false;
			end
		end);			
	item:SetIsDoneFunction(
		function()
			return false
		end);


	-- Local player scout unit added to map
	local item_scoutUnitAddedToMap:TutorialItem = TutorialItem:new("SCOUT_UNIT_ADDED_TO_MAP")
	item_scoutUnitAddedToMap:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_scoutUnitAddedToMap:SetIsEndOfChain(true)
	item_scoutUnitAddedToMap:SetIsQueueable(true)
	item_scoutUnitAddedToMap:SetShowPortrait(true)
	item_scoutUnitAddedToMap:SetRaiseEvents("ScoutUnitAddedToMap")
	item_scoutUnitAddedToMap:SetAdvisorMessage("ADVISOR_LINE_LISTENER_2")
	item_scoutUnitAddedToMap:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_2")
	item_scoutUnitAddedToMap:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_2")
		end)
	item_scoutUnitAddedToMap:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNIT_SCOUT")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_2")
		end)
	item_scoutUnitAddedToMap:SetIsDoneFunction(
		function()
			return false
		end)

	-- Trade route unlocked
	local item_tradeRouteUnlocked:TutorialItem = TutorialItem:new("TRADE_ROUTE_UNLOCKED")
	item_tradeRouteUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_tradeRouteUnlocked:SetIsEndOfChain(true)
	item_tradeRouteUnlocked:SetIsQueueable(true)
	item_tradeRouteUnlocked:SetShowPortrait(true)
	item_tradeRouteUnlocked:SetRaiseEvents("ForeignTradeCivicCompleted")
	item_tradeRouteUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_6")
	item_tradeRouteUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_6")
	item_tradeRouteUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_6")
		end)
	item_tradeRouteUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "TRADE_1")  -- Introduction
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_6")
		end)
	item_tradeRouteUnlocked:SetIsDoneFunction(
		function()
			return false
		end)

	-- Trade route started.
	local item_tradeRouteStarted:TutorialItem = TutorialItem:new("TRADE_ROUTE_STARTED")
	item_tradeRouteStarted:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_tradeRouteStarted:SetIsEndOfChain(true)
	item_tradeRouteStarted:SetIsQueueable(true)
	item_tradeRouteStarted:SetShowPortrait(true)
	item_tradeRouteStarted:SetRaiseEvents("TradeRouteAddedToMap")
	item_tradeRouteStarted:SetAdvisorMessage("ADVISOR_LINE_LISTENER_7")
	item_tradeRouteStarted:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_7")
	item_tradeRouteStarted:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_7")
		end)
	item_tradeRouteStarted:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "MOVEMENT_2")  -- Roads
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_7")
		end)
	item_tradeRouteStarted:SetIsDoneFunction(
		function()
			return false
		end)			


	-- Unit promotion available.
	local item_unitPromotion:TutorialItem = TutorialItem:new("UNIT_PROMOTION_AVAILABLE")
	item_unitPromotion:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_unitPromotion:SetIsEndOfChain(true)
	item_unitPromotion:SetIsQueueable(true)
	item_unitPromotion:SetShowPortrait(true)
	item_unitPromotion:SetRaiseEvents("UnitPromotionAvailable")
	item_unitPromotion:SetAdvisorMessage("ADVISOR_LINE_LISTENER_9")
	item_unitPromotion:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_9")
	item_unitPromotion:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_9")
		end)
	item_unitPromotion:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "COMBAT_8")  -- Experience and Promotions
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_9")
		end)
	item_unitPromotion:SetIsDoneFunction(
		function()
			return false
		end)


	-- Additional governments unlocked.
	local item_governmentsUnlocked:TutorialItem = TutorialItem:new("GOVERNMENTS_UNLOCKED")
	item_governmentsUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_governmentsUnlocked:SetIsEndOfChain(true)
	item_governmentsUnlocked:SetIsQueueable(true)
	item_governmentsUnlocked:SetShowPortrait(true)
	item_governmentsUnlocked:SetRaiseEvents("PoliticalPhilosophyCivicCompleted")
	item_governmentsUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_5")
	item_governmentsUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_5")
	item_governmentsUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_5")
		end)
	item_governmentsUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "GOVT_1")  -- Governments
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_5")
		end)
	item_governmentsUnlocked:SetIsDoneFunction(
		function()
			return false
		end)

	-- Corps unlocked. (civic completed: nationalism)
	local item_corpsUnlocked:TutorialItem = TutorialItem:new("CORPS_UNLOCKED")
	item_corpsUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_corpsUnlocked:SetIsEndOfChain(true)
	item_corpsUnlocked:SetIsQueueable(true)
	item_corpsUnlocked:SetShowPortrait(true)
	item_corpsUnlocked:SetRaiseEvents("NationalismCivicCompleted")
	item_corpsUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_21")
	item_corpsUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_21")
	item_corpsUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_21")
		end)
	item_corpsUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "COMBAT_12")  -- Formations
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_21")
		end)
	item_corpsUnlocked:SetIsDoneFunction(
		function()
			return false
		end)


	-- Armies unlocked. (civic completed: mobilization)
	local item_armiesUnlocked:TutorialItem = TutorialItem:new("ARMIES_UNLOCKED")
	item_armiesUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_armiesUnlocked:SetIsEndOfChain(true)
	item_armiesUnlocked:SetIsQueueable(true)
	item_armiesUnlocked:SetShowPortrait(true)
	item_armiesUnlocked:SetRaiseEvents("MobilizationCivicCompleted")
	item_armiesUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_22")
	item_armiesUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_22")
	item_armiesUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_22")
		end)
	item_armiesUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "COMBAT_12")  -- Formations
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_22")
		end)
	item_armiesUnlocked:SetIsDoneFunction(
		function()
			return false
		end)

	-- Bankrupt (gold balance <= 0)
	local item_bankrupt:TutorialItem = TutorialItem:new("BANKRUPT")
	item_bankrupt:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_bankrupt:SetIsEndOfChain(true)
	item_bankrupt:SetIsQueueable(true)
	item_bankrupt:SetShowPortrait(true)
	item_bankrupt:SetRaiseEvents("Bankrupt")
	item_bankrupt:SetAdvisorMessage("ADVISOR_LINE_LISTENER_18")
	item_bankrupt:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_18")
	item_bankrupt:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_18")
		end)
	item_bankrupt:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "GOLD_4")  -- Bankruptcy
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_18")
		end)
	item_bankrupt:SetIsDoneFunction(
		function()
			return false
		end)

	-- Money surplus (gold balance >= 500 and gold yield > 0)
	local item_moneySurplus:TutorialItem = TutorialItem:new("MONEY_SURPLUS")
	item_moneySurplus:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_moneySurplus:SetIsEndOfChain(true)
	item_moneySurplus:SetIsQueueable(true)
	item_moneySurplus:SetShowPortrait(true)
	item_moneySurplus:SetRaiseEvents("MoneySurplus")
	item_moneySurplus:SetAdvisorMessage("ADVISOR_LINE_LISTENER_71")
	item_moneySurplus:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_71")
	item_moneySurplus:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_71")
		end)
	item_moneySurplus:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "GOLD_3")  -- Spending Gold
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_71")
		end)
	item_moneySurplus:SetIsDoneFunction(
		function()
			return false
		end)

	-- Can embark builders (sailing research completed)
	local item_embarkBuilders:TutorialItem = TutorialItem:new("EMBARK_BUILDERS")
	item_embarkBuilders:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_embarkBuilders:SetIsEndOfChain(true)
	item_embarkBuilders:SetIsQueueable(true)
	item_embarkBuilders:SetShowPortrait(true)
	item_embarkBuilders:SetRaiseEvents("SailingResearchCompleted")
	item_embarkBuilders:SetAdvisorMessage("ADVISOR_LINE_LISTENER_67")
	item_embarkBuilders:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_67")
	item_embarkBuilders:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_67")
		end)
	item_embarkBuilders:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "MOVEMENT_5")  -- Embarking Units
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("ADVISOR_LINE_LISTENER_67")
		end)
	item_embarkBuilders:SetIsDoneFunction(
		function()
			return false
		end)

	-- Can embark all units (shipbuilding research completed)
	local item_embarkAll:TutorialItem = TutorialItem:new("EMBARK_ALL")
	item_embarkAll:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_embarkAll:SetIsEndOfChain(true)
	item_embarkAll:SetIsQueueable(true)
	item_embarkAll:SetShowPortrait(true)
	item_embarkAll:SetRaiseEvents("ShipbuildingResearchCompleted")
	item_embarkAll:SetAdvisorMessage("ADVISOR_LINE_LISTENER_66")
	item_embarkAll:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_66")
	item_embarkAll:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_66")
		end)
	item_embarkAll:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "MOVEMENT_5")  -- Embarking Units
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("ADVISOR_LINE_LISTENER_66")
		end)
	item_embarkAll:SetIsDoneFunction(
		function()
			return false
		end)

	-- Not enough amenities
	local item_lowAmenities:TutorialItem = TutorialItem:new("LOW_AMENITIES")
	item_lowAmenities:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_lowAmenities:SetIsEndOfChain(true)
	item_lowAmenities:SetIsQueueable(true)
	item_lowAmenities:SetShowPortrait(true)
	item_lowAmenities:SetRaiseEvents("LowAmenitiesNotificationAdded")
	item_lowAmenities:SetAdvisorMessage("ADVISOR_LINE_LISTENER_87")
	item_lowAmenities:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_87")
	item_lowAmenities:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_87")
		end)
	item_lowAmenities:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "CITIES_16")  -- Happiness
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
--			UI.PlaySound("Play_ADVISOR_LINE_LISTENER_87")
		end)
	item_lowAmenities:SetIsDoneFunction(
		function()
			return false
		end)

	-- Not enough housing
	local item_housingLimit:TutorialItem = TutorialItem:new("HOUSING_LIMIT")
	item_housingLimit:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_housingLimit:SetIsEndOfChain(true)
	item_housingLimit:SetIsQueueable(true)
	item_housingLimit:SetShowPortrait(true)
	item_housingLimit:SetRaiseEvents("HousingLimitNotificationAdded")
	item_housingLimit:SetAdvisorMessage("ADVISOR_LINE_LISTENER_86")
	item_housingLimit:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_86")
	item_housingLimit:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
--			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_86")
		end)
	item_housingLimit:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "CITIES_14")  -- Housing
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
		end)
	item_housingLimit:SetIsDoneFunction(
		function()
			return false
		end)

	-- First relic received
	local item_relicCreated:TutorialItem = TutorialItem:new("RELIC_CREATED")
	item_relicCreated:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_relicCreated:SetIsEndOfChain(true)
	item_relicCreated:SetIsQueueable(true)
	item_relicCreated:SetShowPortrait(true)
	item_relicCreated:SetRaiseEvents("RelicCreatedNotificationAdded")
	item_relicCreated:SetAdvisorMessage("ADVISOR_LINE_LISTENER_82")
	item_relicCreated:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_82")
	item_relicCreated:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_82")
		end)
	item_relicCreated:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "TOURISM_2")  -- Great Works, Relics, and Artifacts
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("ADVISOR_LINE_LISTENER_82")
		end)
	item_relicCreated:SetIsDoneFunction(
		function()
			return false
		end)

	-- An improvement has been pillaged
	local item_improvementPillaged:TutorialItem = TutorialItem:new("IMPROVEMENT_PILLAGED")
	item_improvementPillaged:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_improvementPillaged:SetIsEndOfChain(true)
	item_improvementPillaged:SetIsQueueable(true)
	item_improvementPillaged:SetShowPortrait(true)
	item_improvementPillaged:SetRaiseEvents("ImprovementPillaged")
	item_improvementPillaged:SetAdvisorMessage("ADVISOR_LINE_LISTENER_19")
	item_improvementPillaged:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_19")
	item_improvementPillaged:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_19")
		end)
	item_improvementPillaged:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "COMBAT_13")  -- Pillaging
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Play_ADVISOR_LINE_LISTENER_19")
		end)
	item_improvementPillaged:SetIsDoneFunction(
		function()
			return false
		end)

	-- Great general earned
	local item_greatGeneral:TutorialItem = TutorialItem:new("GREAT_GENERAL")
	item_greatGeneral:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_greatGeneral:SetIsEndOfChain(true)
	item_greatGeneral:SetIsQueueable(true)
	item_greatGeneral:SetShowPortrait(true)
	item_greatGeneral:SetRaiseEvents("GreatGeneralAddedToMap")
	item_greatGeneral:SetAdvisorMessage("ADVISOR_LINE_LISTENER_34")
	item_greatGeneral:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_34")
	item_greatGeneral:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_34")
		end)
	item_greatGeneral:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNIT_GREAT_GENERAL")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_34")
		end)
	item_greatGeneral:SetIsDoneFunction(
		function()
			return false
		end)

	-- Great admiral earned
	local item_greatAdmiral:TutorialItem = TutorialItem:new("GREAT_ADMIRAL")
	item_greatAdmiral:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_greatAdmiral:SetIsEndOfChain(true)
	item_greatAdmiral:SetIsQueueable(true)
	item_greatAdmiral:SetShowPortrait(true)
	item_greatAdmiral:SetRaiseEvents("GreatAdmiralAddedToMap")
	item_greatAdmiral:SetAdvisorMessage("ADVISOR_LINE_LISTENER_33")
	item_greatAdmiral:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_33")
	item_greatAdmiral:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_33")
		end)
	item_greatAdmiral:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNIT_GREAT_ADMIRAL")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_33")
		end)
	item_greatAdmiral:SetIsDoneFunction(
		function()
			return false
		end)

	-- Great engineer earned
	local item_greatEngineer:TutorialItem = TutorialItem:new("GREAT_ENGINEER")
	item_greatEngineer:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_greatEngineer:SetIsEndOfChain(true)
	item_greatEngineer:SetIsQueueable(true)
	item_greatEngineer:SetShowPortrait(true)
	item_greatEngineer:SetRaiseEvents("GreatEngineerAddedToMap")
	item_greatEngineer:SetAdvisorMessage("ADVISOR_LINE_LISTENER_74")
	item_greatEngineer:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_74")
	item_greatEngineer:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_74")
		end)
	item_greatEngineer:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNIT_GREAT_ENGINEER")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_74")
		end)
	item_greatEngineer:SetIsDoneFunction(
		function()
			return false
		end)

	-- Great merchant earned
	local item_greatMerchant:TutorialItem = TutorialItem:new("GREAT_MERCHANT")
	item_greatMerchant:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_greatMerchant:SetIsEndOfChain(true)
	item_greatMerchant:SetIsQueueable(true)
	item_greatMerchant:SetShowPortrait(true)
	item_greatMerchant:SetRaiseEvents("GreatMerchantAddedToMap")
	item_greatMerchant:SetAdvisorMessage("ADVISOR_LINE_LISTENER_35")
	item_greatMerchant:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_35")
	item_greatMerchant:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_35")
		end)
	item_greatMerchant:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNIT_GREAT_MERCHANT")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_35")
		end)
	item_greatMerchant:SetIsDoneFunction(
		function()
			return false
		end)

	-- Great prophet earned
	local item_greatProphet:TutorialItem = TutorialItem:new("GREAT_PROPHET")
	item_greatProphet:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_greatProphet:SetIsEndOfChain(true)
	item_greatProphet:SetIsQueueable(true)
	item_greatProphet:SetShowPortrait(true)
	item_greatProphet:SetRaiseEvents("GreatProphetAddedToMap")
	item_greatProphet:SetAdvisorMessage("ADVISOR_LINE_LISTENER_31")
	item_greatProphet:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_31")
	item_greatProphet:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_31")
		end)
	item_greatProphet:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNIT_GREAT_PROPHET")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_31")
		end)
	item_greatProphet:SetIsDoneFunction(
		function()
			return false
		end)

	-- Great scientist earned
	local item_greatScientist:TutorialItem = TutorialItem:new("GREAT_SCIENTIST")
	item_greatScientist:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_greatScientist:SetIsEndOfChain(true)
	item_greatScientist:SetIsQueueable(true)
	item_greatScientist:SetShowPortrait(true)
	item_greatScientist:SetRaiseEvents("GreatScientistAddedToMap")
	item_greatScientist:SetAdvisorMessage("ADVISOR_LINE_LISTENER_36")
	item_greatScientist:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_36")
	item_greatScientist:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_36")
		end)
	item_greatScientist:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNIT_GREAT_SCIENTIST")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_36")
		end)
	item_greatScientist:SetIsDoneFunction(
		function()
			return false
		end)

	-- Great writer earned
	local item_greatWriter:TutorialItem = TutorialItem:new("GREAT_WRITER")
	item_greatWriter:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_greatWriter:SetIsEndOfChain(true)
	item_greatWriter:SetIsQueueable(true)
	item_greatWriter:SetShowPortrait(true)
	item_greatWriter:SetRaiseEvents("GreatWriterAddedToMap")
	item_greatWriter:SetAdvisorMessage("ADVISOR_LINE_LISTENER_30")
	item_greatWriter:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_30")
	item_greatWriter:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_30")
		end)
	item_greatWriter:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNIT_GREAT_WRITER")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_30")
		end)
	item_greatWriter:SetIsDoneFunction(
		function()
			return false
		end)

	-- Great artist earned
	local item_greatArtist:TutorialItem = TutorialItem:new("GREAT_ARTIST")
	item_greatArtist:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_greatArtist:SetIsEndOfChain(true)
	item_greatArtist:SetIsQueueable(true)
	item_greatArtist:SetShowPortrait(true)
	item_greatArtist:SetRaiseEvents("GreatArtistAddedToMap")
	item_greatArtist:SetAdvisorMessage("ADVISOR_LINE_LISTENER_29")
	item_greatArtist:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_29")
	item_greatArtist:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_29")
		end)
	item_greatArtist:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNIT_GREAT_ARTIST")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_29")
		end)
	item_greatArtist:SetIsDoneFunction(
		function()
			return false
		end)

	-- Great musician earned
	local item_greatMusician:TutorialItem = TutorialItem:new("GREAT_MUSICIAN")
	item_greatMusician:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_greatMusician:SetIsEndOfChain(true)
	item_greatMusician:SetIsQueueable(true)
	item_greatMusician:SetShowPortrait(true)
	item_greatMusician:SetRaiseEvents("GreatMusicianAddedToMap")
	item_greatMusician:SetAdvisorMessage("ADVISOR_LINE_LISTENER_32")
	item_greatMusician:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_32")
	item_greatMusician:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_32")
		end)
	item_greatMusician:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNIT_GREAT_MUSICIAN")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_32")
		end)
	item_greatMusician:SetIsDoneFunction(
		function()
			return false
		end)

	-- First great person point earned
	local item_greatPersonPoint:TutorialItem = TutorialItem:new("GREAT_PERSON_POINT")
	item_greatPersonPoint:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_greatPersonPoint:SetIsQueueable(true)
	item_greatPersonPoint:SetShowPortrait(true)
	item_greatPersonPoint:SetRaiseEvents("GreatPersonPoint")
	item_greatPersonPoint:SetAdvisorMessage("ADVISOR_LINE_LISTENER_27")
	item_greatPersonPoint:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_27")
	item_greatPersonPoint:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_27")
		end)
	item_greatPersonPoint:SetIsDoneFunction(
		function()
			return false
		end)
	item_greatPersonPoint:SetNextTutorialItemId("GREAT_PERSON_POINT_B");

	-- First great person point earned tell me more
	local item_greatPersonPointB:TutorialItem = TutorialItem:new("GREAT_PERSON_POINT_B")
	item_greatPersonPointB:SetPrereqs("GREAT_PERSON_POINT");
	item_greatPersonPointB:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_greatPersonPointB:SetIsEndOfChain(true)
	item_greatPersonPointB:SetShowPortrait(true)
	item_greatPersonPointB:SetAdvisorMessage("ADVISOR_LINE_LISTENER_28")
	item_greatPersonPointB:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_28")
	item_greatPersonPointB:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_28")
		end)
	item_greatPersonPointB:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "GREATPEOPLE_2")  -- Earning Great People
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_28")
		end)
	item_greatPersonPointB:SetIsDoneFunction(
		function()
			return false
		end)

	-- City-state quest given
	local item_citystateQuestGiven:TutorialItem = TutorialItem:new("CITYSTATE_QUEST_GIVEN")
	item_citystateQuestGiven:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_citystateQuestGiven:SetIsEndOfChain(true)
	item_citystateQuestGiven:SetIsQueueable(true)
	item_citystateQuestGiven:SetShowPortrait(true)
	item_citystateQuestGiven:SetRaiseEvents("CitystateQuestGiven")
	item_citystateQuestGiven:SetAdvisorMessage("ADVISOR_LINE_LISTENER_17")
	item_citystateQuestGiven:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_17")
	item_citystateQuestGiven:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_17")
		end)
	item_citystateQuestGiven:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "CITYSTATES_1")  -- Introduction
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("ADVISOR_LINE_LISTENER_17")
		end)
	item_citystateQuestGiven:SetIsDoneFunction(
		function()
			return false
		end)

	-- Space port available (rocketry research completed)
	local item_spacePortAvailable:TutorialItem = TutorialItem:new("SPACE_PORT_AVAILABLE")
	item_spacePortAvailable:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_spacePortAvailable:SetIsEndOfChain(true)
	item_spacePortAvailable:SetIsQueueable(true)
	item_spacePortAvailable:SetShowPortrait(true)
	item_spacePortAvailable:SetRaiseEvents("RocketryResearchCompleted")
	item_spacePortAvailable:SetAdvisorMessage("ADVISOR_LINE_LISTENER_75")
	item_spacePortAvailable:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_75")
	item_spacePortAvailable:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_75")
		end)
	item_spacePortAvailable:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "VICTORY_3")  -- Science Victory
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_75")
		end)
	item_spacePortAvailable:SetIsDoneFunction(
		function()
			return false
		end)

	-- Great prophet earned via Stonehenge
	local item_stonehengeComplete:TutorialItem = TutorialItem:new("STONEHENGE_COMPLETE")
	item_stonehengeComplete:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_stonehengeComplete:SetIsEndOfChain(true)
	item_stonehengeComplete:SetIsQueueable(true)
	item_stonehengeComplete:SetShowPortrait(true)
	item_stonehengeComplete:SetRaiseEvents("StonehengeProductionCompleted")
	item_stonehengeComplete:SetAdvisorMessage("ADVISOR_LINE_LISTENER_73")
	item_stonehengeComplete:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_73")
	item_stonehengeComplete:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_73")
		end)
	item_stonehengeComplete:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "FAITH_5")  -- Founding Your Religion
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_73")
		end)
	item_stonehengeComplete:SetIsDoneFunction(
		function()
			return false
		end)

	-- Spies unlocked. (if france, tech completed: castles; else, civic unlocked: diplomatic service)
	local item_spiesUnlocked:TutorialItem = TutorialItem:new("SPIES_UNLOCKED")
	item_spiesUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_spiesUnlocked:SetIsEndOfChain(true)
	item_spiesUnlocked:SetIsQueueable(true)
	item_spiesUnlocked:SetShowPortrait(true)
	item_spiesUnlocked:SetRaiseEvents("DiplomaticServiceCivicCompleted")
	item_spiesUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_46")
	item_spiesUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_46")
	item_spiesUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_46")
		end)
	item_spiesUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNIT_SPY")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_46")
		end)
	item_spiesUnlocked:SetIsDoneFunction(
		function()
			return false
		end)
		
	-- Embassy unlocked. (civic completed: diplomatic service)
	local item_embassyUnlocked:TutorialItem = TutorialItem:new("EMBASSY_UNLOCKED")
	item_embassyUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_embassyUnlocked:SetIsEndOfChain(true)
	item_embassyUnlocked:SetIsQueueable(true)
	item_embassyUnlocked:SetShowPortrait(true)
	item_embassyUnlocked:SetRaiseEvents("DiplomaticServiceCivicCompleted")
	item_embassyUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_78")
	item_embassyUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_78")
	item_embassyUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_78")
		end)
	item_embassyUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "DIPLO_8")  -- Delegations and Embassies
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_78")
		end)
	item_embassyUnlocked:SetIsDoneFunction(
		function()
			return false
		end)
		
	-- Feudalism increased farming unlocked. (civic completed: feudalism)
	local item_feudalismUnlocked:TutorialItem = TutorialItem:new("FEUDALISM_UNLOCKED")
	item_feudalismUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_feudalismUnlocked:SetIsEndOfChain(true)
	item_feudalismUnlocked:SetIsQueueable(true)
	item_feudalismUnlocked:SetShowPortrait(true)
	item_feudalismUnlocked:SetRaiseEvents("FeudalismCivicCompleted")
	item_feudalismUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_76")
	item_feudalismUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_76")
	item_feudalismUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_76")
		end)
	--item_feudalismUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
	--	function(advisorInfo)
	--		LuaEvents.OpenCivilopedia("CONCEPTS", "DIPLO_4")
	--		LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
	--		UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_76")
	--	end)
	item_feudalismUnlocked:SetIsDoneFunction(
		function()
			return false
		end)
		
	-- National parks unlocked. (civic completed: conservation)
	local item_nationalParksUnlocked:TutorialItem = TutorialItem:new("NATIONALPARKS_UNLOCKED")
	item_nationalParksUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_nationalParksUnlocked:SetIsEndOfChain(true)
	item_nationalParksUnlocked:SetIsQueueable(true)
	item_nationalParksUnlocked:SetShowPortrait(true)
	item_nationalParksUnlocked:SetRaiseEvents("ConservationCivicCompleted")
	item_nationalParksUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_79")
	item_nationalParksUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_79")
	item_nationalParksUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_79")
		end)
	item_nationalParksUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNIT_NATURALIST")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_79")
		end)
	item_nationalParksUnlocked:SetIsDoneFunction(
		function()
			return false
		end)

	-- Research Agreements unlocked. (tech completed: scientific theory)
	local item_researchAgreementsUnlocked:TutorialItem = TutorialItem:new("RESEARCH_AGREEMENTS_UNLOCKED")
	item_researchAgreementsUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_researchAgreementsUnlocked:SetIsEndOfChain(true)
	item_researchAgreementsUnlocked:SetIsQueueable(true)
	item_researchAgreementsUnlocked:SetShowPortrait(true)
	item_researchAgreementsUnlocked:SetRaiseEvents("ScientificTheoryResearchCompleted")
	item_researchAgreementsUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_81")
	item_researchAgreementsUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_81")
	item_researchAgreementsUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_81")
		end)
	item_researchAgreementsUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "DIPLO_10")  -- Research Agreements
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
--			UI.PlaySound("Play_ADVISOR_LINE_LISTENER_81")
		end)
	item_researchAgreementsUnlocked:SetIsDoneFunction(
		function()
			return false
		end)
	
	-- Resorts unlocked. (tech completed: radio)
	local item_resortsUnlocked:TutorialItem = TutorialItem:new("RESORTS_UNLOCKED")
	item_resortsUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_resortsUnlocked:SetIsEndOfChain(true)
	item_resortsUnlocked:SetIsQueueable(true)
	item_resortsUnlocked:SetShowPortrait(true)
	item_resortsUnlocked:SetRaiseEvents("RadioResearchCompleted")
	item_resortsUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_80")
	item_resortsUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_80")
	item_resortsUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_80")
		end)
	item_resortsUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("IMPROVEMENT_BEACH_RESORT")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_80")
		end)
	item_resortsUnlocked:SetIsDoneFunction(
		function()
			return false
		end)
	
	-- Linked Farms increased output unlocked. (tech completed: replaceable parts)
	local item_linkedFarmsUnlocked:TutorialItem = TutorialItem:new("REPLACEABLE_PARTS_UNLOCKED")
	item_linkedFarmsUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_linkedFarmsUnlocked:SetIsEndOfChain(true)
	item_linkedFarmsUnlocked:SetIsQueueable(true)
	item_linkedFarmsUnlocked:SetShowPortrait(true)
	item_linkedFarmsUnlocked:SetRaiseEvents("ReplaceablePartsResearchCompleted")
	item_linkedFarmsUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_77")
	item_linkedFarmsUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_77")
	item_linkedFarmsUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_77")
		end)
	--item_linkedFarmsUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
	--	function(advisorInfo)
	--		LuaEvents.OpenCivilopedia("CONCEPTS", "DIPLO_4")
	--		LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
	--		UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_77")
	--	end)
	item_linkedFarmsUnlocked:SetIsDoneFunction(
		function()
			return false
		end)

	-- Neighborhood district unlocked. (civic completed: urbanization)
	local item_neighborhoodUnlocked:TutorialItem = TutorialItem:new("NEIGHBORHOOD_UNLOCKED")
	item_neighborhoodUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_neighborhoodUnlocked:SetIsQueueable(true)
	item_neighborhoodUnlocked:SetShowPortrait(true)
	item_neighborhoodUnlocked:SetRaiseEvents("UrbanizationCivicCompleted")
	item_neighborhoodUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_43")
	item_neighborhoodUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_43")
	item_neighborhoodUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_43")
		end)
	item_neighborhoodUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("DISTRICT_NEIGHBORHOOD")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_43")
		end)
	item_neighborhoodUnlocked:SetIsDoneFunction(
		function()
			return false
		end)
	item_neighborhoodUnlocked:SetNextTutorialItemId("NEIGHBORHOOD_UNLOCKED_B")

	-- Neighborhood district unlocked tell me more
	local item_neighborhoodUnlockedB:TutorialItem = TutorialItem:new("NEIGHBORHOOD_UNLOCKED_B")
	item_neighborhoodUnlockedB:SetPrereqs("NEIGHBORHOOD_UNLOCKED");
	item_neighborhoodUnlockedB:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_neighborhoodUnlockedB:SetIsEndOfChain(true)
	item_neighborhoodUnlockedB:SetShowPortrait(true)
	item_neighborhoodUnlockedB:SetRaiseEvents("UrbanizationCivicCompleted")
	item_neighborhoodUnlockedB:SetAdvisorMessage("ADVISOR_LINE_LISTENER_70")
	item_neighborhoodUnlockedB:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_70")
	item_neighborhoodUnlockedB:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_70")
		end)
	item_neighborhoodUnlockedB:SetIsDoneFunction(
		function()
			return false
		end)

	-- First district becomes available. (tech completed: astrology, writing, bronze working, celestial navigation, currency, engineering)
	local item_districtUnlocked:TutorialItem = TutorialItem:new("DISTRICT_UNLOCKED")
	item_districtUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_districtUnlocked:SetIsEndOfChain(true)
	item_districtUnlocked:SetIsQueueable(true)
	item_districtUnlocked:SetShowPortrait(true)
	item_districtUnlocked:SetRaiseEvents("DistrictUnlocked")
	item_districtUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_20")
	item_districtUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_20")
	item_districtUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_20")
		end)
	item_districtUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "CITIES_10")  -- Districts
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_20")
		end)
	item_districtUnlocked:SetIsDoneFunction(
		function()
			return false
		end)

	-- Walls unlocked. (tech completed: masonry, castles, siege tactics)
	local item_wallsUnlocked:TutorialItem = TutorialItem:new("WALLS_UNLOCKED")
	item_wallsUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_wallsUnlocked:SetIsEndOfChain(true)
	item_wallsUnlocked:SetIsQueueable(true)
	item_wallsUnlocked:SetShowPortrait(true)
	item_wallsUnlocked:SetRaiseEvents("WallsUnlocked")
	item_wallsUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_23")
	item_wallsUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_23")
	item_wallsUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_23")
		end)
	item_wallsUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("BUILDING_WALLS")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_23")
		end)
	item_wallsUnlocked:SetIsDoneFunction(
		function()
			return false
		end)


	-- First envoy becomes available.
	local item_influenceToken:TutorialItem = TutorialItem:new("INFLUENCE_TOKEN")
	item_influenceToken:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_influenceToken:SetIsEndOfChain(true)
	item_influenceToken:SetIsQueueable(true)
	item_influenceToken:SetShowPortrait(true)
	item_influenceToken:SetRaiseEvents("HasInfluenceToken")
	item_influenceToken:SetAdvisorMessage("ADVISOR_LINE_LISTENER_16")
	item_influenceToken:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_16")
	item_influenceToken:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_16")
		end)
	item_influenceToken:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "CITYSTATES_4")  -- Envoys
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_16")
		end)
	item_influenceToken:SetIsDoneFunction(
		function()
			return false
		end)

	-- First time government/policy menu is opened. (currently triggers on first civic completed, which unlocks first policy)
	local item_policyUnlocked:TutorialItem = TutorialItem:new("POLICY_UNLOCKED")
	item_policyUnlocked:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_policyUnlocked:SetIsEndOfChain(true)
	item_policyUnlocked:SetIsQueueable(true)
	item_policyUnlocked:SetShowPortrait(true)
	item_policyUnlocked:SetRaiseEvents("CivicCompleted")
	item_policyUnlocked:SetAdvisorMessage("ADVISOR_LINE_LISTENER_4")
	item_policyUnlocked:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_4")
	item_policyUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_4")
		end)
	item_policyUnlocked:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "GOVT_2")  -- Policies
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_4")
		end)
	item_policyUnlocked:SetIsDoneFunction(
		function()
			return false
		end)


	-- First faith generated
	local item_faithChanged:TutorialItem = TutorialItem:new("FAITH_CHANGED")
	item_faithChanged:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_faithChanged:SetIsEndOfChain(true)
	item_faithChanged:SetIsQueueable(true)
	item_faithChanged:SetShowPortrait(true)
	item_faithChanged:SetRaiseEvents("FaithChanged")
	item_faithChanged:SetAdvisorMessage("ADVISOR_LINE_LISTENER_38")
	item_faithChanged:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_38")
	item_faithChanged:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_38")
		end)
	item_faithChanged:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "FAITH_2")  -- Earning Faith
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_38")
		end)
	item_faithChanged:SetIsDoneFunction(
		function()
			return false
		end)

	-- First pantheon available
	local item_pantheonFounded:TutorialItem = TutorialItem:new("PANTHEON_FOUNDED")
	item_pantheonFounded:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_pantheonFounded:SetIsEndOfChain(true)
	item_pantheonFounded:SetIsQueueable(true)
	item_pantheonFounded:SetShowPortrait(true)
	item_pantheonFounded:SetRaiseEvents("PantheonAvailable")
	item_pantheonFounded:SetAdvisorMessage("ADVISOR_LINE_LISTENER_39")
	item_pantheonFounded:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_39")
	item_pantheonFounded:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_39")
		end)
	item_pantheonFounded:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "FAITH_3")  -- Pantheons
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_39")
		end)
	item_pantheonFounded:SetIsDoneFunction(
		function()
			return false
		end)

	-- City-state discovered
	local item_cityStateDiscovered:TutorialItem = TutorialItem:new("CITY_STATE_DISCOVERED")
	item_cityStateDiscovered:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_cityStateDiscovered:SetIsQueueable(true)
	item_cityStateDiscovered:SetShowPortrait(true)
	item_cityStateDiscovered:SetRaiseEvents("DiplomacyMeet")
	item_cityStateDiscovered:SetAdvisorMessage("ADVISOR_LINE_LISTENER_51")
	item_cityStateDiscovered:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_51")
	item_cityStateDiscovered:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_51")
		end)
	item_cityStateDiscovered:SetIsDoneFunction(
		function()
			return false
		end)
	item_cityStateDiscovered:SetNextTutorialItemId("CITY_STATE_DISCOVERED_B");

	-- City-state discovered B
	local item_cityStateDiscoveredB:TutorialItem = TutorialItem:new("CITY_STATE_DISCOVERED_B")
	item_cityStateDiscoveredB:SetPrereqs("CITY_STATE_DISCOVERED");
	item_cityStateDiscoveredB:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_cityStateDiscoveredB:SetIsEndOfChain(true)
	item_cityStateDiscoveredB:SetShowPortrait(true)
	item_cityStateDiscoveredB:SetAdvisorMessage("ADVISOR_LINE_LISTENER_52")
	item_cityStateDiscoveredB:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_52")
	item_cityStateDiscoveredB:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_52")
		end)
	item_cityStateDiscoveredB:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "CITYSTATES_1")  -- Introduction
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_52")
		end)
	item_cityStateDiscoveredB:SetIsDoneFunction(
		function()
			return false
		end)

	-- Ranged unit built
	local item_rangedUnitBuilt:TutorialItem = TutorialItem:new("RANGED_UNIT_BUILT")
	item_rangedUnitBuilt:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_rangedUnitBuilt:SetIsEndOfChain(true)
	item_rangedUnitBuilt:SetIsQueueable(true)
	item_rangedUnitBuilt:SetShowPortrait(true)
	item_rangedUnitBuilt:SetRaiseEvents("RangedUnitProductionCompleted")
	item_rangedUnitBuilt:SetAdvisorMessage("ADVISOR_LINE_LISTENER_53")
	item_rangedUnitBuilt:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_53")
	item_rangedUnitBuilt:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_53")
		end)
	item_rangedUnitBuilt:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "COMBAT_5")  -- Unit Combat Statistics
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_53")
		end)
	item_rangedUnitBuilt:SetIsDoneFunction(
		function()
			return false
		end)

	-- Siege unit built
	local item_siegeUnitBuilt:TutorialItem = TutorialItem:new("SIEGE_UNIT_BUILT")
	item_siegeUnitBuilt:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_siegeUnitBuilt:SetIsEndOfChain(true)
	item_siegeUnitBuilt:SetIsQueueable(true)
	item_siegeUnitBuilt:SetShowPortrait(true)
	item_siegeUnitBuilt:SetRaiseEvents("SiegeUnitProductionCompleted")
	item_siegeUnitBuilt:SetAdvisorMessage("ADVISOR_LINE_LISTENER_54")
	item_siegeUnitBuilt:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_54")
	item_siegeUnitBuilt:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_54")
		end)
	item_siegeUnitBuilt:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "COMBAT_9")  -- City Combat
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_54")
		end)
	item_siegeUnitBuilt:SetIsDoneFunction(
		function()
			return false
		end)

	-- Unit moves into ZoC
	local item_zocUnitMoveComplete:TutorialItem = TutorialItem:new("ZOC_UNIT_MOVE_COMPLETE")
	item_zocUnitMoveComplete:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_zocUnitMoveComplete:SetIsEndOfChain(true)
	item_zocUnitMoveComplete:SetIsQueueable(true)
	item_zocUnitMoveComplete:SetShowPortrait(true)
	item_zocUnitMoveComplete:SetRaiseEvents("ZocUnitMoveComplete")
	item_zocUnitMoveComplete:SetAdvisorMessage("ADVISOR_LINE_LISTENER_12")
	item_zocUnitMoveComplete:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_12")
	item_zocUnitMoveComplete:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_12")
		end)
	item_zocUnitMoveComplete:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "MOVEMENT_3")  -- Zone of Control
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_12")
		end)
	item_zocUnitMoveComplete:SetIsDoneFunction(
		function()
			return false
		end)

	-- Player hasn't founded a second city after x turns
	local item_shouldFoundSecondCity:TutorialItem = TutorialItem:new("SHOULD_FOUND_SECOND_CITY")
	item_shouldFoundSecondCity:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_shouldFoundSecondCity:SetIsEndOfChain(true)
	item_shouldFoundSecondCity:SetIsQueueable(true)
	item_shouldFoundSecondCity:SetShowPortrait(true)
	item_shouldFoundSecondCity:SetRaiseEvents("ShouldFoundSecondCity")
	item_shouldFoundSecondCity:SetAdvisorMessage("ADVISOR_LINE_LISTENER_15")
	item_shouldFoundSecondCity:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_15")
	item_shouldFoundSecondCity:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function(advisorInfo)
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_15")
		end)
	item_shouldFoundSecondCity:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNIT_SETTLER")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_15")
		end)
	item_shouldFoundSecondCity:SetIsDoneFunction(
		function()
			return false
		end)

	-- Tips taken directly from tutorial non-sequential items:

	-- =============================== BARBARIAN_CAMP_DISCOVERED_A =====================================
	local item_barbarianCampDiscovered_A:TutorialItem = TutorialItem:new("BARBARIAN_CAMP_DISCOVERED_A");
	item_barbarianCampDiscovered_A:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_barbarianCampDiscovered_A:SetIsEndOfChain(true)
	item_barbarianCampDiscovered_A:SetIsQueueable(true)
	item_barbarianCampDiscovered_A:SetShowPortrait(true)
	item_barbarianCampDiscovered_A:SetRaiseEvents("BarbarianVillageDiscovered");
	item_barbarianCampDiscovered_A:SetAdvisorMessage("ADVISOR_LINE_2_ALT");
	item_barbarianCampDiscovered_A:SetAdvisorAudio("Play_ADVISOR_LINE_2_ALT");
	item_barbarianCampDiscovered_A:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function( advisorInfo )
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
			UI.PlaySound("Stop_ADVISOR_LINE_2_ALT")
		end );
	item_barbarianCampDiscovered_A:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "WORLD_6")  -- Barbarians
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_2_ALT")
		end)
	item_barbarianCampDiscovered_A:SetIsDoneFunction(
		function()
			return false;
		end );

	-- =============================== GOODY_HUT_DISCOVERED =====================================
	local item_goodyHutDiscovered:TutorialItem = TutorialItem:new("GOODY_HUT_DISCOVERED");
	item_goodyHutDiscovered:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_goodyHutDiscovered:SetIsEndOfChain(true)
	item_goodyHutDiscovered:SetIsQueueable(true)
	item_goodyHutDiscovered:SetShowPortrait(true)
	item_goodyHutDiscovered:SetRaiseEvents("GoodyHutDiscovered");
	item_goodyHutDiscovered:SetAdvisorMessage("ADVISOR_LINE_LISTENER_45");
	item_goodyHutDiscovered:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_45");
	item_goodyHutDiscovered:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function( advisorInfo )
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_45")
		end );
	item_goodyHutDiscovered:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "WORLD_5")  -- Tribal Villages
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_45")
		end)
	item_goodyHutDiscovered:SetIsDoneFunction(
		function()
			return false;
		end );

	-- =============================== CITY_POPULATION_CHANGED_A=====================================
	local item_populationChanged_A:TutorialItem = TutorialItem:new("CITY_POPULATION_CHANGED_A");
	item_populationChanged_A:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_populationChanged_A:SetIsEndOfChain(true)
	item_populationChanged_A:SetIsQueueable(true)
	item_populationChanged_A:SetShowPortrait(true)
	item_populationChanged_A:SetRaiseEvents("CityPopulationFirstChange");
	item_populationChanged_A:SetAdvisorMessage("ADVISOR_LINE_4_ALT");
	item_populationChanged_A:SetAdvisorAudio("Play_ADVISOR_LINE_4_ALT");
	item_populationChanged_A:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function( advisorInfo )
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
			UI.PlaySound("Stop_ADVISOR_LINE_4_ALT")
		end );
	item_populationChanged_A:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "CITIES_12")  -- Growth
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_4_ALT")
		end)
	item_populationChanged_A:SetIsDoneFunction(
		function()
			return false;
		end );

	-- =============================== BUILDER_CHARGES_DEPLETED =====================================
	local item_builderChargesDepleted:TutorialItem = TutorialItem:new("BUILDER_CHARGES_DEPLETED");
	item_builderChargesDepleted:SetTutorialLevel(TutorialLevel.LEVEL_CIV_FAMILIAR)
	item_builderChargesDepleted:SetIsEndOfChain(true)
	item_builderChargesDepleted:SetIsQueueable(true)
	item_builderChargesDepleted:SetShowPortrait(true)
	item_builderChargesDepleted:SetRaiseEvents("BuilderChargesDepleted");
	item_builderChargesDepleted:SetAdvisorMessage("ADVISOR_LINE_LISTENER_3");
	item_builderChargesDepleted:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_3");
	item_builderChargesDepleted:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function( advisorInfo )
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_3")
		end );
	item_builderChargesDepleted:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("UNIT_BUILDER")
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_3")
		end)
	item_builderChargesDepleted:SetIsDoneFunction(
		function()
			return false;
		end );

	-- =============================== NATURAL_WONDER_REVEALED =====================================
	local item_naturalWonderRevealed:TutorialItem = TutorialItem:new("NATURAL_WONDER_REVEALED");
	item_naturalWonderRevealed:SetTutorialLevel(TutorialLevel.LEVEL_TBS_FAMILIAR)
	item_naturalWonderRevealed:SetIsEndOfChain(true)
	item_naturalWonderRevealed:SetIsQueueable(true)
	item_naturalWonderRevealed:SetShowPortrait(true)
	item_naturalWonderRevealed:SetRaiseEvents("NaturalWonderPopupClosed");
	item_naturalWonderRevealed:SetAdvisorMessage("ADVISOR_LINE_LISTENER_1");
	item_naturalWonderRevealed:SetAdvisorAudio("Play_ADVISOR_LINE_LISTENER_1");
	item_naturalWonderRevealed:AddAdvisorButton("LOC_ADVISOR_BUTTON_OK",
		function( advisorInfo )
			LuaEvents.AdvisorPopup_ClearActive( advisorInfo );
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_1")
		end );
	item_naturalWonderRevealed:AddAdvisorButton("LOC_ADVISOR_BUTTON_TELL_ME_MORE",
		function(advisorInfo)
			LuaEvents.OpenCivilopedia("CONCEPTS", "WORLD_3")  -- Natural Wonders
			LuaEvents.AdvisorPopup_ClearActive(advisorInfo)
			UI.PlaySound("Stop_ADVISOR_LINE_LISTENER_1")
		end)
	item_naturalWonderRevealed:SetIsDoneFunction(
		function()
			return false;
		end );

end

-- This must exist here or be moved to TutorialUIRoot, which relies on it.
function GetUnitType( playerID: number, unitID : number )
	if( playerID == Game.GetLocalPlayer() ) then
		local pPlayer	:table = Players[playerID];
		local pUnit		:table = pPlayer:GetUnits():FindID(unitID);
		if pUnit ~= nil then
			return GameInfo.Units[pUnit:GetUnitType()].UnitType;
		end
	end
	return nil;
end
