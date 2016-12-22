-- ===========================================================================
--	Tourism Banner Manager
-- ===========================================================================

include( "InstanceManager" );
include( "SupportFunctions" );

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local YOFFSET_2DVIEW				:number = 26;
local ZOFFSET_3DVIEW				:number = 36;

local TOURISM_SCORE_HIGH			:number = 16;
local TOURISM_SCORE_MED				:number = 8;
local TOURISM_SCORE_LOW				:number = 1;

-- The meta table definition that holds the function pointers
hstructure TourismBannerMeta
	-- Pointer back to itself.  Required.
	__index							: TourismBannerMeta

	new								: ifunction;
	destroy							: ifunction;
	Initialize						: ifunction;

	UpdatePosition					: ifunction;
	UpdateVisibility				: ifunction;

	Refresh							: ifunction;
end

-- The structure that holds the banner instance data
hstructure TourismBanner
	meta							: TourismBannerMeta;

	m_InstanceManager				: table;							-- The instance manager that made the control set.
    m_Instance						: table;							-- The instanced control set.

	m_PlayerID						:number;
	m_PlotID						:number;

	m_PlotX							:number;
	m_PlotY							:number;
end

-- ===========================================================================
--	MEMBERS
-- ===========================================================================

-- Create one instance of the meta object as a global variable with the same name as the data structure portion.  
-- This allows us to do a TourismBanner:new, so the naming looks consistent.
TourismBanner = hmake TourismBannerMeta {};

-- Link its __index to itself
TourismBanner.__index = TourismBanner;

-- Table of instances
local TourismBannerInstances : table = {};

-- Instance manager
local m_TourismBannerIM:table = InstanceManager:new( "TourismBannerInstance", "Anchor", Controls.TourismBanners );

local m_zoomMultiplier				:number = 1;
local m_prevZoomMultiplier			:number = 1;

-- ===========================================================================
-- constructor
-- ===========================================================================
function TourismBanner.new( self:TourismBannerMeta, playerID:number, plotID:number )
    local o = hmake TourismBanner {}; -- << Assign default values
    setmetatable( o, self );

	o:Initialize(playerID, plotID);

	if (TourismBannerInstances[playerID] == nil) then
		TourismBannerInstances[playerID] = {};
	end
	TourismBannerInstances[playerID][plotID] = o;
end

-- ===========================================================================
-- destructor
-- ===========================================================================
function TourismBanner.destroy( self:TourismBanner )
    if ( self.m_InstanceManager ~= nil ) then           
		if (self.m_Instance ~= nil) then
			self.m_InstanceManager:ReleaseInstance( self.m_Instance );
		end
    end
end

-- ===========================================================================
function TourismBanner.Initialize( self:TourismBanner, playerID:number, plotID:number )
	-- Store reference to instance manager
	self.m_InstanceManager = m_TourismBannerIM;

	-- Instantiate the banner
	self.m_Instance = self.m_InstanceManager:GetInstance();

	self.m_PlayerID = playerID;
	self.m_PlotID = plotID;

	local pPlot = Map.GetPlotByIndex(self.m_PlotID);
	self.m_PlotX = pPlot:GetX();
	self.m_PlotY = pPlot:GetY();

	self:Refresh();
end

-- ===========================================================================
function TourismBanner.UpdatePosition( self:TourismBanner )
	local yOffset = 0;	--offset for 2D strategic view
	local zOffset = 0;	--offset for 3D world view
	
	if (UI.GetWorldRenderView() == WorldRenderView.VIEW_2D) then
		yOffset = YOFFSET_2DVIEW;
		zOffset = 0;
	else
		yOffset = 0;
		yOffset = -25 + m_zoomMultiplier*25;
		zOffset = ZOFFSET_3DVIEW;
	end
	
	local worldX;
	local worldY;
	local worldZ;

	worldX, worldY, worldZ = UI.GridToWorld( self.m_PlotX, self.m_PlotY );
	self.m_Instance.Anchor:SetWorldPositionVal( worldX, worldY+yOffset, worldZ+zOffset );
end

-- ===========================================================================
function TourismBanner.UpdateVisibility( self:TourismBanner )
	-- Only show when the tourism lens is active
	if UILens.IsLayerOn( LensLayers.TOURIST_TOKENS ) then
		self.m_Instance.TourismBannerContainer:SetHide(false);
	else
		self.m_Instance.TourismBannerContainer:SetHide(true);
	end
end

