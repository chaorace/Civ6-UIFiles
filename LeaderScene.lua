-- ************************************************************************************************************************
--	LeaderScene
--	Description:	A parallaxed UI scene with NO interaction, which sits underneath the 3d leader and 
--					the Diplomacy UI contexts 
--	Behavior:		This scene listens for a change in leader selection, changes the textures 
--					appropriately, and plays the parallax animation on new textures
--	Interacts With:	DiplomacyActionView, DiplomacyView, and DiplomacyDealView
-- ------------------------------------------------------------------------------------------------------------------------
include( "InstanceManager" );
include( "SupportFunctions" ); -- DarkenLightenColor

--	MEMBERS
local m_kBackgroundLayersIM	:table		= InstanceManager:new( "Layer",  "Background_Anim", Controls.Backgrounds );
local m_uiBackgroundLayers	: table = {};
local m_isViewInitialized	: boolean	= false;
local m_oldLeaderName       : string = "";
--	CONSTANTS
local PARALLAX_DISTANCE		: number	= 100;
local m_isTutorial			: boolean = false;

local TUTORIAL_ID				:string = "17462E0F-1EE1-4819-AAAA-052B5896B02A";

-- ------------------------------------------------------------------------------------------------------------------------
--	Parallax:		Simple function to tween a layered scene from left to right and simulate a simple parallax effect
--		distance:	The total distance in pixels that the layers should travel	
function Parallax(distance: number)
	SizeBackgrounds();
	local numLayers = table.count(m_uiBackgroundLayers);
	local spacing = distance/numLayers;
	local rightToLeft : boolean = false;
	for layer = numLayers,1,-1 do
		if (layer == numLayers) then												-- The Nth layer or "porthole" should be stationery, sized to the full size of the screen and centered
			m_uiBackgroundLayers[layer].Background_Anim:SetAnchor("C,C");
			m_uiBackgroundLayers[layer].Background_Image:SetAnchor("C,C");
			m_uiBackgroundLayers[layer].Background_Anim:ReprocessAnchoring();
			m_uiBackgroundLayers[layer].Background_Image:ReprocessAnchoring();
		else
			m_uiBackgroundLayers[layer].Background_Anim:SetBeginVal(-distance, 0);	-- The remaining layers should do the parallaxing behavior
			m_uiBackgroundLayers[layer].Background_Anim:SetEndVal(0, 0);
		end
		m_uiBackgroundLayers[layer].Background_Anim:SetSpeed(.2);
		m_uiBackgroundLayers[layer].Background_Anim:SetToBeginning();
		m_uiBackgroundLayers[layer].Background_Anim:Play();
		distance = distance-spacing;
	end
end

-- Creates the appropriate layers for the player_ID provided.
-- selectedPlayerID - the id of the leader whose background should be displayed
function GenerateLayers(selectedPlayerID:number)
	local playerConfig = PlayerConfigurations[selectedPlayerID];
	if (playerConfig ~= nil) then
		
		m_uiBackgroundLayers = {};
		m_kBackgroundLayersIM:ResetInstances();

		local leaderName = playerConfig:GetLeaderTypeName();
		local unloadTextures : boolean = m_oldLeaderName ~= leaderName;
		m_oldLeaderName = leaderName;

		local diplomacyInfo = GameInfo.DiplomacyInfo[leaderName];
		if diplomacyInfo and diplomacyInfo.BackgroundImage then
			local layer:table = CreateBackgroundLayer(diplomacyInfo.BackgroundImage, unloadTextures);
			table.insert(m_uiBackgroundLayers, layer);
		else
			local numLayers = GameInfo.Leaders[leaderName].SceneLayers;
			leaderName = string.gsub(leaderName, "LEADER_","");

			-- Safety fallback
			if (numLayers == 0) then
				leaderName = "CLEOPATRA";
				numLayers = 4;
			end

			for i=1, numLayers, 1 do
				local layer:table = CreateBackgroundLayer(leaderName.."_"..i, unloadTextures);
				table.insert(m_uiBackgroundLayers, layer);
			end
		end
	end
end

function CreateBackgroundLayer(texture:string, unloadTextures:boolean)
	local instance:table = m_kBackgroundLayersIM:GetInstance();
	if (unloadTextures) then
		instance.Background_Image:UnloadTexture();
	end
	instance.Background_Image:SetTexture(texture);
	return instance;
end

-- This function correctly sizes the background images.  Layers 1-3 are sized down vertically by 200 pixels so that most of the 
-- scene is visible within the letterboxing.  The last layer - the "porthole" - can be stretched to be the full size of the screen
function SizeBackgrounds()
	local numLayers = table.count(m_uiBackgroundLayers);
--	local adjustedWidth = adjustedY*1.9; -- TODO
	for layer = 1,numLayers,1 do
		if(not layer == numLayers) then
			m_uiBackgroundLayers[layer].Background_Anim:SetParentRelativeSizeY(-200);
			m_uiBackgroundLayers[layer].Background_Anim:ReprocessAnchoring();
			m_uiBackgroundLayers[layer].Background_Image:SetParentRelativeSizeY(-200);
			m_uiBackgroundLayers[layer].Background_Image:ReprocessAnchoring();
		end
	end
end

