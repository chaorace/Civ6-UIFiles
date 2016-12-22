include( "ToolTipHelper_PlayerYields" );

local YIELD_PADDING_Y	= 12;

-- ===========================================================================
function RefreshYields()
	-- This panel should only show at minispec
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	if (screenY > 768 ) then
		Controls.YieldsContainer:SetHide(true);
		return;
	end

	local ePlayer		:number = Game.GetLocalPlayer();
	local localPlayer	:table= nil;
	if ePlayer ~= -1 then
		localPlayer = Players[ePlayer];
		if localPlayer == nil then
			return;
		end
	else
		return;
	end

	---- SCIENCE ----
	local playerTechnology		:table	= localPlayer:GetTechs();
	local currentScienceYield	:number = playerTechnology:GetScienceYield();
	Controls.SciencePerTurn:SetText( FormatValuePerTurn(currentScienceYield) );	

	Controls.ScienceBacking:SetToolTipString( GetScienceTooltip() );
	Controls.ScienceStack:CalculateSize();
	Controls.ScienceBacking:SetSizeX(Controls.ScienceStack:GetSizeX() + YIELD_PADDING_Y);

	---- GOLD ----
	local playerTreasury:table	= localPlayer:GetTreasury();
	local goldYield		:number = playerTreasury:GetGoldYield() - playerTreasury:GetTotalMaintenance();
	local goldBalance	:number = math.floor(playerTreasury:GetGoldBalance());
	Controls.GoldBalance:SetText( Locale.ToNumber(goldBalance, "#,###.#") );	
	Controls.GoldPerTurn:SetText( FormatValuePerTurn(goldYield) );	

	Controls.GoldBacking:SetToolTipString( GetGoldTooltip() );

	Controls.GoldStack:CalculateSize();	
	Controls.GoldBacking:SetSizeX(Controls.GoldStack:GetSizeX() + YIELD_PADDING_Y);

	-- Size yields in first column to match largest
	if Controls.GoldBacking:GetSizeX() > Controls.ScienceBacking:GetSizeX() then
		-- Gold is wider so size Science to match
		Controls.ScienceBacking:SetSizeX(Controls.GoldBacking:GetSizeX());
	else
		-- Science is wider so size Gold to match
		Controls.GoldBacking:SetSizeX(Controls.ScienceBacking:GetSizeX());
	end
	
	---- CULTURE----
	local playerCulture			:table	= localPlayer:GetCulture();
	local currentCultureYield	:number = playerCulture:GetCultureYield();
	Controls.CulturePerTurn:SetText( FormatValuePerTurn(currentCultureYield) );	

	Controls.CultureBacking:SetToolTipString( GetCultureTooltip() );
	Controls.CultureStack:CalculateSize();
	Controls.CultureBacking:SetSizeX(Controls.CultureStack:GetSizeX() + YIELD_PADDING_Y);

	---- FAITH ----
	local playerReligion		:table	= localPlayer:GetReligion();
	local faithYield			:number = playerReligion:GetFaithYield();
	local faithBalance			:number = playerReligion:GetFaithBalance();
	Controls.FaithBalance:SetText( Locale.ToNumber(faithBalance, "#,###.#") );	
	Controls.FaithPerTurn:SetText( FormatValuePerTurn(faithYield) );

	Controls.FaithBacking:SetToolTipString( GetFaithTooltip() );

	Controls.FaithStack:CalculateSize();	
	Controls.FaithBacking:SetSizeX(Controls.FaithStack:GetSizeX() + YIELD_PADDING_Y);

	-- Size yields in second column to match largest
	if Controls.FaithBacking:GetSizeX() > Controls.CultureBacking:GetSizeX() then
		-- Faith is wider so size Culture to match
		Controls.CultureBacking:SetSizeX(Controls.FaithBacking:GetSizeX());
	else
		-- Culture is wider so size Faith to match
		Controls.FaithBacking:SetSizeX(Controls.CultureBacking:GetSizeX());
	end

	Controls.YieldsContainer:SetHide(false);
	Controls.YieldsContainer:ReprocessAnchoring();

	if Controls.ModalScreenClose ~= nil then
		Controls.ModalScreenClose:Reparent();
	end
end

-- ===========================================================================
function FormatValuePerTurn( value:number )
	if(value == 0) then
		return Locale.ToNumber(value);
	else
		return Locale.Lookup("{1: number +#,###.#;-#,###.#}", value);
	end
end