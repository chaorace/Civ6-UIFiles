-- ===========================================================================
--
--	Show an 3d world-anchored arrow to point out a hex during the tutorial
--
-- ===========================================================================


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local m_textMargin		:number = 30;
local m_DefaultWidth	:number = 140;
local m_DefaultHeight	:number = 140;
local m_PositionOffsetX :number = 0;	--amount in pixels to offset the pointer on the X axis
local m_PositionOffsetY :number = 0;	--amount in pixels to offset the pointer on the Y axis


-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnShowWorldPointer( plotID:number, direction:string, offset:number, itemText:string )

	if plotID == -1 then
		UI.DataError("Cannot set tutorial world anchor due to invalid plot. itemText: '"..itemText.."'");
		return;
	end

	-- Set default parameters
	if direction == nil then	direction = "DOWN"; end
	if offset == nil then		offset = 0; end
	
	if direction ~= "UP" and direction ~= "RIGHT" and direction ~= "LEFT" and direction ~= "DOWN" then
		UI.DataError("Unknown direction '"..direction.."' setting to DOWN.  itemText: '"..itemText.."'");
		direction = "DOWN";
	end
	

	local pX, pY = Map.GetPlotLocation(plotID);
	local worldX : number, worldY : number, worldZ : number = UI.GridToWorld( pX, pY);
	Controls.Anchor:SetWorldPositionVal( worldX, worldY, worldZ );
	Controls.PointerRoot:SetOffsetVal(0,0);

	-- resize the text window if necessary
	Controls.LabelBox:SetHide( itemText == nil );
	if itemText ~= nil then		
		Controls.ItemText:SetText(itemText);
		local textWidth = Controls.ItemText:GetSizeX();
		local textHeight = Controls.ItemText:GetSizeY();
		if (textWidth + m_textMargin > m_DefaultWidth) then
			Controls.LabelBox:SetSizeX(textWidth + m_textMargin);
		else
			Controls.LabelBox:SetSizeX(m_DefaultWidth);
		end
		if (textHeight + m_textMargin > m_DefaultHeight) then
			Controls.LabelBox:SetSizeY(textHeight + m_textMargin);
		else
			Controls.LabelBox:SetSizeY(m_DefaultHeight);
		end
	end

	-- orient the text window and arrow pointer based on the direction and offset passed in
	Controls.DownArrow:SetHide(true);
	Controls.UpArrow:SetHide(true);
	Controls.RightArrow:SetHide(true);
	Controls.LeftArrow:SetHide(true);
	if (direction == "UP") then
		Controls.PointerRoot:SetOffsetY(offset);
		Controls.UpArrow:SetHide(false);
		Controls.LabelBox:SetOffsetX(0);
		Controls.LabelBox:SetOffsetY(Controls.LabelBox:GetSizeY() / 2 + 58);
	elseif (direction == "RIGHT") then
		Controls.PointerRoot:SetOffsetX(-offset);
		Controls.RightArrow:SetHide(false);
		Controls.LabelBox:SetOffsetX(-(Controls.LabelBox:GetSizeX() / 2 + 59));
		Controls.LabelBox:SetOffsetY(0);
	elseif (direction == "LEFT") then
		Controls.PointerRoot:SetOffsetX(offset);
		Controls.LeftArrow:SetHide(false);
		Controls.LabelBox:SetOffsetX(Controls.LabelBox:GetSizeX() / 2 + 59 );
		Controls.LabelBox:SetOffsetY(0);
	else	--assume DOWN
		Controls.PointerRoot:SetOffsetY(-offset);
		Controls.DownArrow:SetHide(false);
		Controls.LabelBox:SetOffsetX(0);
		Controls.LabelBox:SetOffsetY(-(Controls.LabelBox:GetSizeY() / 2 + 58));
	end

	ContextPtr:SetHide(false);
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnHideWorldPointer()
	ContextPtr:SetHide(true);
end


-- ===========================================================================
function Initialize()
	LuaEvents.TutorialUIRoot_ShowWorldPointer.Add( OnShowWorldPointer );
	LuaEvents.TutorialUIRoot_HideWorldPointer.Add( OnHideWorldPointer );
end
Initialize();
