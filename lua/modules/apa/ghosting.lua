if (not APA.hasCPPI) or (not APA.FindOwner) then return false end -- Must Have CPPI

local APGhosts = {}
local hook, table, ents, timer, IsValid = hook, table, ents, timer, IsValid

local vector_origin = vector_origin or Vector(0,0,0)
local isFrozen = APA.isFrozen
local killvel = APA.killvel

do
	local count = {}
	function APA.GhostIsTrap(ent)
		local tr
		local trace
		local mins = ent:OBBMins()
		local maxs = ent:OBBMaxs()
		local check = false

		mins = ent:LocalToWorld(mins)*Vector(1.0005, 1.0005, 1.0005)
		maxs = ent:LocalToWorld(maxs)*Vector(1.0005, 1.0005, 1.0005)

		local pos = ent and ent.GetPos and ent:GetPos() or false

		if pos then
			tr = {
				start = pos, 
				endpos = pos, 
				filter = ent,
				ignoreworld = true,
			}

			trace = util.TraceEntity( tr, ent )
			local tre = trace.Entity
			check = IsValid(tre) and (not isFrozen(tre)) and tre or check
		end

		if check or not pos then
			local found = {}
			for _,v in next, ents.FindInBox(mins, maxs) do
				if v ~= ent and (not APA.IsWorld(v)) then
					table.insert(found,v)
					if not check then check = v end
					killvel(v,false)
					v.APAGhostBlock = true
				end
			end

			if check then
				for _,v in next, found do
					if v.GetClass and v:GetClass() ~= "player" then
						if not isFrozen(v) then
							local owner = APA.FindOwner(v)
							local steamid = IsValid(owner) and owner:SteamID() or "invalid"
							count[steamid] = count[steamid] or {}
							count[steamid][#count[steamid]+1] = v
						end
					end
				end

				for k,v in next, count do
					local t = 0
					local c = #v
					local ply = player.GetBySteamID(k)

					if c > 3 then t = 1 end
					if c > 5 then t = 2 end

					for _,e in next, v do
						if t == 1 then killvel(e,true) end 
						if t == 2 then SafeRemoveEntity(e) end
					end

					if c > 10 then
						ply.FPPAntiSpamCount = c -- Make a correction for FPP spam count.
						APA.Notify(ply, "Naughty, Prop Spam Detected!", NOTIFY_ERROR, 5, 1)
					end
				end

				count = {}
				return check
			end
		end
		return check
	end
end -- Magic Scope
local IsTrap = APA.GhostIsTrap

local function AntiSpam(ent)
	if not IsValid(ent) then return end

	local owner = APA.FindOwner(ent)
	local badents = {}
	local blockghost = false

	local count = 0
	for _,v in next, ents.FindInSphere(ent:GetPos(), 10) do
		if not isFrozen(ent) and not APA.IsWorld(v) then
			local o = APA.FindOwner(v)
			if owner == o then
				count = count + 1
				badents[v:EntIndex()] = v
			end
		end
	end
	
	owner.APAAntiSpam = owner.APAAntiSpam or 0
	owner.APAAntiSpam = owner.APAAntiSpam + count

	if owner.APAAntiSpam < 100 then
		timer.Simple(owner.APAAntiSpam/10, function()
			if IsValid(owner) and owner.APAAntiSpam > 0 then
				owner.APAAntiSpam = owner.APAAntiSpam - 1
				if owner.APAAntiSpam < 5 then owner.APASpam_HasWarned = nil end
			end
		end)
	end

	if owner.APAAntiSpam > 20 and owner.APAAntiSpam < 25 then
		APA.Notify(owner, "UnGhost: Slow Down!", NOTIFY_ERROR, 3, 1)
		blockghost = true
	end

	if owner.APAAntiSpam > 25 then
		if not owner.APASpam_HasWarned then
			APA.Notify(owner, "Naughty, UnGhost Spam Detected!", NOTIFY_ERROR, 5, 1)
			owner.APASpam_HasWarned = true
			owner.APAAntiSpam = 35

			ent.APAGhostBlock = true
			for _,v in next, badents do
				APA.killvel(v,true)
				v.APAGhostBlock = true
			end
		end

		blockghost = true
	end

	if owner.APAAntiSpam > 100 then owner.APAAntiSpam = 100 end
	if blockghost then return true end
end

function APA.CheckGhost( ent )
	local owner = APA.FindOwner(ent)

	if ent.GetVelocity and ent:GetVelocity():Distance( Vector( 0.01, 0.01, 0.01 ) ) > 0.15 then return false end -- Are we moving?
	local trap = IsTrap(ent)
	if IsValid(trap) then
		if APA.Settings.GhostPickup:GetBool() and not APA.Settings.UnGhostPassive:GetBool() then 
			APA.Notify(owner, "Cannot UnGhost: Prop Obstructed! (See Console)", NOTIFY_ERROR, 4, 0, {ent:GetModel(),tostring(trap).."("..trap:GetModel()..")"})
		end
		return false 
	end
	return IsValid(ent)
end

function APA.InitGhost( ent, ghostoff, freeze, collision, forced)
	local ghostspawn, GhostPickup, ghostfreeze = APA.Settings.GhostSpawn:GetBool(), APA.Settings.GhostPickup:GetBool(), APA.Settings.GhostFreeze:GetBool()
	local freezeonunghost = APA.Settings.FreezeOnUnghost:GetBool()


	if not (ghostspawn or GhostPickup or ghostfreeze) then return false end -- Don't run without ghosting.
	if not IsValid(ent) then return true end -- Ghosting is enabled but the entity isn't valid.

	local isfrozen = isFrozen(ent)
	if (not isfrozen) and ghostoff and ent.APAGhostBlock then return end
	if isfrozen then
		ghostoff = true
		ent.APAGhostBlock = nil 
	end

	if( (not APA.IsWorld( ent )) or forced ) then
		local collision = (collision or APA.Settings.GhostsNoCollide:GetBool()) and COLLISION_GROUP_WORLD or COLLISION_GROUP_WEAPON
		local unghost = ghostoff and APA.CheckGhost(ent) or false

		if ent.FPPAntiSpamIsGhosted then -- Fix/Workaround for FPP ghosting compatibility.
			local function x(ent)
				if IsValid(ent) then
					DropEntityIfHeld(ent)
					ent:ForcePlayerDrop()
				end
			end
			x(ent)
			timer.Simple(0.001, x)
			unghost = false
		end

		killvel(ent,freeze or false)
		ent.APGhost = APA.Settings.GhostPickup:GetBool() or nil
		ent:DrawShadow(unghost)

		if unghost or (ghostoff and ghostspawn and not GhostPickup) then
			
			if ent.OldColor then 
				if ent.OldColor.a == 255 then ent:SetRenderMode(RENDERMODE_NORMAL) end
				ent:SetColor(Color(ent.OldColor.r, ent.OldColor.g, ent.OldColor.b, ent.OldColor.a))
			end
			ent.OldColor = nil

			if ent.OldCollisionGroup then
				if APA.Settings.PropsNoCollide:GetInt() >= 1 and ent.OldCollisionGroup == COLLISION_GROUP_INTERACTIVE_DEBRIS then
					ent.OldCollisionGroup = COLLISION_GROUP_NONE
				end
				ent:SetCollisionGroup(ent.OldCollisionGroup)
				ent.CollisionGroup = ent.OldCollisionGroup
				ent:CollisionRulesChanged()
			end

			if ent.OldMaterial and ent.GetClass and string.find( string.lower(ent:GetClass()), "gmod_" ) or string.find( string.lower(ent:GetClass()), "wire_" ) then
				ent:SetMaterial(ent.OldMaterial or '')
			end
			ent.OldMaterial = nil

			ent.OldCollisionGroup = nil
			ent.APGhost = nil
		elseif GhostPickup or ghostspawn then
			DropEntityIfHeld(ent)

			local oColGroup = ent:GetCollisionGroup()
			ent.OldCollisionGroup = ent.OldCollisionGroup or oColGroup or 0

			ent:SetRenderMode(RENDERMODE_TRANSALPHA)
			ent.OldColor = ent.OldColor or ent:GetColor()
			ent:SetColor(Color(255, 255, 255, 185))

			if ent.GetClass and string.find( string.lower(ent:GetClass()), "gmod_" ) or string.find( string.lower(ent:GetClass()), "wire_" ) then
				ent.OldMaterial = ent.OldMaterial or (ent.GetMaterial and ent:GetMaterial())
				ent:SetMaterial("models/wireframe")
			end

			if not ( oColGroup == COLLISION_GROUP_WEAPON or oColGroup == COLLISION_GROUP_WORLD ) then
				ent:SetCollisionGroup(collision)
				ent.CollisionGroup = collision
			end
		end

		if ent.APGhost then table.insert(APGhosts, ent) else table.RemoveByValue(APGhosts, ent) end

		if GhostPickup then
			for _,x in next, constraint.GetAllConstrainedEntities(ent) do
				for _,v in next, (x.__APAPhysgunHeld or {}) do 
					if v then nofreeze = true break end
				end
			end

			for i = 0, ent:GetPhysicsObjectCount() - 1 do
				local subphys = ent:GetPhysicsObjectNum( i )
				timer.Simple(i/1000,function()
					if ( IsValid( subphys ) ) then
						local canfreeze = ((unghost and freezeonunghost) or ghostfreeze) and subphys:IsMotionEnabled()
						if (canfreeze and not nofreeze) or forcefreeze then 
							subphys:EnableMotion(false)
							subphys:Sleep()
						end
					end
				end)
			end
		end

		ent.APAIsObscured = nil
	end
end

function APA.GetGhosts()
	APGhosts = APGhosts or {}
	for k,v in next, APGhosts do 
		if not (v or IsValid(v)) then
			APGhosts[k] = nil
		end
	end
	return APGhosts or {}
end

function APA.IsSafeToGhost(p,ent)
	if not p then return end

	local ply = (IsValid(p) and (p.IsPlayer and p:IsPlayer())) and p or nil
	local ent = IsValid(p) and not ply and p or ent

	if IsValid(ply) and IsValid(ent) then
		ent = (ent.CPPICanPhysgun and ent:CPPICanPhysgun(ply)) and ent or nil
	end

	return IsValid(ent)
end

local IsSafeToGhost = APA.IsSafeToGhost

local function CallGhost(ent, ghostoff, freeze)
	local i = 0
	for _,v in next, constraint.GetAllConstrainedEntities(ent) do
		timer.Simple(i/100, function()
			local valid = IsValid(v)
			local phys = valid and v.GetPhysicsObject and v:GetPhysicsObject()

			if valid and ent == v or ( v.OldCollisionGroup or v.APGhost ) or IsValid(phys) and phys:IsMotionEnabled() then
				APA.InitGhost(v, ghostoff, freeze)
			end
		end)
		i = i + 1
	end
end

hook.Add( "PhysgunPickup", "APAntiPickup", function(ply,ent)
	if APA.Settings.GhostPickup:GetBool() then
		local antispam = AntiSpam(ent)

		if not APA.Settings.Method:GetBool() and not ent.PhysgunDisabled then APA.SetBadEnt(ent,true,true) end
		timer.Simple(0.001, function() -- Delay so that the above command goes through befor our check.
			if not IsSafeToGhost(ply,ent) then return end

			local puid = tostring(ply:UniqueID())
			local pickup = CallGhost(ent, false, false)

			ent.__APAPhysgunHeld = ent.__APAPhysgunHeld or {}
			ent.__APAPhysgunHeld[puid] = true
		end)
	end
end)

hook.Add("PhysgunDrop", "APAntiDrop", function(ply,ent)
	if IsValid(ent) and IsSafeToGhost(ply,ent) then
		ent.__APAPhysgunHeld = ent.__APAPhysgunHeld or {}
		local puid = tostring(ply:UniqueID())
		local freezing = (ent.GetPhysicsObject and isFrozen(ent)) or APA.Settings.FreezeOnDrop:GetBool()
		
		timer.Simple(freezing and 0 or 1, function()
			if IsValid(ent) and ent.__APAPhysgunHeld then
				if next(ent.__APAPhysgunHeld) == nil then
					CallGhost(ent, true, freezing)
				end
			end
		end)

		ent.__APAPhysgunHeld[puid] = nil
	end
end)

local function DontPickupGhosts(ply,ent) if ent.APGhost then return false end end
hook.Add("CanPlayerUnfreeze","APADontPickupGhosts", DontPickupGhosts)

timer.Create("APAUnGhostPassive", 1.23, 0, function()
	if not APA.Settings.UnGhostPassive:GetBool() then return end
	local i = 0
	for _,v in next, APA.GetGhosts() do
		if IsValid(v) and v.APGhost then
			i = i + 1
			timer.Simple(i/100, function()
				if IsValid(v) and next(v.__APAPhysgunHeld) == nil and v.APGhost and IsSafeToGhost(v) then
					APA.InitGhost(v, true, false)
				end
			end)
		end
	end
end)

hook.Add( "OnEntityCreated", "APAntiGhostSpawn", function(ent)
	timer.Simple(0.002, function() -- Make GhostSpawn compatible with Method0.
		local ply = APA.FindOwner(ent)
		if APA.Settings.GhostSpawn:GetBool() and IsValid(ply) then
			if not APA.Settings.Method:GetBool() then
				APA.SetBadEnt(ent,true)
			end
			APA.InitGhost(ent, false, true, true, true)
		end
	end)
end)

hook.Add( "CanTool", "APAntiGhostSpawn", function(ply, tr, mode)
	local ent = tr.Entity
	if IsValid(ply) then
		for _,v in next, ents.FindInSphere(tr.HitPos, 30) do
			if IsValid(v) and not APA.IsWorld(v) then
				if IsTrap(v) then
					APA.InitGhost(ent, false, true)
				end
			end
		end
		if IsValid(ent) and ent.CPPICanTool and ent:CPPICanTool(ply, mode) then
			timer.Simple(0.01, function() -- Wierd hook order stuff.
				if not ent.PhysgunDisabled and IsValid(ent) then
					APA.InitGhost(ent, false, false, false)
				end
			end)
		end
	end
end)

hook.Add("PlayerUnfrozeObject", "APAntiGhostR", function(ply,ent,phys)
	timer.Simple(0, function()
		if APA.Settings.GhostPickup:GetBool() and IsValid(ply) and IsSafeToGhost(ply,ent) then
			APA.InitGhost(ent, false, true)
			timer.Simple(0, function() if IsValid(phys) then phys:Wake() end end)
		end
	end)
end)

hook.Add("CanProperty", "APA.CanPropertyFix", function( ply, property, ent )
	if( tostring(property) == "collision" and ent.APGhost ) then
		APA.Notify(ply, "Cannot Set Property on Ghost.", NOTIFY_ERROR, 4, 0)
		return false 
	end
end)

APA.initPlugin('ghosting') -- Init Plugin (Must match filename.)