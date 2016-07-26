if (not APA.hasCPPI) or (not APA.FindOwner) then return false end -- Must Have CPPI

local APABadEnts = APABadEnts or {}

local log = APA.log
local isPlayer = APA.isPlayer
local physStop = APA.physStop

local IsValid = IsValid
local timer = timer
local hook = hook
local _G = _G

function APA.SetBadEnt(ent,bool)
	local phys = IsValid(ent) and ent:GetPhysicsObject()

	if bool then
		if not phys:IsMotionEnabled() then return end -- Don't apply on frozen entities.

		log('[BadEntity]',ent,' is now a BAD entity!') if APA.Settings.Debug:GetInt() > 0 then ent:SetColor(Color(255,0,0)) end

		ent:SetNWBool("APABadEntity", true)

		ent.APAt = ent.APAt or {}
		ent.APAt["block entity"] = true
		ent.APAt["time stamp"] = (not ent.APAt["time stamp"]) and CurTime()+((APA.Settings.BadTime:GetFloat() >= 0.15 and APA.Settings.BadTime:GetFloat() or 0.15)) or ent.APAt["time stamp"]
		log('[BadEntity]','Wait Time',Vector(0,0,(ent.APAt["time stamp"] or 0)):Distance(Vector(0,0,CurTime() or 0)),'seconds')

		if table.HasValue(APABadEnts, ent) then return end -- Don't rebind if bound.

		if not ent.APAt.Think then
			ent.APAt.Think = function()
				local checkheld = false

				for _,v in next, constraint.GetAllConstrainedEntities(ent) do
					if IsValid(v) then
						checkheld = next(v.__APAPhysgunHeld or {}) == nil
						if not checkheld then break end
					end
				end

				if tonumber(ent.APAt["time stamp"] or 0) < CurTime() and checkheld then
					local phys = IsValid(ent) and ent:GetPhysicsObject()
					if IsValid(phys) then
						if phys:GetVelocity():Length() <= 0.001 then
							phys:SetVelocityInstantaneous(Vector(0,0,0))
							phys:AddAngleVelocity(phys:GetAngleVelocity()*-1)
							APA.SetBadEnt(ent,false)
						end
					end
				end
			end
		end

		ent.APAtCallback = function(ent, c)
			if APA.Settings.AnnoySurf:GetBool() and IsValid(ent) and type(ent.APAt) == "table" then
				if isPlayer(c.HitEntity) then
					ent.APAt["time stamp"] = CurTime()+0.15
					ent.APANoPhysgun = (not ent.APANoPhysgun) and CurTime()+0.55 or ent.APANoPhysgun

					if not IsValid(c.PhysObject) then return end 

					physStop(c.PhysObject)
					physStop(c.HitEntity)

					c.HitObject:EnableMotion(false)
					
					c.PhysObject:EnableMotion(false)
					c.PhysObject:Sleep()
					
					ent:ForcePlayerDrop()
					c.PhysObject:EnableMotion(not APA.Settings.FreezeOnHit:GetBool())

					c.HitObject:EnableMotion(true)
				else
					timer.Simple(0.001, function()
						if (c.OurOldVelocity:Length() > 95 or (IsValid(c.HitObject) and c.HitObject:GetVelocity():Length() > 75)) and not APA.IsWorld(c.HitEntity) then
							APA.SetBadEnt(c.HitEntity,true)
						end
					end)
				end
			end
		end
		
		if not ent.APAfCallback then
			ent.APAfCallback = ent:AddCallback( "PhysicsCollide", ent.APAtCallback )
		end

		if not table.HasValue(APABadEnts, ent) then
 			table.insert(APABadEnts, ent)
 		end
	elseif ent and ent.APAt and type(ent.APAt) == 'table' then
		log('[BadEntity]',ent,' is now a GOOD entity!') if APA.Settings.Debug:GetInt() > 0 then ent:SetColor(Color(255,255,255)) end
		
		ent.APAt = nil
		ent:SetNWBool("APABadEntity", false)

		timer.Simple(3, function() if IsValid(ent) then ent.APANoPhysgun = nil end end)
		table.RemoveByValue(APABadEnts, ent)
	end
end

function APA.IsEntBad(ent)
	if ent and ent.APAt then return ent.APAt["block entity"] end
	return ent:GetNWBool("APABadEntity", false)
end

timer.Create("APABaddieFinder", 1.25, 0, function() 
	for k,v in next, APABadEnts do
		timer.Simple(k/100, function() 
			if v and v.APAt and v.APAt.Think then
				v.APAt.Think()
			end
		end)
	end
end)

hook.Add( "OnEntityCreated", "APAntiSpawns", function(ent)
	if IsValid(ent) and not APA.IsWorld(ent) and not APA.Settings.Method:GetBool() then
		APA.SetBadEnt(ent,true)
	end
end)

hook.Add( "PhysgunPickup", "APAMethod0", function(ply,ent)
	timer.Simple(0.001, function() -- Wierd hook order stuff.
		if not APA.Settings.Method:GetBool() and not ent.PhysgunDisabled and IsValid(ent) then
			local i = 0
			local isvalid = function(v) return IsValid(v) and not v.PhysgunDisabled end

			for _,v in next, constraint.GetAllConstrainedEntities(ent) do
				if isvalid(v) then 
					timer.Simple((i <= 0 and i or i/100), function()
						if isvalid(v) then
							APA.SetBadEnt(v,true)
						end
					end)
					i = i + 1
				end
			end
		end
	end)
end)

APA.initPlugin('method0') -- Init Plugin (Must match filename.)