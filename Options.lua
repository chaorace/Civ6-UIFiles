-- ===========================================================================
--	Options
-- ===========================================================================
include("Civ6Common");
include("InstanceManager");
include("PopupDialogSupport");

-- ===========================================================================
--	DEBUG 
--	Toggle these for temporary debugging help.
-- ===========================================================================

local m_debugAlwaysAllowAllOptions	:boolean= false;	-- (false) When true no options are disabled, even when in game. :/


-- ===========================================================================
--	MEMBERS / VARIABLES
-- ===========================================================================


local _KeyBindingCategories = InstanceManager:new("KeyBindingCategory", "CategoryName", Controls.KeyBindingsStack);
local _KeyBindingActions = InstanceManager:new("KeyBindingAction", "Root", Controls.KeyBindingsStack);
local m_tabs;

_PromptRestartApp = false;
_PromptRestartGame = false;
_PromptResolutionAck = false;

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function OnOptionChangeRequiresAppRestart()
	_PromptRestartApp = true
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function OnOptionChangeRequiresGameRestart()
	_PromptRestartGame = true;
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function OnOptionChangeRequiresResolutionAck()
	_PromptResolutionAck = true;
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function OnCancel()
	Options.RevertOptions();
	UserConfiguration.RestoreCheckpoint();

    RefreshKeyBinding();

	_PromptRestartApp = false;
	_PromptRestartGame = false;
    _PromptResolutionAck = false;

    local value = Options.GetAudioOption("Sound", "Master Volume");
	Controls.MasterVolSlider:SetValue(value / 100.0);
    Options.SetAudioOption("Sound", "Master Volume", value, 0);

    value = Options.GetAudioOption("Sound", "Music Volume"); 
    Controls.MusicVolSlider:SetValue(value / 100.0);
    Options.SetAudioOption("Sound", "Music Volume", value, 0);

    value = Options.GetAudioOption("Sound", "SFX Volume"); 
    Controls.SFXVolSlider:SetValue(value / 100.0);
    Options.SetAudioOption("Sound", "SFX Volume", value, 0);

    value = Options.GetAudioOption("Sound", "Ambience Volume"); 
    Controls.AmbVolSlider:SetValue(value / 100.0);
    Options.SetAudioOption("Sound", "Ambience Volume", value, 0);

    value = Options.GetAudioOption("Sound", "Speech Volume"); 
    Controls.SpeechVolSlider:SetValue(value / 100.0);
    Options.SetAudioOption("Sound", "Speech Volume", value, 0);

    value = Options.GetAudioOption("Sound", "Mute Focus"); 
    if (value == 0) then
        Controls.MuteFocusCheckbox:SetSelected(false);
    else
        Controls.MuteFocusCheckbox:SetSelected(true);
    end
    Options.SetAudioOption("Sound", "Mute Focus", value, 0);

	UIManager:DequeuePopup(ContextPtr);
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function OnReset()
    function EnableControls()
        Controls.ResetButton:SetDisabled(false);
        Controls.ConfirmButton:SetDisabled(false);
        Controls.WindowCloseButton:SetDisabled(false);
    end
	function ResetOptions()
		Options.ResetOptions();

		_PromptRestartApp = false;
		_PromptRestartGame = false;
        _PromptResolutionAck = false;

        PopulateGraphicsOptions();

		TemporaryHardCodedGoodness();
        EnableControls();
	end
    function CancelReset()
        EnableControls();
    end

    _kPopupDialog:AddText(Locale.Lookup("LOC_OPTIONS_RESET_OPTIONS_POPUP_TEXT"));
	_kPopupDialog:AddButton(Locale.Lookup("LOC_OPTIONS_RESET_OPTIONS_POPUP_NO"), function() CancelReset(); end); 
    _kPopupDialog:AddButton(Locale.Lookup("LOC_OPTIONS_RESET_OPTIONS_POPUP_YES"), function() ResetOptions(); end, nil, nil,"PopupButtonAltInstance");  
    _kPopupDialog:Open();
    Controls.ResetButton:SetDisabled(true);
    Controls.ConfirmButton:SetDisabled(true);

    Controls.WindowCloseButton:SetDisabled(true);
end                       

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function OnConfirm()
    
    function KeepGraphicsChanges()
        -- Make sure the next game start uploads the changed settings telemetry
        Options.SetAppOption("Misc", "TelemetryUploadNecessary", 1);

        -- Save after applying the options to make sure they are valid
        Options.SaveOptions();
        
        _PromptRestartApp = false;
	    _PromptRestartGame = false;
        _PromptResolutionAck = false;
        
        UIManager:DequeuePopup(ContextPtr);
    end

    function RevertGraphicsChanges()
        -- Revert the graphics option changes
        Options.RevertResolutionChanges();

        -- Save after reverting the options to make sure they are valid
        Options.SaveOptions();

        _PromptRestartApp = false;
	    _PromptRestartGame = false;
        _PromptResolutionAck = false;
        
        UIManager:DequeuePopup(ContextPtr);
    end

	function ConfirmChanges()
		-- Confirm clicked: set audio system's .ini to slider values --
		Options.SetAudioOption("Sound", "Master Volume", Controls.MasterVolSlider:GetValue() * 100.0, 1);
		Options.SetAudioOption("Sound", "Music Volume", Controls.MusicVolSlider:GetValue() * 100.0, 1);
		Options.SetAudioOption("Sound", "SFX Volume", Controls.SFXVolSlider:GetValue() * 100.0, 1);
		Options.SetAudioOption("Sound", "Ambience Volume", Controls.AmbVolSlider:GetValue() * 100.0, 1);
		Options.SetAudioOption("Sound", "Speech Volume", Controls.SpeechVolSlider:GetValue() * 100.0, 1);
        if (Controls.MuteFocusCheckbox:IsSelected()) then
            Options.SetAudioOption("Sound", "Mute Focus", 1, 1);
        else
            Options.SetAudioOption("Sound", "Mute Focus", 0, 1);
        end

        -- Now we apply the userconfig options
		UserConfiguration.SetValue("QuickCombat", Options.GetUserOption("Gameplay", "QuickCombat"));
		UserConfiguration.SetValue("QuickMovement", Options.GetUserOption("Gameplay", "QuickMovement"));
		UserConfiguration.SetValue("AutoEndTurn", Options.GetUserOption("Gameplay", "AutoEndTurn"));
		UserConfiguration.SetValue("TutorialLevel", Options.GetUserOption("Gameplay", "TutorialLevel"));
		UserConfiguration.SetValue("EdgePan", Options.GetUserOption("Gameplay", "EdgePan"));
        
        -- Apply the graphics options (modifies in-memory values and modifies the engine, but does not save to disk)
        Options.ApplyGraphicsOptions();

        -- Show the resolution acknowledgment pop-up
        if(_PromptResolutionAck) then
			-- Re-populate the graphics options to update any settings that the engine had to modify from the user's selected values
			PopulateGraphicsOptions();

            _kPopupDialog:AddText(Locale.Lookup("LOC_OPTIONS_RESOLUTION_OK"));
            _kPopupDialog:AddButton(Locale.Lookup("LOC_OPTIONS_RESET_OPTIONS_POPUP_NO"), function() RevertGraphicsChanges(); end);
		    _kPopupDialog:AddButton(Locale.Lookup("LOC_OPTIONS_RESET_OPTIONS_POPUP_YES"), function() KeepGraphicsChanges(); end); 
            _kPopupDialog:AddCountDown(15, function() RevertGraphicsChanges(); end );
		    _kPopupDialog:Open();
            
            _PromptResolutionAck = false;
        else
            KeepGraphicsChanges();
        end
    end
    
	local isInGame = false;
	if(GameConfiguration ~= nil) then
		isInGame = GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_PREGAME;
	end
	
	if(_PromptRestartApp) then
		_kPopupDialog:AddText(Locale.Lookup("LOC_OPTIONS_CHANGES_REQUIRE_APP_RESTART"));
		_kPopupDialog:AddButton(Locale.Lookup("LOC_OPTIONS_RESET_OPTIONS_POPUP_OK"), function() ConfirmChanges(); end); 
		_kPopupDialog:Open();

	elseif(_PromptRestartGame and isInGame) then
		_kPopupDialog:AddText(Locale.Lookup("LOC_OPTIONS_CHANGES_REQUIRE_GAME_RESTART"));
		_kPopupDialog:AddButton(Locale.Lookup("LOC_OPTIONS_RESET_OPTIONS_POPUP_OK"), function() ConfirmChanges(); end);
		_kPopupDialog:Open();
	else
		ConfirmChanges();
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function PopulateComboBox(control, values, selected_value, selection_handler, is_locked)

	if (is_locked == nil) then
		is_locked = false;
	end

	control:ClearEntries();
	for i, v in ipairs(values) do
		local instance = {};
		control:BuildEntry( "InstanceOne", instance );
		instance.Button:SetVoid1(i);
        instance.Button:LocalizeAndSetText(v[1]);

		if(v[2] == selected_value) then
			local button = control:GetButton();
            button:LocalizeAndSetText(v[1]);
		end
	end
	control:CalculateInternals();	
		
	control:SetDisabled(is_locked ~= false);

	if(selection_handler) then
		control:RegisterSelectionCallback(
			function(voidValue1, voidValue2, control)
				local option = values[voidValue1];

				local button = control:GetButton();
                button:LocalizeAndSetText(option[1]);
								
				selection_handler(option[2]);
			end
		);
	end
    	
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function PopulateCheckBox(control, current_value, check_handler, is_locked)
    
    if (is_locked == nil) then
		is_locked = false;
	end

    if(current_value == 0) then
        control:SetSelected(false);
    else
        control:SetSelected(true);
    end

    control:SetDisabled(is_locked ~= false);

    if(check_handler) then
        control:RegisterCallback(Mouse.eLClick, 
            function()
			    local selected = not control:IsSelected();
			    control:SetSelected(selected);
                check_handler(selected);
            end
        );
    end

