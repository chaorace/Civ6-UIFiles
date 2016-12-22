
function ResizeButtonToText(buttonControl:table, padding:number)
	if padding == nil then
		padding = 50; -- default value
	end
	local textControl:table = buttonControl:GetTextControl();
	buttonControl:SetSizeX(textControl:GetSizeX() + padding);
end