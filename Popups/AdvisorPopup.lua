-- ===========================================================================
--	Popup that occurs with the tutorial system
-- ===========================================================================
include( "InstanceManager" );


-- ===========================================================================
--	Action Hotkeys
-- ===========================================================================
local m_actionHotkeyContinue	:number = Input.GetActionId("TutorialContinue");
local m_actionHotkeyContinueAlt	:number = Input.GetActionId("TutorialContinueAlt");
local m_actionHotkeyShowMore	:number = Input.GetActionId("TutorialShowMore");



-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local RELOAD_CACHE_ID	:string = "AdvisorPopup";

-- FIXME(asherburne): Move declaration of AdvisorItem to a location
-- available to both AdvisorPopup.lua and TutorialUIRoot.lua so it does
-- not have to be duplicated and kept in-sync.
hstructure AdvisorItem
	Message			: string;		-- TXT key to look up for advisor message (if raised via an advisor)
	MessageAudio	: string;		-- Name of the accompanying audio to play with the message.
	Image			: string;		-- (optional) Name of texture used in image.
	OptionsNum		: number;		-- Number of options.
	Button1Text		: string;		-- TXT key to look up for button 1
	Button2Text		: string;		-- " " " 2
	Button1Func		: ifunction;	-- Callback on button 1
	Button2Func		: ifunction;	-- " " " 2
	CalloutHeader	: string;		-- TXT key to look up for callout header
	CalloutBody		: string;		-- TXT key to look up for callout body
	PlotCallback	: ifunction;	-- Function to return the ID of a world plot to which dialog will be anchored
	ShowPortrait	: boolean;		-- Whether or not the advisor portrait should appear in the dialog (expected when VO is played)
	UITriggers		: table;		-- IDs and/or Trigger names for the UI when advisor item is up.
end

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_dialogButtonIM		: table	= InstanceManager:new( "DialogButtonInstance", "DialogButton", Controls.ButtonStack );
local m_metaDialogButtonIM	: table	= InstanceManager:new( "DialogButtonInstance", "DialogButton", Controls.MetaButtonStack );
local ms_eventID			: number = 0;
local m_bTutorialEnabled	: boolean = true;
local m_currentItem			: AdvisorItem;		-- Currently only exists for hotloading
local m_isDiplomacyUp		: boolean = false;	-- Is the diplomacy system currently not showing
local m_hotkeyCallback		: ifunction = nil;
local m_isAlwaysActiveSet	: boolean = false;	-- Did this context set the tutorial to be in always active mode.

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

function AddAdvisorButton( data:AdvisorItem, text:string, callbackFunc:ifunction, isHotkeyed:boolean )	

	local BUTTON_PADDING	:number = 40;
	local BUTTON_MIN_SIZE_X	:number = 200;

	local buttonInstance	:table;
	local buttonStackControl = Controls.ButtonStack;
	if data.ShowPortrait then
		buttonInstance = m_dialogButtonIM:GetInstance();
	else
		buttonInstance = m_metaDialogButtonIM:GetInstance();
		buttonStackControl = Controls.MetaButtonStack;
	end

	buttonInstance.DialogButton:SetText( text );	
	local sizeX :number = math.max( BUTTON_MIN_SIZE_X, buttonInstance.DialogButton:GetTextControl():GetSizeX() + BUTTON_PADDING );
	buttonInstance.DialogButton:SetSizeX( sizeX );	
	buttonInstance.DialogButton:RegisterCallback( Mouse.eLClick, 
		function() 
			OnHideAdvisorDialog(); 
			callbackFunc(data); 
		end );

	if isHotkeyed then
		m_hotkeyCallback = 
		function() 
			OnHideAdvisorDialog(); 
			callbackFunc(data); 
		end
	end

	buttonStackControl:CalculateSize();
	buttonStackControl:ReprocessAnchoring();
end

