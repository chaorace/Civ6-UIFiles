-- ===========================================================================
function OnSetTabHeader( header:string )
	Controls.TabHeader:SetText(header);
end

-- ===========================================================================
--	Init
-- ===========================================================================
function OnInit()
	LuaEvents.WorldBuilderMapTools_SetTabHeader.Add( OnSetTabHeader );
end
ContextPtr:SetInitHandler( OnInit );
