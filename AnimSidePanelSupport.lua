-- ===========================================================================
--	Contains scaffolding for animating in/out large panels from the side of
--	the screen.
-- ===========================================================================


function CreateScreenAnimation( slideAnimControl:table, onCloseCallback:ifunction )

	if slideAnimControl == nil then 
		error("Cannot create kAnim for "..ContextPtr:GetID()..", no slide animation control passed into create.");
		return nil;
	end

	local kAnim:table = {};
	kAnim["_animControl"] = slideAnimControl;
	kAnim["_closeCallback"] = onCloseCallback;

	-- ===========================================================================
	--	CONSTANTS
	-- ===========================================================================
	kAnim.TOP_BAR_SIZE = 30;

	-- ===========================================================================
	--	MEMBERS
	-- ===========================================================================
	kAnim.State = {
		Closed	= "CLOSED",
		In		= "IN",
		Open	= "OPEN",
		Out		= "OUT"
	};
	kAnim.m_state = kAnim.State.Closed;

	-- ===========================================================================
	--	Animate in 
	-- ===========================================================================
	kAnim.Show = function()
		if(kAnim.m_state ~= kAnim.State.Open and kAnim.m_state ~= kAnim.State.In) then
			kAnim.m_state = kAnim.State.In;
			ContextPtr:SetHide(false);
			kAnim["_animControl"]:SetToBeginning();
			kAnim["_animControl"]:RegisterEndCallback( kAnim.OnEndIn );
			kAnim["_animControl"]:Play();
		end
	end

	-- ===========================================================================
	--	Animate out
	-- ===========================================================================
	kAnim.Hide = function()
		if(kAnim.m_state ~= kAnim.State.Closed and kAnim.m_state ~= kAnim.State.Out) then
			kAnim.m_state = kAnim.State.Out;
			kAnim["_animControl"]:RegisterEndCallback( kAnim.OnEndOut );
			kAnim["_animControl"]:Reverse();
			if(kAnim["_closeCallback"] ~= nil) then
				kAnim["_closeCallback"]();
			end
		end
	end

	-- ===========================================================================
	--	Return whether panel is currently visible (or animating in)
	-- ===========================================================================
	kAnim.IsVisible = function()
		return kAnim.m_state == kAnim.State.Open or kAnim.m_state == kAnim.State.In;
	end

	-- ===========================================================================
	--	Callback when completeing a show.
	-- ===========================================================================
	kAnim.OnEndIn = function() 	
		kAnim.m_state = kAnim.State.Open;
		kAnim["_animControl"]:ClearEndCallback();	
	end

	-- ===========================================================================
	--	Callback when completeing a hide.
	-- ===========================================================================
	kAnim.OnEndOut = function() 
		kAnim.m_state = kAnim.State.Closed;
		kAnim["_animControl"]:ClearEndCallback();
		ContextPtr:SetHide(true); 	
	end

	-- ===========================================================================
	--	Resize area based on screen
	-- ===========================================================================
	kAnim.Resize = function()
		local width:number , height:number = UIManager:GetScreenSizeVal();
		kAnim["_animControl"]:SetSizeY( height - kAnim.TOP_BAR_SIZE );
	end
	
	-- ===========================================================================
	--	UI EVENT
	-- ===========================================================================
	kAnim.OnUpdateUI = function(type:number, tag:string, iData1:number, iData2:number, strData1:string)
		if type == SystemUpdateUI.ScreenResize then
			kAnim.Resize();
		end
	end

	-- ===========================================================================
	--	KEYBOARD INPUT UI EVENT
	-- ===========================================================================
	kAnim.OnInputHandler = function( input:table )
		if (input:GetMessageType() == KeyEvents.KeyUp and input:GetKey() == Keys.VK_ESCAPE) then
			kAnim.Hide();
			return true;
		end
		return false;
	end

	-- Resize after construction
	kAnim.Resize();

	return kAnim;
end