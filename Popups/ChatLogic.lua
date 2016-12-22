----------------------------------------------------------------  
-- Chat Logic
--
-- Core logic used by chat panels.
----------------------------------------------------------------  
include( "PlayerTargetLogic" ); -- GetNoPlayerTargetID(); GetLocalPlayerID()



----------------------------------------------------------------  
-- Globals
----------------------------------------------------------------  
local CHAT_ENTRY_LIMIT	:number	= 1000;			-- Max number of chat entries allowed at the same time.
local tokenPattern :string = "%S+";				-- Regular expression used for tokenizing chat text.
local NO_PLAYER = -1;

local m_lastWhisper = GetNoPlayerTargetID();	-- the last player to whisper at the local player.

local chatHelpStr = Locale.Lookup( "LOC_CHAT_HELP_COMMAND_TEXT" );
local chatHelpHintStr = Locale.Lookup( "LOC_CHAT_HELP_COMMAND_HINT" );


---------------------------------------------------------------- 
-- General Scripting
----------------------------------------------------------------  
-- Returns
-- parsedText - chat text post parsing.  This can be empty if the chat consisted only of commands.
-- chatTargetChanged - was playerTargetData changed as the result of a parsed chat command?
function ParseInputChatString(chatText :string, playerTargetData :table)
	local parsedText :string = chatText;
	local chatTargetChanged = false;
	local printHelp = false;
	for token in string.gmatch(chatText, tokenPattern) do
		if(token == "/help") then
			parsedText = "";
			printHelp = true;
		elseif(token == "/t") then
			parsedText = string.gsub(parsedText, token.." ", "", 1);
			if(playerTargetData.targetType ~= ChatTargetTypes.CHATTARGET_TEAM) then
				playerTargetData.targetType = ChatTargetTypes.CHATTARGET_TEAM;
				chatTargetChanged = true;
			end
		elseif(token == "/g") then
			parsedText = string.gsub(parsedText, token.." ", "", 1);
			if(playerTargetData.targetType ~= ChatTargetTypes.CHATTARGET_ALL) then
				playerTargetData.targetType = ChatTargetTypes.CHATTARGET_ALL;
				chatTargetChanged = true;
			end
		elseif(token == "/w") then
			parsedText, chatTargetChanged = WhisperCommand(chatText, playerTargetData);
		elseif(token == "/r") then
			parsedText = string.gsub(parsedText, token.." ", "", 1);
			if(m_lastWhisper ~= GetNoPlayerTargetID()) then
				playerTargetData.targetType = ChatTargetTypes.CHATTARGET_PLAYER;
				playerTargetData.targetID = m_lastWhisper;
				chatTargetChanged = true;
			end
		end
		break;
	end

	return parsedText, chatTargetChanged, printHelp;
end

-------------------------------------------------
-- LiterializeString
-- Prefixes all special string characters in str with the string escape character 
-- so the returned string will be treated as a literal string when inputted into 
-- string library functions that use regular expression patterns.
function LiterializeString(str)
	return string.gsub(str, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
end

-------------------------------------------------
-- WhisperCommand
-- Handles the whisper (/w) chat command.  This function assumes that chat text is a whisper chat. 
-------------------------------------------------
function WhisperCommand(chatText :string, playerTargetData :table)
	local parsedText :string = chatText;
	local chatTargetChanged = false;
	local curMatchNameString : string = "";
	local bestMatchPlayerID : number = NO_PLAYER;
	local bestMatchNameString : string = "";
	local tokenIdx = 0;

	parsedText = string.gsub(parsedText, "/w ", "", 1); -- Scrub /w command from parsed text.

	-- Find the best player name match while using more and more of the chat text tokens as the match name.
	for token in string.gmatch(parsedText, tokenPattern) do
		if(tokenIdx == 0) then
			curMatchNameString = token;
		else
			curMatchNameString = curMatchNameString .. " " .. token;
		end

		local curMatchNameStringLower :string = Locale.ToLower(curMatchNameString);
		local matchFound : boolean = false;
		local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
		for i, iPlayer in ipairs(player_ids) do	
			local curPlayerConfig = PlayerConfigurations[iPlayer];
			if(curPlayerConfig:IsHuman()) then
				local curPlayerName :string = curPlayerConfig:GetPlayerName();
				local curPlayerNameLower :string = Locale.ToLower(curPlayerName);
				local findResult = string.find(curPlayerNameLower, curMatchNameStringLower, 1, true);
				if(findResult ~= nil) then
					-- found a match, use this as the best so far.
					bestMatchPlayerID = iPlayer;
					bestMatchNameString = curMatchNameString;
					matchFound = true;
					break;
				end
			end
		end
		if(not matchFound) then
			-- if no match was found with the current curMatchNameString, we're not going to get a better match with more tokens, we're done.
			break;
		end
		tokenIdx = tokenIdx + 1;
	end

	if(bestMatchPlayerID ~= NO_PLAYER) then
		playerTargetData.targetType = ChatTargetTypes.CHATTARGET_PLAYER;
		playerTargetData.targetID = bestMatchPlayerID;
		chatTargetChanged = true;
		local bestMatchLiterial : string = LiterializeString(bestMatchNameString);
		parsedText = string.gsub(parsedText, bestMatchLiterial, "", 1); -- Scrub player name match string from parsed text.		
	end

	return parsedText, chatTargetChanged;
end

-------------------------------------------------
-- 
-------------------------------------------------
function ChatPrintHelp(chatEntryStack :table, chatInstances :table, chatLogPanel :table)
	AddChatEntry(chatHelpStr, chatEntryStack, chatInstances, chatLogPanel);
end

-------------------------------------------------
-- 
-------------------------------------------------
function ChatPrintHelpHint(chatEntryStack :table, chatInstances :table, chatLogPanel :table)
	AddChatEntry(chatHelpHintStr, chatEntryStack, chatInstances, chatLogPanel);
end

-------------------------------------------------
-- 
-------------------------------------------------
function AddChatEntry( chatString :string, chatEntryStack :table, chatInstances :table, chatLogPanel :table )
	local controlTable = {};
	ContextPtr:BuildInstanceForControl( "ChatEntry", controlTable, chatEntryStack );
	    
	local newChatEntry = { ChatControl = controlTable; };
	table.insert( chatInstances, newChatEntry );

	local numChatInstances:number = table.count(chatInstances);

	-- limit chat log
	if( numChatInstances > CHAT_ENTRY_LIMIT) then
		chatEntryStack:ReleaseChild( chatInstances[ 1 ].ChatControl.ChatRoot );
		table.remove( chatInstances, 1 );
	end
	    
	controlTable.String:SetText(chatString);	
	controlTable.ChatRoot:SetSize(controlTable.String:GetSize());	

	chatEntryStack:CalculateSize();
	chatEntryStack:ReprocessAnchoring();
	chatLogPanel:CalculateInternalSize();
	chatLogPanel:ReprocessAnchoring();
end



---------------------------------------------------------------- 
-- Button Events
---------------------------------------------------------------- 



---------------------------------------------------------------- 
-- Exteneral Event Handlers
---------------------------------------------------------------- 
function OnMultiplayerChat( fromPlayer, toPlayer, text, eTargetType )
	if(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER and toPlayer == GetLocalPlayerID()) then
		--Remember the last person who whispered to this player.
		m_lastWhisper = fromPlayer;
	end
end




---------------------------------------------------------------- 
-- Exteneral Event Handlers
---------------------------------------------------------------- 
function Initialize()
	Events.MultiplayerChat.Add( OnMultiplayerChat );
end
Initialize();



