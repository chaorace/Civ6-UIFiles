-- ===========================================================================
--	Popup that occurs with the automation narration system
-- ===========================================================================
include( "InstanceManager" );


-- ===========================================================================
--	Action Hotkeys
-- ===========================================================================
local m_actionHotkeyTogglePause	:number = Input.GetActionId("AutomationTogglePause");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

--	Message			: string;		-- TXT key to look up for advisor message (if raised via an advisor)
--	MessageAudio	: string;		-- Name of the accompanying audio to play with the message.
--	Image			: string;		-- (optional) Name of texture used in image.
--	OptionsNum		: number;		-- Number of options.
--	Button1Text		: string;		-- TXT key to look up for button 1
--	Button2Text		: string;		-- " " " 2
--	Button1Func		: ifunction;	-- Callback on button 1
--	Button2Func		: ifunction;	-- " " " 2
--	CalloutHeader	: string;		-- TXT key to look up for callout header
--	CalloutBody		: string;		-- TXT key to look up for callout body
--	PlotCallback	: ifunction;	-- Function to return the ID of a world plot to which dialog will be anchored
--	ShowPortrait	: boolean;		-- Whether or not the advisor portrait should appear in the dialog (expected when VO is played)
--	DisplayTime		: number		-- Amount of time to display the narration
--  BlocksInput		: boolean;		-- If true, the popup blocks input to other contexts if the popup is visible

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_dialogButtonIM		: table	= InstanceManager:new( "DialogButtonInstance", "DialogButton", Controls.ButtonStack );
local m_metaDialogButtonIM	: table	= InstanceManager:new( "DialogButtonInstance", "DialogButton", Controls.MetaButtonStack );
local ms_eventID			: number = 0;
local m_bTutorialEnabled	: boolean = true;
local m_currentItem			: table;		-- Currently only exists for hotloading
local m_isDiplomacyUp		: boolean = false;	-- Is the diplomacy system currently not showing
local m_hotkeyCallback		: ifunction = nil;
local m_itemQueue			: table = {};

local DEFAULT_TIME_TO_DISPLAY : number = 2.5;
-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

function AddButton( data:table, text:string, callbackFunc:ifunction, isHotkeyed:boolean )	

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
			Close(); 
			if (callbackFunc ~= nil) then
				callbackFunc(data); 
			end
		end );

	if isHotkeyed then
		m_hotkeyCallback = 
		function() 
			Close(); 
			if (callbackFunc ~= nil) then
				callbackFunc(data);
			end
		end
	end

	buttonStackControl:CalculateSize();
	buttonStackControl:ReprocessAnchoring();
end

-- ===========================================================================
function OnPortraitTimerEnd()
	Controls.AdvisorAlpha:Reverse();
	Controls.AdvisorAlpha:Play();
	Controls.AdvisorAnim:Reverse();	
	Controls.AdvisorAnim:Play();
end

-- ===========================================================================
function OnPortraitPopupComplete(timeToDisplay)
	if (Controls.AdvisorAnim:IsReversing()) then
		-- Completed the fade out.
		Close();
		UpdateQueue();
	else
		if (timeToDisplay ~= nil and timeToDisplay ~= 0) then
			Controls.AdvisorTimer:RegisterEndCallback(OnPortraitTimerEnd);
			Controls.AdvisorTimer:SetPauseTime(timeToDisplay);
			Controls.AdvisorTimer:SetToBeginning();
			Controls.AdvisorTimer:Play();
		end
	end
end

-- ===========================================================================
function OnMetaTimerEnd()
	Controls.MetaAlpha:Reverse();	
	Controls.MetaAlpha:Play();
	Controls.MetaAnim:Reverse();	
	Controls.MetaAnim:Play();
end

-- ===========================================================================
function OnBasePopupComplete(autoHide)
	if (Controls.MetaAnim:IsReversing()) then
		-- Completed the fade out.
		Close();
		UpdateQueue();
	else
		if (timeToDisplay ~= nil and timeToDisplay ~= 0) then
			Controls.MetaTimer:RegisterEndCallback(OnMetaTimerEnd);
			Controls.MetaTimer:SetPauseTime(timeToDisplay);
			Controls.MetaTimer:SetToBeginning();
			Controls.MetaTimer:Play();
		end
	end
end

-- ===========================================================================
function ShowNarrationPopup( narrationData:table )

	 m_dialogButtonIM:ResetInstances();
	 m_metaDialogButtonIM:ResetInstances();

	if narrationData == nil then
		UI.DataError("Attempt to show narration with NIL narration data.");
		return;
	end

	local imageControl			:table = Controls.InfoImage;
	local contentStack			:table = Controls.WindowContentStack;
	local dialogWindowControl	:table = Controls.Window;
	local audio					:string= narrationData.MessageAudio;
	local buttonStack			:table = Controls.ButtonStack;

	local timeToDisplay:number	= 0;
	if (narrationData.Button1Text == nil and narrationData.Button2Text == nil) then
		timeToDisplay = (narrationData.DisplayTime ~= nil and narrationData.DisplayTime > 0) and narrationData.DisplayTime or DEFAULT_TIME_TO_DISPLAY;
	end

	if narrationData.ShowPortrait ~= nil and narrationData.ShowPortrait then
		Controls.AdvisorBase:SetHide( false );
		Controls.MetaBase:SetHide( true );
		Controls.InfoString:SetText( narrationData.Message );
		if (narrationData.Title ~= nil) then
			Controls.TitleText:SetText( narrationData.Title );
			Controls.TitleText:SetHide( false );
		else
			Controls.TitleText:SetHide( true );
		end
		Controls.AdvisorPortrait:SetHide(false);
		Controls.AdvisorTimer:Stop();
		Controls.AdvisorAnim:RegisterEndCallback( function() OnPortraitPopupComplete(timeToDisplay) end );
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
		Controls.MetaInfoString:SetText( narrationData.Message );
		if (narrationData.Title ~= nil) then
			Controls.MetaTitleText:SetText( narrationData.Title );
			Controls.MetaTitleText:SetHide( false );
		else
			Controls.MetaTitleText:SetHide( true );
		end
		Controls.MetaTimer:Stop();
		Controls.MetaAnim:RegisterEndCallback( function() OnBasePopupComplete(timeToDisplay) end );			
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
	if narrationData.Image ~= nil then
		imageControl:SetHide(false);
		imageControl:SetTexture( narrationData.Image );
	else
		imageControl:SetHide(true);
	end

	if narrationData.PlotCallback ~= nil then
		local plotID = narrationData.PlotCallback();
		local pX, pY = Map.GetPlotLocation(plotID);
		local worldX : number, worldY : number, worldZ : number = UI.GridToWorld(pX, pY);
		Controls.Anchor:SetWorldPositionVal(worldX, worldY, worldZ);
	end

	Controls.CalloutHeader:SetText( narrationData.CalloutHeader );
	Controls.CalloutBody:SetText( narrationData.CalloutBody );

	-- NIL functions?  Assume it just means to close and raise message back.
