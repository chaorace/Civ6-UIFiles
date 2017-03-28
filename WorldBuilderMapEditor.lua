-- ===========================================================================
--	World Builder Player Editor
-- ===========================================================================

include("InstanceManager");
include("SupportFunctions");
include("TabSupport");

-- ===========================================================================
--	DATA MEMBERS
-- ===========================================================================

local DATA_FIELD_SELECTION						:string = "Selection";

local m_ViewingTab		   : table = {};
local m_tabs				:table;

local m_simpleIM			:table = InstanceManager:new("SimpleInstance",			"Top",		Controls.Stack);				-- Non-Collapsable, simple
local m_tabIM			   : table = InstanceManager:new("TabInstance",				"Button",	Controls.TabContainer);

local m_LanguageEntries		: table = {};
local m_TextEntries			: table = {};

-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
--
-- ===========================================================================
function AddTabSection( tabs:table, name:string, populateCallback:ifunction, parent )
	local kTab		:table				= m_tabIM:GetInstance(parent);	
	kTab.Button[DATA_FIELD_SELECTION]	= kTab.Selection;

	local callback	:ifunction	= function()
		if tabs.prevSelectedControl ~= nil then
			-- Restore proper color
			tabs.prevSelectedControl:GetTextControl():SetColorByName("ShellOptionText");

			tabs.prevSelectedControl[DATA_FIELD_SELECTION]:SetHide(true);
		end
		kTab.Selection:SetHide(false);
		populateCallback();
	end

	kTab.Button:GetTextControl():SetText( Locale.Lookup(name) );
	kTab.Button:SetSizeToText( 40, 20 );
    kTab.Button:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	tabs.AddTab( kTab.Button, callback );
end

-- ===========================================================================
function ResetTabForNewPageContent()
	m_uiGroups = {};
	m_ViewingTab = {};
	m_simpleIM:ResetInstances();
	Controls.Scroll:SetScrollValue( 0 );	
end

-- ===========================================================================
function CalculatePrimaryTabScrollArea()

	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();

	local xOffset, yOffset = Controls.Scroll:GetParentRelativeOffset();
	Controls.Scroll:SetSizeY( Controls.TabsContainer:GetSizeY() - yOffset );
end

-- ===========================================================================
function PopulateTextEntries(forLanguage)

	m_TextEntries = {};

	local iIndex = 1;
	local selected = 1;

	while true do

		local key, text = WorldBuilder.ModManager():GetKeyStringPairByIndex(iIndex, forLanguage);
		if key == nil then 
			break;
		end

		table.insert(m_TextEntries, { Key = key, Text = text, Index = iIndex, ForLanguage = forLanguage });

		iIndex = iIndex + 1;
	end
	
	if iIndex == 1 then
		selected = 0;
	end

	m_ViewingTab.TextInstance.KeyStringList:SetEntries( m_TextEntries, selected );
	
	-- Manually call selection callback since SetEntries does not trigger it
	OnKeyStringListSelection(m_TextEntries[selected]);
end

-- ===========================================================================
function OnCommitTextKey(text, control)

	local i = control:GetVoid1();
	local controlEntry = m_ViewingTab.TextInstance.KeyStringList:GetIndexedEntry( i );
	if controlEntry ~= nil then
		controlEntry.Key = text;
		WorldBuilder.ModManager():SetKeyStringPairByIndex(controlEntry.Index, controlEntry.Key, controlEntry.Text, controlEntry.ForLanguage);		
	end
end

-- ===========================================================================
function OnCommitTextString(text, control)

	local i = control:GetVoid1();
	local controlEntry = m_ViewingTab.TextInstance.KeyStringList:GetIndexedEntry( i );
	if controlEntry ~= nil then
		controlEntry.Text = text;
		WorldBuilder.ModManager():SetKeyStringPairByIndex(controlEntry.Index, controlEntry.Key, controlEntry.Text, controlEntry.ForLanguage);		
	end
end

-- ===========================================================================
function UpdateTextPage()

	if (m_ViewingTab ~= nil and m_ViewingTab.TextInstance ~= nil) then
		
		local selectedLanguageEntry = m_LanguageEntries[ m_ViewingTab.TextInstance.LanguagePullDown:GetSelectedIndex() ];
		if selectedLanguageEntry ~= nil then

			PopulateTextEntries(selectedLanguageEntry.Type);

			for i, entry in ipairs(m_TextEntries) do
				local controlEntry = m_ViewingTab.TextInstance.KeyStringList:GetIndexedEntry( i );
				if controlEntry ~= nil then
					if controlEntry.Root.Button ~= nil then
						-- Set button text as 
						TruncateString(controlEntry.Root.Button, controlEntry.Root.Button:GetSizeX()-20, entry.Text, "");
					end
				end
			end
		end
	end

