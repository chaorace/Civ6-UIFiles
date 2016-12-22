-- ===========================================================================
--	PopupDialogSupport
--
--	Allows for a "Are You Sure" or other confirmation dialog.
--	This logic can be used with a custom dialog and it also drives the PopupGeneric dialog.
--
--	Example 1:
--		-- Standard Ok/Cancel dialog
--		local m_kPopupDialog = PopupDialog:new( "MyOwnPopupDialog" )
--		m_kPopupDialog:ShowOkCancelDialog("This will just dismiss", OnOkay, OnCancel);
--
--	Example 2:
--		-- Build a custom dialog
--		local kDialog:table = PopupDialog:new( "MyCustomPopupDialog" );
--		kDialog:AddText("What is your favorite meta-syntatic variable?");
--		kDialog:AddButton("Foo", function() print("Foo pressed"); end );
--		kDialog:AddButton("Bar", function() print("Bar pressed"); end );
--		kDialog:Open();
--
--	Example 3:
--		-- Build a super custom styled dialog inline to your context.
--		local kDialog:table = PopupDialogLogic:new( "MyCustomPopupDialog", Controls.MyMainGridArea, Controls.AStackToHoldTheStuff );
--		kDialog:SetInstanceNames( "PopupButtonInstance", "Button", "PopupTextInstance", "Text", "RowInstance", "Row");
--		kDialog:AddText("Press something?");
--		kDialog:AddButton("Something", function() print("Something pressed"); end );
--		kDialog:Open();
--
--	Original Author: Tronster
-- ===========================================================================


-- ===========================================================================
--	Action Hotkeys
-- ===========================================================================
local m_actionHotkeyPopupAccept		:number = Input.GetActionId("PopupAccept");
local m_actionHotkeyPopupActivate	:number = Input.GetActionId("PopupActivate");
local m_actionHotkeyPopupCancel		:number = Input.GetActionId("PopupCancel");



-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

PopupDialog = {

	-- ===========================================================================
	--	 Constructor
	-- ===========================================================================
	new = function( self:table, id:string )
		print("Creating PopupDialog '"..id.."'");
		local o = {};
		setmetatable(o, self);
		self.__index	= self;
		o.m_id			= id;
		o.m_options		= {};
		o.m_functions	= {};
		o.m_functionID	= 0;
		return o;
	end,

	-- ===========================================================================
	--	 Create text
	-- ===========================================================================
	AddText = function( self:table, message:string )
		self.m_options[table.count(self.m_options)+1] = {Type="Text", Content=message};
	end,

	-- ===========================================================================
	--	 Create title
	--	 Can only be one of these; if more than one is set, last one wins.
	-- ===========================================================================
	AddTitle = function( self:table, message:string )
		self.m_options[table.count(self.m_options)+1] = {Type="Title", Content=message};
	end,

	-- ===========================================================================
	--	 Create a button
	-- ===========================================================================
	AddButton = function( self:table, label:string, callbackFunction:ifunction )

		-- Since functions cannot call across contexts, save function in this context and make a string key
		-- value that can be passed across and matched back up.
		local callbackID:string = "callback_" .. tostring(self.m_functionID);
		self.m_functions[callbackID] = callbackFunction;
		self.m_functionID = self.m_functionID + 1;
		
		self.m_options[table.count(self.m_options)+1] = {Type="Button", Content=label, CallbackString=callbackID};
	end,

	-- ===========================================================================
	--	 Create a count down timer
	-- ===========================================================================
	AddCountDown = function( self:table, startValue:number, callbackFunction:ifunction )

		-- Since functions cannot call across contexts, save function in this context and make a string key
		-- value that can be passed across and matched back up.
		self.m_functions["callbackCountDownTimer"] = callbackFunction;
		self.m_options[table.count(self.m_options)+1] = {Type="Count", Content=startValue, CallbackString="callbackCountDownTimer"};
	end,

	-- ===========================================================================
	--	 Open the generic dialog
	-- ===========================================================================
	Open = function( self:table )
		LuaEvents.RaisePopupGeneric(self.m_id, self.m_options);
		self.m_options = {};
		self.m_functionID = 0;

		-- Catches callback from the generic popup context.
		function OnGenericPopupCallbackHandler(popupID:string, callbackID:string) 
			if popupID == self.m_id then				-- If same context
				if self.m_functions[callbackID] ~= nil then
					self.m_functions[callbackID]();			-- Lookup function from hash and call it.	
				end
				-- If there was no callback function, just let it pass as this is valid, likely just dismissing the dialog which auto-closes.
				
				-- Stop listening, new "Add" will occur on the next Open().
				LuaEvents.CallbackPopupGeneric.Remove( OnGenericPopupCallbackHandler );
			end			
		end

		LuaEvents.CallbackPopupGeneric.Add( OnGenericPopupCallbackHandler );
	end,
	
	-- ===========================================================================
	--	Utility Helper
	--	Create a dialog with an "ok" button.
	-- ===========================================================================
	ShowOkDialog = function( self:table, text:string, callbackOk:ifunction )
		self.m_options = {};
		self:AddText( text );
		self:AddButton( Locale.Lookup("LOC_OK"), callbackOk );
		self:Open( self.m_id );
	end,
	
	-- ===========================================================================
	--	Utility Helper
	--	Create a dialog with an "ok" and "cancel" buttons.
	-- ===========================================================================
	ShowOkCancelDialog = function( self:table, text:string, callbackOk:ifunction, callbackCancel:ifunction )
		self.m_options = {};
		self:AddText( text );
		self:AddButton( Locale.Lookup("LOC_CANCEL"),callbackCancel );
		self:AddButton( Locale.Lookup("LOC_OK"), callbackOk );
		self:Open( self.m_id );
	end	
}



