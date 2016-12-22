-- ===========================================================================
--	Takes a bunch of (Grid)Button controls in a container and gives them
--	tab-like functionality.
--
-- ===========================================================================


-- ===========================================================================
--	tabContainerControl		The container (parent) control for the tabs
--	sizeX					(optional) Size of texture X length
--	sizeY					(optional) Size of texture Y height
--  selectedFontColor		(optional) AGBR Font color of the 
--
--	RETURNS: tab object for working with controls in a tabby manner.
-- ===========================================================================
function CreateTabs( tabContainerControl, sizeX, sizeY, selectedFontColor)
	
	-- Set default options if not passed in.
	if sizeX == nil then sizeX = 64; end;
	if sizeY == nil then sizeY = 32; end;

	local defaultFontColor:number = 0xffffffff;
	local tabs = {};
	tabs.containerControl	= tabContainerControl;
	tabs.tabControls		= {};
	tabs.selectedControl	= nil;	
	tabs.prevSelectedControl= nil;	
	tabs.defaultFontColor = defaultFontColor;
	tabs.selectedFontColor	= selectedFontColor;
	tabs.decoAnim		= nil;
	tabs.decoOffset		= 0;

	-- Set size, used in operation to get the selected state from sprite sheet.
	tabs.textureSizeX = sizeX;
	tabs.textureSizeY = sizeY;

	-- ===========================================================================
	--	(PRIVATE) Sets the visual style of the selected tab.
	-- ===========================================================================
	tabs.SetSelectedTabVisually =
		function ( tabControl )
			if ( tabs.decoAnim ~= nil ) then
				tabs.decoAnim:SetEndVal(tabControl:GetOffsetX() + (tabControl:GetSizeX()/2) - tabs.decoOffset,0);
				tabs.decoAnim:Play();		
			end
			tabs.prevSelectedControl = tabs.selectedControl;	-- Record last tab selected
			if ( tabs.selectedControl ~= nil ) then
				local oldSelectedTabID = tabs.selectedControl:GetID() .. "Selected";
				if(Controls[oldSelectedTabID] ~= nil) then
					Controls[oldSelectedTabID]:SetHide(true);
					Controls[oldSelectedTabID]:SetToBeginning();
				end
				if (tabs.selectedControl:GetTextControl() ~= nil and tabs.defaultFontColor ~= nil) then
					tabs.selectedControl:GetTextControl():SetColor(0xFFefe7e1);
				end
				tabs.selectedControl:SetTextureOffsetVal( 0, 0 );
				tabs.selectedControl = nil;
			end
			if ( tabControl ~= nil ) then
				local newSelectedTabID = tabControl:GetID() .. "Selected";
				if(Controls[newSelectedTabID] ~= nil) then
					Controls[newSelectedTabID]:SetHide(false);
					Controls[newSelectedTabID]:Play();
				end
				if (tabControl:GetTextControl() ~= nil and tabs.selectedFontColor ~= nil) then
					tabControl:GetTextControl():SetColor(tabs.selectedFontColor);
				end
				-- Change parent back to container, this will re-add it to the end of the 
				-- child list, thereby drawing last (on top of other tabs if they overlap).
				tabControl:ChangeParent( tabs.containerControl ); 
				tabs.selectedControl = tabControl;
			end
		end

	-- ===========================================================================
	-- ===========================================================================
	tabs.SelectTab =
		function ( tabControlOrIndex )
			-- If NIL select no tabs.
			local callback :ifunction = nil;

			if tabControlOrIndex == nil then
				tabs.SetSelectedTabVisually( nil );
			elseif type(tabControlOrIndex) == "number" then
				callback = tabs.tabControls[tabControlOrIndex]["CallbackFunc"]; -- Actually an index
			else
				callback = tabControlOrIndex["CallbackFunc"];
			end

			if callback ~= nil then
				callback();
			end
		end

	-- ===========================================================================
	-- Add a sliding decor piece
	-- decoAnim		A SlideAnim containing the decor image which will slide the decor over the selected tab
	-- decoControl	An Image control which will be centered over the selected tab
	-- ===========================================================================
	tabs.AddAnimDeco =	
		function ( decoAnim, decoControl )

			-- Reset to a new beginning
			function setNewBegin()
				if(tabs.selectedControl ~= nil) then
					tabs.decoAnim:SetBeginVal(tabs.selectedControl:GetOffsetX() + (tabs.selectedControl:GetSizeX()/2) - tabs.decoOffset,0);
					tabs.decoAnim:SetToBeginning();
				end
			end

			if(decoAnim ~= nil and decoControl ~= nil) then
				if(tabs.selectedControl ~= nil) then
					decoAnim:SetEndVal(tabs.selectedControl:GetOffsetX() + (tabs.selectedControl:GetSizeX()/2) - (decoControl:GetSizeX()/2),0);
					decoAnim:SetBeginVal(tabs.selectedControl:GetOffsetX() + (tabs.selectedControl:GetSizeX()/2) - (decoControl:GetSizeX()/2),0);
					decoAnim:SetToBeginning();
					decoAnim:Stop();
					decoAnim:SetHide(false);
					tabs.decoAnim = decoAnim;
					tabs.decoOffset = decoControl:GetSizeX()/2;
				else
					tabs.decoAnim = decoAnim;
					tabs.decoOffset = decoControl:GetSizeX()/2;
					decoAnim:SetHide(true);
				end
				decoAnim:RegisterEndCallback( setNewBegin );
			end
		end

	-- ===========================================================================
	--	Add a tab control to be managed by tab manager.
	--	tabContainerControl		The group of tabs to add this tab to
	--	tabControl				The tab UI element to be managed.
	--	focusCallback			A callback to call when the tab is focused
	-- ===========================================================================
	tabs.AddTab =	
		function ( tabControl, focusCallBack )
			
			if ( tabControl:GetTextControl() ~= nil ) then
				--tabs.defaultFontColor = tabControl:GetTextControl():GetColor();
				tabs.defaultFontColor = 0xffffff;
			end
			-- Protect the flock
			if ( focusCallBack == nil ) then
				print("ERROR: NIL focusCallback for tabControl");
			end
			
			tabControl["CallbackFunc"] = function()
				tabs.SetSelectedTabVisually( tabControl );	-- Our function to change UI appearance
				focusCallBack( tabControl );				-- User's function to do stuff when tab is clicked
				end;

			-- Register callback when tab is click/pressed.
			tabControl:RegisterCallback( Mouse.eLClick, tabControl["CallbackFunc"] );

			table.insert( tabs.tabControls, tabControl );	-- Add to list of controls in tabs.
		end

	-- ===========================================================================
	--	Coverts all the tabs to be the same size as the largest.
	--	Call this before a layout function.
	-- ===========================================================================
	tabs.SameSizedTabs =
		function( padding:number )
			if padding == nil then padding = 0; end
			local largestSize	= 0;
			local tabNum		= table.count(tabs.tabControls);
			for _,control in ipairs(tabs.tabControls) do
				if control:GetSizeX() > largestSize then
					largestSize = control:GetSizeX();
				end
			end
			largestSize = largestSize + padding;
			for _,control in ipairs(tabs.tabControls) do
				control:SetSizeX( largestSize );
			end
		end

	-- ===========================================================================
	--	Spreads out the tabs evenly, from end-to-end using maths!
	-- ===========================================================================
	tabs.EvenlySpreadTabs =
		function( )			
			local width			= tabs.containerControl:GetSizeX();
			local tabNum		= table.count(tabs.tabControls);

			if ( tabNum < 1 ) then
				UI.DataError("Attempting to evenly spread tabs but no tabs to spread in: ", tabs.containerControl );
				return;
			end

			-- Adjust with to starting X offsets with the last offset being the width of the last tab.
			if(tabNum > 1) then
				local totalSize:number = 0;
				for i,control in ipairs(tabs.tabControls) do
					totalSize = totalSize + control:GetSizeX();
				end

				local step:number = (width - totalSize) / (tabNum - 1);
				local nextX:number = 0;
				for i,control in ipairs(tabs.tabControls) do
					control:SetOffsetX(nextX);
					nextX = nextX + control:GetSizeX() + step;
				end
			else
				local control:table = tabs.tabControls[1];
				control:SetOffsetX((width / 2) - (control:GetSizeX() / 2));
			end
		end

	-- ===========================================================================
	--	Spreads out the tabs within the center of the given area
	-- ===========================================================================
	tabs.CenterAlignTabs =
		function( tabOverlapSpace )			
			local DEFAULT_TAB_OVERLAP_SPACE = 20;
			local width				= tabs.containerControl:GetSizeX();
			local tabNum			= table.count(tabs.tabControls);

			if tabOverlapSpace == nil then
				tabOverlapSpace = DEFAULT_TAB_OVERLAP_SPACE;
			end

			if ( tabNum < 1 ) then
				UI.DataError("Attempting to center align tabs but no tabs to center in: ", tabs.containerControl );
				return;
			end

			-- Determine total width of tabs
			local totalTabsWidth = tabOverlapSpace;
			for _,control in ipairs(tabs.tabControls) do				
				totalTabsWidth = totalTabsWidth + control:GetSizeX() - tabOverlapSpace;
			end			

			local nextX	= (width/2) - (totalTabsWidth/2 );

			for i,control in ipairs(tabs.tabControls) do
				control:SetOffsetX( nextX );
				nextX = nextX + control:GetSizeX() - tabOverlapSpace;
			end
		end

	return tabs;

end