-- ===========================================================================
function TourismBanner.Refresh( self:TourismBanner )
	-- Update number of tourists
	local pPlayer:table = Players[self.m_PlayerID];
	if pPlayer then
		local pPlayerCulture:table = pPlayer:GetCulture();
		if pPlayerCulture then
			-- Update number of tourists
			local numberOfTourists:number = pPlayerCulture:GetTouristsAt( self.m_PlotID );
			self.m_Instance.TouristsLabel:SetText(numberOfTourists);

			-- Update tooltip
			self.m_Instance.TourismTokenImage:SetToolTipString( pPlayerCulture:GetTourismTooltipAt( self.m_PlotID ) );
		
			-- Update tourism animation
			local backColor:number, frontColor:number  = UI.GetPlayerColors( self.m_PlayerID );
			local brighterBackColor = DarkenLightenColor(backColor,90,255);
			local tourismScore:number = pPlayerCulture:GetTourismAt( self.m_PlotID );
			if tourismScore >= TOURISM_SCORE_HIGH then
				-- High tourism
				self.m_Instance.HighTourismAnim:SetHide(false);
				self.m_Instance.HighTourismAnim:SetColor(brighterBackColor);
				self.m_Instance.MedTourismAnim:SetHide(true);
				self.m_Instance.LowTourismAnim:SetHide(true);
			elseif tourismScore >= TOURISM_SCORE_MED then
				-- Med tourism
				self.m_Instance.HighTourismAnim:SetHide(true);
				self.m_Instance.MedTourismAnim:SetHide(false);
				self.m_Instance.MedTourismAnim:SetColor(brighterBackColor);
				self.m_Instance.LowTourismAnim:SetHide(true);
			else
				-- Low tourism
				self.m_Instance.HighTourismAnim:SetHide(true);
				self.m_Instance.MedTourismAnim:SetHide(true);
				self.m_Instance.LowTourismAnim:SetHide(false);
				self.m_Instance.LowTourismAnim:SetColor(brighterBackColor);
			end

			-- Set glow color
			self.m_Instance.TourismBannerGlow:SetColor(backColor);
		end
	end

	self:UpdateVisibility();
	self:UpdatePosition();
end

-- ===========================================================================
function AddTourismBannerToMap( playerID:number, plotID:number )
	-- Don't add if we already have a instance for this player/plot
	if (TourismBannerInstances[playerID] ~= nil and
	    TourismBannerInstances[playerID][plotID] ~= nil) then
	    return;
    end
	
	TourismBanner:new( playerID, plotID );
end

-- ===========================================================================
function CreateTourismBanners( playerID:number )
	local pPlayer:table = Players[ playerID ];
	if pPlayer then
		local pPlayerCulture:table = pPlayer:GetCulture();
		if pPlayerCulture then
			local pPlayerCities:table = pPlayer:GetCities();
			for i, pCity in pPlayerCities:Members() do
				local pCityPlots:table = Map.GetCityPlots():GetPurchasedPlots( pCity );
				for _, plotID in ipairs(pCityPlots) do
					-- Create a tourism banner for any plot which has a greater than 0 tourism score
					local tourismValue:number = pPlayerCulture:GetTourismAt( plotID );
					if tourismValue > 0 then
						AddTourismBannerToMap( playerID, plotID );
					end
				end
			end
		end
	end	
end

-- ===========================================================================
function RefreshBanners()
	local players = Game.GetPlayers();
	for i, player in ipairs(players) do
		local playerID = player:GetID();
		if TourismBannerInstances[playerID] ~= nil then
			for i,instance in pairs(TourismBannerInstances[playerID]) do
				-- Check if we need to delete a banner because the plot no longer has any tourism value
				local shouldDelete:boolean = true;

				local pPlayer:table = Players[instance.m_PlayerID];
				if pPlayer then
					local pPlayerCulture:table = pPlayer:GetCulture();
					if pPlayerCulture then
						-- If we have a tourism value make sure we don't delete it and update the tourism value and number of tourists
						local tourismValue:number = pPlayerCulture:GetTourismAt( instance.m_PlotID );
						if tourismValue > 0 then
							shouldDelete = false;
							instance:Refresh();
						end
					end
				end
				
				-- Delete banner
				if shouldDelete then
					instance:destroy();
				end
			end
		end
	end
end

-- ===========================================================================
function RefreshBannerPositions()
	local players = Game.GetPlayers();
	for i, player in ipairs(players) do
		local playerID = player:GetID();
		if TourismBannerInstances[playerID] ~= nil then
			for i,instance in pairs(TourismBannerInstances[playerID]) do
				instance:UpdatePosition();
			end
		end
	end
end

-- ===========================================================================
function OnWorldRenderViewChanged()
	if UILens.IsLayerOn(LensLayers.TOURIST_TOKENS) then
		RefreshBannerPositions();
	end
end

-- ===========================================================================
function OnCameraUpdate()
	if UILens.IsLayerOn(LensLayers.TOURIST_TOKENS) then
		RefreshBannerPositions();
	end
end

-- ===========================================================================
function OnLensLayerOn( layerNum:number )		
	if layerNum == LensLayers.TOURIST_TOKENS then
		-- Add any new banners
		CreateTourismBanners( Game.GetLocalPlayer() );

		-- Refresh all banners
		RefreshBanners(false);
	end
end

-- ===========================================================================
function OnLensLayerOff( layerNum:number )
	if layerNum == LensLayers.TOURIST_TOKENS then
		RefreshBanners(false);
	end
end

-- ===========================================================================
function OnContextInitialize( isReload:boolean )	
	if isReload then
		if UILens.IsLayerOn( LensLayers.TOURIST_TOKENS ) then
			CreateTourismBanners( Game.GetLocalPlayer() );
			RefreshBanners(false);
		end
	end
end

-- ===========================================================================
function Initialize()
	Events.WorldRenderViewChanged.Add(	OnWorldRenderViewChanged );
	Events.Camera_Updated.Add( OnCameraUpdate );
	Events.LensLayerOn.Add(	OnLensLayerOn );
	Events.LensLayerOff.Add( OnLensLayerOff );

	ContextPtr:SetInitHandler( OnContextInitialize );
end
Initialize();