-- ===========================================================================
function ShowAdvisorPopup( advisorData:AdvisorItem )

	UITutorialManager:EnableOverlay( true );
	UITutorialManager:SetActiveAlways( true );
	m_isAlwaysActiveSet = true;

	m_currentItem = advisorData;	-- For hotloading

	local localPlayer = Game.GetLocalPlayer();
	if localPlayer == PlayerTypes.NONE then
		return;	-- Nobody there to click on it, just exit.
	end

	 m_dialogButtonIM:ResetInstances();
	 m_metaDialogButtonIM:ResetInstances();

	if advisorData == nil then
		UI.DataError("Attempt to show advisor with NIL advisor data.");
		return;
	end

	local bHideAdvisor:boolean = ( advisorData.Button1Func == nil and advisorData.Button2Func == nil );

	local imageControl			:table = Controls.InfoImage;
	local contentStack			:table = Controls.WindowContentStack;
	local dialogWindowControl	:table = Controls.Window;
	local audio					:string= advisorData.MessageAudio;
	local buttonStack			:table = Controls.ButtonStack;

	if advisorData.ShowPortrait then
		Controls.AdvisorBase:SetHide( false );
		Controls.MetaBase:SetHide( true );
		Controls.InfoString:SetText( advisorData.Message );
		Controls.AdvisorPortrait:SetHide(false);
		Controls.AdvisorAnim:SetToBeginning();
		Controls.AdvisorAnim:Play();
		Controls.AdvisorAlpha:SetToBeginning();
		Controls.AdvisorAlpha:Play();
		Controls.AdvisorAlpha:RegisterEndCallback(
			function()
				UI.PlaySound("Alert_Advisor");
				if audio ~= nil and audio ~= "" then
					UI.PlaySound( audio );
				end
			end
		);
	else
		Controls.AdvisorBase:SetHide( true );
		Controls.MetaBase:SetHide( false );
		Controls.MetaInfoString:SetText( advisorData.Message );
		Controls.MetaAnim:SetToBeginning();
		Controls.MetaAnim:Play();
		Controls.MetaAlpha:SetToBeginning();
		Controls.MetaAlpha:Play();
		imageControl = Controls.MetaInfoImage;
		contentStack = Controls.MetaWindowContentStack;
		buttonStack = Controls.MetaButtonStack;
		dialogWindowControl = Controls.MetaWindow;
	end
	
	-- display an image if provided
	if advisorData.Image then
		imageControl:SetHide(false);
		imageControl:SetTexture( advisorData.Image );
	else
		imageControl:SetHide(true);
	end

	if advisorData.PlotCallback ~= nil then
		local plotID = advisorData.PlotCallback();
		local pX, pY = Map.GetPlotLocation(plotID);
		local worldX : number, worldY : number, worldZ : number = UI.GridToWorld(pX, pY);
		Controls.Anchor:SetWorldPositionVal(worldX, worldY, worldZ);
	end

	Controls.CalloutHeader:SetText( advisorData.CalloutHeader );
	Controls.CalloutBody:SetText( advisorData.CalloutBody );

	-- NIL functions?  Assume it just means to close and raise message back.
	if advisorData.Button1Func == nil then 
		advisorData.Button1Func = function() 
			LuaEvents.AdvisorPopup_ClearActive( advisorData ); 
		end 
	end
	if advisorData.Button2Func == nil then 
		advisorData.Button2Func = function() 
			LuaEvents.AdvisorPopup_ClearActive( advisorData ); 
		end 
	end

	-- Only create button if it has contents.
	if advisorData.Button1Text ~= nil then
		AddAdvisorButton( advisorData, advisorData.Button1Text, advisorData.Button1Func, true );		
	end
	if advisorData.Button2Text ~= nil then
		AddAdvisorButton( advisorData, advisorData.Button2Text, advisorData.Button2Func );
	end

	-- If there are any associated <tutorial> triggers... trigger them.
	for _,trigger in ipairs(advisorData.UITriggers) do	
		UITutorialManager:ShowControlsByID( trigger, false );	
	end

	UIManager:QueuePopup( ContextPtr, PopupPriority.Current );

	-- Put a hold on the event so further events don't process
	ms_eventID = ReferenceCurrentGameCoreEvent();

	if advisorData.ShowPortrait then
		Controls.ButtonStack:ReprocessAnchoring();
	else
		Controls.MetaButtonStack:ReprocessAnchoring();
	end

	-- After all the buttons have been added and the dialog is finished being built, calculate the correct size of the dialog
	buttonStack:CalculateSize();
	contentStack:CalculateSize();
	local contentSize = math.max( contentStack:GetSizeY() + 60, 120 );
	dialogWindowControl:SetSizeY( contentSize );
	dialogWindowControl:ReprocessAnchoring();

	if bHideAdvisor then
		OnHideAdvisorDialog();
	end
    
