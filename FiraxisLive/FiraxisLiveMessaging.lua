-- ===========================================================================
-- FiraxisLiveMessaging
-- ===========================================================================

include( "InstanceManager" );

-- ===========================================================================
--	DEFINES
-- ===========================================================================

local DIALOG_TIME_IN_SECONDS	=	10;
local DIALOG_BUFFER_IN_PIXELS	=	17;
local DIALOG_ICON_WIDTH			=	48;
local DIALOG_SLIDE_SPEED		=	400;	-- Pixels per second
local DIALOG_DEFAULT_ICON		=	"CivBEIcon.dds";

-- ===========================================================================
--	MEMBERS
--	TODO:	Consider making the managers local to an Initialize and keeping
--			the dialogs themselves.
-- ===========================================================================
local g_FiraxisLiveMessageManager		= InstanceManager:new( "FiraxisLiveMessage",		"Dialog",		Controls.FiraxisLiveMessageArea );
local g_FiraxisLiveMessages = {};

local g_PopupDisplayed : boolean = false;
local g_PopupTime : number = 0;

-- ===========================================================================
--	Animation States
-- ===========================================================================

local ANIM_STATE_NONE  = 0;
local ANIM_STATE_SLIDE_IN  = 1;
local ANIM_STATE_SLIDE_OUT  = 2;

local g_AnimationState = ANIM_STATE_NONE;
local g_CurrentInstance = nil;

-- ===========================================================================
--	Leave My2K popup dialog
-- ===========================================================================
function OnReturn()
	UIManager:DequeuePopup( ContextPtr );

	-- Clear any prior dialogs:
	DestroyDialogIfExists( g_FiraxisLiveMessageManager );
end

-- ===========================================================================
-- ===========================================================================
function InputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if (wParam == Keys.VK_ESCAPE and g_PopupDisplayed == true) then
			g_PopupTime = 0;
			return true;
		end
	end
	return false;
end
ContextPtr:SetInputHandler( InputHandler );

-- ===========================================================================
-- ===========================================================================
function UpdateAnimationState( fDeltaTime )

	if g_CurrentInstance ~= nil then

		local curY = g_CurrentInstance.Dialog:GetOffsetY();
		local screenHeight = Controls.FiraxisLiveMessageArea:GetSizeY();
		local panelHeight = g_CurrentInstance.Dialog:GetSizeY();

		if ( g_AnimationState == ANIM_STATE_SLIDE_IN ) then
			curY = curY - (DIALOG_SLIDE_SPEED * fDeltaTime);
			if( curY < screenHeight - panelHeight ) then
				curY = screenHeight - panelHeight;
				g_AnimationState = ANIM_STATE_NONE;
			end
		elseif ( g_AnimationState == ANIM_STATE_SLIDE_OUT ) then
			curY = curY + (DIALOG_SLIDE_SPEED * fDeltaTime);
			if( curY >= screenHeight ) then
				curY = screenHeight;
				g_AnimationState = ANIM_STATE_NONE;
			end
		end

		g_CurrentInstance.Dialog:SetOffsetY(curY);
	end

end

-- ===========================================================================
-- ===========================================================================
function CreateNewInstance( newMessage )

	if (newMessage ~= nil) then
		g_CurrentInstance = g_FiraxisLiveMessageManager:GetInstance();

		if( newMessage.icon ~= nil) then
			g_CurrentInstance.MessageIcon:SetTexture(newMessage.icon);
		else
			g_CurrentInstance.MessageIcon:SetTexture(DIALOG_DEFAULT_ICON);
		end

		-- Get the screen dimensions from the topmost control which is set to be "Full, Full"
		local screenWidth = Controls.FiraxisLiveMessageArea:GetSizeX();
		local screenHeight = Controls.FiraxisLiveMessageArea:GetSizeY();

		-- Don't allow the message to take more than 2/3rds of the screen width
		screenWidth = (screenWidth * 2) / 3;

		-- Set the text and word wrap size.
		g_CurrentInstance.MessageTitle:SetText( newMessage.title );
		g_CurrentInstance.MessageTitle:SetWrapWidth( screenWidth - ((DIALOG_BUFFER_IN_PIXELS * 3) + DIALOG_ICON_WIDTH ) );
		g_CurrentInstance.MessageText:SetText( newMessage.message );
		g_CurrentInstance.MessageText:SetWrapWidth( screenWidth - ((DIALOG_BUFFER_IN_PIXELS * 3) + DIALOG_ICON_WIDTH ) );


		-- Calculate the width and height of the new control based on word wrapping and font height.
		g_CurrentInstance.MessageArea:CalculateSize();
		local contentSizeY	= g_CurrentInstance.MessageArea:GetSizeY();
		g_CurrentInstance.Dialog:SetSizeY( contentSizeY + (DIALOG_BUFFER_IN_PIXELS * 2) );
		g_CurrentInstance.Dialog:SetSizeX( g_CurrentInstance.MessageArea:GetSizeX() + (DIALOG_BUFFER_IN_PIXELS * 3) + DIALOG_ICON_WIDTH );

		-- Start it offscreen.
		g_CurrentInstance.Dialog:SetOffsetY( screenHeight );

		-- Set global data and away we go!
		g_PopupTime = DIALOG_TIME_IN_SECONDS;
		g_PopupDisplayed = true;
		g_AnimationState = ANIM_STATE_SLIDE_IN;
	end
end

-- ===========================================================================
-- ===========================================================================
function OnUpdate( fDeltaTime )

	-- If we are animating in or out, handle that transition first.
	if g_AnimationState ~= ANIM_STATE_NONE then

		UpdateAnimationState( fDeltaTime );

	-- Then, if there is a popup already displayed, see if it should be closed
	elseif g_PopupDisplayed == true then
		g_PopupTime = g_PopupTime - fDeltaTime;
		if g_PopupTime <= 0 then
			g_PopupTime = 0;
			g_PopupDisplayed = false;

			g_AnimationState = ANIM_STATE_SLIDE_OUT;

		end

	-- If no popup displayed, see if we have one reserved.
	else

		g_CurrentInstance = nil;

		-- If there is a new popup, display it now.
		if #g_FiraxisLiveMessages > 0 then

			g_FiraxisLiveMessageManager:ResetInstances();
			CreateNewInstance( table.remove( g_FiraxisLiveMessages, 1 ) );

		end
	end
end
ContextPtr:SetUpdate( OnUpdate );

-- ===========================================================================
-- ===========================================================================
function ShowMy2KMessage(iconTexture, titleString, messageString)

	-- Add new message to message queue, if it's not already in the queue
	if (#g_FiraxisLiveMessages > 0) then
		for message in g_FiraxisLiveMessages do
			if (message.icon == iconTexture and message.title == titleString and message.message == messageString ) then
				return;
			end
		end
	end

	local newMessage = {};
	newMessage.icon = iconTexture;
	newMessage.title = titleString;
	newMessage.message = messageString;

	g_FiraxisLiveMessages[#g_FiraxisLiveMessages+1] = newMessage;

end
