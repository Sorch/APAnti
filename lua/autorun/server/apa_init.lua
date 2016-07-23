if not SERVER then return end if CLIENT then return end
APA = (APA and APA.Settings) and APA or {Settings = {}} -- Do not remove.
local defaults = defaults or {}

APA.Settings = {
	--- Base AntiPK ---
	AntiPK 					= {1, "Setting this to 1 will enable Anti Prop Kill."},
	Debug 					= {0, "Setting this to 1 will enable Debug Output. Setting this to 2 will log the output. (Warning: This command is spammy!)"},
	PhysgunNerf 			= {1, "Setting this to 1 will limit the physgun speed."},
	BlockVehicleDamage 		= {1, "Setting this to 1 will stop vehicle damage."},
	BlockExplosionDamage 	= {1, "Setting this to 1 will block explosion damage."},
	BlockWorldDamage 		= {0, "Setting this to 1 will block world damage."},
	BlockPropDamage 		= {0, "Setting this to 1 will always block \"prop_\" damage."},
	KillOwnership 	 		= {0, "Setting this to 1 will reward kills for \"prop_\" damage based on the props owner. (Warning: Due to possible entropy this may not be accurate!)"},
	Method 					= {0, "Setting this to 1 will use the Blacklist, setting it to 0 will predict."},
	PropsOnly 				= {0, "Setting this to 1 will effect only \"prop_\" classes."},
	BadTime 				= {0.15, "How long (in seconds) does an entity have to wait to become \"good\" and be able to do damage again. (Minimum is 0.15)"},
	--- Prop Control ---
	UnbreakableProps 		= {0, "Setting this to 1 will make props unbreakable."},
	NoCollideVehicles 		= {1, "Setting this to 1 will make vehicles not collide with players."},
	AnnoySurf 		 		= {1, "Setting this to 1 will make prop surf annoying."},
	NoThrow					= {0, "Setting this to 1 will stop people from throwing props."},
	MaxMass 				= {1500, "This is the max weight a /spawned/ object may have. Minimum is 1, 0 Disables."},
	--- Freezing ---
	StopMassUnfreeze		= {1, "Setting this to 1 will stop people from unfreezing all their props by double tapping R."},
	StopRUnfreeze			= {0, "Setting this to 1 will stop people from unfreezing props by tapping R."},
	FreezeOnHit 			= {1, "Setting this to 1 will freeze props when they hit a player. (Needs AntiPK.)"},
	FreezeOnDrop 			= {0, "Setting this to 1 will freezes props when a player lets go of them."},
	FreezeOnUnghost			= {1, "Setting this to 1 will freeze props when they unghost."},
	FreezePassive			= {0, "Setting this to 1 will freeze props passivly."},
	--- Ghosting ---
	GhostPickup 			= {0, "Setting this to 1 will enable ghost props on pickup."},
	GhostSpawn				= {0, "Setting this to 1 will enable ghosting on spawn."},
	GhostFreeze				= {0, "Setting this to 1 will freeze ghosts."},
	UnGhostPassive			= {0, "Setting this to 1 will passivly unghost props. (Needs AntiPush.)"},
	GhostsNoCollide			= {0, "Setting this to 1 will make ghosts nocollide with everything."},
}

APA.Settings.L = {
	Freeze = {"prop_physics", "gmod_button", "gmod_", "lawboard", "light", "lamp", "jail", "wire"},
	Black  = {"prop_physics", "gmod_", "money", "printer", "cheque", "light", "lamp", "wheel", "playx", "radio", "lawboard", "fadmin", "jail", "prop", "wire", "media"},
	White  = {"player", "npc", "weapon", "knife", "grenade", "prop_combine_ball", "npc_tripmine", "npc_satchel", "prop_door_", "trigger_", "env_"},
	Damage = { DMG_CRUSH, DMG_SLASH, DMG_CLUB, DMG_DIRECT, DMG_PHYSGUN, DMG_VEHICLE }
}

---------------------------------------------------------

local include = include
local function plugin(a)
	local a = tostring(a)
	MsgN('> '..a:gsub('^%l',string.upper))
	include('modules/apa/'..a..'.lua')
end

APA.Settings.M = APA.Settings.M or {}
for k,v in next, APA.Settings do -- Build Cvars.
	if k ~= 'L' and k ~= 'M' then
		APA.Settings[k] = CreateConVar(string.lower("apa_"..tostring(k)), v[1], {FCVAR_DEMO, FCVAR_GAMEDLL, FCVAR_SERVER_CAN_EXECUTE, FCVAR_NOTIFY}, v[2])
		defaults[k] = {string.Replace(tostring(v[1]), ".00", ""), v[2]}
	end
end

APA.hasCPPI = CPPI and CPPI.GetVersion and CPPI.GetVersion() and true or false

