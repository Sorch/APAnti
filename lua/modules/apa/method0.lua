
local APABadEnts = APABadEnts or {}

local log = APA.log
local isPlayer = APA.isPlayer
local physStop = APA.physStop

local IsValid = IsValid
local timer = timer
local hook = hook

function APA.SetBadEnt(ent,bool,ignorefrozen)
	local phys = IsValid(ent) and ent.GetPhysicsObject and ent:GetPhysicsObject()

	if bool then
		if (not ignorefrozen) and IsValid(phys) and not phys:IsMotionEnabled() then return end -- Don't apply on frozen entities.

		log('[BadEntity]',ent,' is now a BAD entity!') if APA.Settings.Debug:GetInt() > 0 then ent:SetColor(Color(255,0,0)) end

		ent:SetNWBool("APABadEntity", true)

		local inc = ((APA.Settings.BadTime:GetFloat() >= 0.15 and APA.Settings.BadTime:GetFloat() or 0.15))

		ent.APAt = ent.APAt or {}
		ent.APAt["block entity"] = true
		ent.APAt["time stamp"] = (not ent.APAt["time stamp"]) and CurTime()+inc or ent.APAt["time stamp"]
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
			local speed = c.OurOldVelocity:Length()

			if speed < 8.4 then return end
			if speed > 1000 then
				c.HitEntity:SetPos(c.HitEntity:GetPos())
				c.HitObject:SetPos(c.HitObject:GetPos())
				c.HitObject:SetVelocityInstantaneous(Vector())
			end

			if IsValid(ent) and type(ent.APAt) == "table" then

				ent.APAt["time stamp"] = CurTime()+0.15

				if APA.Settings.AnnoySurf:GetBool() and isPlayer(c.HitEntity) then
					ent.APANoPhysgun = (not ent.APANoPhysgun) and CurTime()+0.55 or ent.APANoPhysgun

					if not IsValid(c.PhysObject) then return end 

					physStop(c.PhysObject)
					physStop(c.HitEntity)

					ent:ForcePlayerDrop()
					c.PhysObject:EnableMotion(not APA.Settings.FreezeOnHit:GetBool())
					c.PhysObject:SetVelocityInstantaneous(Vector(0,0,c.PhysObject:GetMass()*1.1))
					c.PhysObject:Sleep()
				end
				
				if not isPlayer(c.HitEntity) then
					timer.Simple(0.01, function()
						if (speed > 95 or (IsValid(c.HitObject) and c.HitObject:GetVelocity():Length() > 75)) and not APA.IsWorld(c.HitEntity) then
							if not ( c.HitEntity:GetNWBool("APABadEntity", false) ) then 
								APA.SetBadGroup(c.HitEntity,true)
							else 
								ent.APAt["time stamp"] = CurTime()+0.15
							end
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

		for _,v in next, constraint.GetAllConstrainedEntities(ent) do
			if IsValid(v) then
				v.APAForceBlock = nil
				v.APAForceFreeze = nil
			end
		end

		timer.Simple(3, function() if IsValid(ent) then ent.APANoPhysgun = nil end end)
		table.RemoveByValue(APABadEnts, ent)
	end
end

hook.Add("StartCommand", "APAAnnoySurf2", function(ply, mv)
	if not APA.Settings.AnnoySurf:GetBool() then return end
	local wep = isPlayer(ply) and ply:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == "weapon_physgun" then
		local phys = ply:GetPhysicsObject()
		if ply:IsOnGround() and IsValid(phys) and phys:GetVelocity():Distance(Vector()) > 500 then
			mv:RemoveKey(IN_ATTACK)
			local pos = ply:GetPos()
			timer.Simple(0, function() if IsValid(ply) then ply:SetPos(pos) end end)
		end
	end
end)

function APA.SetBadGroup(ent,bool)
	local i = 0
	local isvalid = function(v) return IsValid(v) and not v.PhysgunDisabled end
	for _,v in next, constraint.GetAllConstrainedEntities(ent) do
		if isvalid(v) then 
			timer.Simple((i <= 0 and i or i/100), function()
				if isvalid(v) then
					APA.SetBadEnt(v,bool)
				end
			end)
			i = i + 1
		end
	end
end

function APA.IsEntBad(ent)
	if ent and ent.APAt then return ent.APAt["block entity"] end
	return ent:GetNWBool("APABadEntity", false)
end

timer.Create("APABaddieFinder", 0.75, 0, function() 
	for k,v in next, APABadEnts do
		timer.Simple(k/100, function()
			if v and v.APAt and v.APAt.Think then
				v.APAt.Think()
			end
		end)
	end
end)

hook.Add( "OnEntityCreated", "APAMethod0", function(ent)
	timer.Simple(0.001, function()
		if IsValid(ent) and not APA.IsWorld(ent) and not APA.Settings.Method:GetBool() then
			APA.SetBadEnt(ent,true)
		end
	end)
end)

if APA.hasCPPI and APA.FindOwner then

	hook.Add( "PhysgunPickup", "APAMethod0", function(ply,ent)
		if (IsValid(ply) and IsValid(ent)) and ent.CPPICanPhysgun and ent:CPPICanPhysgun(ply) then
			timer.Simple(0.001, function() -- Wierd hook order stuff.
				if not APA.Settings.Method:GetBool() and not ent.PhysgunDisabled and IsValid(ent) then
					APA.SetBadGroup(ent,true)
				end
			end)
		end
	end)

	hook.Add( "CanTool", "APAMethod0", function(ply, tr, mode)
		local ent = tr.Entity
		if (IsValid(ply) and IsValid(ent)) and ent.CPPICanTool and ent:CPPICanTool(ply, mode) then
			timer.Simple(0.01, function() -- Wierd hook order stuff.
				if not APA.Settings.Method:GetBool() and not ent.PhysgunDisabled and IsValid(ent) then
					APA.SetBadGroup(ent,true)
				end
			end)
		end
	end)

end

APA.initPlugin('method0') -- Init Plugin (Must match filename.)
