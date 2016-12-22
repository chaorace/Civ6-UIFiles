------------------------------------------------------------------------------
-- Misc Support Functions
------------------------------------------------------------------------------

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local m_strEllipsis = Locale.Lookup("LOC_GENERIC_DOT_DOT_DOT");


-- ===========================================================================
--	Sets a Label or control that contains a label (e.g., GridButton) with
--	a string that, if necessary, will be truncated.
--
--	RETURNS: true if truncated.
-- ===========================================================================
function TruncateString(control, resultSize, longStr, trailingText)

	-- Ensure this has the actual text control
	if control.GetTextControl ~= nil then
		control = control:GetTextControl();
	end

	local isTruncated = false;
	if(longStr == nil)then
		longStr = control:GetText();
		
		if(trailingText == nil)then
			longStr = "";
		end
	end
	
	if(control ~= nil)then

		-- Determine full length of control.
		control:SetText(longStr);
		local fullStrExtent = control:GetSizeX();
		
		-- Determine how long a trailing text portion will be.
		if(trailingText == nil)then
			trailingText = "";
		end
		control:SetText(trailingText);
		local trailingExtent = control:GetSizeX();
		
		local sizeAfterTruncate = resultSize - trailingExtent;
		if(sizeAfterTruncate > 0)then
			local truncatedSize = fullStrExtent;
			local newString = longStr;
			
			local ellipsis = "";
			
			if( sizeAfterTruncate < truncatedSize ) then
				ellipsis = m_strEllipsis;
				isTruncated = true;
			end
			
			control:SetText(ellipsis);
			local ellipsisExtent = control:GetSizeX();
			sizeAfterTruncate = sizeAfterTruncate - ellipsisExtent;
			
			while (sizeAfterTruncate < truncatedSize and Locale.Length(newString) > 1) do
				newString = Locale.SubString(newString, 1, Locale.Length(newString) - 1);
				control:SetText(newString);
				truncatedSize = control:GetSizeX();
			end
			
			control:SetText(newString .. ellipsis .. trailingText);
		end
	else
		UI.DataError("Attempt to TruncateString but NIL control passed in!. string=", longStr);
	end
	return isTruncated;
end


-- ===========================================================================
--	Same as TruncateString(), but if truncation occurs automatically adds
--	the full text as a tooltip.
-- ===========================================================================
function TruncateStringWithTooltip(control, resultSize, longStr, trailingText)
	local isTruncated = TruncateString( control, resultSize, longStr, trailingText );
	if isTruncated then
		control:SetToolTipString( longStr );
	else
		control:SetToolTipString( nil );
	end
	return isTruncated;
end


-- ===========================================================================
--	Performs a truncation based on the control's contents
-- ===========================================================================
function TruncateSelfWithTooltip( control )
	local resultSize = control:GetSizeX();
	local longStr	 = control:GetText();
	return TruncateStringWithTooltip(control, resultSize, longStr);
end


