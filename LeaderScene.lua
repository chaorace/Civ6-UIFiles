-- ************************************************************************************************************************
--	LeaderScene
--	Description:	A parallaxed UI scene with NO interaction, which sits underneath the 3d leader and 
--					the Diplomacy UI contexts 
--	Behavior:		This scene listens for a change in leader selection, changes the textures 
--					appropriately, and plays the parallax animation on new textures
--	Interacts With:	DiplomacyActionView, DiplomacyView, and DiplomacyDealView
-- ------------------------------------------------------------------------------------------------------------------------
include( "InstanceManager" );
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
	--Controls.Backgrounds:SetOffsetX(0);
	SizeBackgrounds();
	local numLayers = table.count(m_uiBackgroundLayers);
	local spacing = distance/numLayers;
	local rightToLeft : boolean = false;
	for layer = numLayers-1,1,-1 do
		if (layer == numLayers) then
			m_uiBackgroundLayers[layer].Background_Anim:SetBeginVal(0, 0);
			m_uiBackgroundLayers[layer].Background_Anim:SetEndVal(distance, 0);
		else
			m_uiBackgroundLayers[layer].Background_Anim:SetBeginVal(-distance, 0);
			m_uiBackgroundLayers[layer].Background_Anim:SetEndVal(0, 0);
		end
		m_uiBackgroundLayers[layer].Background_Anim:SetSpeed(.2);
		m_uiBackgroundLayers[layer].Background_Anim:SetToBeginning();
		m_uiBackgroundLayers[layer].Background_Anim:Play();
		distance = distance-spacing;
	end
end

function GenerateLayers(selectedPlayerID)
	local playerConfig = PlayerConfigurations[selectedPlayerID];
	if (playerConfig ~= nil) then
		local leaderName = playerConfig:GetLeaderTypeName();
		local numLayers = GameInfo.Leaders[leaderName].SceneLayers;

		m_kBackgroundLayersIM:ResetInstances();
		m_uiBackgroundLayers = {};
		leaderName = string.gsub(leaderName, "LEADER_","")
		if (numLayers == 0) then
			leaderName = "CLEOPATRA";
			numLayers = 4;
		end

		local unloadTextures : boolean = m_oldLeaderName ~= leaderName;
		m_oldLeaderName = leaderName;

		for i=1, numLayers, 1 do
			local instance:table	= m_kBackgroundLayersIM:GetInstance();
			if (unloadTextures) then
				instance.Background_Image:UnloadTexture();
			end
			instance.Background_Image:SetTexture(leaderName.."_"..i);
			table.insert(m_uiBackgroundLayers, instance);
			if(i==numLayers) then
				--add an extra one in there
			end
		end
	end
end
-- ------------------------------------------------------------------------------------------------------------------------
--	ParallaxCinemaSequence:		Simple function to tween a layered scene from left to right and simulate a simple parallax effect. 
--					The cinema version of the parallax makes the leader sit more comfortably in the center of the scene.
--		distance:	The total distance in pixels that the layers should travel	
function ParallaxCinemaSequence(distance: number)
	SizeBackgrounds();
	local numLayers = table.count(m_uiBackgroundLayers);
	--Controls.Backgrounds:SetOffsetX(-distance*4);
	local spacing = distance/numLayers;
	for layer = numLayers,1,-1 do
		if (layer == numLayers) then
			m_uiBackgroundLayers[layer].Background_Anim:SetBeginVal(0, 0);
			m_uiBackgroundLayers[layer].Background_Anim:SetEndVal(distance, 0);
		else
			m_uiBackgroundLayers[layer].Background_Anim:SetBeginVal(-distance*4, 0);
			m_uiBackgroundLayers[layer].Background_Anim:SetEndVal(-distance*2, 0);
		end
		
		m_uiBackgroundLayers[layer].Background_Anim:SetSpeed(.5);
		m_uiBackgroundLayers[layer].Background_Anim:SetToBeginning();
		m_uiBackgroundLayers[layer].Background_Anim:Play();
		distance = distance-spacing;
	end
end

function SizeBackgrounds()
	local _, screenY:number = UIManager:GetScreenSizeVal();
	local numLayers = table.count(m_uiBackgroundLayers);
	local adjustedWidth = screenY*1.9;
	for layer = 1,numLayers,1 do
		if (layer == numLayers) then
			adjustedWidth= adjustedWidth+400;
		end
		m_uiBackgroundLayers[layer].Background_Anim:SetSizeVal(adjustedWidth,screenY);
		m_uiBackgroundLayers[layer].Background_Anim:ReprocessAnchoring();
		m_uiBackgroundLayers[layer].Background_Image:SetSizeVal(adjustedWidth,screenY);
		m_uiBackgroundLayers[layer].Background_Image:ReprocessAnchoring();
	end
end

-- ------------------------------------------------------------------------------------------------------------------------
-- LUA EVENT HANDLING
-- Listen for a change in leader selection, and update the background images to correspond to it
function OnLeaderSelect(selectedPlayerID)
	GenerateLayers(selectedPlayerID);
	Parallax(PARALLAX_DISTANCE);
end

-- Listen for a cinema sequence, and parallax the scene accordingly
function OnLeaderCinema(selectedPlayerID)
	GenerateLayers(selectedPlayerID);
	Parallax(PARALLAX_DISTANCE);
	--ParallaxCinemaSequence(PARALLAX_DISTANCE);
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
	LuaEvents.DiploScene_CinemaSequence.Add(OnLeaderCinema);
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

