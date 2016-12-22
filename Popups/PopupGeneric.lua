-- ===========================================================================
--	Popup for generic interactions
--
--	TO LISTEN:
--	Listen for LuaEvents.CallbackPopupGeneric();
--	Two parameters are passed:  i. the UniqueStringName   ii. the CallbackString
--
--	TO USE:
--	0. Ignore all this if you use PopupDialogSupport.lua
--	1. Open by: LuaEvents.RaisePopupGeneric( uniqueNameString, optionsTable);
--	2. The optionsTable is an ordered list of what appears.
--	3. Each item in the list is a table that contains:
--		{ Type, Content, (Options), (CallbackString) }
--	4. From an item, 'Type' can equal:
--		"Text"		- A blob of text, where 'Content' is the text.
--		"Button"	- Create a button with text on it, where 'Content' is the text.
--	4. From an item, Options is reserved for future use (likely formatting().)
--	5. From and item, 'CallbackString' is the string sent back to the caller
--	   when it's corresonding button is pressed.
--
--	EXAMPLE Setup:
--		local options:table = {};
--		options[1] = {Type="Text", Content="Are you sure you want to do that?"};
--		options[2] = {Type="Text", Content="Yes", CallbackString="chooseAccept"};
--		options[3] = {Type="Text", Content="No", CallbackString="chooseCancel"};
--		LuaEvents.RaisePopupGeneric( "WorldInputDestroyForest", options );
--
--	EXAMPLE Listener:
--	function OnPopupGeneric( id:string, value:string )
--		if id=="MySuperSpecialScreen" and value=="accept" then DoStuff(); end
--		if id=="MySuperSpecialScreen" and value=="cancel" then CancelStuff(); end
--	end
--	LuaEvents.PopupGeneric.Add( OnPopupGeneric );
--
-- ===========================================================================
include("PopupDialogSupport");


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local TXT_ARE_YOU_SURE	:string = Locale.Lookup("LOC_GENERIC_POPUP_ARE_YOU_SURE");
local TXT_ACCEPT		:string = Locale.Lookup("LOC_GENERIC_POPUP_ACCEPT");
local TXT_CANCEL		:string = Locale.Lookup("LOC_GENERIC_POPUP_CANCEL");
local TITLE_AREA_Y		:number = 30; -- The additional size to add to the popup height to accomodate the title


-- ===========================================================================j
--	MEMBERS
-- ===========================================================================
local m_kPopupDialog		:table;
local m_uniqueStringName	:string;
local m_options				:table;


-- ===========================================================================
function Close()
	UIManager:DequeuePopup( ContextPtr );
	m_options			= {};	
	m_uniqueStringName	= "_JUST_CLOSED:"..m_uniqueStringName;
end

-- ===========================================================================
function Realize()
	-- If no options were passed in, fill with generic options.
	if m_options == nil or table.count(m_options) == 0 then
		print("Using generic popup because no options were passed in!",m_uniqueStringName);
		m_options = {};
		m_options[1] = { Type="Text",	Content=TXT_ARE_YOU_SURE};
		m_options[2] = { Type="Button", Content=TXT_ACCEPT, CallbackString="accept"};
		m_options[3] = { Type="Button", Content=TXT_CANCEL, CallbackString="cancel"};
	end

	-- Assume the popup has no title until it is set
	Controls.PopupDialogWithTitle:SetHide(true);
	Controls.StackContents:SetOffsetY(-5);

	-- Populate	
	for i= 1, table.count(m_options), 1 do
		local option:table = m_options[i];
		local optionType:string = option.Type;
		if optionType ~= nil then
			if		optionType == "Text"	then m_kPopupDialog:AddText( option.Content );
			elseif	optionType == "Button"	then m_kPopupDialog:AddButton( option.Content, function() OnCallback( option.CallbackString ); end );
			elseif	optionType == "Count"	then m_kPopupDialog:AddCountDown( option.Content, function() OnCallback( option.CallbackString ); end );
			elseif	optionType == "Title"	then Controls.PopupDialogWithTitle:SetHide(false); Controls.PopupTitle:SetText(option.Content); Controls.StackContents:SetOffsetY(5);
			else
				UI.DataError("Unhandled type '"..optionType.."' for '"..m_uniqueStringName.."'");
			end
		else
			UI.DataError( "An option was passed to PopupGeneric without a Type specified for '"..m_uniqueStringName.."'" );
		end
	end

	-- Size internal contents to be small so autosize doesn't keep growing
	Controls.PopupDialogPlain:SetSizeVal( 10,10 );
	Controls.PopupDialogWithTitle:SetSizeVal( 10,10 );
	Controls.PopupDialog:ReprocessAnchoring();	

	-- Obtain actual size of dialog in autosize mode and appropriate set content's size.
	local size:table = Controls.PopupDialog:GetSize();
	Controls.PopupDialogPlain:SetSize( size );
	size.y = size.y + TITLE_AREA_Y;
	Controls.PopupDialogWithTitle:SetSize( size );

	Controls.StackContents:CalculateSize();
	Controls.StackContents:ReprocessAnchoring();	
	
	UIManager:QueuePopup( ContextPtr, PopupPriority.Current );
	m_kPopupDialog:Open();