end

-- ===========================================================================
function Close()
	m_currentItem = nil;	

	if ms_eventID ~= 0 then
		ReleaseGameCoreEvent(ms_eventID);
		ms_eventID = 0;
	end
	
	m_hotkeyCallback = nil;

	UITutorialManager:EnableOverlay( false );
	UIManager:DequeuePopup( ContextPtr );		
	UI.PlaySound("Stop_Advisor_Speech_All");
end

-- ===========================================================================
function OnHideAdvisorDialog()
	
	-- If the advisor is not showing, don't force active tutorial input mode,
	-- it may or may not still be active depending on if any controls are showing.
	UITutorialManager:SetActiveAlways( false );
	m_isAlwaysActiveSet = false;

	-- If there are any associated <tutorial> triggers... trigger them.
	for _,trigger in ipairs(m_currentItem.UITriggers) do	
		UITutorialManager:HideControlsByID( trigger, false );	
	end

	if ms_eventID ~= 0 then
		ReleaseGameCoreEvent(ms_eventID);
		ms_eventID = 0;
	end
	
	m_hotkeyCallback = nil;

	Controls.AdvisorBase:SetHide( true );
	Controls.MetaBase:SetHide( true );
end

	
-- ===========================================================================
--	LUA Event
--	Called when a diplomacy scene is closed
-- ===========================================================================
function OnDiploSceneClosed()
	m_isDiplomacyUp = false;
	if m_isAlwaysActiveSet then
		UITutorialManager:SetActiveAlways( true );
	end
end

-- ===========================================================================
--	LUA Event
--	Called when a diplomacy scene is opened
-- ===========================================================================
function OnDiploSceneOpened()
	m_isDiplomacyUp = true;

	-- If always active was set by this, turn it off to not interfer with the
	-- diplomacy input.  (So it's ALMOST always active.)
	if m_isAlwaysActiveSet then
		UITutorialManager:SetActiveAlways( false );	
	end
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnAdvisorRaise( item:AdvisorItem )
	ShowAdvisorPopup( item );
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnAdvisorLower()
	Close();
end

-- ===========================================================================
--	LUA Event
--	Hotload callback
-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then 
		m_isDiplomacyUp = contextTable["m_isDiplomacyUp"];
		if contextTable["isHidden"] ~= nil and (not contextTable["isHidden"]) then
			if contextTable["m_currentItem"] then
				m_currentItem = hmake AdvisorItem{};
				m_currentItem.Message		= contextTable["m_currentItem.Message"];
				m_currentItem.Image			= contextTable["m_currentItem.Image"];
				m_currentItem.OptionsNum	= contextTable["m_currentItem.OptionsNum"];
				m_currentItem.Button1Text	= contextTable["m_currentItem.Button1Text"];
				m_currentItem.Button2Text	= contextTable["m_currentItem.Button2Text"];
				m_currentItem.Button1Func	= contextTable["m_currentItem.Button1Func"];
				m_currentItem.Button2Func	= contextTable["m_currentItem.Button2Func"];
				m_currentItem.CalloutHeader = contextTable["m_currentItem.CalloutHeader"];
				m_currentItem.CalloutBody	= contextTable["m_currentItem.CalloutBody"];		
				m_currentItem.PlotCallback	= nil;
				m_currentItem.ShowPortrait  = contextTable["m_currentItem.ShowPortrait"];
				m_currentItem.UITriggers	= contextTable["m_currentItem.UITriggers"];					
				ShowAdvisorPopup( m_currentItem );	
			end			
		end
	end
end


-- ===========================================================================
--	Hotkey
-- ===========================================================================
function OnInputActionTriggered( actionId:number )
	if	actionId == m_actionHotkeyContinue		or
		actionId == m_actionHotkeyContinueAlt	then
		if m_hotkeyCallback ~= nil then 
			m_hotkeyCallback();
		end		
	end		
end


-- ===========================================================================
--	Is the advisor popup blocking all other input?
--
--	1) Since the context is marked to always be processed in the tutorial flow,
--	   it will get first crack at the input (with the other tutorial controls)
--	   before the normal flow of cascade controls.
--
--	2) This also means tutorial items in the normal control tree will not
--	   receive input if this is showing.
-- ===========================================================================
function IsBlockingInput()
	-- Context itself must be showing and then at least one of the sub dialogs also must be up.
	local isContextVisible	:boolean = (not ContextPtr:IsHidden());
	local isAdvisorVisible	:boolean = (not Controls.AdvisorBase:IsHidden());
	local isMetaVisible		:boolean = (not Controls.MetaBase:IsHidden());

	return isContextVisible and (isAdvisorVisible or isMetaVisible) and (m_isDiplomacyUp==false);
