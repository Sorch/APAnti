local APAWorldEnts = APAWorldEnts or {}
local hook, table, print, ents, timer, IsValid = hook, table, print, ents, timer, IsValid
local tostring = tostring

if #APAWorldEnts <= 0 then timer.Simple(0.001, function() for _,v in next, ents.GetAll() do table.insert( APAWorldEnts, v ) end end) end

local function log(tag,...)
	if APA.Settings.Debug:GetInt() <= 0 then return end

	local str = tostring(os.date("%H:%M"))..'| [APA-DEBUG]'..tostring(tag)
	print(str,...)
	if APA.Settings.Debug:GetInt() >= 2 then
		ServerLog(str,...)
	end
end

function APA.EntityCheck( entClass )
	local good, bad = false, false

	for _,v in pairs(APA.Settings.L.Black) do
		if( string.find( string.lower(entClass), string.lower(v) ) ) then
			bad = true
			break -- No need to go through the rest of the loop.
		end
	end

	for _,v in pairs(APA.Settings.L.White) do
		if( string.find( string.lower(entClass), string.lower(v) ) ) then
			good = true
			break
		end
	end

	log('[Check] Checking',entClass,'Good:',good,'Bad:',bad)
	return good, bad, entClass
end

function APA.isPlayer(ent)
	if not ent or ent == nil or ent == NULL then return false end
	return IsValid(ent) and (ent.GetClass and ent:GetClass() == "player") or (ent.IsPlayer and ent:IsPlayer()) or false
end
local isPlayer = APA.isPlayer

function APA.FindProp(attacker, inflictor)
	if( attacker:IsPlayer() ) then attacker = inflictor end
	return ( IsValid(attacker) and attacker.GetClass ) and attacker or nil
end

function APA.WeaponCheck(attacker, inflictor)
	for _,ent in next, {attacker, inflictor} do
		if ent and IsValid(ent) and (isPlayer(ent) or (ent.IsWeapon and ent:IsWeapon()) or (ent.IsNPC and ent:IsNPC())) then 
			return true
		end
	end
	return false
end

local APABadEnts = APABadEnts or {}

local function physStop(phys)
	if phys == NULL or not IsValid(phys) then return false end

	if type(phys) == "PhysObj" then
		phys:SetVelocityInstantaneous(Vector(0,0,0))
		phys:AddAngleVelocity(phys:GetAngleVelocity()*-1)
	elseif isPlayer(phys) then
		phys:SetVelocity(phys:GetVelocity()*-1)
	else
		phys = IsValid(phys) and phys:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetVelocityInstantaneous(Vector(0,0,0))
			phys:AddAngleVelocity(phys:GetAngleVelocity()*-1)
			return phys
		end
	end
end

local function DamageFilter( target, d ) -- d for damage info.
	local attacker, inflictor, damage, type = d:GetAttacker(), d:GetInflictor(), d:GetDamage(), d:GetDamageType()
	local dents = {attacker, inflictor}

	local isvehicle = (attacker:IsVehicle() or inflictor:IsVehicle())
	local isexplosion = d:IsExplosionDamage()

	local targetClass = IsValid(target) and target.GetClass and target:GetClass() or nil
	if string.find(string.lower(targetClass), "prop_") == 1 then return APA.Settings.UnbreakableProps:GetBool() end

	for _,v in next, dents do
		local propdmg = (v.GetClass and (string.find(string.lower(v:GetClass()), "prop_") == 1))
		local good, bad, ugly = APA.EntityCheck( (IsValid(v) and v.GetClass) and v:GetClass() or '' )
		bad = APA.Settings.Method:GetBool() and bad or APA.IsEntBad(v)

		if APA.hasCPPI and APA.Settings.KillOwnership and propdmg and isPlayer(APA.FindOwner(v)) then
			d:SetAttacker(APA.FindOwner(v))
		end

		if APA.Settings.PropsOnly:GetBool() then
			bad = propdmg and bad or false
			if not bad then good = true end
		end

		log('[Damage]1) Checking Entity',v,'Is Vehicle: '..tostring(isvehicle),'Is Explosion: '..tostring(isexplosion))
		log('[Damage]2) Checking Entity',v,'Is Bad: '..tostring(bad),'Is Prop Damage: '..tostring(propdmg))
		log('[Damage]3) Checking Entity',v,'Is Good: '..tostring(good),'Is Fall: '..tostring(d:IsFallDamage()))

		if (bad or (APA.Settings.BlockPropDamage:GetBool() and propdmg)) and not (good or d:IsFallDamage()) then
			if APA.WeaponCheck(attacker, inflictor) then return end
			if APA.Settings.BlockVehicleDamage:GetBool() and isvehicle then return true end
			if APA.Settings.BlockExplosionDamage:GetBool() and isexplosion then return true end
			if APA.Settings.BlockWorldDamage:GetBool() and inflictor == 'worldspawn' then return true end
			if APA.Settings.AntiPK:GetBool() and not isvehicle and not isexplosion then 
				d:SetDamage(0) d:ScaleDamage(0) d:SetDamageForce(Vector(0,0,0))

				if APA.Settings.FreezeOnHit:GetBool() then
					if damage >= 10 then
						local phys = IsValid(v) and v:GetPhysicsObject()
						if IsValid(phys) then
							if isPlayer(target) then 
								physStop(target)
							end
							physStop(phys)
							phys:Sleep()
							if not v:IsPlayer() then
								phys:EnableMotion(false)
							else
								phys:Wake()
							end
							timer.Simple(0.01, function() 
								if isPlayer(target) then
									physStop(target)
								end 
							end)
						end
					end
				end

				return true
			end
		end
	end
