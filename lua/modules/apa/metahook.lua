APA.metahook = APA.metahook or {} 

local FindMetaTable = FindMetaTable
local e = FindMetaTable("Entity")
local p = FindMetaTable("Player")
local old = {e={},p={}}

if not APA.metahook.SetCollisionGroup then
	old.e.SetCollisionGroup = e.SetCollisionGroup
	function e:SetCollisionGroup(group)
		local group = hook.Run("APA.SetCollisionGroup", self, group) or group
		if isbool(group) and group == true then return end -- Prevent Operation.

		return old.e.SetCollisionGroup(self,group)
	end

	APA.metahook.SetCollisionGroup = true
end

APA.initPlugin('metahook') -- Init Plugin (Must match filename.)