function APA.initPlugin(plugin)
	local plugin = tostring(plugin)
	timer.Simple(0, function()
		APA.Settings.M = APA.Settings.M or {}
		APA.Settings.M[plugin:gsub('^%l',string.upper)] = true
	end)
end

cvars.AddChangeCallback(APA.Settings.PhysgunNerf:GetName(), function( v, o, n )
	APA.physgun_maxSpeed = APA.physgun_maxSpeed or GetConVar("physgun_maxSpeed"):GetInt()
	if tobool(n) then 
		RunConsoleCommand("physgun_maxSpeed", "975") 
	else
		RunConsoleCommand("physgun_maxSpeed", tostring(APA.physgun_maxSpeed))
	end
end)

cvars.AddChangeCallback(APA.Settings.AntiPK:GetName(), function(v, o, n)
	if not tobool(n) then
		for _,v in next, player.GetAll() do
			if IsValid(v) and (v:IsAdmin() or v:IsSuperAdmin()) then
				APA.Notify(v, "WARNING: APAnti Disabled!", NOTIFY_ERROR, 3.5, 1)
			end
		end
	end
end)

hook.Add("PostGamemodeLoaded", "APAntiLOAD", function()
	MsgN("          _____              _   _ ")
	MsgN("    /\\   |  __ \\ /\\         | | (_)")
	MsgN("   /  \\  | |__) /  \\   _ __ | |_ _ ")
	MsgN("  / /\\ \\ |  ___/ /\\ \\ | '_ \\| __| |")
	MsgN(" / ____ \\| |  / ____ \\| | | | |_| |")
	MsgN("/_/    \\_\\_| /_/    \\_\\_| |_|\\__|_|")
	MsgN("-         -          -   Loading...")
	APA.hasCPPI = CPPI and CPPI.GetVersion and CPPI.GetVersion() and true or false
	if not APA.hasCPPI then
		MsgC( Color(255, 0, 0), "\n\n---------------------------------------------------------------") 
		MsgC( Color( 255, 0, 0 ), "\n| [APA] ERROR: CPPI not found, Prop Protection not installed? |")
		MsgC( Color(255, 0, 0), "\n---------------------------------------------------------------\n")
		ErrorNoHalt("[APA] CPPI not found, APAnti will be heavily limited.")  MsgN("\n") 
	end

	include('sv_apanti.lua')

	timer.Simple(0, function()
		if APA.Settings.PhysgunNerf:GetBool() then
			APA.physgun_maxSpeed = APA.physgun_maxSpeed or GetConVar("physgun_maxSpeed"):GetInt() 
			RunConsoleCommand("physgun_maxSpeed", "950") 
		end

		MsgN('\n-------------------------')
		MsgN('|APAnti - Plugins Called|')
		APA.Settings.M = APA.Settings.M or {}
		local plugins, _ = file.Find('modules/apa/*.lua','LUA')
		for _,v in next, plugins do
			if v then
				v = string.gsub(tostring(v),'%.lua','')
				APA.Settings.M[v:gsub('^%l',string.upper)] = false
				plugin(v)
			end
		end
		MsgN('|APAnti - Plugins Loaded|')
		MsgN('-------------------------')
		MsgN('APAnti is ready to go!')
	end)
end)

util.AddNetworkString("APAnti AlertNotice")

function APA.Notify(ply, str, ctype, time, alert, moreinfo)
	if alert >= 1 or tobool(alert) then alert = 1 end

	if not IsValid(ply) then return end
	if not (ply.IsPlayer and ply:IsPlayer()) then return end
	if not str then return end
	if not ctype then ctype = 1 end

	str,ctype,time,alert = tostring(str),tonumber(ctype),tonumber(time),tonumber(alert)

	if moreinfo then
		for k,v in next, moreinfo do if( type(v) != "string" ) then moreinfo[k] = nil end end
	else moreinfo = {} end

	net.Start("APAnti AlertNotice")
		net.WriteString(str)
		net.WriteFloat(ctype)
		net.WriteFloat(time)
		net.WriteFloat(alert)
		net.WriteTable(moreinfo)
	net.Send(ply)
end

local shortcut_help = [[
APAnti Shortcut Commands

"apa help" 		= Info about all commands.
"apa nolag" 	= Quickly freeze all entities.
"apa default" 	= Restore defaults.
]]

concommand.Add("apa", function( ply, cmd, _, argStr )
	if argStr == "help" then
		print("Help and update notes can be found here...","https://github.com/LuaTenshi/APAnti/blob/TEST/README.md")
	elseif argStr == "nolag" then
		APA.NoLag()
		print('[APA] Freezing entities...')
	elseif argStr == "default" then
		for k,v in next, defaults do
			RunConsoleCommand("apa_"..k,v[1])
		end
	else
		print(shortcut_help)
	end
end, 
function() return {"apa help", "apa nolag", "apa default"} end, shortcut_help, 
{FCVAR_DEMO, FCVAR_GAMEDLL, FCVAR_SERVER_CAN_EXECUTE})