end
hook.Add( "EntityTakeDamage", "APAntiPk", DamageFilter )

hook.Add( "PlayerSpawnedProp", "APAntiExplode", function( _, _, prop )
	if( IsValid(prop) and APA.Settings.BlockExplosionDamage:GetInt() >= 1 ) then
		if not string.find( string.lower(prop:GetClass()), "wire" ) then -- Wiremod causes problems.
			log('[Block]','Removed explosion from',prop)
			prop:SetKeyValue("ExplodeDamage", "0") 
			prop:SetKeyValue("ExplodeRadius", "0")
		end
	end
end)

if not APA.hasCPPI then error('[APA] CPPI not found, APAnti will be heavily limited.') return end

hook.Add("StartCommand", "APAStartCmd", function(ply, mv)
	if isPlayer(ply) and ply:GetEyeTrace().Entity.APANoPhysgun and ply:GetEyeTrace().Entity.APANoPhysgun > CurTime() then
		local ent = ply:GetEyeTrace().Entity
		if mv:GetMouseWheel() != 0 and (ent.APANoPhysgun-0.55) <= CurTime() then  
			ent.APANoPhysgun = CurTime()+0.7
		end
		mv:SetButtons(bit.band(mv:GetButtons(),bit.bnot(IN_ATTACK)))
	end
end)

function APA.SetBadEnt(ent,bool)
	local phys = IsValid(ent) and ent:GetPhysicsObject()
	if bool then
		log('[BadEntity]',ent,' is now a BAD entity!') if APA.Settings.Debug:GetInt() > 0 then ent:SetColor(Color(255,0,0)) end

		ent:SetNWBool("APABadEntity", true)

		ent.APAt = ent.APAt or {}
		ent.APAt["block entity"] = true
		ent.APAt["time stamp"] = (not ent.APAt["time stamp"]) and CurTime()+((APA.Settings.BadTime:GetFloat() >= 0.15 and APA.Settings.BadTime:GetFloat() or 0.15)) or ent.APAt["time stamp"]
		log('[BadEntity]','Wait Time',Vector(0,0,(ent.APAt["time stamp"] or 0)):Distance(Vector(0,0,CurTime() or 0)),'seconds')

		ent.APAt.Think = function()
			if tonumber(ent.APAt["time stamp"] or 0) < CurTime() and next(ent.__APAPhysgunHeld) == nil then
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

		ent.APAtCallback = function(ent, c)
			if APA.Settings.AnnoySurf:GetBool() and IsValid(ent) and ent.APAt and type(ent.APAt) == "table" then
				if isPlayer(c.HitEntity) then
					ent.APAt["time stamp"] = CurTime()+0.15
					ent.APANoPhysgun = (not ent.APANoPhysgun) and CurTime()+0.55 or ent.APANoPhysgun

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

timer.Create("APABaddieFinder", 0.33, 0, function() 
	for k,v in next, APABadEnts do
		timer.Simple(k/100, function() 
			if v and v.APAt and v.APAt.Think then
				v.APAt.Think()
			end
		end)
	end
end)

function APA.FindOwner( ent )
	local owner, _ = ent:CPPIGetOwner()
	return owner or ent.FPPOwner or nil -- Fallback to FPP variable if CPPI fails.
end

function APA.ModelNameFix( model )
	return tostring(string.gsub(model, "[\\/ %;]+", "/"):gsub("%.%..", "")) or nil
end

local function ModelFilter(mdl) -- Return true to block model.
	local mdl = APA.ModelNameFix(tostring(mdl)) or nil
	if not mdl then return true end
	-- Model Blocking Code Here --
end

function APA.IsWorld( ent )
	local iw = ent.IsWorld and ent:IsWorld()
	if (not APA.FindOwner(ent)) or (not (IsValid(ent) or iw)) or (not ent.GetClass) or ent.NoDeleting or ent.jailWall or isPlayer(ent) or
		(ent.IsNPC and ent:IsNPC()) or (ent.IsBot and ent:IsBot()) or ent.PhysgunDisabled or ( ent.CreatedByMap and ent:CreatedByMap() ) or
		(ent.GetPersistent and ent:GetPersistent()) or table.HasValue(APAWorldEnts, ent) then return true end

	local blacklist = {"func_", "env_", "info_", "predicted_", "chatindicator", "prop_door_"}
	local ec = string.lower(ent:GetClass())
	for _,v in pairs(blacklist) do
		if string.find( ec, string.lower(v) ) then
			return true
		end
	end

	return false