--	Displays the leader's name (with screen name if you are a human in a multiplayer game), along with the civ name,
--	and the icon of the civ with civ colors.  When you mouse over the civ icon, you should see a full list of all cities.
--	This should help players differentiate between duplicate civs.
function PopulateSignatureArea(player:table)
	-- Set colors for the Civ icon
	if (player ~= nil) then
		m_primaryColor, m_secondaryColor  = UI.GetPlayerColors( player:GetID() );
		local darkerBackColor = DarkenLightenColor(m_primaryColor,(-85),100);
		local brighterBackColor = DarkenLightenColor(m_primaryColor,90,255);
		Controls.CivBacking_Base:SetColor(m_primaryColor);
		Controls.CivBacking_Lighter:SetColor(brighterBackColor);
		Controls.CivBacking_Darker:SetColor(darkerBackColor);
		Controls.CivIcon:SetColor(m_secondaryColor);
	end

	-- Set the leader name, civ name, and civ icon data
	local leader:string = PlayerConfigurations[player:GetID()]:GetLeaderTypeName();
	if GameInfo.CivilizationLeaders[leader] == nil then
		UI.DataError("Banners found a leader \""..leader.."\" which is not/no longer in the game; icon may be whack.");
	else
		if(GameInfo.CivilizationLeaders[leader].CivilizationType ~= nil) then
			local civTypeName = GameInfo.CivilizationLeaders[leader].CivilizationType
			local civIconName = "ICON_"..civTypeName;
			Controls.CivIcon:SetIcon(civIconName);
			Controls.CivName:SetText(Locale.ToUpper(Locale.Lookup(GameInfo.Civilizations[civTypeName].Name)));
			local leaderName = Locale.ToUpper(Locale.Lookup(GameInfo.Leaders[leader].Name))
			local playerName = PlayerConfigurations[player:GetID()]:GetPlayerName();
			if GameConfiguration.IsAnyMultiplayer() and player:IsHuman() then
				leaderName = leaderName .. " ("..Locale.ToUpper(playerName)..")"
			end
			Controls.LeaderName:SetText(leaderName);

			--Create a tooltip which shows a list of this Civ's cities
			local civTooltip = Locale.Lookup(GameInfo.Civilizations[civTypeName].Name);
			local pPlayerConfig = PlayerConfigurations[player:GetID()];
			local playerName = pPlayerConfig:GetPlayerName();
			local playerCities = player:GetCities();
			if(playerCities ~= nil) then
				civTooltip = civTooltip .. "[NEWLINE]"..Locale.Lookup("LOC_PEDIA_CONCEPTS_PAGEGROUP_CITIES_NAME").. ":[NEWLINE]----------";
				for i,city in playerCities:Members() do
					civTooltip = civTooltip.. "[NEWLINE]".. Locale.Lookup(city:GetName());
				end
			end
			Controls.CivIcon:SetToolTipString(Locale.Lookup(civTooltip));
		end
	end
	Controls.SignatureStack:CalculateSize();
	Controls.SignatureStack:ReprocessAnchoring();
end

-- ------------------------------------------------------------------------------------------------------------------------
-- LUA EVENT HANDLING
-- Listen for a change in leader selection, and update the background images to correspond to it
function OnLeaderSelect(selectedPlayerID)
	PopulateSignatureArea(Players[selectedPlayerID]);
	GenerateLayers(selectedPlayerID);
	Parallax(PARALLAX_DISTANCE);
end
-- ------------------------------------------------------------------------------------------------------------------------
-- The DiploActionView is notifying us that the leader has loaded.
function OnSceneOpened(selectedPlayerID)
	if(selectedPlayerID ~= nil) then
		GenerateLayers(selectedPlayerID);
	end
	if (ContextPtr:IsHidden()) then
		ContextPtr:SetHide(false);
		InitializeView();
	end

	PopulateSignatureArea(Players[selectedPlayerID]);
	Controls.Signature_Slide:SetToBeginning();
	Controls.Signature_Alpha:SetToBeginning();
	Controls.Signature_Slide:Play();
	Controls.Signature_Alpha:Play();
end
-- ------------------------------------------------------------------------------------------------------------------------
--	InitializeView and UninitializeView
--	These functions allow us to wait until the leader is fully loaded before we show the context.
function InitializeView()
	if (not m_isViewInitialized) then
		m_isViewInitialized = true;
		if (m_isTutorial == false) then
			UIManager:DisablePopupQueue( true );		-- Enable once this added into Forge
		end
	end
end

function UninitializeView()
	if (m_isViewInitialized) then
		ContextPtr:SetHide(true);
		m_isViewInitialized = false;
		UIManager:DisablePopupQueue( false );		-- Enable once this added into Forge
	end
end

-- ------------------------------------------------------------------------------------------------------------------------
function Initialize()	
	SizeBackgrounds();
	LuaEvents.DiploScene_CinemaSequence.Add(OnLeaderSelect);
	LuaEvents.DiploScene_LeaderSelect.Add(OnLeaderSelect);
	LuaEvents.DiploScene_SceneClosed.Add(UninitializeView);
	LuaEvents.DiploScene_SceneOpened.Add(OnSceneOpened);
	UI.SetLeaderSceneControl(Controls.LeaderScene);

	local mods = Modding.GetActiveMods();
	if (mods ~= nil) then
		for i,v in ipairs(mods) do
			if v.Id == TUTORIAL_ID then
				m_isTutorial = true;
				break;
			end
		end
	end

end
Initialize();

