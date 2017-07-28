
local VALID_RELATIONSHIPS:table = {
	"DIPLO_STATE_ALLIED",
	"DIPLO_STATE_DECLARED_FRIEND",
	"DIPLO_STATE_DENOUNCED",
	"DIPLO_STATE_WAR"
};

function IsValidRelationship(relationshipType:string)
	for _:number, tmpType:string in ipairs(VALID_RELATIONSHIPS) do
		if relationshipType == tmpType then
			return true;
		end
	end
	return false;
end