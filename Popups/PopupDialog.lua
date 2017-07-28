--[[
-- Last modifed by Samuel Batista on Jun 28 2017
-- Original Author: Tronster
-- Copyright (c) Firaxis Games
--]]

include("LuaClass");
include("InstanceManager");

-- ===========================================================================
--	PopupDialog
--
--	Allows for a "Are You Sure" or other confirmation dialog.
--	This logic can be used with a custom dialog
--
--  PopupDialog creates a dialog inline to your context
--  PopupDialogInGame creates a dialog within the context of InGame
--  The following two examples use PopupDialog, but the same logic applies for PopupDialogInGame  
--
--	Example 1:
--		-- Standard Ok/Cancel dialog
--		local m_kPopupDialog = PopupDialog:new( "MyOwnPopupDialog" )
--		m_kPopupDialog:ShowOkCancelDialog("This will just dismiss", OnOkay, OnCancel);
--
--	Example 2:
--		-- Build a super custom styled dialog
--		local kDialog:table = PopupDialog:new( "MyCustomPopupDialog" );
--		kDialog:AddTtitle("Sexy Dialog Title");
--		kDialog:AddText("Press something?");
--		kDialog:AddButton("Something", function() print("Something pressed"); end );
--		kDialog:Open();
--
-- ===========================================================================

-- This class manages PopupDialog controls defined in PopupDialog.xml
PopupDialog = LuaClass:Extend()

-- Helper class to interface with InGamePopup context
PopupDialogInGame = LuaClass:Extend()

------------------------------------------------------------------
-- Class Constants
------------------------------------------------------------------
PopupDialog.TOP_CONTROL_ROW = "Row";
PopupDialog.TOP_CONTROL_TEXT = "Text";
PopupDialog.TOP_CONTROL_BUTTON = "Button";
PopupDialog.TOP_CONTROL_COUNTDOWN = "Anim";

PopupDialog.DEFAULT_INSTANCE_ROW = "PopupRowInstance";
PopupDialog.DEFAULT_INSTANCE_TEXT = "PopupTextInstance";
PopupDialog.DEFAULT_INSTANCE_BUTTON = "PopupButtonInstance";
PopupDialog.DEFAULT_INSTANCE_COUNTDOWN = "PopupCountDownInstance";

-- ===========================================================================
--	PopupDialog Constructor
--
--	ARGS:	id							Idenitifer of the popup dialog
--			myControls (optional)		A table containing at PopupRoot, PopupStack, PopupTitle, and other popup related controls
--
--	RETURNS: PopupDialog object
-- ===========================================================================
function PopupDialog:new( id:string, myControls:table )
	self = LuaClass.new(PopupDialog)
	
	self.ID				= id;
	self.Controls		= myControls or Controls;
	self.AnimsOnOpen	= {};
	self.PopupControls	= {};

	-- Set default size, instance names and animation behavior
	self:SetInstanceNames();
	self:SetOpenAnimationControls(Controls.PopupAlphaIn, Controls.PopupSlideIn);
	self:SetSize(400,200);
	
	return self;
end

-- ===========================================================================
--	Utility Helper
--	Create a dialog with an "ok" button.
-- ===========================================================================
function PopupDialog:ShowOkDialog( text:string, callbackOk:ifunction )
	self:Reset();
	self:AddText( text );
	self:AddButton( Locale.Lookup("LOC_OK"), callbackOk );
	self:Open();
end

-- ===========================================================================
--	Utility Helper
--	Create a dialog with an "ok" and "cancel" buttons.
-- ===========================================================================
function PopupDialog:ShowOkCancelDialog( text:string, callbackOk:ifunction, callbackCancel:ifunction )
	self:Reset();
	self:AddText( text );
	self:AddButton( Locale.Lookup("LOC_CANCEL"),callbackCancel );
	self:AddButton( Locale.Lookup("LOC_OK"), callbackOk );
	self:Open();
end

