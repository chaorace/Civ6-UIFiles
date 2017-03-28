-- ===========================================================================
--	VARIABLES
-- ===========================================================================

ms_LeaderAnimationQueue		= {};
ms_BackgroundEffectQueue	= {};
ms_bInitialAnimtion			= true;
ms_bLeaderIsVisible			= false;

------------------------------------------------------------------------------
function LeaderSupport_UpdateAnimationQueue()
	if ms_bLeaderIsVisible and ms_LeaderAnimationQueue ~= nil and ms_LeaderAnimationQueue.Sequence ~= nil and table.count(ms_LeaderAnimationQueue.Sequence) > 0 then
		if ms_bInitialAnimtion then
			ms_bInitialAnimtion = false;
			if (ms_LeaderAnimationQueue.Initial ~= nil and ms_LeaderAnimationQueue.Initial ~= "") then
				-- We have a specific initial animation to set the state to.
				UI.PlayLeaderAnimation(ms_LeaderAnimationQueue.Initial, {BlendTime = 0.0});
				-- We then want to play the sequence right now.  We need to do this because the forced initial animation could be a looping animation, which never completes
				UI.PlayLeaderAnimation(ms_LeaderAnimationQueue.Sequence[1]);
				ms_LeaderAnimationQueue.Initial = nil;
			else
				UI.PlayLeaderAnimation(ms_LeaderAnimationQueue.Sequence[1], {BlendTime = 0.0});
			end
		else
			UI.PlayLeaderAnimation(ms_LeaderAnimationQueue.Sequence[1]);
		end
		table.remove(ms_LeaderAnimationQueue.Sequence, 1);
	end
end

------------------------------------------------------------------------------
function LeaderSupport_UpdateSceneEffectQueue()
	if ms_bLeaderIsVisible  and (table.count(ms_BackgroundEffectQueue) > 0) then
		UI.PlayLeaderSceneEffect( ms_BackgroundEffectQueue[1] );
		table.remove(ms_BackgroundEffectQueue, 1);
	end
end

------------------------------------------------------------------------------
function LeaderSupport_QueueAnimation(anim : string)
	if (ms_LeaderAnimationQueue.Sequence == nil) then
		ms_LeaderAnimationQueue.Sequence = {};
	end

	table.insert(ms_LeaderAnimationQueue.Sequence, anim);
	
	LeaderSupport_UpdateAnimationQueue();
end

------------------------------------------------------------------------------
function GetLeaderAnimationSequenceFromQuery(q, kOutputTable : table, leaderMood)

	for i, row in ipairs(q) do		-- Should only be one
		local initialAnimation = row.Initial;

		if (initialAnimation ~= nil) then
			if (leaderMood ~= nil) then
				if (leaderMood == DiplomacyMoodTypes.HAPPY) then 
					initialAnimation = string.gsub(initialAnimation, "%$%(MOOD%)","HAPPY");
				elseif (leaderMood == DiplomacyMoodTypes.NEUTRAL) then
					initialAnimation = string.gsub(initialAnimation, "%$%(MOOD%)","NEUTRAL");
				elseif (leaderMood == DiplomacyMoodTypes.UNHAPPY) then
					initialAnimation = string.gsub(initialAnimation, "%$%(MOOD%)","UNHAPPY");
				end
			end
		end

		kOutputTable.Initial = initialAnimation;
		kOutputTable.Sequence = {};
		for anim in string.gmatch(row.Sequence, "([%w_]+)") do			
			table.insert(kOutputTable.Sequence, anim);
		end
	end

	if (kOutputTable.Sequence ~= nil) then
		return table.count(kOutputTable.Sequence) > 0;
	else
		return false;
	end
end

------------------------------------------------------------------------------
function GetLeaderAnimationSequence(leaderName : string, sequenceName : string, leaderMood )

	local kOutputTable = {};

	local q = DB.Query("SELECT Sequence, Initial from LeaderAnimations WHERE Leader = ? AND Name = ?", leaderName, sequenceName);
	if (not GetLeaderAnimationSequenceFromQuery(q, kOutputTable, leaderMood)) then
		q = DB.Query("SELECT Sequence, Initial from LeaderAnimations WHERE Leader = 'ANY' AND Name = ?", sequenceName);
		GetLeaderAnimationSequenceFromQuery(q, kOutputTable, leaderMood);
	end

	return kOutputTable;
end

------------------------------------------------------------------------------
function LeaderSupport_QueueAnimationSequence( leaderName: string, sequenceName : string, leaderMood )
	local kSequence = GetLeaderAnimationSequence(leaderName, sequenceName, leaderMood);
	if (kSequence ~= nil) then
		-- Current sequence empty/complete?
		if (ms_LeaderAnimationQueue.Sequence == nil or #ms_LeaderAnimationQueue.Sequence == 0) then
			ms_LeaderAnimationQueue = kSequence;
			-- Start the animation
			LeaderSupport_UpdateAnimationQueue();
		else
			-- There are still animations to play from the last sequence.
			if (kSequence.Sequence ~= nil) then				
				-- It would be nice to just add the new animations to the end BUT, what if the last animation in the previous list was looping?
				-- If, so we would never get to our desired animations.

				-- Instead, we will add the new sequence, but just let the current animation complete and kick us off, rather than interrupting it.
				ms_LeaderAnimationQueue = kSequence;
				if (ms_LeaderAnimationQueue.Initial ~= nil and ms_LeaderAnimationQueue.Initial ~= "") then
					-- Act like it is the initial animation too.
					ms_bInitialAnimtion = true;	
				end
			end
		end
	end
end

------------------------------------------------------------------------------
function LeaderSupport_QueueSceneEffect( effectName : string )
	if (effectName ~= nil) then
		table.insert(ms_BackgroundEffectQueue, effectName);
		LeaderSupport_UpdateSceneEffectQueue();
	end
end

------------------------------------------------------------------------------
function LeaderSupport_Initialize()
	ms_bLeaderIsVisible = false;
	ms_bInitialAnimtion = true;
	ms_LeaderAnimationQueue = {};
end

------------------------------------------------------------------------------
function LeaderSupport_OnLeaderLoaded()
	ms_bLeaderIsVisible = true;
	LeaderSupport_UpdateAnimationQueue();
	LeaderSupport_UpdateSceneEffectQueue();
end

------------------------------------------------------------------------------
function LeaderSupport_IsLeaderVisible()
	return ms_bLeaderIsVisible;
end

------------------------------------------------------------------------------
function LeaderSupport_ClearInitialAnimationState()
	ms_bInitialAnimtion = true;
end