end

local function SpawnFilter(ply, model)
	local ent = not ply:IsPlayer() and ply or nil
	local model = model and APA.ModelNameFix( model )

	if ent then 
		ent.__APAPhysgunHeld = ent.__APAPhysgunHeld or {}
		
		if not APA.IsWorld( ent ) then
			if not APA.Settings.Method:GetBool() then APA.SetBadEnt(ent,true) end
			if APA.Settings.MaxMass:GetInt() >= 1 then
				local phys = IsValid(ent) and ent:GetPhysicsObject()
				if IsValid(phys) and phys:GetMass() > APA.Settings.MaxMass:GetInt() then phys:SetMass(APA.Settings.MaxMass:GetInt()) end
			end
		end
	end

	if IsValid(ent) then
		if APA.Settings.NoCollideVehicles:GetBool() and ent:IsVehicle() then ent:SetCollisionGroup(COLLISION_GROUP_WEAPON) return end
	end
end
hook.Add( "OnEntityCreated", "APAntiSpawns", SpawnFilter)

hook.Add( "PlayerSpawnObject", "APAntiSpawns", function(ply,mdl) if mdl and ModelFilter(mdl) then return false end end)
hook.Add( "AllowPlayerPickup", "APAntiPickup", function(ply,ent) 
	local good, bad, ugly = ent.GetClass and APA.EntityCheck(ent:GetClass())
	if bad or not good then return false end
end)

hook.Add( "PhysgunPickup", "APAIndex", function(ply,ent)
	if ent and ent.APANoPhysgun and ent.APANoPhysgun > CurTime() then return false end
	ent.APANoPhysgun = nil

	if (IsValid(ply) and IsValid(ent)) and ent.CPPICanPhysgun and ent:CPPICanPhysgun(ply) then
		local puid = tostring(ply:UniqueID())
		
		ent.__APAPhysgunHeld = ent.__APAPhysgunHeld or {}
		ent.__APAPhysgunHeld[puid] = true

		if not APA.Settings.Method:GetBool() and not ent.PhysgunDisabled then APA.SetBadEnt(ent,true) end
	end
end)

hook.Add( "PhysgunDrop", "APANoThrow", function(ply,ent)
	if APA.Settings.NoThrow:GetBool() and IsValid(ent) then
		for _,v in next, constraint.GetAllConstrainedEntities(ent) do
			if IsValid(v) then
				local phys = v.GetPhysicsObject and v:GetPhysicsObject() or nil
				if IsValid(phys) then 
					phys:SetVelocityInstantaneous(Vector(0,0,0))
					phys:AddAngleVelocity(phys:GetAngleVelocity()*-1)
				end
			end
		end
	end
	if APA.Settings.FreezeOnDrop:GetBool() and IsValid(ent) and ent.GetClass and table.HasValue(APA.Settings.L.Freeze, string.lower(ent:GetClass())) then
		local phys = ent.GetPhysicsObject and ent:GetPhysicsObject() or nil 
		if IsValid(phys) then phys:EnableMotion(false) end
	end
	if (IsValid(ply) and IsValid(ent)) and ent.CPPICanPhysgun and ent:CPPICanPhysgun(ply) and ent.__APAPhysgunHeld then
		ent.__APAPhysgunHeld[tostring(ply:UniqueID())] = nil
	end
end)

timer.Create("APAFreezePassive", 2.1, 0, function()
	if not APA.Settings.FreezePassive:GetBool() then return end
	for _,v in next, ents.GetAll() do
		if IsValid(v) and v.GetClass and table.HasValue(APA.Settings.L.Freeze, string.lower(v:GetClass())) then
			if not next(v.__APAPhysgunHeld) == nil then
				local k = 0
				for _,v in next, constraint.GetAllConstrainedEntities(v) do
					timer.Simple(k/100,function() -- Prevent possible crashes or lag on freeze sweep.
						local v = v:GetPhysicsObject()
						if IsValid(v) then v:EnableMotion(false) end
					end)
					k = k + 1
				end
			end
		end
	end
end)

hook.Add( "OnPhysgunReload", "APAMassUnfreeze", function(gun,ply)
	if APA.Settings.StopMassUnfreeze:GetBool() then
		local returnfalse = false
		if gun.APAunfreezetimeout and gun.APAunfreezetimeout > CurTime() then returnfalse = true end
		gun.APAunfreezetimeout = CurTime()+0.5
		if returnfalse then return false end
	else
		gun.APAunfreezetimeout = nil
	end
	if APA.Settings.StopRUnfreeze:GetBool() then
		APA.Notify(ply, "Cannot Unfreeze Using Reload!", NOTIFY_ERROR, 1, 0)
		return false 
	end
end)