end

-- ===========================================================================
function KeyHandler( key:number )
	if key == Keys.VK_ESCAPE then
		if m_isDiplomacyUp then return false; end	-- Currently cannot handle ESC if diplomacy is up.
		LuaEvents.Tutorial_ToggleInGameOptionsMenu();
		return true;
	end
	
	if key == Keys.VK_RETURN and (not UI.IsFinalRelease()) then
		if m_isDiplomacyUp then return false; end	-- Currently cannot handle ESC if diplomacy is up.
			if m_hotkeyCallback ~= nil then 
				m_hotkeyCallback();
			end
		return true;
	end
	
	return IsBlockingInput();	
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then 
		return KeyHandler( pInputStruct:GetKey() ); 
	end
	return IsBlockingInput();
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInit( isReload:boolean )
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnShow()
    UI.PlaySound("Resume_Advisor_Speech");
    UI.PlaySound("Pause_TechCivic_Speech");
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnShutdown()
	if ms_eventID ~= 0 then
		ReleaseGameCoreEvent(ms_eventID);
	end
	
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden() );
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_isDiplomacyUp", m_isDiplomacyUp );	

	if m_currentItem ~= nil then
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentItem", true );
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentItem.Message",		m_currentItem.Message );
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentItem.Image",		m_currentItem.Image );
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentItem.OptionsNum",	m_currentItem.OptionsNum );
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentItem.Button1Text",	m_currentItem.Button1Text );
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentItem.Button2Text",	m_currentItem.Button2Text );
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentItem.Button1Func",	m_currentItem.Button1Func );
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentItem.Button2Func",	m_currentItem.Button2Func );
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentItem.CalloutHeader",m_currentItem.CalloutHeader );
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentItem.CalloutBody",	m_currentItem.CalloutBody );		
		if (m_currentItem.PlotCallback ~= nil ) then 
			UI.DataError("Warning, you are hotloading with a plot callback, but ifunction definitions cannot be serialized across hotload.  Your milage will vary."); 
		end
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentItem.ShowPortrait", m_currentItem.ShowPortrait );
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentItem.UITriggers",	m_currentItem.UITriggers );
	else
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_currentItem", false );
	end

	LuaEvents.DiploScene_SceneClosed.Remove( OnDiploSceneClosed );
	LuaEvents.DiploScene_SceneOpened.Remove( OnDiploSceneOpened );
	LuaEvents.GameDebug_Return.Remove( OnGameDebugReturn );
	LuaEvents.TutorialUIRoot_AdvisorRaise.Remove( OnAdvisorRaise );
	LuaEvents.TutorialUIRoot_AdvisorLower.Remove( OnAdvisorLower );
end


-- ===========================================================================
--	
-- ===========================================================================
function Initialize()

	-- DEBUG
	if (m_currentItem ~= nil) then
		m_currentItem.ShowPortrait = false;
		ShowAdvisorPopup(m_currentItem);
	end

	-- UI Events
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShutdown( OnShutdown );
    ContextPtr:SetShowHandler( OnShow );

	-- Events
	Events.InputActionTriggered.Add( OnInputActionTriggered );

	-- Lua Events
	LuaEvents.DiploScene_SceneClosed.Add( OnDiploSceneClosed );
	LuaEvents.DiploScene_SceneOpened.Add( OnDiploSceneOpened );
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );
	LuaEvents.TutorialUIRoot_AdvisorRaise.Add( OnAdvisorRaise );
	LuaEvents.TutorialUIRoot_AdvisorLower.Add( OnAdvisorLower );

end
Initialize();