end

-- ===========================================================================
function OnTextLanguageSelection(entry)
	UpdateTextPage();
end

-- ===========================================================================
function OnKeyStringListSelection(entry)
	if m_ViewingTab.TextInstance ~= nil then
		-- Set text tag and callback
		if m_ViewingTab.TextInstance.TextTagEditBox ~= nil then
			m_ViewingTab.TextInstance.TextTagEditBox:SetText(entry.Key);
			m_ViewingTab.TextInstance.TextTagEditBox:SetVoid1(entry.Index);
			m_ViewingTab.TextInstance.TextTagEditBox:RegisterCommitCallback(OnCommitTextKey);
		end

		-- Set text string and callback
		if m_ViewingTab.TextInstance.TextStringEditBox ~= nil then
			m_ViewingTab.TextInstance.TextStringEditBox:SetText(entry.Text);
			m_ViewingTab.TextInstance.TextStringEditBox:SetVoid1(entry.Index);
			m_ViewingTab.TextInstance.TextStringEditBox:RegisterCommitCallback(OnCommitTextString);						
		end
	end
end

-- ===========================================================================
function OnAddText()
	if (m_ViewingTab ~= nil and m_ViewingTab.TextInstance ~= nil) then

		local selectedLanguageEntry = m_LanguageEntries[ m_ViewingTab.TextInstance.LanguagePullDown:GetSelectedIndex() ];
		if selectedLanguageEntry ~= nil then
			WorldBuilder.ModManager():SetString("DUMMY_ID", "Dummy Text", selectedLanguageEntry.Type);

			UpdateTextPage();	-- This is overkill/inefficient
		end
	end
end

-- ===========================================================================
function OnRemoveText()
	if (m_ViewingTab ~= nil and m_ViewingTab.TextInstance ~= nil) then
		local iSelectedIndex = m_ViewingTab.TextInstance.KeyStringList:GetSelectedIndex();
		if iSelectedIndex ~= nil then
			local entry = m_TextEntries[ iSelectedIndex ];
			if entry ~= nil then
				
				WorldBuilder.ModManager():RemoveString(entry.Key, entry.ForLanguage);		

				UpdateTextPage();	-- This is overkill/inefficient
			end
		end
	end
end

-- ===========================================================================
function ViewMapTextPage()	

	ResetTabForNewPageContent();

	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();

	m_ViewingTab.Name = "Text";
	m_ViewingTab.TextInstance = {};
	ContextPtr:BuildInstanceForControl( "TextInstance", m_ViewingTab.TextInstance, instance.Top ) ;	

	-- Initialize Controls
	m_ViewingTab.TextInstance.LanguagePullDown:SetEntrySelectedCallback( OnTextLanguageSelection );
	m_ViewingTab.TextInstance.LanguagePullDown:SetEntries( m_LanguageEntries, 1 );
	m_ViewingTab.TextInstance.KeyStringList:SetEntrySelectedCallback( OnKeyStringListSelection );
	m_ViewingTab.TextInstance.AddText:RegisterCallback( Mouse.eLClick, OnAddText );
	m_ViewingTab.TextInstance.RemoveText:RegisterCallback( Mouse.eLClick, OnRemoveText );

	UpdateTextPage();

	CalculatePrimaryTabScrollArea();

end

-- ===========================================================================
function UpdateModPage()
	if (m_ViewingTab ~= nil and m_ViewingTab.ModInstance ~= nil) then
		
		m_ViewingTab.ModInstance.IsModCheckbox:SetSelected( WorldBuilder.IsMod() );
	end
end

-- ===========================================================================
function OnModCheckboxButton()
	if (m_ViewingTab ~= nil and m_ViewingTab.ModInstance ~= nil) then
		local newIsSelected:boolean = not m_ViewingTab.ModInstance.IsModCheckbox:IsSelected();

		m_ViewingTab.ModInstance.IsModCheckbox:SetSelected(newIsSelected);
		WorldBuilder.SetMod( newIsSelected );
	end	
end

-- ===========================================================================
function ViewMapModPage()	

	ResetTabForNewPageContent();

	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();

	m_ViewingTab.Name = "Mod";
	m_ViewingTab.ModInstance = {};
	ContextPtr:BuildInstanceForControl( "ModInstance", m_ViewingTab.ModInstance, instance.Top ) ;	
	m_ViewingTab.ModInstance.IsModCheckbox:RegisterCallback( Mouse.eLClick, OnModCheckboxButton );

	UpdateModPage();

	CalculatePrimaryTabScrollArea();

