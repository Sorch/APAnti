-- A Fork of https://github.com/Kefta/Entity-Crash-Catcher Most of the code left untouched. -- Sunday, February 07, 2016 --
-- Latest known commit: https://github.com/Kefta/Entity-Crash-Catcher/commit/2e8f8d9ba38d71611b53487b49d7687f21b808f4

local has = AntiCrashCMDTable
local inworld, util, ents = util.IsInWorld, util, ents

hook.Add("OnEntityCreated", "APAAntiCrash", function(ent)
	if APA.Settings.AntiCrash:GetBool() then
		timer.Simple(0, function()
			if not IsValid(ent) then return end
			if ent.IsPlayer and ent:IsPlayer() then return end

			local pos = ent.GetPos and ent:GetPos()
			local phys = ent.GetPhysicsObject and ent:GetPhysicsObject() or nil
			local physpos = IsValid(phys) and phys.GetPos and phys:GetPos() or nil

			if IsValid(phys) and ((pos and not inworld(pos)) or (physpos and not inworld(physpos)) or 
				ent.GetClass and ent:GetClass() != "prop_ragdoll" and phys:HasGameFlag(FVPHYSICS_PENETRATING)) then
				phys:SetVelocityInstantaneous(Vector(0,0,0))
				phys:Sleep()
			end
		end)
	end
end)

local function unfreeze(ply,ent,phys)
	if APA.Settings.AntiCrash:GetBool() and has.MassUnfreeze:GetBool() then
		phys:SetVelocityInstantaneous(Vector(0,0,0))
		phys:AddAngleVelocity(phys:GetAngleVelocity() * -1)
		phys:Sleep()
		timer.Simple(0.001, function() 
			phys:SetVelocityInstantaneous(Vector(0,0,0))
			phys:AddAngleVelocity(phys:GetAngleVelocity() * -1)
			phys:Sleep()
		end)
	end
end

hook.Add("CanPlayerUnfreeze", "APA-AC-MassUnfreeze", unfreeze)
hook.Add("PlayerUnfrozeObject", "APA-AC-MassUnfreeze", unfreeze)

-- Entity Crash Catcher
-- This script detects entities that are moving too fast or falling out of the world, leading to a potential server crash
-- By code_gs, Ambro, DarthTealc, TheEMP, and LuaTenshi
-- GitHub: https://github.com/Kefta/Entity-Crash-Catcher
-- Facepunch: http://facepunch.com/showthread.php?t=1347114

if ( CLIENT ) then return end

local IsTTT = false			-- Internal variable for detecting TTT
local MAX_REASONABLE_COORD = 15000
local MAX_REASONABLE_ANGLE = 15000
local MIN_REASONABLE_COORD = -MAX_REASONABLE_COORD
local MIN_REASONABLE_ANGLE = -MAX_REASONABLE_ANGLE

local ENTITY = debug.getregistry().Entity

hook.Add( "PostGamemodeLoaded", "GS - CheckTTT", function()
	if ( GAMEMODE_NAME == "terrortown" or engine.ActiveGamemode() == "terrortown" ) then
		IsTTT = true
	end
end )

function ENTITY:KillVelocity()
	self:SetVelocityInstantaneous( vector_origin )

	if self.IsPlayer and self:IsPlayer() and has.EffectPlayers:GetBool() then
		self:SetVelocity(self:GetVelocity()*-1)
	end
	
	for i = 0, self:GetPhysicsObjectCount() - 1 do
		local subphys = self:GetPhysicsObjectNum( i )
		if ( IsValid( subphys ) ) then
			subphys:EnableMotion( false )
			subphys:SetMass( subphys:GetMass() * 20 )
			subphys:SetVelocity( vector_origin )
			subphys:Sleep()
			subphys:RecheckCollisionFilter() -- MAKE SURE it knows
		end
	end
	
	self:CollisionRulesChanged()
end