end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function InvertOptionInt(option)

    if(option == 0) then
        return 1;
    else
        return 0;
    end

end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function ImpactValueToSliderStep(slider, impact_value)

    if(impact_value == -1) then
        return slider:GetNumSteps();
    else
        return impact_value;
    end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function SliderStepToImpactValue(slider, slider_step)

    if(slider_step == slider:GetNumSteps()) then
        return -1;
    else
        return slider_step;
    end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local TIME_SCALE = 23.0 + (59.0 / 60.0); -- 11:59 PM
function UpdateTimeLabel(value)
	local iHours = math.floor(value);
	local iMins  = math.floor((value - iHours) * 60);
	local meridiem = "";

	if (UserConfiguration.GetClockFormat() == 0) then
		meridiem = " am";
		if ( iHours >= 12 ) then
			meridiem = " pm";
			if( iHours > 12 ) then iHours = iHours - 12; end
		end
		if( iHours < 1 ) then iHours = 12; end
	end

	local strTime = string.format("%.2d:%.2d%s", iHours, iMins, meridiem);
	Controls.TODText:SetText(strTime);
end

-- Change the state of the resolution pulldown based on whether we have selected borderless mode or not
function AdjustResolutionPulldown(is_borderless, is_in_game )
    if is_in_game then
        Controls.ResolutionPullDown:SetDisabled(true);
    else
        if is_borderless  then
            Controls.ResolutionPullDown:SetDisabled(true);
            local resolution_button = Controls.ResolutionPullDown:GetButton();
	        local display_width  = Options.GetDisplayWidth();
            local display_height = Options.GetDisplayHeight();
            resolution_button:SetText(display_width .. "x" .. display_height );
        else
            Controls.ResolutionPullDown:SetDisabled(false);
            local current_width = Options.GetAppOption("Video", "RenderWidth");
	        local current_height = Options.GetAppOption("Video", "RenderHeight");
	        local refresh_rate = Options.GetGraphicsOption("Video", "RefreshRateInHz");
	
	        local resolution_button = Controls.ResolutionPullDown:GetButton();
	        resolution_button:SetText(current_width .. "x" .. current_height .. " (" .. refresh_rate .. " Hz)");
        end

    end

end