-- ===========================================================================
--	Add a title to the dialog box
--		ARGS:	title - the pre-localized string to assign to the title control
--				optionalTitleControl - if the user did not already set up the 
--					initially in the constructor, it can be specified here.
-- ===========================================================================
function PopupDialog:AddTitle(title:string)
	
	if self:IsOpen() then
		UI.DataError("Called AddTitle on an already opened PopupDialog: " .. self.ID);
		return;
	end

	if optionalTitleControl then
		self.Controls.PopupTitle = optionalTitleControl;
	end

	if self.Controls.PopupTitle then
		self.Controls.PopupTitle:SetText( title );
	else
		UI.DataError("A title was set without first having a control specified.  Try including the title control as a 2nd argument to AddTitle");
	end
end

-- ===========================================================================
--	The prompt displayed
-- ===========================================================================
function PopupDialog:AddText( text:string )
	
	if self:IsOpen() then
		UI.DataError("Called AddText on an already opened PopupDialog: " .. self.ID);
		return;
	end

	self.RowInstance = nil;	-- Reset for first/new row of buttons later on.

	local pTextControl:table = self.TextIM:GetInstance().GetTopControl();
	pTextControl:SetText( text );

	-- Add to ordered list for later layout (type, actual instance)
	table.insert(self.PopupControls, { Type = "Text", Control = pTextControl });
end

-- ===========================================================================
--	Create a button
--	self						this popup dialog object
--	label						String to print on button
--	callback					function to call when pressed (or NIL to just close)
--	optionalActivatedCommand	some string that when matched will "virtually" press button
--	optionalToolTip				tooltip
-- ===========================================================================
function PopupDialog:AddButton( label:string, callback:ifunction, optionalActivateCommand:string, optionalToolTip:string, optionalButtonInstanceName: string )
	
	if self:IsOpen() then
		UI.DataError("Called AddButton on an already opened PopupDialog: " .. self.ID);
		return;
	end
			
	-- Build row instance manager if one doesn't exist.
	local pTopControl:table;
	if self.RowInstance then
		pTopControl = self.RowInstance[self.RowTopControlName];
	else
		self.RowInstance = self.RowStackIM:GetInstance();
		pTopControl = self.RowInstance[self.RowTopControlName];
		table.insert(self.PopupControls, { Type = "Row", Control = pTopControl }); -- Add to ordered list for later (type, actual instance)
	end

	local pInstance:table = {};
	local buttonInstanceName:string = optionalButtonInstanceName and optionalButtonInstanceName or PopupDialog.DEFAULT_INSTANCE_BUTTON;
	ContextPtr:BuildInstanceForControl(buttonInstanceName, pInstance, pTopControl);

	-- Ensure this is some type of button that can send callbacks.
	local pButtonControl:table = pInstance[self.ButtonTopControlName];
	if not pButtonControl.RegisterCallback then
		UI.DataError("Unable to AddButon("..label.." ...) because top item in instance isn't a Button, ColorBoxButton, or a GridButton type!");
		ContextPtr:DestroyChild(pInstance);
		return;
	end

	-- Set button label and callback with an injected "Close()"
	pButtonControl:SetText(label);

	-- Set button tooltip (if any)
	if not optionalToolTip then optionalToolTip = ""; end
	pButtonControl:SetToolTipString( optionalToolTip );

	-- Set the same mouseover button sound for all popup buttons
	pButtonControl:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	-- Wrap callback in local function so we can close the popup before trigerring the callback
	local closeAndCallback:ifunction = function() self:Close(); if callback then callback(); end end
	pButtonControl:RegisterCallback(Mouse.eLClick, closeAndCallback);

	-- Add button to popup controls table so we can match activate commands to button callbacks
	table.insert(self.PopupControls, { Type = "Button", Control = pButtonControl, Callback = closeAndCallback, Command = optionalActivateCommand });

	-- Recalculate size of button container
	pTopControl:CalculateSize();
	pTopControl:ReprocessAnchoring();
end