-- ===========================================================================
--	Truncate string based on # of characters
--	(Most useful when having to truncate a string *in* a tooltip.
-- ===========================================================================
function TruncateStringByLength( textString, textLen )
	if ( Locale.Length(textString) > textLen ) then
		return Locale.SubString(textString, 1, textLen) .. Locale.Lookup("TXT_KEY_GENERIC_DOT_DOT_DOT");
	end
	return textString;
end


-- ===========================================================================
-- Convert a set of values (red, green, blue, alpha) into a single hex value.
-- Values are from 0.0 to 1.0
-- return math.floor(value is a single, unsigned uint as ABGR
-- ===========================================================================
function RGBAValuesToABGRHex( red, green, blue, alpha )

	-- optionally pass in alpha, to taste
	if alpha==nil then
		alpha = 1.0;
	end

	-- prepare ingredients so they are clamped from 0 to 255
	red 	= math.max( 0, math.min( 255, red*255 ));
	green 	= math.max( 0, math.min( 255, green*255 ));
	blue	= math.max( 0, math.min( 255, blue*255 ));
	alpha	= math.max( 0, math.min( 255, alpha*255 ));

	-- combine the ingredients, stiring gently
	local value = lshift( alpha, 24 ) + lshift( blue, 16 ) + lshift( green, 8 ) + red;

	-- return the baked goodness
	return math.floor(value);
end

-- ===========================================================================
--	Use to convert from CivBE style colors to ForgeUI color
-- ===========================================================================
function RGBAObjectToABGRHex( colorObject )
	return RGBAValuesToABGRHex( colorObject.x, colorObject.y, colorObject.z, colorObject.w );
end

-- ===========================================================================
--	Guess what, TextControls still use legacy color; use to convert to it.
--	RETURNS: Object with R G B A to a vector like format with fields X Y Z W 
-- ===========================================================================
function ABGRHExToRGBAObject( hexColor )
	local ret = {};
	ret.w = math.floor( math.fmod( rshift(hexColor,24), 256)); 
	ret.z = math.floor( math.fmod( rshift(hexColor,16), 256));
	ret.y = math.floor( math.fmod( rshift(hexColor,8), 256));
	ret.x = math.floor( math.fmod( hexColor, 0x256 ));	-- lower MODs are messed up due what is in higher bits, need an AND!
	return ret;
end



-- ===========================================================================
-- Support for shifts
-- ===========================================================================
local g_supportFunctions_shiftTable = {};
g_supportFunctions_shiftTable[0] = 1;
g_supportFunctions_shiftTable[1] = 2;
g_supportFunctions_shiftTable[2] = 4;
g_supportFunctions_shiftTable[3] = 8;
g_supportFunctions_shiftTable[4] = 16;
g_supportFunctions_shiftTable[5] = 32;
g_supportFunctions_shiftTable[6] = 64;
g_supportFunctions_shiftTable[7] = 128;
g_supportFunctions_shiftTable[8] = 256;
g_supportFunctions_shiftTable[9] = 512;
g_supportFunctions_shiftTable[10] = 1024;
g_supportFunctions_shiftTable[11] = 2048;
g_supportFunctions_shiftTable[12] = 4096;
g_supportFunctions_shiftTable[13] = 8192;
g_supportFunctions_shiftTable[14] = 16384;
g_supportFunctions_shiftTable[15] = 32768;
g_supportFunctions_shiftTable[16] = 65536;
g_supportFunctions_shiftTable[17] = 131072;
g_supportFunctions_shiftTable[18] = 262144;
g_supportFunctions_shiftTable[19] = 524288;
g_supportFunctions_shiftTable[20] = 1048576;
g_supportFunctions_shiftTable[21] = 2097152;
g_supportFunctions_shiftTable[22] = 4194304;
g_supportFunctions_shiftTable[23] = 8388608;
g_supportFunctions_shiftTable[24] = 16777216;



-- ===========================================================================
--	Bit Helper function
--	Converts a number into a table of bits.
-- ===========================================================================
function numberToBitsTable( value:number )
	if value < 0 then
		return numberToBitsTable( bitNot(math.abs(value))+1 );	-- Recurse
	end

	local kReturn	:table = {};
	local i			:number = 1;
	while value > 0 do
		local digit:number = math.fmod(value, 2);
		if digit == 1 then
			kReturn[i] = 1;
		else
			kReturn[i] = 0;
		end
		value = (value - digit) * 0.5;
		i = i + 1;
	end

	return kReturn;
end

-- ===========================================================================
--	Bit Helper function
--	Converts a table of bits into it's corresponding number.
-- ===========================================================================
function bitsTableToNumber( kTable:table )
	local bits	:number = table.count(kTable);
	local n		:number = 0;
	local power :number = 1;
	for i = 1, bits,1 do
		n = n + kTable[i] * power;
		power = power * 2;
	end
	return n;
end

-- ===========================================================================
--	Bitwise not (because LUA 5.2 support doesn't exist yet in Havok script)
-- ===========================================================================
function bitNot( value:number )
	local kBits:table	= numberToBitsTable(value);
	local size:number	= math.max(table.getn(kBits), 32)
	for i = 1, size do
		if(kBits[i] == 1) then 
			kBits[i] = 0
		else
			kBits[i] = 1
		end
	end
	return bitsTableToNumber(kBits);
 end

 -- ===========================================================================
--	Bitwise or (because LUA 5.2 support doesn't exist yet in Havok script)
-- ===========================================================================
 local function bitOr( na:number, nb:number)
	local ka :table = numberToBitsTable(na);
	local kb :table = numberToBitsTable(nb);

	-- Make sure both are the same size; pad with 0's if necessary.
	while table.count(ka) < table.count(kb) do ka[table.count(ka)+1] = 0; end
	while table.count(kb) < table.count(ka) do kb[table.count(kb)+1] = 0; end

	local kResult	:table	= {};
	local digits	:number = table.count(ka);
	for i:number = 1, digits, 1 do
		kResult[i] = (ka[i]==1 or kb[i]==1) and 1 or 0;
	end 
	return bitsTableToNumber( kResult );
end


-- ===========================================================================
-- Left shift (because LUA 5.2 support doesn't exist yet in Havok script)
-- ===========================================================================
function lshift( value, shift )
	return math.floor(value) * g_supportFunctions_shiftTable[shift];
end

-- ===========================================================================
-- Right shift (because LUA 5.2 support doesn't exist yet in Havok script)
-- ===========================================================================
function rshift( value:number, shift:number )
	local highBit:number = 0;

	if value < 0 then	
		value	= bitNot(math.abs(value)) + 1;
		highBit = 0x80000000;
	end

	for i=1, shift, 1 do
		value = bitOr( math.floor(value*0.5), highBit );
	end
	return math.floor(value);	
end


-- ===========================================================================
--	Determine if string is IP4, IP6, or invalid
--
--	Based off of: 
--	http://stackoverflow.com/questions/10975935/lua-function-check-if-ipv4-or-ipv6-or-string
--
--	Returns: 4 if IP4, 6 if IP6, or 0 if not valid
-- ===========================================================================
function GetIPType( ip )

    if ip == nil or type(ip) ~= "string" then
        return 0;
    end

    -- Check for IPv4 format, 4 chunks between 0 and 255 (e.g., 1.11.111.111)
    local chunks = {ip:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")}
    if (table.count(chunks) == 4) then
        for _,v in pairs(chunks) do
            if (tonumber(v) < 0 or tonumber(v) > 255) then
                return 0;
            end
        end
        return 4;	-- This is IP4
    end

	-- Check for ipv6 format, should be 8 'chunks' of numbers/letters without trailing chars
	local chunks = {ip:match(("([a-fA-F0-9]*):"):rep(8):gsub(":$","$"))}
	if table.count(chunks) == 8 then
		for _,v in pairs(chunks) do
			if table.count(v) > 0 and tonumber(v, 16) > 65535 then 
				return 0;
			end
		end
		return 6;	-- This is IP6
	end
	return 0;
end




-- ===========================================================================
--	LUA Helper function
-- ===========================================================================
function RemoveTableEntry( T:table, key:string, theValue )
	local pos = nil;
	for i,v in ipairs(T) do
		if (v[key]==theValue) then
			pos=i;	
			break;
		end
	end
	if(pos ~= nil) then
		table.remove(T, pos);
		return true;
	end
	return false;
end

-- ===========================================================================
--	orderedPairs()
--	Allows an ordered iteratation of the pairs in a table.  Use like pairs().
--	Original version from: http://lua-users.org/wiki/SortedIteration
-- ===========================================================================
function __genOrderedIndex( t )
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex )
    return orderedIndex
end
function orderedNext(t, state)
    -- Equivalent of the next function, but returns the keys in the alphabetic order. 
	-- Using a temporary ordered key table that is stored in the table being iterated.
    key = nil;
    if state == nil then
        -- Is first time; generate the index.
        t.__orderedIndex = __genOrderedIndex( t );
        key = t.__orderedIndex[1];
    else
        -- Fetch next value.
        for i = 1,table.count(t.__orderedIndex) do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1];
            end
        end
    end

    if key then
        return key, t[key];
	else
		t.__orderedIndex = nil;		-- No more value to return, cleanup.
    end    
end
function orderedPairs(t)    
    return orderedNext, t, nil;
end


-- ===========================================================================
--	Split()
--	Allows splitting a string (tokenizing) into an array based on a delimeter.
--	Original version from: http://lua-users.org/wiki/SplitJoin
--	RETURNS: Table of tokenized strings
-- ===========================================================================
function Split(str:string, delim:string, maxNb:number)
	-- Eliminate bad cases...
    if string.find(str, delim) == nil then
        return { str };
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0;    -- No limit
    end
    local result:table = {};
    local pat	:string = "(.-)" .. delim .. "()";
    local nb	:number = 0;
    local lastPos:number;
    for part, pos in string.gmatch(str, pat) do
        nb = nb + 1;
        result[nb] = part;
        lastPos = pos;
        if nb == maxNb then 
			break;
		end
    end
    -- Handle the last field
    if nb ~= maxNb then
        result[nb + 1] = string.sub(str, lastPos);
    end
    return result;
end


-- ===========================================================================
--	Clamp()
--	Returns the value passed, only changing if it's above or below the min/max
-- ===========================================================================
function Clamp( value:number, min:number, max:number )
	if value < min then 
		return min;
	elseif value > max then
		return max;
	else
		return value;
	end
end



-- ===========================================================================
--	Round()
--	Rounds a number to X decimal places.
--	Original version from: http://lua-users.org/wiki/SimpleRound
-- ===========================================================================
function Round(num:number, idp:number)
  local mult:number = 10^(idp or 0);
  return math.floor(num * mult + 0.5) / mult;
end


-- ===========================================================================
--	Convert polar coordiantes to Cartesian plane.
--	ARGS: 	r		radius
--			phi		angle in degrees (90 is facing down, 0 is pointing right)
--			ratio	y-axis to x-axis to "squash" the circle if desired
--
--	Unwrapped Circle:	local x = r * math.cos( math.rad(phi) );
--						local y = r * math.sin( math.rad(phi) );
--						return x,y;
-- ===========================================================================
function PolarToCartesian( r:number, phi:number )
	return r * math.cos( math.rad(phi) ), r * math.sin( math.rad(phi) );
end
function PolarToRatioCartesian( r:number, phi:number, ratio:number )
	return r * math.cos( math.rad(phi) ), r * math.sin( math.rad(phi) ) * ratio;
end

-- ===========================================================================
--	Transforms a ABGR color by some amount
--	ARGS:	hexColor	Hex color value (0xAAGGBBRR)
--			amt			(0-255) the amount to darken or lighten the color
--			alpha		???
--RETURNS:	transformed color (0xAAGGBBRR)
-- ===========================================================================
function DarkenLightenColor( hexColor:number, amt:number, alpha:number )

	--Parse the a,g,b,r hex values from the string
	local hexString :string = string.format("%x",hexColor);
	local b = string.sub(hexString,3,4);
	local g = string.sub(hexString,5,6);
	local r = string.sub(hexString,7,8);
	b = tonumber(b,16);
	g = tonumber(g,16);
	r = tonumber(r,16);

	if (b == nil) then b = 0; end
	if (g == nil) then g = 0; end
	if (r == nil) then r = 0; end

	local a = string.format("%x",alpha);
	if (string.len(a)==1) then
			a = "0"..a;
	end

	b = b + amt;
	if (b < 0 or b == 0) then
		b = "00";
	elseif (b > 255 or b == 255) then
		b = "FF";
	else
		b = string.format("%x",b);
		if (string.len(b)==1) then
			b = "0"..b;
		end
	end

	g = g + amt;
	if (g < 0 or g == 0) then
		g = "00";
	elseif (g > 255 or g == 255) then
		g = "FF";
	else
		g = string.format("%x",g);
		if (string.len(g)==1) then
			g = "0"..g;
		end
	end

	r = r + amt;
	if (r < 0 or r == 0) then
		r = "00";
	elseif (r > 255 or r == 255) then
		r = "FF";
	else
		r = string.format("%x",r);
		if (string.len(r)==1) then
			r = "0"..r;
		end
	end

	hexString = a..b..g..r; 
	return tonumber(hexString,16);
end


-- ===========================================================================
--	Recursively duplicate (deep copy)
--	Original from: http://lua-users.org/wiki/CopyTable
-- ===========================================================================
function DeepCopy( orig )
    local orig_type = type(orig);
    local copy;
    if orig_type == 'table' then
        copy = {};
        for orig_key, orig_value in next, orig, nil do
            copy[DeepCopy(orig_key)] = DeepCopy(orig_value);
        end
        setmetatable(copy, DeepCopy(getmetatable(orig)));
    else -- number, string, boolean, etc
        copy = orig;
    end
    return copy;
end

-- ===========================================================================
--	Sizes a control to fit a maximum height, while maintaining the aspect ratio
--	of the original control. If no Y is specified, we will use the height of the screen.
--	ARG 1: control (table) - expects a control to be resized
--	ARG 5: OPTIONAL maxY (number) - the minimum height of the control.  
-- ===========================================================================
function UniformToFillY( control:table, maxY:number )
	local currentX = control:GetSizeX();
	local currentY = control:GetSizeY();
	local newX = 0;
	local newY = 0;
	if (maxY == nil) then
		local _, screenY:number = UIManager:GetScreenSizeVal();
		newY = screenY;
	else
		newY = maxY;
	end
	newX = (currentX * newY)/currentY;
	control:SetSizeVal(newX,newY);
end