-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
function PopulateGraphicsOptions()
    
    
    local tickInterval_options =
    {
        {"LOC_OPTIONS_DISABLED", 0},        
        {"LOC_OPTIONS_TICK_INTERVAL_20_FPS", 49},
        {"LOC_OPTIONS_TICK_INTERVAL_30_FPS", 32},
        {"LOC_OPTIONS_TICK_INTERVAL_60_FPS", 16},
    };

    local BORDERLESS_OPTION = 2;
    local FULLSCREEN_OPTION = 1;
    local WINDOWED_OPTION = 0;
	local windowed_options =
    {
		{"LOC_OPTIONS_WINDOW_MODE_WINDOWED", WINDOWED_OPTION},
		{"LOC_OPTIONS_WINDOW_MODE_FULLSCREEN", FULLSCREEN_OPTION},
		{"LOC_OPTIONS_WINDOW_MODE_BORDERLESS", BORDERLESS_OPTION}
	};

    local performanceImpact_options =
    { 
        [0]="LOC_OPTIONS_MINIMUM",
            "LOC_OPTIONS_LOW", 
            "LOC_OPTIONS_MEDIUM",
            "LOC_OPTIONS_HIGH",
			"LOC_OPTIONS_ULTRA",
            "LOC_OPTIONS_CUSTOM"
    };

    local memoryImpact_options =
    { 
        [0]="LOC_OPTIONS_MINIMUM",
            "LOC_OPTIONS_LOW", 
            "LOC_OPTIONS_MEDIUM",
            "LOC_OPTIONS_HIGH",
			"LOC_OPTIONS_ULTRA",
            "LOC_OPTIONS_CUSTOM"
    };

	local msaa_options =
    {
		{"LOC_OPTIONS_DISABLED", {1,  0}},
		{"LOC_OPTIONS_MSAA_2X",  {2,  0}},
		{"LOC_OPTIONS_MSAA_4X",  {4,  0}},
		{"LOC_OPTIONS_MSAA_8X",  {8,  0}},
		{"LOC_OPTIONS_MSAA_16X", {16, 0}},
		{"LOC_OPTIONS_MSAA_32X", {32, 0}},
	};

    local csaa_options =
    {
		{"LOC_OPTIONS_CSAA_2X",  {2,  4}},
		{"LOC_OPTIONS_CSAA_4X",  {4,  8}},
		{"LOC_OPTIONS_CSAA_8X",  {8,  16}},
		{"LOC_OPTIONS_CSAA_16X", {16, 32}},
	};

    local eqaa_options =
    {
		{"LOC_OPTIONS_EQAA_2X",  {2,  4}},
		{"LOC_OPTIONS_EQAA_4X",  {4,  8}},
		{"LOC_OPTIONS_EQAA_8X",  {8,  16}},
		{"LOC_OPTIONS_EQAA_16X", {16, 32}},
	};

    local vfx_options =
    {
        {"LOC_OPTIONS_LOW", 0},
        {"LOC_OPTIONS_HIGH", 1}
    };

    local aoResolution_options =
    {
        {"1024x1024", 1024},
        {"2048x2048", 2048},
    };

    local shadowResolution_options =
    {
        {"2048x2048", 2048},
        {"4096x4096", 4096},
        {"8192x8192", 8192},
    };

    local overlayResolution_options =
    {
        {"2048x2048", 2048},
        {"4096x4096", 4096},
    };

    local fowMaskResolution_options =
    {
        {"512x512", 512},
        {"1024x1024", 1024},
    };

	local terrainQuality_options =
    {
		{"LOC_OPTIONS_LOW_MEMORY_OPTIMIZED", 0},
		{"LOC_OPTIONS_LOW_PERFORMANCE_OPTIMIZED", 1},
		{"LOC_OPTIONS_MEDIUM_MEMORY_OPTIMIZED", 2},
		{"LOC_OPTIONS_MEDIUM_PERFORMANCE_OPTIMIZED", 3},
		{"LOC_OPTIONS_HIGH", 4},
	};

    local reflectionPasses_options =
    {
		{"LOC_OPTIONS_DISABLED", 0},
		{"LOC_OPTIONS_REFLECTION_1PASS", 1},
		{"LOC_OPTIONS_REFLECTION_2PASSES", 2},
		{"LOC_OPTIONS_REFLECTION_3PASSES", 3},
		{"LOC_OPTIONS_REFLECTION_4PASSES", 4},
	};
	
	local leaderQuality_options =
	{
		{"LOC_OPTIONS_DISABLED", 0},
		{"LOC_OPTIONS_LOW",      1},
		{"LOC_OPTIONS_MEDIUM",   2},
		{"LOC_OPTIONS_HIGH",     3},
	}

    -------------------------------------------------------------------------------
    -- Main Options
    -------------------------------------------------------------------------------

    local is_in_game = Options.IsAppInMainMenuState() == 0;
    if m_debugAlwaysAllowAllOptions then
        is_in_game = false
    end

    -- Adapter
    local adapters = Options.GetAvailableDisplayAdapters();

    Controls.AdapterPullDown:ClearEntries();
	for i, v in pairs(adapters) do
		local instance = {};
		Controls.AdapterPullDown:BuildEntry( "InstanceOne", instance );
		instance.Button:SetVoid1(i);
		instance.Button:SetText(v);
	end
	Controls.AdapterPullDown:CalculateInternals();

    local adapter_index = Options.GetAppOption("Video", "DeviceID");

    local adapter_button = Controls.AdapterPullDown:GetButton();
	adapter_button:SetText(adapters[adapter_index]);

    Controls.AdapterPullDown:RegisterSelectionCallback(
		function(voidValue1, voidValue2, control)
			local adapter_button = control:GetButton();
			adapter_button:SetText(adapters[voidValue1]);

			Options.SetAppOption("Video", "DeviceID", voidValue1);

            _PromptRestartApp = true;
		end
	);

    -- Resolution
	local named_modes = {};
	local modes = Options.GetAvailableDisplayModes();
	for i, v in ipairs(modes) do
		local s = v.Width .. "x" .. v.Height .. " (" .. v.RefreshRate .. " Hz)";
		named_modes[s] = v;
	end

	local indexed_modes = {};
	for k, v in pairs(named_modes) do
		table.insert(indexed_modes, {k, v});
	end
	table.sort(indexed_modes, function(a, b) return a[1] > b[1]; end);

    Controls.ResolutionPullDown:ClearEntries();
	for i, v in ipairs(indexed_modes) do
		local instance = {};
		Controls.ResolutionPullDown:BuildEntry( "InstanceOne", instance );
		instance.Button:SetVoid1(i);
		instance.Button:SetText(v[1]);
	end
	Controls.ResolutionPullDown:CalculateInternals();
	
	local current_width = Options.GetAppOption("Video", "RenderWidth");
	local current_height = Options.GetAppOption("Video", "RenderHeight");
	local refresh_rate = Options.GetGraphicsOption("Video", "RefreshRateInHz");
	
	local resolution_button = Controls.ResolutionPullDown:GetButton();
	resolution_button:SetText(current_width .. "x" .. current_height .. " (" .. refresh_rate .. " Hz)");

	Controls.ResolutionPullDown:RegisterSelectionCallback(
		function(voidValue1, voidValue2, control)
			local option = indexed_modes[voidValue1];

			local resolution_button = control:GetButton();
			resolution_button:SetText(option[1]);

			Options.SetAppOption("Video", "RenderWidth", option[2].Width);
			Options.SetAppOption("Video", "RenderHeight", option[2].Height);
			Options.SetGraphicsOption("Video", "RefreshRateInHz", option[2].RefreshRate);

            local fullscreen_option = Options.GetAppOption("Video", "FullScreen");
            _PromptResolutionAck = (fullscreen_option == FULLSCREEN_OPTION);
		end
	);

    -- UI Upscale
    PopulateCheckBox(Controls.UIUpscaleCheckbox, Options.GetAppOption("Video", "UIUpscale"),
        function(option)
            Options.SetAppOption("Video", "UIUpscale", option);
        end
    );
    Controls.UIUpscaleCheckbox:SetDisabled( Options.IsUIUpscaleAllowed() == 0 );

    local performance_customStep = Controls.PerformanceSlider:GetNumSteps();
    local memory_customStep = Controls.MemorySlider:GetNumSteps();

    -- Performance Impact
    local performance_sliderStep = ImpactValueToSliderStep(Controls.PerformanceSlider, Options.GetGraphicsOption("Video", "PerformanceImpact"));
    
    Controls.PerformanceSlider:SetStep(performance_sliderStep);
    Controls.PerformanceValue:LocalizeAndSetText(performanceImpact_options[performance_sliderStep]);

    local performance_sliderValue = Controls.PerformanceSlider:GetValue();

    Controls.PerformanceSlider:RegisterSliderCallback(
    	function(option)
        
            -- Guard against multiple calls with the same value
            if(performance_sliderValue ~= option) then

                -- This has to happen before SetStepAndCall(), otherwise we get into an endless loop
                performance_sliderValue = option;

                -- We can't rely on option, because it is a float value [0.0 .. 1.0] and we need the step integer number
                performance_sliderStep = Controls.PerformanceSlider:GetStep();

                -- Update the option set with the new preset, which updates all other options (see OptionSet::ProcessExternally())
                Options.SetGraphicsOption("Video", "PerformanceImpact", SliderStepToImpactValue(Controls.PerformanceSlider, performance_sliderStep));
            
                -- Update the text description
                Controls.PerformanceValue:LocalizeAndSetText(performanceImpact_options[performance_sliderStep]);

                if(performance_sliderStep ~= performance_customStep) then

                    if(Controls.MemorySlider:GetStep() == memory_customStep) then
                        -- The memory slider is set to "custom", so reset it to its default value
                        Controls.MemorySlider:SetStepAndCall(ImpactValueToSliderStep(Controls.MemorySlider, Options.GetGraphicsDefault("Video", "MemoryImpact")));
                    end

                    -- Update all settings in the UI if the performance impact changed to something other than "custom"
                    PopulateGraphicsOptions();

                else
                    -- The performance slider is set to "custom", so set the memory slider to "custom" as well
                    Controls.MemorySlider:SetStepAndCall(memory_customStep);
                end
                
            end
    	end
    );

    -- Memory Impact
    local memory_sliderStep = ImpactValueToSliderStep(Controls.MemorySlider, Options.GetGraphicsOption("Video", "MemoryImpact"));
    
    Controls.MemorySlider:SetStep(memory_sliderStep);
    Controls.MemoryValue:LocalizeAndSetText(memoryImpact_options[memory_sliderStep]);

    local memory_sliderValue = Controls.MemorySlider:GetValue();

    Controls.MemorySlider:RegisterSliderCallback(
    	function(option)
            
            -- Guard against multiple calls with the same value
            if(memory_sliderValue ~= option) then

                -- This has to happen before SetStepAndCall(), otherwise we get into an endless loop
                memory_sliderValue = option;

                -- We can't rely on option, because it is a float value [0.0 .. 1.0] and we need the step integer number
                memory_sliderStep = Controls.MemorySlider:GetStep();

                -- Update the option set with the new preset, which updates all other options (see OptionSet::ProcessExternally())
                Options.SetGraphicsOption("Video", "MemoryImpact", SliderStepToImpactValue(Controls.MemorySlider, memory_sliderStep));

                -- Update the text description
                Controls.MemoryValue:LocalizeAndSetText(memoryImpact_options[memory_sliderStep]);

                if(memory_sliderStep ~= memory_customStep) then

                    if(Controls.PerformanceSlider:GetStep() == performance_customStep) then
                        -- The performance slider is set to "custom", so reset it to its default
                        Controls.PerformanceSlider:SetStepAndCall(ImpactValueToSliderStep(Controls.PerformanceSlider, Options.GetGraphicsDefault("Video", "PerformanceImpact")));
                    end

                    -- Update all settings in the UI if the memory impact changed to something other than "custom"
                    PopulateGraphicsOptions();

                else
                    -- The memory slider is set to "custom", so set the performance slider to "custom" as well
                    Controls.PerformanceSlider:SetStepAndCall(performance_customStep);
                end
                
            end
    	end
    );

    -------------------------------------------------------------------------------
    -- Advanced Settings
    -------------------------------------------------------------------------------

    -- VSync
    PopulateCheckBox(Controls.VSyncEnabledCheckbox, Options.GetGraphicsOption("Video", "VSync"),
        function(option)
            Options.SetGraphicsOption("Video", "VSync", option);
        end
    );
	
    -- Tick Interval
    PopulateComboBox(Controls.TickIntervalPullDown, tickInterval_options, Options.GetAppOption("Performance", "TickIntervalInMS"), 
        function(option)
	    	Options.SetAppOption("Performance", "TickIntervalInMS", option);
	    end
    );
    
    -- Fullscreen
	PopulateComboBox(Controls.FullScreenPullDown, windowed_options,  Options.GetAppOption("Video", "FullScreen"), 
        function(option)
		    Options.SetAppOption("Video", "FullScreen", option);

            -- In borderless mode, snap width/height to desktop size
            if option == BORDERLESS_OPTION then
            	Options.SetAppOption("Video", "RenderWidth",  Options.GetDisplayWidth());
			    Options.SetAppOption("Video", "RenderHeight", Options.GetDisplayHeight());
            end

            AdjustResolutionPulldown(option == BORDERLESS_OPTION, is_in_game )

            _PromptResolutionAck = (option == FULLSCREEN_OPTION);
	    end
    );	

    -- MSAA
    local nMaxMSAACount = UI.GetMaxMSAACount();
    
    local availableMSAAOptions = {};
	for i, v in ipairs(msaa_options) do
        local bValid = UI.CanHaveMSAAQuality(v[2][1], v[2][2])
        if(bValid) then
			table.insert(availableMSAAOptions, {v[1], v[2]});
        end
	end

    local ihvMSAAModes = nil;
    if UI.IsVendorAMD() then
        ihvMSAAModes = eqaa_options;
    elseif UI.IsVendorNVIDIA() then
        ihvMSAAModes = csaa_options;
    end

    if ihvMSAAModes ~= nil then
        for i, v in ipairs(ihvMSAAModes) do
            local bValid = UI.CanHaveMSAAQuality(v[2][1], v[2][2])
            if(bValid) then
			    table.insert(availableMSAAOptions, {v[1], v[2]});
            end
	    end
    end

    local nMSAACount = Options.GetGraphicsOption("Video", "MSAA");
    if nMSAACount == -1 then
        nMSAACount = nMaxMSAACount;
    end
    local nMSAAQuality = Options.GetGraphicsOption("Video", "MSAAQuality");

    -- PopulateComboBox() does a "pointer" compare with non POD, so we have to find the current sample / quality in the MSAA tables
    -- so that we can pass it into PopulateComboBox()
    local msaaValue = msaa_options[1][2];
    if nMSAAQuality == 0 then
        for i, v in ipairs(msaa_options) do
            if v[2][1] == nMSAACount and v[2][2] == nMSAAQuality then
                msaaValue = v[2];
                break;
            end
        end
    elseif ihvMSAAModes ~= nil then
        for i, v in ipairs(ihvMSAAModes) do
            if v[2][1] == nMSAACount and v[2][2] == nMSAAQuality then
                msaaValue = v[2];
                break;
            end
        end
    end

    PopulateComboBox(Controls.MSAAPullDown, availableMSAAOptions, msaaValue,
        function(option)
            Controls.PerformanceSlider:SetStepAndCall(performance_customStep);  -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
            Options.SetGraphicsOption("Video", "MSAA", option[1]);              -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
            Options.SetGraphicsOption("Video", "MSAAQuality", option[2]);
	    end
    );

    -- High-Resolution Asset Textures
    PopulateCheckBox(Controls.AssetTextureResolutionCheckbox, InvertOptionInt(Options.GetGraphicsOption("Video", "ReducedAssetTextures")),
        function(option)
            Controls.MemorySlider:SetStepAndCall(memory_customStep);                -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
            Options.SetGraphicsOption("Video", "ReducedAssetTextures", not option); -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset

            _PromptRestartGame = true;
        end
    );

    -- High-Quality Visual Effects
    PopulateComboBox(Controls.VFXDetailLevelPullDown, vfx_options, Options.GetGraphicsOption("General", "VFXDetailLevel"), 
        function(option)
            Controls.PerformanceSlider:SetStepAndCall(performance_customStep);  -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
		    Options.SetGraphicsOption("General", "VFXDetailLevel", option);     -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
	    end
    );
	
    -------------------------------------------------------------------------------
    -- Advanced Settings - Lighting
    -------------------------------------------------------------------------------
    
    -- Bloom Enabled
    PopulateCheckBox(Controls.LightingBloomEnabledCheckbox, Options.GetGraphicsOption("Bloom", "EnableBloom"),
        function(option)
            Controls.PerformanceSlider:SetStepAndCall(performance_customStep);  -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
            Options.SetGraphicsOption("Bloom", "EnableBloom", option);          -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
        end
    );

    -- Dynamic Lighting Enabled
    PopulateCheckBox(Controls.LightingDynamicLightingEnabledCheckbox, Options.GetGraphicsOption("DynamicLighting", "EnableDynamicLighting"),
        function(option)
            Controls.PerformanceSlider:SetStepAndCall(performance_customStep);              -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
            Options.SetGraphicsOption("DynamicLighting", "EnableDynamicLighting", option);  -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
        end
    );
    
    -------------------------------------------------------------------------------
    -- Advanced Settings - Shadows
    -------------------------------------------------------------------------------

    -- Shadows Enabled
    PopulateCheckBox(Controls.ShadowsEnabledCheckbox, Options.GetGraphicsOption("Shadows", "EnableShadows"),
        function(option)
            Controls.PerformanceSlider:SetStepAndCall(performance_customStep);  -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
            Options.SetGraphicsOption("Shadows", "EnableShadows", option);      -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset

            Controls.ShadowsResolutionPullDown:SetDisabled(not option);
        end
    );

    -- Shadow Resolution
    PopulateComboBox(Controls.ShadowsResolutionPullDown, shadowResolution_options, Options.GetGraphicsOption("Video", "ShadowMapResolution"), 
        function(option)
            Controls.MemorySlider:SetStepAndCall(memory_customStep);            -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
		    Options.SetGraphicsOption("Video", "ShadowMapResolution", option);  -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
	    end,
        Options.GetGraphicsOption("Shadows", "EnableShadows") == 0
    );

    -------------------------------------------------------------------------------
    -- Advanced Settings - Overlay
    -------------------------------------------------------------------------------

    -- Overlay Resolution
    PopulateComboBox(Controls.OverlayResolutionPullDown, overlayResolution_options, Options.GetGraphicsOption("Video", "OverlayResolution"), 
        function(option)
            Controls.MemorySlider:SetStepAndCall(memory_customStep);            -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
		    Options.SetGraphicsOption("Video", "OverlayResolution", option);    -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
	    end
    );
    
    -- Screen-Space Overlay Enabled
    PopulateCheckBox(Controls.SSOverlayEnabledCheckbox, Options.GetGraphicsOption("General", "ScreenSpaceOverlay"),
        function(option)
            Controls.PerformanceSlider:SetStepAndCall(performance_customStep);  -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
            Options.SetGraphicsOption("General", "ScreenSpaceOverlay", option); -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
        end
    );
        
    -------------------------------------------------------------------------------
    -- Advanced Settings - Terrain
    -------------------------------------------------------------------------------

    -- Terrain Quality
	PopulateComboBox(Controls.TerrainQualityPullDown, terrainQuality_options, Options.GetGraphicsOption("Terrain", "TerrainQuality"), 
        function(option)
             Controls.PerformanceSlider:SetStepAndCall(performance_customStep); -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
	    	 Options.SetGraphicsOption("Terrain", "TerrainQuality", option);    -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset

	    	 _PromptRestartGame = true;
	    end
    );

    -- Terrain Synthesis
    local terrainSynthesis_option = Options.GetGraphicsOption("Terrain", "TerrainSynthesisDetailLevel");

    -- 1 = full-res, 2 = low-res, because of course.
    if(terrainSynthesis_option == 2) then 
        terrainSynthesis_option = 0;
    end

    PopulateCheckBox(Controls.TerrainSynthesisCheckbox, terrainSynthesis_option,
        function(option)
            Controls.PerformanceSlider:SetStepAndCall(performance_customStep);  -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
            -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
            -- 1 = full-res, 2 = low-res, because of course.
            if(option) then
                Options.SetGraphicsOption("Terrain", "TerrainSynthesisDetailLevel", 1);
            else
                Options.SetGraphicsOption("Terrain", "TerrainSynthesisDetailLevel", 2);
            end

            _PromptRestartGame = true;
        end
    );

    -- High-Resolution Textures
    PopulateCheckBox(Controls.TerrainTextureResolutionCheckbox, InvertOptionInt(Options.GetGraphicsOption("Terrain", "ReducedTerrainMaterials")),
        function(option)
            Controls.MemorySlider:SetStepAndCall(memory_customStep);                        -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
            Options.SetGraphicsOption("Terrain", "ReducedTerrainMaterials", not option);    -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
        end
    );

    -- Low-quality Shader
    PopulateCheckBox(Controls.TerrainShaderCheckbox, InvertOptionInt(Options.GetGraphicsOption("Terrain", "LowQualityTerrainShader")),
        function(option)
            Controls.PerformanceSlider:SetStepAndCall(performance_customStep);              -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
            Options.SetGraphicsOption("Terrain", "LowQualityTerrainShader", not option);    -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset

            Controls.TerrainAOEnabledCheckbox:SetDisabled(not option);
            
            local bAODropDownEnabled = option and Options.GetGraphicsOption("AO", "EnableAO") == 1;
            Controls.TerrainAOResolutionPullDown:SetDisabled(not bAODropDownEnabled);
        end
    );

    -- Ambient Occlusion Enabled
    PopulateCheckBox(Controls.TerrainAOEnabledCheckbox, Options.GetGraphicsOption("AO", "EnableAO"),
        function(option)
            Controls.PerformanceSlider:SetStepAndCall(performance_customStep);  -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
            Options.SetGraphicsOption("AO", "EnableAO", option);                -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset

            Controls.TerrainAOResolutionPullDown:SetDisabled(not option);
        end,
        Options.GetGraphicsOption("Terrain", "LowQualityTerrainShader") == 1
    );

    -- Ambient Occlusion Render and Depth Resolutions
    PopulateComboBox(Controls.TerrainAOResolutionPullDown, aoResolution_options, Options.GetGraphicsOption("Video", "AORenderResolution"), 
        function(option)
            Controls.MemorySlider:SetStepAndCall(memory_customStep);            -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
		    Options.SetGraphicsOption("Video", "AORenderResolution", option);   -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
            Options.SetGraphicsOption("Video", "AODepthResolution", option);
	    end,
        Options.GetGraphicsOption("AO", "EnableAO") == 0 or Options.GetGraphicsOption("Terrain", "LowQualityTerrainShader") == 1
    );

    -- Clutter Detail Level
    PopulateCheckBox(Controls.TerrainClutterCheckbox, Options.GetGraphicsOption("General", "ClutterDetailLevel"),
        function(option)
            Controls.PerformanceSlider:SetStepAndCall(performance_customStep);  -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
            Options.SetGraphicsOption("General", "ClutterDetailLevel", option); -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
        end
    );

    -------------------------------------------------------------------------------
    -- Advanced Settings - Water
    -------------------------------------------------------------------------------

    -- Water Quality
    PopulateCheckBox(Controls.WaterResolutionCheckbox, InvertOptionInt(Options.GetGraphicsOption("General", "UseLowResWater")),
        function(option)
            Controls.MemorySlider:SetStepAndCall(memory_customStep);            -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
            Options.SetGraphicsOption("General", "UseLowResWater", not option); -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
        end
    );

    -- Water Shader
    PopulateCheckBox(Controls.WaterShaderCheckbox, InvertOptionInt(Options.GetGraphicsOption("General", "UseLowQualityWaterShader")),
        function(option)
            Controls.PerformanceSlider:SetStepAndCall(performance_customStep);              -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
            Options.SetGraphicsOption("General", "UseLowQualityWaterShader", not option);   -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
        end
    );

    -- Screen-space Reflection Passes
    PopulateComboBox(Controls.WaterReflectionPassesPullDown, reflectionPasses_options, Options.GetGraphicsOption("General", "SSReflectPasses"), 
        function(option)
            Controls.PerformanceSlider:SetStepAndCall(performance_customStep);  -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
		    Options.SetGraphicsOption("General", "SSReflectPasses", option);    -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
	    end
    );

    -------------------------------------------------------------------------------
    -- Advanced Settings - Leaders
    -------------------------------------------------------------------------------

	 -- Leader Quality
    PopulateComboBox(Controls.LeaderQualityPullDown, leaderQuality_options, Options.GetGraphicsOption("Leaders", "Quality"), 
        function(option)
            Controls.PerformanceSlider:SetStepAndCall(performance_customStep);  -- It's enough to set just one of the Impact sliders to "custom", the logic sets the other one
		    Options.SetGraphicsOption("Leaders", "Quality", option);     -- First set the sliders to "custom", then set the new value, otherwise ProcessExternally() will overwrite the new value with a preset
			if (UI.LeaderQualityRequiresRestart(option)) then
				_PromptRestartGame = true;
			end
	    end
    );
    
    -- Disable things we aren't allowed to change when game is running
    Controls.UIUpscaleCheckbox:SetDisabled( is_in_game or (Options.IsUIUpscaleAllowed()==0) )
    Controls.FullScreenPullDown:SetDisabled( is_in_game )
    Controls.TerrainSynthesisCheckbox:SetDisabled( is_in_game )
    Controls.TerrainQualityPullDown:SetDisabled( is_in_game )
    Controls.TerrainSynthesisCheckbox:SetDisabled( is_in_game )
    Controls.AdapterPullDown:SetDisabled( is_in_game )

    -- Put resolution dropdown in the right state for current borderless setting
    AdjustResolutionPulldown( Options.GetAppOption("Video", "FullScreen") == BORDERLESS_OPTION, is_in_game )