-- ===========================================================================
--	Assumes instance has a top level control of <Anim> with a <Label> inside. 
function PopupDialog:AddCountDown(  startValue:number, callback:ifunction  )
	
	if self:IsOpen() then
		UI.DataError("Called AddCountDown on an already opened PopupDialog, ID: " .. self.ID);
		return;
	end

	self.RowInstance = nil;	-- Reset for first/new row of buttons later on.
	local pInstance:table = self.CountDownIM:GetInstance();

	-- If no callback; create an empty one; then ensure close is called.
	local closeAndCallback:ifunction = function() self:Close(); if callback then callback(); end end

	pInstance.Text:SetText( tostring(startValue) );
	pInstance.Anim:RegisterEndCallback( 
		function()
			local value:number = tonumber( pInstance.Text:GetText() );
			value = value - 1;
			if value < 0 then
				pInstance.Anim:ClearEndCallback();
				closeAndCallback();
			else
				pInstance.Text:SetText( tostring(value) );
				pInstance.Anim:SetToBeginning();
				pInstance.Anim:Play();
			end
		end
	);

	table.insert(self.PopupControls, { Type = "Count", Control = pInstance.Anim, Callback = closeAndCallback });
	pInstance.Anim:Play();	-- To be super correct, have open() scan controls and if anim exists THEN kick off playing.
end

-- ===========================================================================
function PopupDialog:SetSize( width:number, height:number )
	if self:IsOpen() then
		UI.DataError("Called SetSize on an already opened PopupDialog, ID: " .. self.ID);
		return;
	end
	self.Controls.PopupStack:SetSizeVal(width,height);
end

-- ===========================================================================
function PopupDialog:Open( optionalID:string )
	
	if self:IsOpen() then
		local ID:string = optionalID and optionalID or self.ID;
		UI.DataError("Attempt to open a popup dialog that is already open. ID: '" .. ID .. "'");
		return;
	end
	
	self.Controls.PopupRoot:SetHide(false);

	-- If animation controls are set to play on open, now is the time...
	for _,pAnimationControl in ipairs( self.AnimsOnOpen ) do
		pAnimationControl:SetToBeginning();
		pAnimationControl:Play();
	end

	self.Controls.PopupStack:CalculateSize();
	self.Controls.PopupStack:ReprocessAnchoring();
	self.Controls.PopupRoot:ReprocessAnchoring();
end

-- ===========================================================================
function PopupDialog:Close()
	self.Controls.PopupRoot:SetHide(true);
	self:Reset();
end

-- ===========================================================================
function PopupDialog:Reset()
	if self.Controls.PopupTitle then
		self.Controls.PopupTitle:SetText(Locale.ToUpper(Locale.Lookup("LOC_CONFIRM_CHOICE")));
	end

	for _,value in ipairs(self.PopupControls) do
		local type:string = value.Type;
		if value.Type == "Row" then
			value.Control:DestroyAllChildren();
		end
	end

	self.TextIM:ResetInstances();
	self.RowStackIM:ResetInstances();
	if self.CountDownIM then
		self.CountDownIM:ResetInstances();
	end
	self.Controls.PopupStack:CalculateSize();

	self.RowInstance = nil;
	self.PopupControls = {};
end

-- ===========================================================================
function PopupDialog:IsOpen()
	return self.Controls.PopupRoot:IsVisible();
end

-- ===========================================================================
function PopupDialog:ActivateCommand( command:string )
	for _,uiControl in ipairs(self.PopupControls) do
		if uiControl.Type == "Button" and uiControl.Command == command then
			uiControl.Callback();
			return;
		end
	end		
end

