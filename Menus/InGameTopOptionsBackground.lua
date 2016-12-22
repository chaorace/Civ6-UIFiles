-- ===========================================================================
--	InGameTopOptionsBackground
-- ===========================================================================


function OnHide(bAlpha:boolean)
	if(bAlpha) then
		Controls.AlphaIn:Reverse();
		Controls.PauseWindowClose:SetToBeginning();
		Controls.PauseWindowClose:Play();
	else
		ShutdownAfterClose();
	end
end

function ShutdownAfterClose()
	ContextPtr:SetHide(true);
end
Controls.PauseWindowClose:RegisterEndCallback(ShutdownAfterClose);

function OnShow(bAlpha:boolean)
	if(ContextPtr:IsHidden()) then
		if(bAlpha) then
			Controls.AlphaIn:SetToBeginning();
			Controls.AlphaIn:Play();
		else
			Controls.AlphaIn:SetToEnd();
		end
		ContextPtr:SetHide(false);
		if(GameConfiguration.IsHotseat()) then
			Controls.HotseatBackground:SetHide(false);
			Controls.NormalBackground:SetHide(true);
		else
			Controls.NormalBackground:SetHide(false);
			Controls.HotseatBackground:SetHide(true);
		end
	end
end


function HideFromPlayerChange()
	OnHide(false);
end
function HideFromOptions()
	OnHide(true);
end
function ShowFromPlayerChange()
	OnShow(false);
end
function ShowFromOptions()
	OnShow(true);
end
-- ===========================================================================
function Initialize()
	LuaEvents.InGameTopOptionsMenu_Close.Add( HideFromOptions );
	LuaEvents.InGameTopOptionsMenu_Show.Add( ShowFromOptions );
	LuaEvents.PlayerChange_Close.Add( HideFromPlayerChange );
	LuaEvents.PlayerChange_Show.Add( ShowFromPlayerChange );
end
Initialize();