end

-------------------------------------------------------------------------------
-- "OMG This is so hard-coded."  Yep. It is.
-- This will be replaced w/ 'real' code eventually.    (... or will it :))
-------------------------------------------------------------------------------
function TemporaryHardCodedGoodness()

    local boolean_options = {
		{"LOC_OPTIONS_ENABLED", 1},
		{"LOC_OPTIONS_DISABLED", 0},
	};

	local tutorial_options = {
		{"LOC_OPTIONS_DISABLED", -1},
		{"LOC_OPTIONS_TUTORIAL_FAMILIAR_CIVILIZATION", 0},
		{"LOC_OPTIONS_TUTORIAL_FAMILIAR_STRATEGY", 1}
	};

	local autosave_settings = {
		{"1", 1},
		{"2", 2},
		{"3", 3},
		{"4", 4},
		{"5", 5},
		{"6", 6},
		{"7", 7},
		{"8", 8},
		{"9", 9},
		{"10", 10}
	};

	-- Quick note about language names.
	-- Not all languages return in upper-case.  This is because certain languages don't 
	-- upper-case language names! 
	-- However, since we are using them as single terms, we do want to title case it.
	local currentLanguage = Locale.GetCurrentLanguage();
	local currentLocale = currentLanguage and currentLanguage.Type or "en_US";


	local language_options = {};
	local languages = Locale.GetLanguages();

	for i, v in ipairs(languages) do
		table.insert(language_options, {
			Locale.Lookup("{1: title}", v.Name),
			v.Locale,
		});
	end
	
	function LangName(l)
		return Locale.Lookup("{1: title}", Locale.GetLanguageDisplayName(l, currentLocale));
	end

	local audio_language_options = {};
	local audioLanguages = Locale.GetAudioLanguages();

	for i, v in ipairs(audioLanguages) do
		table.insert(audio_language_options, {
			LangName(v.Locale), 
			v.AudioLanguage
		});
	end	

	local clock_options = {
		{"LOC_OPTIONS_12HOUR", 0},
		{"LOC_OPTIONS_24HOUR", 1},
	};

    local grab_options = {
		{"LOC_OPTIONS_NEVER", 0},
		{"LOC_OPTIONS_WINDOW_MODE_FULLSCREEN", 1},
		{"LOC_OPTIONS_ALWAYS", 2},
	};


	-- Populate the pull-downs because we can't do this in XML.
	--Gameplay
	PopulateComboBox(Controls.QuickCombatPullDown, boolean_options, Options.GetUserOption("Gameplay", "QuickCombat"), function(option)
		Options.SetUserOption("Gameplay", "QuickCombat", option);
	end, 
	UserConfiguration.IsValueLocked("QuickCombat"));
	
	
	PopulateComboBox(Controls.QuickMovementPullDown, boolean_options, Options.GetUserOption("Gameplay", "QuickMovement"), function(option)
		Options.SetUserOption("Gameplay", "QuickMovement", option);
	end,
	UserConfiguration.IsValueLocked("QuickMovement"));

	PopulateComboBox(Controls.AutoEndTurnPullDown, boolean_options, Options.GetUserOption("Gameplay", "AutoEndTurn"), function(option)
		Options.SetUserOption("Gameplay", "AutoEndTurn", option);
	end,
	UserConfiguration.IsValueLocked("AutoEndTurn"));

	PopulateComboBox(Controls.TunerPullDown, boolean_options, Options.GetAppOption("Debug", "EnableTuner"), function(option)
		Options.SetAppOption("Debug", "EnableTuner", option);
		_PromptRestartApp = true;
	end);	

	PopulateComboBox(Controls.TutorialPullDown, tutorial_options, Options.GetUserOption("Gameplay", "TutorialLevel"), function(option)
		Options.SetUserOption("Gameplay", "TutorialLevel", option);
	end,
	UserConfiguration.IsValueLocked("TutorialLevel"));	

	PopulateComboBox(Controls.SaveFrequencyPullDown, autosave_settings, Options.GetUserOption("Gameplay", "AutoSaveFrequency"), function(option)
		Options.SetUserOption("Gameplay", "AutoSaveFrequency", option);
	end);	

	PopulateComboBox(Controls.SaveKeepPullDown, autosave_settings, Options.GetUserOption("Gameplay", "AutoSaveKeepCount"), function(option)
		Options.SetUserOption("Gameplay", "AutoSaveKeepCount", option);
	end);	

	local fTOD = Options.GetGraphicsOption("General", "DefaultTimeOfDay");
	Controls.TODSlider:SetValue(fTOD / TIME_SCALE);
	UpdateTimeLabel(fTOD);
    Controls.TODSlider:RegisterSliderCallback(function(value)
		local fTime = value * TIME_SCALE;
        Options.SetGraphicsOption("General", "DefaultTimeOfDay", fTime, 0);
        UI.SetAmbientTimeOfDay(fTime);
		UpdateTimeLabel(fTime);
    end);

    PopulateCheckBox(Controls.TimeOfDayCheckbox, Options.GetGraphicsOption("General", "AmbientTimeOfDay"), function(option)
        Options.SetGraphicsOption("General", "AmbientTimeOfDay", option);
        UI.SetAmbientTimeOfDayAnimating(option);
    end
    );

	-- Interface
	PopulateComboBox(Controls.ClockFormat, clock_options, Options.GetUserOption("Interface", "ClockFormat"), function(option)
		UserConfiguration.SetValue("ClockFormat", option);
		Options.SetUserOption("Interface", "ClockFormat", option);
	end,
	UserConfiguration.IsValueLocked("ClockFormat"));	


	-- Language
	PopulateComboBox(Controls.DisplayLanguagePullDown, language_options, Options.GetAppOption("Language", "DisplayLanguage"), function(option)
		Options.SetAppOption("Language", "DisplayLanguage", option);
		_PromptRestartApp = true;
	end);	

	PopulateComboBox(Controls.SpokenLanguagePullDown, audio_language_options, Options.GetAppOption("Language", "AudioLanguage"), function(option)
		Options.SetAppOption("Language", "AudioLanguage", option);
		_PromptRestartApp = true;
	end);	

    PopulateCheckBox(Controls.EnableSubtitlesCheckbox, Options.GetAppOption("Language", "EnableSubtitles"), function(value)
        if (value == true) then
            Options.SetAppOption("Language", "EnableSubtitles", 1);
        else
            Options.SetAppOption("Language", "EnableSubtitles", 0);
        end
    end);

    -- Sound
	Controls.MasterVolSlider:SetValue(Options.GetAudioOption("Sound", "Master Volume") / 100.0);
    Controls.MasterVolSlider:RegisterSliderCallback(
    	function(value)
            Options.SetAudioOption("Sound", "Master Volume", value * 100.0, 0);
            UI.PlaySound("Bus_Feedback_Master");
    	end
    );

    Controls.MusicVolSlider:SetValue(Options.GetAudioOption("Sound", "Music Volume") / 100.0);
    Controls.MusicVolSlider:RegisterSliderCallback(
    	function(value)
            Options.SetAudioOption("Sound", "Music Volume", value * 100.0, 0);
    	end
    );

    Controls.SFXVolSlider:SetValue(Options.GetAudioOption("Sound", "SFX Volume") / 100.0);
    Controls.SFXVolSlider:RegisterSliderCallback(
    	function(value)
            Options.SetAudioOption("Sound", "SFX Volume", value * 100.0, 0);
            UI.PlaySound("Bus_Feedback_SFX");
    	end
    );

	Controls.AmbVolSlider:SetValue(Options.GetAudioOption("Sound", "Ambience Volume") / 100.0);
    Controls.AmbVolSlider:RegisterSliderCallback(
    	function(value)
            Options.SetAudioOption("Sound", "Ambience Volume", value * 100.0, 0);
            UI.PlaySound("Bus_Feedback_Ambience");
    	end
    );

	Controls.SpeechVolSlider:SetValue(Options.GetAudioOption("Sound", "Speech Volume") / 100.0);
    Controls.SpeechVolSlider:RegisterSliderCallback(
    	function(value)
            Options.SetAudioOption("Sound", "Speech Volume", value * 100.0, 0);
            UI.PlaySound("Bus_Feedback_Speech");
    	end
    );

    PopulateCheckBox(Controls.MuteFocusCheckbox, Options.GetAudioOption("Sound", "Mute Focus"),
        function(value)
            if (value == true) then
                Options.SetAudioOption("Sound", "Mute Focus", 1, 0);
            else
                Options.SetAudioOption("Sound", "Mute Focus", 0, 0);
            end
        end
            );

        --    if (Options.GetAudioOption("Sound", "Mute Focus") == 0) then
        --        Controls.MuteFocusCheckbox:SetSelected(false);
        --    else