PopupDialogLogic = 
{
	include("InstanceManager");

	-- ===========================================================================
	--	Constructor
	--
	--	ARGS:	id					Idenitifer of the popup dialog.
	--			mainControl			The most parent control of the whole dialog
	--			stackControl		The stack containing all controls for sizing.
	--			optionalTitle		The control for title of the dialog - Defaults to "Are you sure?"
	--
	--	RETURNS: PopupDialog object
	-- ===========================================================================
	new = function( self:table, id:string, mainControl:table, stackControl:table, optionalTitle:table  )

		if stackControl	== nil	then stackControl = Controls.PopupStack; end
		-- Bail if minimum set of controls are found or explicitly set.
		if stackControl == nil then 		
			UI.DataError("No dialog stack was passed in to PopupDialogSupport for '"..id.."' and the default, Controls.PopupStack, also didn't exist in the context.");
			return nil;
		end


		local o = {};
		setmetatable(o, self);
		self.__index		= self;
		o.m_id				= id;
		o.m_pMainControl	= mainControl;
		o.m_pStackControl	= stackControl;
		o.m_kAnimsOnOpen	= {};

		if (optionalTitle ~= nil) then
			o.m_pTitle		= optionalTitle;
		end

		return o;
	end,

	-- ===========================================================================
	--	Sets the name of the instance objects to be used when constructing pieces
	--	for a popup dialog.
	--
	--	ARGS:	buttonInstanceName		Name of the instance to create for buttons.
	--			buttonTopControlName	Name of the top control in the button instance.
	--			textInstanceName		Name of the instance to create for text.
	--			textTopControlName		Name of the top control in the text instance.
	--			rowInstanceName			Name of the instance to create a row for buttons
	--			rowTopControlName		Name of the top control in the row instance.
	-- ===========================================================================
	SetInstanceNames = function( o:table, buttonInstanceName:string, buttonTopControlName:string, textInstanceName:string, textTopControlName:string, rowInstanceName:string, rowTopControlName:string )

		-- Look for default named items if explicit ones aren't passed in.
		if buttonInstanceName == nil	then buttonInstanceName = "PopupButtonInstance"; end
		if buttonTopControlName == nil	then buttonTopControlName = "Button"; end
		if rowInstanceName == nil		then rowInstanceName = "RowInstance"; end
		if rowTopControlName == nil		then rowTopControlName = "Row"; end
		if textInstanceName == nil		then textControl = "PopupText"; end
		if textTopControlname == nil	then textTopControlname = "Text"; end
		
		o.m_pRowStackControl	= rowControl;
		o.m_buttonTopControlName= buttonTopControlName;
		o.m_textTopControlName	= textTopControlName;
		o.m_rowTopControlName	= rowTopControlName;
		o.m_buttonInstanceName	= buttonInstanceName;
		o.m_kTextIM				= InstanceManager:new( textInstanceName,textTopControlName,	o.m_pStackControl );
		o.m_kRowStackIM			= InstanceManager:new( rowInstanceName,	rowTopControlName,	o.m_pStackControl );
		o.m_kCountDownIM		= nil;	-- Most dialogs don't use a timer; delay IM creation until needed.
		o.m_pRowInstance		= nil;
		o.m_openOptionalDebugId = "";
		o.m_uiControls			= {};

		-- Immediate attempt to create instances (and destroy) to ensure they are valid.
		o.m_kTextIM:GetInstance();
		o.m_kTextIM:ResetInstances();
		o.m_kRowStackIM:GetInstance();
		o.m_kRowStackIM:ResetInstances();
	end,

	-- ===========================================================================
	--	Animation controls to play when a dialog is opened.
	--	ARGS:	N# of animation controls to play.
	-- ===========================================================================
	SetOpenAnimationControls = function ( o:table, ... )
		for i,pControl in ipairs(arg) do
			if pControl.Play ~= nil then
				table.insert(o.m_kAnimsOnOpen, pControl );
			else
				UI.DataError("Cannot add control '"..tostring(pControl:GetID()).."' to play animation on generic dialog open; no play() function.");
			end
		end
	end,

	-- ===========================================================================
	--	Add a title to the dialog box
	--		ARGS:	title - the pre-localized string to assign to the title control
	--				optionalTitleControl - if the user did not already set up the 
	--					initially in the constructor, it can be specified here.
	-- ===========================================================================
	AddTitle = function( self:table, title:string, optionalTitleControl:table)
		if (optionalTitleControl ~= nil) then
			self.m_pTitle = optionalTitleControl;
		end
		if (self.m_pTitle == nil) then
			UI.DataError("A title was set without first having a control specified.  Try including the title control as a 2nd argument to AddTitle");
			return false;
		else
			self.m_pTitle:SetText( title );
		end
	end,

	-- ===========================================================================
	--	The prompt displayed
	-- ===========================================================================
	AddText = function( self:table, text:string )
		if self:IsOpen() then return false; end

		self.m_pRowInstance = nil;	-- Reset for first/new row of buttons later on.

		local pInstance:table = self.m_kTextIM:GetInstance();
		pInstance.GetTopControl():SetText( text );

		self.m_uiControls[table.count(self.m_uiControls)+1] = {
			Type	= "Text",
			Control	= pInstance[self.m_textTopControlName]
		};	-- Add to ordered list for later layout (type, actual instance)

		return true;
	end,

	-- ===========================================================================
	--	Create a button
	--	self						this popup dialog object
	--	label						String to print on button
	--	callback					function to call when pressed (or NIL to just close)
	--	optionalActivatedCommand	some string that when matched will "virtually" press button
	--	optionalToolTip				tooltip
	-- ===========================================================================
	AddButton = function( self:table, label:string, callback:ifunction, optionalActivateCommand:string, optionalToolTip:string, optionalAltButtonInstanceName: string )
		if self:IsOpen() then return false; end
				
		-- Build row instance manager if one doesn't exist.
		if self.m_pRowInstance == nil then
			self.m_pRowInstance = self.m_kRowStackIM:GetInstance();
			self.m_uiControls[table.count(self.m_uiControls)+1] = {Type="Row",Control=self.m_pRowInstance[self.m_rowTopControlName]};	-- Add to ordered list for later (type, actual instance)
		end

		local pInstance:table = {};
		local pInstanceName:string = "";
		if(optionalAltButtonInstanceName ~= nil) then
			pInstanceName = optionalAltButtonInstanceName;
		else
			pInstanceName = self.m_buttonInstanceName;
		end
		ContextPtr:BuildInstanceForControl( pInstanceName, pInstance, self.m_pRowInstance[self.m_rowTopControlName] );

		-- Ensure this is some type of button that can send callbacks.
		local pTopControl:table = pInstance[self.m_buttonTopControlName];
		if pTopControl.RegisterCallback == nil then
			UI.DataError("Unable to AddButon("..label.." ...) because top item in instance isn't a Button, ColorBoxButton, or a GridButton type!");
			ContextPtr:DestroyChild( pInstance);
			return;
		end

		-- Set the same mouseover button sound for all popup buttons
		pTopControl:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

		-- If no callback; create an empty one; then ensure close is called.
		if callback == nil then 
			callback = function() end 
		end;			
		local wrappedCallback:ifunction = 
			function() 
				callback(); 
				self:Close(); 
			end 

		self.m_uiControls[table.count(self.m_uiControls)+1] = {Type="Button", Control=pTopControl, Callback=wrappedCallback, Command=optionalActivateCommand};	-- Add to ordered list for later (type, actual instance)

		-- Set button label and callback with an injected "Close()"
		pTopControl:SetText(label);
		pTopControl:RegisterCallback(Mouse.eLClick, wrappedCallback );

		if optionalToolTip ~= nil and optionalToolTip ~= "" then
			pTopControl:SetToolTipString( optionalToolTip );
		end

		self.m_pRowInstance[self.m_rowTopControlName]:CalculateSize();
		self.m_pRowInstance[self.m_rowTopControlName]:ReprocessAnchoring();

		return true;
	end,

	-- ===========================================================================
	--	Assumes instance has a top level control of <Anim> with a <Label> inside. 
	AddCountDown = function( self:table,  startValue:number, callback:ifunction  )
		if self:IsOpen() then return false; end

		self.m_pRowInstance = nil;	-- Reset for first/new row of buttons later on.

		if self.m_kCountDownIM == nil then
			self.m_kCountDownIM = InstanceManager:new( "CountDownInstance",	"Anim", self.m_pStackControl );
		end

		local pInstance:table = self.m_kCountDownIM:GetInstance();

		-- If no callback; create an empty one; then ensure close is called.
		if callback == nil then 
			callback = function() end 
		end;			
		local wrappedCallback:ifunction = 
			function() 				
				callback(); 
				self:Close(); 
			end;

		pInstance.Text:SetText( tostring(startValue) );
		pInstance.Anim:RegisterEndCallback( 
			function()
				local value:number = tonumber( pInstance.Text:GetText() );
				value = value - 1;
				if value < 0 then
					pInstance.Anim:ClearEndCallback();
					wrappedCallback();
				else
					pInstance.Text:SetText( tostring(value) );
					pInstance.Anim:SetToBeginning();
					pInstance.Anim:Play();
				end
			end
		);

		self.m_uiControls[table.count(self.m_uiControls)+1] = {Type="Count", Control=pInstance.Anim, Callback=wrappedCallback};
		pInstance.Anim:Play();	-- To be super correct, have open() scan controls and if anim exists THEN kick off playing.

		return true;
	end,

	-- ===========================================================================
	SetSize = function( self:table, width:number, height:number )
		if self:IsOpen() then return false; end

		self.m_pStackControl:SetSizeVal(width,height);
	end,

	-- ===========================================================================
	Open = function( self:table, optionalDebugId:string )
		
		local newId	:string = (optionalDebugId ~= nil ) and optionalDebugId or self.m_id;
		if self:IsOpen() then 
			local currentId :string = (self.m_openOptionalDebugId ~= nil ) and self.m_openOptionalDebugId or self.m_id;			
			UI.DataError("(Temp assert to track open cases)... Attempt to open a common popup dialog that is already open. Current: '"..currentId.."'   new: '"..newId.."'");
			return false;
		end
		
		self.m_pMainControl:SetHide(false);

		-- If animation controls are set to play on open, now is the time...
		for _,pAnimationControl in ipairs( self.m_kAnimsOnOpen ) do
			pAnimationControl:SetToBeginning();
			pAnimationControl:Play();
		end

		self:_DoLayout();
		self.m_openOptionalDebugId = newId;
		return true;
	end,

	-- ===========================================================================
	Close = function( self:table )
		self.m_pMainControl:SetHide(true);
		self:Reset();
	end,

	-- ===========================================================================
	Reset = function( self:table )
		for _,value in ipairs(self.m_uiControls) do
			local type:string = value.Type;
			if value.Type == "Row" then
				value.Control:DestroyAllChildren();
			end
		end
		if self.m_kCountDownIM then self.m_kCountDownIM:DestroyInstances(); end
		self.m_kTextIM:DestroyInstances();
		self.m_kRowStackIM:DestroyInstances();
		self.m_pStackControl:CalculateSize();	
		self.m_pRowInstance = nil;
		self.m_uiControls = {};
	end,

	-- ===========================================================================
	IsOpen = function( self:table )		
		return (self.m_pMainControl:IsHidden() == false);
	end,

	-- ===========================================================================
	ActivateCommand = function( self:table, command:string )
		for _,uiControl in ipairs(self.m_uiControls) do
			if uiControl.Type == "Button" and uiControl.Command == command then
				uiControl.Callback();
				return true;
			end
		end		
		return false;
	end,

	-- ===========================================================================
	--	PRIVATE
	--	Layout contents based on buttons.
	-- ===========================================================================
	_DoLayout = function( self:table)

		self.m_pStackControl:CalculateSize();
		self.m_pStackControl:ReprocessAnchoring();
		self.m_pMainControl:ReprocessAnchoring();
	end,	
}
