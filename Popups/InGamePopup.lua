--[[
-- Last modifed by Samuel Batista on Jun 28 2017
-- Original Author: Samuel Batista
-- Copyright (c) Firaxis Games
--]]

include("PopupDialog");
local m_PopupDialog:table;

-- ===========================================================================
-- PopupDialog functionality
-- ===========================================================================
function OnPopupOpen( uniqueStringName:string, options:table )

	-- If no options were passed in, fill with generic options.
	if options == nil or #options == 0 then
		options = {};
		options[1] = { Type="Text",	Content=TXT_ARE_YOU_SURE};
		options[2] = { Type="Button", Content=TXT_ACCEPT, CallbackString="accept"};
		options[3] = { Type="Button", Content=TXT_CANCEL, CallbackString="cancel"};
		print("Using generic popup because no options were passed in!", uniqueStringName);
	end

	m_PopupDialog:Reset();
	
	for _, option in ipairs(options) do
		local optionType:string = option.Type;
		if optionType ~= nil then
			if		optionType == "Text"	then m_PopupDialog:AddText( option.Content );
			elseif	optionType == "Button"	then m_PopupDialog:AddButton( option.Content, option.Callback );
			elseif	optionType == "Count"	then m_PopupDialog:AddCountDown( option.Content, option.Callback );
			elseif	optionType == "Title"	then m_PopupDialog:AddTitle(option.Content);
			else
				UI.DataError("Unhandled type '"..optionType.."' for '"..uniqueStringName.."'");
			end
		else
			UI.DataError( "An option was passed to PopupGeneric without a Type specified for '"..uniqueStringName.."'" );
		end
	end
	
	UIManager:QueuePopup(ContextPtr, PopupPriority.Normal);
	m_PopupDialog:Open();
end

function OnClosePopup()
	UIManager:DequeuePopup(ContextPtr);
	if m_PopupDialog:IsOpen() then
		m_PopupDialog:Close();
	end
end

-- ===========================================================================
-- ESC handler
-- ===========================================================================
function InputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			if(m_PopupDialog and m_PopupDialog:IsOpen()) then
				m_PopupDialog:Close();
				return true;
			end
		end
	end
	return false;
end

-- ===========================================================================
function Initialize()
	m_PopupDialog = PopupDialog:new("InGamePopup");
	ContextPtr:SetInputHandler(InputHandler);
	LuaEvents.OnRaisePopupInGame.Add(OnPopupOpen);
	LuaEvents.Tutorial_TutorialEndHideBulkUI.Add(OnClosePopup);
end
Initialize();