--        Controls.MuteFocusCheckbox:SetSelected(true);
--    end
--    Controls.MuteFocusCheckbox:RegisterCallback( Mouse.eLClick,
--        function(value)
--            if (value == true) then
--                Options.SetAudioOption("Sound", "Mute Focus", 1, 0);
--            else
--                Options.SetAudioOption("Sound", "Mute Focus", 0, 0);
--            end
--        end
--    );

    -- Interface
	PopulateComboBox(Controls.StartInStrategicView, boolean_options, Options.GetUserOption("Gameplay", "StartInStrategicView"), function(option)
		Options.SetUserOption("Gameplay", "StartInStrategicView", option);
		_PromptRestartGame = true;
	end);

    PopulateComboBox(Controls.MouseGrabPullDown, grab_options, Options.GetAppOption("Video", "MouseGrab"), function(option)
		Options.SetAppOption("Video", "MouseGrab", option);
        _PromptRestartApp = true;
	end
    );
	PopulateComboBox(Controls.EdgeScrollPullDown, boolean_options, Options.GetUserOption("Gameplay", "EdgePan"), function(option)
		Options.SetUserOption("Gameplay", "EdgePan", option);
        OnOptionChangeRequiresAppRestart();
	end, 
	UserConfiguration.IsValueLocked("EdgePan"));

    -- Application
    PopulateComboBox(Controls.ShowIntroPullDown, boolean_options, Options.GetAppOption("Video", "PlayIntroVideo"), function(option)
        Options.SetAppOption("Video", "PlayIntroVideo", option);
    end
    );