-- ===========================================================================
-- These next functions allow us to alter look and animation of Popup Dialogs.
-- ===========================================================================

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
function PopupDialog:SetInstanceNames( buttonInstanceName:string, buttonTopControlName:string, textInstanceName:string, textTopControlName:string, rowInstanceName:string, rowTopControlName:string, countDownInstanceName:string, countDownTopControlName:string )
	
	-- Look for default named items if explicit ones aren't passed in.
	self.RowTopControlName = rowTopControlName and rowTopControlName or PopupDialog.TOP_CONTROL_ROW;
	self.ButtonTopControlName = buttonTopControlName and buttonTopControlName or PopupDialog.TOP_CONTROL_BUTTON;

	-- We don't need to access these later, so it's ok to override the function parameters with default values.
	textTopControlName = textTopControlName and textTopControlName or PopupDialog.TOP_CONTROL_TEXT;
	countDownTopControlName = countDownTopControlName and countDownTopControlName or PopupDialog.TOP_CONTROL_COUNTDOWN;

	-- Setup instance managers with the newly updated instance names.
	self.TextIM = InstanceManager:new(textInstanceName and textInstanceName or PopupDialog.DEFAULT_INSTANCE_TEXT, textTopControlName, self.Controls.PopupStack);
	self.RowStackIM = InstanceManager:new(rowInstanceName and rowInstanceName or PopupDialog.DEFAULT_INSTANCE_ROW, self.RowTopControlName, self.Controls.PopupStack);
	self.CountDownIM = InstanceManager:new(countDownInstanceName and countDownInstanceName or PopupDialog.DEFAULT_INSTANCE_COUNTDOWN, countDownTopControlName, self.Controls.PopupStack);
end

-- ===========================================================================
--	Animation controls to play when a dialog is opened.
--	ARGS:	N# of animation controls to play.
-- ===========================================================================
function PopupDialog:SetOpenAnimationControls( ... )
	for i,pControl in ipairs(arg) do
		if pControl and pControl.Play then
			table.insert(self.AnimsOnOpen, pControl );
		elseif pControl then
			UI.DataError("Cannot add control '"..tostring(pControl:GetID()).."' to play animation on generic dialog open; no play() function.");
		end
	end
end


-- ===========================================================================
--	PopupDialogInGame Constructor
--
--	Original Author: Tronster
-- ===========================================================================
function PopupDialogInGame:new( id:string )
	local o:table = LuaClass.new(self)
	
	o.ID			= id;
	o.m_options		= {};
	
	return o;
end

-- ===========================================================================
function PopupDialogInGame:AddText( message:string )
	table.insert(self.m_options, { Type = "Text", Content = message });
end

-- ===========================================================================
--	 Can only be one of these; if more than one is set, last one wins.
-- ===========================================================================
function PopupDialogInGame:AddTitle( message:string )
	table.insert(self.m_options, { Type = "Title", Content = message });
end

-- ===========================================================================
function PopupDialogInGame:AddButton( label:string, callback:ifunction )
	table.insert(self.m_options, { Type = "Button", Content = label, Callback = callback });
end

-- ===========================================================================
function PopupDialogInGame:AddCountDown( startValue:number, callback:ifunction )
	table.insert(self.m_options, { Type = "Count", Content = startValue, Callback = callback });
end

-- ===========================================================================
function PopupDialogInGame:Open()
	LuaEvents.OnRaisePopupInGame(self.ID, self.m_options);
	self.m_options = {};
end

-- ===========================================================================
--	Utility Helper
--	Create a dialog with an "ok" button.
-- ===========================================================================
function PopupDialogInGame:ShowOkDialog( text:string, callbackOk:ifunction )
	self.m_options = {};
	self:AddText( text );
	self:AddButton( Locale.Lookup("LOC_OK"), callbackOk );
	self:Open( self.ID );
end

-- ===========================================================================
--	Utility Helper
--	Create a dialog with an "ok" and "cancel" buttons.
-- ===========================================================================
function PopupDialogInGame:ShowOkCancelDialog( text:string, callbackOk:ifunction, callbackCancel:ifunction )
	self.m_options = {};
	self:AddText( text );
	self:AddButton( Locale.Lookup("LOC_CANCEL"),callbackCancel );
	self:AddButton( Locale.Lookup("LOC_OK"), callbackOk );
	self:Open( self.ID );
end	