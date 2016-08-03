if (not APA.hasCPPI) or (not APA.FindOwner) then return false end -- Must Have CPPI

local APGhosts = {}
local hook, table, ents, timer, IsValid = hook, table, ents, timer, IsValid

function APA.GhostIsTrap(ent)
	local mins, maxs, check = ent:OBBMins(), ent:OBBMaxs(), false
	
	local tr = {
		start = ent:LocalToWorld(mins), 
		endpos = ent:LocalToWorld(maxs), 
		filter = ent
	}

	local trace = util.TraceLine(tr)
	check = APA.isPlayer(trace.Entity) and trace.Entity or false

	if check then return check end
	local pos = ent and ent:GetPos()

	tr = {
		start = pos, 
		endpos = pos, 
		filter = ent, 
		mins = ent:OBBMins(), 
		maxs = ent:OBBMaxs()
	}

	trace = util.TraceHull(tr)
	check = APA.isPlayer(trace.Entity) and trace.Entity or false

	if check then return check end

	for _,v in pairs(ents.FindInBox( ent:LocalToWorld(mins), ent:LocalToWorld(maxs) )) do
		if APA.isPlayer(v) or (v.IsNPC and v:IsNPC()) or (v.IsBot and v:IsBot()) then
			if not ent.APAIsObscured then
				ent.APAIsObscured = v
				break
			end
		end
	end

	ent.APAIsObscured = ent.APAIsObscured or check or false
	return ent.APAIsObscured
end
local IsTrap = APA.GhostIsTrap

function APA.CheckGhost( ent )
	local owner = APA.FindOwner(ent)
	if ent.GetVelocity and ent:GetVelocity():Distance( Vector( 0.01, 0.01, 0.01 ) ) > 0.15 then return false end
	local trap = IsTrap(ent)
	if trap then
		if APA.Settings.GhostPickup:GetBool() and not APA.Settings.UnGhostPassive:GetBool() then 
			APA.Notify(owner, "Cannot UnGhost: Prop Obstructed! (See Console)", NOTIFY_ERROR, 4, 0, {ent:GetModel(),tostring(trap).."("..trap:GetModel()..")"})
		end
		return false 
	end
	return IsValid(ent)
end

local function psleep(unghost,ent,subphys)
	if unghost and !ent.APGhost and IsValid(subphys) then
		subphys:SetVelocity( Vector(0,0,0) )
		subphys:AddAngleVelocity( subphys:GetAngleVelocity() * -1 )
		subphys:Sleep()
	end
end

function APA.InitGhost( ent, ghostoff, nofreeze, collision, forcefreeze )
	if( IsValid(ent) and not APA.IsWorld( ent ) ) then
		local collision = (collision or APA.Settings.GhostsNoCollide:GetBool()) and COLLISION_GROUP_WORLD or COLLISION_GROUP_WEAPON
		local unghost = ghostoff and APA.CheckGhost(ent) or false

		if ent.ForcePlayerDrop and ent.FPPAntiSpamIsGhosted then 
			DropEntityIfHeld(ent)
			ent:ForcePlayerDrop()
			
			timer.Simple(0.001, function()
				if IsValid(ent) then
					DropEntityIfHeld(ent)
					ent:ForcePlayerDrop()
				end
			end)
			
			unghost = false
		end

		local ghostspawn, GhostPickup, ghostfreeze = APA.Settings.GhostSpawn:GetBool(), APA.Settings.GhostPickup:GetBool(), APA.Settings.GhostFreeze:GetBool()
		local freezeonunghost = APA.Settings.FreezeOnUnghost:GetBool()

		ent.APGhost = APA.Settings.GhostPickup:GetBool() or nil
		ent:DrawShadow(unghost)

		if unghost or (ghostoff and ghostspawn and not GhostPickup) then
			ent:SetRenderMode(RENDERMODE_NORMAL)

			if ent.OldColor then ent:SetColor(Color(ent.OldColor.r, ent.OldColor.g, ent.OldColor.b, ent.OldColor.a)) end
			ent.OldColor = nil

			if ent.OldCollisionGroup then
				ent:SetCollisionGroup(ent.OldCollisionGroup)
				ent.CollisionGroup = ent.OldCollisionGroup
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
			ent:SetColor(Color(255, 255, 255, ent.OldColor.a - 70))

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
						if (canfreeze and not nofreeze) or forcefreeze then subphys:EnableMotion(false) end
						psleep(unghost,ent,subphys)   timer.Simple(0.001, function() psleep(unghost,ent,subphys) end)
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

	local good, bad, ugly = APA.EntityCheck( (IsValid(ent) and ent.GetClass) and ent:GetClass() or '' )
	bad = APA.Settings.Method:GetBool() and bad or APA.IsEntBad(ent)

	if ply and ent then
		ent = (ent.CPPICanPhysgun and ent:CPPICanPhysgun(ply)) and ent or nil
	end

	return IsValid(ent) and ((not good) and bad) and
	not (ent:IsVehicle() or ent:IsWeapon() or APA.IsWorld(ent)) and 
	not (ent.GetClass and ent:GetClass() == "prop_ragdoll") and true or false