end

----------------------------------------------------------------        
-- Input handling
----------------------------------------------------------------       
function InputHandler( pInputStruct )
	-- Handle escape being pressed to cancel active key binding.
	local uiMsg = pInputStruct:GetMessageType();
	if(uiMsg == KeyEvents.KeyUp) then
		local uiKey = pInputStruct:GetKey();
		if(uiKey == Keys.VK_ESCAPE and not Controls.KeyBindingPopup:IsHidden()) then
			StopActiveKeyBinding();
			return true;
		end
        -- if we're here, we're not in control bindings mode
		if(uiKey == Keys.VK_ESCAPE) then
			OnCancel();
			return true;
		end
	end
	
	return false;
end

-------------------------------------------------------------------------------
-- 
-------------------------------------------------------------------------------
function InitializeKeyBinding()
		
	-- Key binding infrastructure.
	function RefreshKeyBinding()
		local ActionIdIndex = 1;
		local ActionNameIndex = 2;
		local ActionCategoryIndex = 3;
		local Gesture1Index = 4;
		local Gesture2Index = 5;

		local actions = {};
		local count = Input.GetActionCount();
		for i = 0, count - 1, 1 do
			local action = Input.GetActionId(i);
			local info = {
				action,
				Locale.Lookup(Input.GetActionName(action)),
				Locale.Lookup(Input.GetActionCategory(action)),
				Input.GetGestureDisplayString(action, 0) or false,
				Input.GetGestureDisplayString(action, 1) or false
			};
			table.insert(actions, info);
		end
	
		table.sort(actions, function(a, b)
			local result = Locale.Compare(a[ActionCategoryIndex], b[ActionCategoryIndex]);
			if(result == 0) then
				return Locale.Compare(a[ActionNameIndex], b[ActionNameIndex]) == -1;
			else
				return result == -1;
			end	
		end);


		_KeyBindingCategories:ResetInstances();
		_KeyBindingActions:ResetInstances();


		local currentCategory;
		for i, action in ipairs(actions) do
			if(currentCategory ~= action[ActionCategoryIndex]) then
				currentCategory = action[ActionCategoryIndex];
				local category = _KeyBindingCategories:GetInstance();
				category.CategoryName:SetText(currentCategory);
			end

			local entry = _KeyBindingActions:GetInstance();

			local actionId = action[ActionIdIndex];
			local binding = entry.Binding;
			entry.ActionName:SetText(action[ActionNameIndex]);
			binding:SetText(action[Gesture1Index] or "");
			binding:RegisterCallback(Mouse.eLClick, function()
				StartActiveKeyBinding(actionId, 0);
			end);
		
			local altBinding = entry.AltBinding;
			altBinding:SetText(action[Gesture2Index] or "");
			altBinding:RegisterCallback(Mouse.eLClick, function()
				StartActiveKeyBinding(actionId, 1);
			end);

		end

		Controls.KeyBindingsStack:CalculateSize();
		Controls.KeyBindingsStack:ReprocessAnchoring();
		Controls.KeyBindingsScrollPanel:CalculateSize();
	end

	function StartActiveKeyBinding(actionId, index)
        Controls.BindingTitle:SetText(Locale.Lookup(Input.GetActionName(actionId)));
		Controls.KeyBindingPopup:SetHide(false);
		Controls.KeyBindingAlpha:SetToBeginning();
		Controls.KeyBindingAlpha:Play();
		Controls.KeyBindingSlide:SetToBeginning();
		Controls.KeyBindingSlide:Play();
		_CurrentAction = actionId;
		_CurrentActionIndex = index;
		Input.BeginRecordingGestures(true);
	end

	function StopActiveKeyBinding()
		_CurrentAction = nil
		_CurrentActionIndex = nil;
				
		Input.StopRecordingGestures();
		Input.ClearRecordedGestures();
		Controls.KeyBindingPopup:SetHide(true);
	end

	function BindRecordedGesture(gesture)
		if(_CurrentAction and _CurrentActionIndex) then
			Input.BindAction(_CurrentAction, _CurrentActionIndex, gesture);
			RefreshKeyBinding();
		end

		StopActiveKeyBinding();
	end
	Events.InputGestureRecorded.Add(BindRecordedGesture);

	Controls.CancelBindingButton:RegisterCallback(Mouse.eLClick, function()
		StopActiveKeyBinding();
	end);

	Controls.ClearBindingButton:RegisterCallback(Mouse.eLClick, function()
		local currentAction = _CurrentAction;
		local currentActionIndex = _CurrentActionIndex;

		StopActiveKeyBinding();	

		if(currentAction and currentActionIndex) then
			Input.ClearGesture(currentAction, currentActionIndex);
			RefreshKeyBinding();
		end		
	end);

	-- Initialize buttons and categories
	RefreshKeyBinding();
	Controls.KeyBindingsScrollPanel:SetScrollValue(0);