function ENTITY:EnableVelocity()
	for i = 0, self:GetPhysicsObjectCount() - 1 do
		local subphys = self:GetPhysicsObjectNum( i )
		if ( IsValid( subphys ) ) then
			subphys:SetMass( subphys:GetMass() / 20 )
			subphys:EnableMotion( true )
			subphys:Wake()
			subphys:RecheckCollisionFilter()
		end
	end
	
	self:CollisionRulesChanged()
end

local function IdentifyCorpse( ent )
	if ( not IsValid( ent ) or not CORPSE or not CORPSE.GetFound or CORPSE.GetFound( ent, false ) ) then return end -- Thanks no ragdoll metatable
	
	local dti = CORPSE.dti
	local ply = ent:GetDTEntity( dti.ENT_PLAYER ) or player.GetByUniqueID( ent.uqid )
	local nick = CORPSE.GetPlayerNick( ent, nil ) or ply:Nick() or "N/A"
	local role = ent.was_role or ( ply.GetRole and ply:GetRole() ) or ROLE_INNOCENT
	
	if ( IsValid( ply ) ) then
		ply:SetNWBool( "body_found", true )
		if ( role == ROLE_TRAITOR ) then
			SendConfirmedTraitors( GetInnocentFilter( false ) )
		end
	end
	
	local bodyfound = true
	
	if ( IsValid( GetConVar( "ttt_announce_body_found" ) ) ) then
		bodyfound = GetConVar( "ttt_announce_body_found" ):GetBool()
	end
	
	local roletext = "body_found_i"
	
	if ( bodyfound ) then
		if ( role == ROLE_TRAITOR ) then
			roletext = "body_found_t"
		elseif ( role == ROLE_DETECTIVE ) then
			roletext = "body_found_d"
		end
		
		LANG.Msg( "body_found", { finder = "The Server", victim = nick, role = LANG.Param( roletext ) } )
	end
	
	CORPSE.SetFound( ent, true )
	
	if ( ent.kills ) then
		for _, vicid in pairs( ent.kills ) do
			local vic = player.GetByUniqueID( vicid )
			if ( IsValid( vic ) and not vic:GetNWBool( "body_found", false ) ) then
				LANG.Msg( "body_confirm", { finder = "The Server", victim = vic:Nick() or vic:GetClass() } )
				vic:SetNWBool( "body_found", true )
			end
		end
	end
end

local UnreasonableEnts =
{
	[ "prop_physics" ] = true,
	[ "prop_ragdoll" ] = true
}

local EntList = {}
local EntIDs = {}

hook.Add( "OnEntityCreated", "GS - Create Soft Entity List", function( ent )
	if not APA.Settings.AntiCrash:GetBool() then return end
	if ( not ( ent:IsValid() and UnreasonableEnts[ ent:GetClass() ] )) then return end
	
	EntIDs[ ent:EntIndex() ] = table.insert( EntList, ent )
end )

hook.Add( "EntityRemoved", "GS - Remove Soft Entity List", function( ent )
	if not APA.Settings.AntiCrash:GetBool() then return end
	local index = table.remove( EntIDs, ent:EntIndex() )
	
	if ( not index ) then
		return -- OnEntityCreated wasn't called
	end
	
	EntList[ index ] = nil
end )