end

-- ===========================================================================
function OnMapScriptEdited( text, control )
	
	WorldBuilder.ConfigurationManager():SetMapValue("MapScript", text);

end

-- ===========================================================================
function OnRulesetEdited( text, control )
	
	WorldBuilder.ConfigurationManager():SetMapValue("Ruleset", text);

end

-- ===========================================================================
function UpdateGeneralPage()	

	if (m_ViewingTab ~= nil and m_ViewingTab.GeneralInstance ~= nil) then
		
		m_ViewingTab.GeneralInstance.IDEdit:SetText( WorldBuilder.GetID() );
		local attribs = WorldBuilder.ConfigurationManager():GetMapValues();
		m_ViewingTab.GeneralInstance.WidthEdit:SetText( tostring( attribs.Width ) );
		m_ViewingTab.GeneralInstance.WidthEdit:SetDisabled(true);
		m_ViewingTab.GeneralInstance.HeightEdit:SetText( tostring( attribs.Height ) );
		m_ViewingTab.GeneralInstance.HeightEdit:SetDisabled(true);
		m_ViewingTab.GeneralInstance.RulesetEdit:SetText( tostring( attribs.Ruleset ) );
		m_ViewingTab.GeneralInstance.MapScriptEdit:SetText( tostring( attribs.MapScript ) );

	end

end

-- ===========================================================================
function ViewMapGeneralPage()	

	ResetTabForNewPageContent();

	local instance:table = m_simpleIM:GetInstance();	
	instance.Top:DestroyAllChildren();
	
	m_ViewingTab.Name = "General";
	m_ViewingTab.GeneralInstance = {};
	ContextPtr:BuildInstanceForControl( "GeneralInstance", m_ViewingTab.GeneralInstance, instance.Top ) ;	

	m_ViewingTab.GeneralInstance.MapScriptEdit:RegisterCommitCallback( OnMapScriptEdited );
	m_ViewingTab.GeneralInstance.RulesetEdit:RegisterCommitCallback( OnRulesetEdited );

	UpdateGeneralPage();

	CalculatePrimaryTabScrollArea();
end

-- ===========================================================================
function OnShow()

	if m_tabs.selectedControl == nil then
		m_tabs.SelectTab(1);
	end
end

-- ===========================================================================
function OnClose()
	ContextPtr:SetHide(true);
end

-- ===========================================================================
function OnShowPlayerEditor(bShow)
	ContextPtr:SetHide(true);
end

-- ===========================================================================
function OnShowMapEditor(bShow)
	if bShow == nil or bShow == true then
		if ContextPtr:IsHidden() then
			ContextPtr:SetHide(false);
		end
	else
		if not ContextPtr:IsHidden() then
			ContextPtr:SetHide(true);
		end
	end
end

-- ===========================================================================
--	Init
-- ===========================================================================
function OnInit()

	-- Title
	Controls.ModalScreenTitle:SetText( Locale.ToUpper("Map Editor") );

	m_tabs = CreateTabs( Controls.TabContainer, 42, 34, 0xFF331D05 );
	AddTabSection( m_tabs, "LOC_WORLDBUILDER_TAB_GENERAL", ViewMapGeneralPage, Controls.TabContainer );
	AddTabSection( m_tabs, "LOC_WORLDBUILDER_TAB_MOD", ViewMapModPage, Controls.TabContainer );
	AddTabSection( m_tabs, "LOC_WORLDBUILDER_TAB_TEXT", ViewMapTextPage, Controls.TabContainer );

	m_tabs.SameSizedTabs(50);
	m_tabs.CenterAlignTabs(-10);		

	-- Langauges we can edit.  These should come from a data file.
	table.insert(m_LanguageEntries, { Text="en_US", Type="en_US" });
	table.insert(m_LanguageEntries, { Text="de_DE", Type="de_DE" });	
	table.insert(m_LanguageEntries, { Text="es_ES", Type="es_ES" });
	table.insert(m_LanguageEntries, { Text="fr_FR", Type="fr_FR" });
	table.insert(m_LanguageEntries, { Text="it_IT", Type="it_IT" });

	-- Register for events
	ContextPtr:SetShowHandler( OnShow );

	Controls.ModalScreenClose:RegisterCallback( Mouse.eLClick, OnClose );

	LuaEvents.WorldBuilder_ShowPlayerEditor.Add( OnShowPlayerEditor );
	LuaEvents.WorldBuilder_ShowMapEditor.Add( OnShowMapEditor );

end
ContextPtr:SetInitHandler( OnInit );