end

-- ===========================================================================
--	Callback from a dialog button being pressed.
--	Raise an event for the rest of the contexts to listen to.
-- ===========================================================================
function OnCallback( callbackString:string )
	LuaEvents.CallbackPopupGeneric(m_uniqueStringName, callbackString);
	Close();	-- DialogSupport will already be closing when returning.
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnRaisePopupGeneric( uniqueStringName:string, options:table )
	m_uniqueStringName	= uniqueStringName;
	m_options			= options;
	Realize();
end

-- ===========================================================================
--	Input
--	UI Event Handler
-- ===========================================================================
function KeyHandler( key:number )
	if key == Keys.VK_ESCAPE then		
		Close();
		m_kPopupDialog:Close();
		return true;
	end
	return false;
end
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then return KeyHandler( pInputStruct:GetKey() ); end;
	return false;
end


-- ===========================================================================
function Test()

	local options:table = {};
	options[1] = {Type="Text",		Content="Oh no time is running out?"};
	options[2] = {Type="Count",		Content="5",	CallbackString="chooseAccept"};
	options[3] = {Type="Button",	Content="Yes",	CallbackString="chooseAccept"};
	--[[
	options[1] = {Type="Text", Content="Are you sure you want to do that?"};
	options[2] = {Type="Button", Content="Yes", CallbackString="chooseAccept"};
	options[3] = {Type="Button", Content="No", CallbackString="chooseCancel"};
	options[4] = {Type="Title", Content="Big Question"};
	]]
	LuaEvents.RaisePopupGeneric( "WorldInputDestroyForest", options );	--Test with options
	--LuaEvents.RaisePopupGeneric( "Test" );	-- Test default creation
	--[[
	local pPopupDialog :table = PopupDialog:new("TestInternal");
	pPopupDialog:AddText("This is an internal test; press 'yes' to print yes in the console or no to just dismiss");
	pPopupDialog:AddButton("Yes", function() print("yes!"); end );
	pPopupDialog:AddButton("No", nil );
	pPopupDialog:Open();
	]]
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInit( isReload:boolean )
	if isReload then		
		LuaEvents.GameDebug_GetValues( "GenericPopup" );		
	end
	--Test();
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShutdown()
	-- Write values:
	LuaEvents.GameDebug_AddValue("GenericPopup", "m_options",	m_options );
	LuaEvents.GameDebug_AddValue("GenericPopup", "m_uniqueStringName",	m_uniqueStringName );

	-- Un register.
	LuaEvents.RaisePopupGeneric.Remove( OnRaisePopupGeneric );
	LuaEvents.GameDebug_Return.Remove( OnGameDebugReturn );
	LuaEvents.Tutorial_TutorialEndHideBulkUI.Remove( OnTutorialEndHide );
end

-- ===========================================================================
--	LUA Event
--	Set cached values back after a hotload.
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	if context ~= "GenericPopup" then
		return;
	end
	local options:table = contextTable["m_options"]; 
	uniqueStringName = contextTable["m_uniqueStringName"]; 
	if options ~= nil then
		LuaEvents.RaisePopupGeneric( uniqueStringName, options );	-- Will set members on call
	end
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnTutorialEndHide()
	print("WARNING: Tutorial is forcing the PopupGeneric to be hidden!  This is fine if you are exiting a game.");
	ContextPtr:SetHide( true );
end

-- ===========================================================================
--
-- ===========================================================================
function Initialize()

	m_kPopupDialog = PopupDialogLogic:new( "PopupGeneric", Controls.PopupDialog, Controls.StackContents );
	m_kPopupDialog:SetInstanceNames( "PopupButtonInstance", "Button", "PopupTextInstance", "Text" );
	m_kPopupDialog:SetOpenAnimationControls( Controls.PopupAlphaIn, Controls.PopupSlideIn );

	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShutdown( OnShutdown );

	LuaEvents.RaisePopupGeneric.Add( OnRaisePopupGeneric );
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );
	LuaEvents.Tutorial_TutorialEndHideBulkUI.Add( OnTutorialEndHide );
end
Initialize();