end

-------------------------------------------------------------------------------
function OnShow()
    local isInGame = false;

	UserConfiguration.SaveCheckpoint();
    PopulateGraphicsOptions();
    TemporaryHardCodedGoodness();
end

-------------------------------------------------------------------------------
function OnToggleAdvancedOptions()
	if(Controls.AdvancedGraphicsOptions:IsSelected()) then
		Controls.AdvancedGraphicsOptions:SetSelected(false);
		Controls.AdvancedGraphicsOptions:SetText(Locale.Lookup("LOC_OPTIONS_SHOW_ADVANCED_GRAPHICS"));
		Controls.AdvancedOptionsContainer:SetHide(true);
	else
		Controls.AdvancedGraphicsOptions:SetSelected(true);
		Controls.AdvancedGraphicsOptions:SetText(Locale.Lookup("LOC_OPTIONS_HIDE_ADVANCED_GRAPHICS"));
		Controls.AdvancedOptionsContainer:SetHide(false);
	end
	Controls.GraphicsOptionsStack:CalculateSize();
	Controls.GraphicsOptionsStack:ReprocessAnchoring();
	Controls.GraphicsOptionsPanel:CalculateSize();
end
-------------------------------------------------------------------------------
function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	
	if (screenY < 768 ) then
		Controls.Content:SetSizeY(screenY-98);
	end

	local hideLogo = true;
	if(screenY >= Controls.MainWindow:GetSizeY() + (Controls.LogoContainer:GetSizeY()+ Controls.LogoContainer:GetOffsetY())*2) then
		hideLogo = false;
	end
	Controls.LogoContainer:SetHide(hideLogo);
	Controls.MainGrid:ReprocessAnchoring();