--	if narrationData.Button1Func == nil then 
--		narrationData.Button1Func = function() 
--			LuaEvents.AdvisorPopup_ClearActive( narrationData ); 
--		end 
--	end
--	if narrationData.Button2Func == nil then 
--		narrationData.Button2Func = function() 
--			LuaEvents.AdvisorPopup_ClearActive( narrationData ); 
--		end 
--	end

	-- Only create button if it has contents.
	if narrationData.Button1Text ~= nil then
		AddButton( narrationData, narrationData.Button1Text, narrationData.Button1Func, true );		
	end
	if narrationData.Button2Text ~= nil then
		AddButton( narrationData, narrationData.Button2Text, narrationData.Button2Func );
	end

	UIManager:QueuePopup( ContextPtr, PopupPriority.Current );

	-- Put a hold on the event so further events don't process
	if (narrationData.ReferenceEvent ~= nil and narrationData.ReferenceEvent) then
		ms_eventID = ReferenceCurrentGameCoreEvent();
	end

	if narrationData.ShowPortrait ~= nil and narrationData.ShowPortrait then
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

end

-- ===========================================================================
function Close()
	m_currentItem = nil;	

	if ms_eventID ~= 0 then
		ReleaseGameCoreEvent(ms_eventID);
		ms_eventID = 0;
	end
	
	m_hotkeyCallback = nil;

	Controls.AdvisorBase:SetHide( true );
	Controls.MetaBase:SetHide( true );

	UIManager:DequeuePopup( ContextPtr );		
	UI.PlaySound("Stop_Advisor_Speech_All");
end
	
-- ===========================================================================
--	LUA Event
--	Called when a diplomacy scene is closed
-- ===========================================================================
function OnDiploSceneClosed()
	m_isDiplomacyUp = false;
end

-- ===========================================================================
--	LUA Event
--	Called when a diplomacy scene is opened
-- ===========================================================================
function OnDiploSceneOpened()
	m_isDiplomacyUp = true;
end

-- ===========================================================================
--	Update the queue
-- ===========================================================================
function UpdateQueue()
	if (m_currentItem == nil) then
		if (#m_itemQueue > 0) then
			m_currentItem = m_itemQueue[1];
			table.remove(m_itemQueue, 1);
			ShowNarrationPopup( m_currentItem );
		end
	end
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnAddToNarrationQueue( item : table )
	
	table.insert( m_itemQueue, item );	
	UpdateQueue();
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnAdvisorLower()
	Close();
end

-- ===========================================================================
--	Hotkey
-- ===========================================================================
function OnInputActionTriggered( actionId:number )
	if	actionId == m_actionHotkeyTogglePause	then
		if m_hotkeyCallback ~= nil then 
			m_hotkeyCallback();
		end		
	end		
end


-- ===========================================================================
--	Is the popup blocking all other input?
-- ===========================================================================
function IsBlockingInput()
	-- Context itself must be showing and then at least one of the sub dialogs also must be up.
	local isContextVisible	:boolean = (not ContextPtr:IsHidden());
	local isAdvisorVisible	:boolean = (not Controls.AdvisorBase:IsHidden());
	local isMetaVisible		:boolean = (not Controls.MetaBase:IsHidden());

	if (m_currentItem ~= nil and m_currentItem.BlocksInput ~= nil) then
		return isContextVisible and (isAdvisorVisible or isMetaVisible) and (m_isDiplomacyUp==false) and m_currentItem.BlocksInput;
	end

	return false;
end

-- ===========================================================================
function KeyHandler( key:number )
--	if key == Keys.VK_SPACE then
--		if m_isDiplomacyUp then return false; end
--		-- Handle the key
--		return true;
--	end
		
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

end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnShutdown()
	if ms_eventID ~= 0 then
		ReleaseGameCoreEvent(ms_eventID);
	end
	
	LuaEvents.DiploScene_SceneClosed.Remove( OnDiploSceneClosed );
	LuaEvents.DiploScene_SceneOpened.Remove( OnDiploSceneOpened );
	LuaEvents.Automation_AddToNarrationQueue.Remove( OnAddToNarrationQueue );
end


-- ===========================================================================
--	
-- ===========================================================================
function Initialize()

	-- DEBUG
	if (m_currentItem ~= nil) then
		m_currentItem.ShowPortrait = false;
		ShowNarrationPopup(m_currentItem);
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
	LuaEvents.Automation_AddToNarrationQueue.Add( OnAddToNarrationQueue );

end
Initialize();