if ( has.VelocityHook:GetBool() or has.UnreasonableHook:GetBool() ) then
	local NextThink = 0
	
	hook.Add( "Think", "GS - Check Velocity", function()
		if not APA.Settings.AntiCrash:GetBool() then return end
		if ( NextThink > CurTime() ) then return end
		
		NextThink = CurTime() + has.ThinkDelay:GetInt()
		
		local pos
		local velo
		local nick
		local ent
		local rMessage = "[GS] Removed %s (ID: %i) for moving too fast"
		local fMessage = "[GS] Froze %s (ID: %i) for moving too fast"
		local nMessage = "[GS] Removed %s (ID: %i) for having a nan position"
		local veloMessage = " (%f)\n"
		local tempMessage
		local nickString = "nick" -- Don't run StringBuilder everytime
		
		for i = 0, #EntList do
			ent = EntList[i]
			if ( IsValid( ent ) ) then
				if ( has.UnreasonableHook:GetBool() ) then
					--[[local ang = ent:GetAngles() -- Need to do some more testing before I want to check for these
					if ( not util.IsReasonable( ang ) ) then
						ent:SetAngles( ang.p % 360, ang.y % 360, ang.r % 360 )
					end]]
					
					pos = ent:GetPos()
					
					if ( isnan( pos:Length() ) or not util.IsReasonable( pos ) ) then
						tempMessage = string.format( nMessage, nick, ent:EntIndex() )
						ServerLog( tempMessage )
						if ( has.EchoRemove:GetBool() ) then
							PrintMessage( HUD_PRINTTALK, tempMessage )
						end
						
						ent:KillVelocity() -- Just in-case remove doesn't fully kill it

						if not (ent.IsPlayer and ent:IsPlayer()) then
							ent:Remove() -- Just remove the entity, no use trying to find somewhere to put them
						elseif has.EffectPlayers:GetBool() then
							ent:SetPos(vector_origin)
							ent:KillSilent()
						end

						continue -- We're done here
					end
				end
				
				if ( has.VelocityHook:GetBool() ) then
					velo = ent:GetVelocity():Length()
					
					if ( velo >= has.RemoveSpeed:GetInt() ) then
						nick = ent:GetNWString( nickString, ent:GetClass() )
						if ( IsTTT ) then
							IdentifyCorpse( ent )
						end
						
						tempMessage = string.format( rMessage, nick, ent:EntIndex() )
						ServerLog( tempMessage .. string.format( veloMessage, velo ) )
						if ( has.EchoRemove:GetBool() ) then
							PrintMessage( HUD_PRINTTALK, tempMessage )
						end
						
						ent:KillVelocity()
						ent:Remove()
					elseif ( velo >= has.FreezeSpeed:GetInt() ) then
						nick = ent:GetNWString( nickString, ent:GetClass() )
						ent:KillVelocity()
						timer.Simple( has.FreezeTime:GetInt(), function() 
							if ( IsValid( ent ) ) then 
								ent:EnableVelocity() 
							end 
						end )
						
						tempMessage = string.format( rMessage, nick, ent:EntIndex() )
						ServerLog( tempMessage .. string.format( veloMessage, velo ) )
						if ( has.EchoFreeze:GetBool() ) then
							PrintMessage( HUD_PRINTTALK, tempMessage )
						end
					end
				end
			else
				EntList[i] = nil -- Entity is now invalid, but it didn't call EntityRemoved for some reason
				EntIDs[i] = nil
			end
		end
	end )
end

function util.IsReasonable( struct )
	--if ( isvector( struct ) ) then
		if( struct.x >= MAX_REASONABLE_COORD or struct.x <= MIN_REASONABLE_COORD or 
			struct.y >= MAX_REASONABLE_COORD or struct.y <= MIN_REASONABLE_COORD or 
			struct.z >= MAX_REASONABLE_COORD or struct.y <= MIN_REASONABLE_COORD ) then
			return false
		end
	--[[elseif ( isangle( struct ) ) then
		if( struct.p >= MAX_REASONABLE_ANGLE or struct.p <= MIN_REASONABLE_ANGLE or 
			struct.y >= MAX_REASONABLE_ANGLE or struct.y <= MIN_REASONABLE_ANGLE or 
			struct.r >= MAX_REASONABLE_ANGLE or struct.r <= MIN_REASONABLE_ANGLE ) then
			return false
		end
	else
		error( string.format( "Invalid data type sent into util.IsReasonable ( Vector or Angle expected, got %s )", type( struct ) ) )
	end]]
	
	return true
end

function ents.GetUnreasonables()
	return EntList
end

function isnan( num )
	-- NaN can't ever be equal to itself; thanks Meepen and MetaMan!
	return num ~= num
end

-- Add as Plugin --
APA.initPlugin('anticrash')