end

function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
    Resize();
  end
end

function OnUpdateGraphicsOptions()
    PopulateGraphicsOptions();  -- Ensure that the new monitor's resolutions are shown in the UI
end

function Initialize()

	_PromptRestartApp = false;
	_PromptRestartGame = false;

	_kPopupDialog = PopupDialogLogic:new( "Options", Controls.PopupDialog, Controls.PopupStack, Controls.PopupAlphaIn, Controls.PopupSlideIn );
	_kPopupDialog:SetInstanceNames( "PopupButtonInstance", "Button", "PopupTextInstance", "Text", "RowInstance", "Row");	
	_kPopupDialog:SetSize(400,200);

	Controls.AdvancedGraphicsOptions:RegisterCallback(Mouse.eLClick, OnToggleAdvancedOptions);
	Controls.AdvancedGraphicsOptions:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Controls.WindowCloseButton:RegisterCallback(Mouse.eLClick, OnCancel);
	Controls.WindowCloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Controls.ResetButton:RegisterCallback(Mouse.eLClick, OnReset);
	Controls.ResetButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Controls.ConfirmButton:RegisterCallback(Mouse.eLClick, OnConfirm);
	Controls.ConfirmButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	
	Controls.CancelBindingButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ClearBindingButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	
	Events.OptionChangeRequiresAppRestart.Add(OnOptionChangeRequiresAppRestart);
	Events.OptionChangeRequiresGameRestart.Add(OnOptionChangeRequiresGameRestart);
	Events.OptionChangeRequiresResolutionAck.Add(OnOptionChangeRequiresResolutionAck);

	ContextPtr:SetShowHandler( OnShow );
	ContextPtr:SetInputHandler(InputHandler, true );

	--AutoSizeGridButton(Controls.AdvancedGraphicsOptions,250,22,10,"H");
	AutoSizeGridButton(Controls.WindowCloseButton,133,36);
	Controls.GraphicsOptionsPanel:CalculateSize();

	m_tabs = {
		{Controls.GameTab,		Controls.GameOptions,				"LOC_OPTIONS_GAME_OPTIONS"},
		{Controls.GraphicsTab,	Controls.GraphicsOptions,			"LOC_OPTIONS_GRAPHICS_OPTIONS"},
		{Controls.AudioTab,		Controls.AudioOptions,				"LOC_OPTIONS_AUDIO_OPTIONS"},
		{Controls.InterfaceTab, Controls.InterfaceOptions,			"LOC_OPTIONS_INTERFACE_OPTIONS"},
		{Controls.AppTab,		Controls.ApplicationOptions,		"LOC_OPTIONS_APPLICATION_OPTIONS"},
	};

	-- TODO: Some platforms set language outside of the application at which point we must disable this panel.
	local supportsChangingLanguage = true;

	if(supportsChangingLanguage) then
		table.insert(m_tabs, {Controls.LanguageTab, Controls.LanguageOptions,"LOC_OPTIONS_LANGUAGE_OPTIONS"});
	end

	-- TODO: Some platforms don't allow for key binding.  Disable this panel.
	local supportsKeyBinding = true;

	if(supportsKeyBinding) then
		table.insert(m_tabs, {Controls.KeyBindingsTab, Controls.KeyBindings,"LOC_OPTIONS_KEY_BINDINGS_OPTIONS"});
		InitializeKeyBinding();
	end
	
	for i, tab in ipairs(m_tabs) do
		local button = tab[1];
		local panel = tab[2];
		local title = tab[3]
		button:RegisterCallback(Mouse.eLClick, function()
			for i, v in ipairs(m_tabs) do
				v[2]:SetHide(true);
				v[1]:SetSelected(false);
			end	
			button:SetSelected(true);
			panel:SetHide(false);		
			Controls.WindowTitle:SetText(Locale.ToUpper(Locale.Lookup(title)));
		end);
		button:SetHide(false);
	end

	m_tabs[1][1]:SetSelected(true);
	Controls.WindowTitle:SetText(Locale.ToUpper(Locale.Lookup(m_tabs[1][3])));
	Controls.TabStack:CalculateSize();
	Controls.TabStack:ReprocessAnchoring();

	Events.SystemUpdateUI.Add( OnUpdateUI );
    Events.UpdateGraphicsOptions.Add( OnUpdateGraphicsOptions );

	Resize();
end

Initialize();