end

local IsSafeToGhost = APA.IsSafeToGhost

local function CallGhost(ent, ghostoff, nofreeze)
	local i = 0
	for _,v in next, constraint.GetAllConstrainedEntities(ent) do
		timer.Simple(i/100, function()
			local valid = IsValid(v)
			local phys = valid and v.GetPhysicsObject and v:GetPhysicsObject()

			if valid and ent == v or ( v.OldCollisionGroup or v.APGhost ) or phys:IsMotionEnabled() then
				APA.InitGhost(v, ghostoff, nofreeze)
			end
		end)
		i = i + 1
	end
end

hook.Add( "PhysgunPickup", "APAntiPickup", function(ply,ent)
	if APA.Settings.GhostPickup:GetBool() then
		if not APA.Settings.Method:GetBool() and not ent.PhysgunDisabled then APA.SetBadEnt(ent,true) end
		if not IsSafeToGhost(ply,ent) then return end

		local puid = tostring(ply:UniqueID())
		local pickup = CallGhost(ent, false, true)

		ent.__APAPhysgunHeld = ent.__APAPhysgunHeld or {}
		ent.__APAPhysgunHeld[puid] = true
	end
end)

hook.Add("PhysgunDrop", "APAntiDrop", function(ply,ent)
	if IsValid(ent) and IsSafeToGhost(ply,ent) then
		ent.__APAPhysgunHeld = ent.__APAPhysgunHeld or {}
		local puid = tostring(ply:UniqueID())
		local freezing = (ent.GetPhysicsObject and IsValid(ent:GetPhysicsObject()) and !ent:GetPhysicsObject():IsMotionEnabled()) or APA.Settings.FreezeOnDrop:GetBool()
		
		timer.Simple(freezing and 0 or 1, function()
			if IsValid(ent) and ent.__APAPhysgunHeld then
				if next(ent.__APAPhysgunHeld) == nil then
					CallGhost(ent, true, false)
				end
			end
		end)

		ent.__APAPhysgunHeld[puid] = nil
	end
end)

local function DontPickupGhosts(ply,ent) if ent.APGhost then return false end end
hook.Add("CanPlayerUnfreeze","APADontPickupGhosts", DontPickupGhosts)
hook.Add("AllowPlayerPickup","APADontPickupGhosts", DontPickupGhosts)

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
	timer.Simple(0, function()
		local ply = APA.FindOwner(ent)
		if APA.Settings.GhostSpawn:GetBool() and IsValid(ply) then

			if not APA.Settings.Method:GetBool() then
				APA.SetBadEnt(ent,true)
			end

			if IsSafeToGhost(ply,ent) then
				APA.InitGhost(ent, false, false, true, true)
			end

		end
	end)
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