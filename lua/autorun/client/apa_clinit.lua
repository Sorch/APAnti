local function escape(s) return tostring(s):gsub( "%%", "<p>" ) end

local mat = CreateMaterial( "APAGhostMaterial", "VertexLitGeneric", {
	["$basetexture"] = "models/debug/debugwhite", ["$model"] = 1, 
	["$color"] = "{ 0 0 0 }", ["$alpha"] = "0.72",
	["$color2"] = "{ 0 0 0 }"
});

local NoticeMaterial = NoticeMaterial or {}
NoticeMaterial[ NOTIFY_GENERIC ]	= Material( "vgui/notices/generic" )
NoticeMaterial[ NOTIFY_ERROR ]		= Material( "vgui/notices/error" )
NoticeMaterial[ NOTIFY_UNDO ]		= Material( "vgui/notices/undo" )
NoticeMaterial[ NOTIFY_HINT ]		= Material( "vgui/notices/hint" )
NoticeMaterial[ NOTIFY_CLEANUP ]	= Material( "vgui/notices/cleanup" )

local baramount = 0
local function Notify( text, type, time )
	local bars = vgui.Create( "DPanel" )
	local l = (string.len(text)*10)+42

	baramount = baramount < 3 and (baramount + 1) or 1

	bars:SetPos(ScrW()+l, 20)
	bars:SetSize(l, 40)

	local tri = {
		{ x = 35, y = 40 },
		{ x = 35, y = 0 },
		{ x = 50, y = 20 }
	}

	bars.Paint = function()
		draw.RoundedBox(0, 0, 0, l, ScrH(), Color(70,70,70,255))
		draw.DrawText( text, "GModNotify", 60, 12, Color(255,255,255,255), TEXT_ALIGN_LEFT )
		
		local col = Color(0,0,0,255)
		draw.RoundedBox(0, 0, 0, 35, ScrH(), col)
		surface.SetDrawColor(col.r, col.g, col.b, col.a)
		draw.NoTexture()
		surface.DrawPoly( tri )
	end

	local img = vgui.Create( "DImageButton", bars )
	img:SetMaterial( NoticeMaterial[type] )
	img:SetSize( 32, 32 )
	img:Dock( LEFT )
	img:DockMargin( 5, 5, 15, 5 )

	img.DoClick = function() end
	img:SizeToContents()

	-- surface.PlaySound("buttons/lightswitch2.wav")
	local pos = baramount > 1 and (20+(21*baramount)) or 20
	bars:MoveTo(ScrW()-l, pos, 0.7, 0, -1, function()
		bars:MoveTo(ScrW()+300, pos, 0.5, time, -1, function() 
			bars:Remove()
			baramount = baramount > 0 and (baramount - 1) or 0
		end)
	end)
end

net.Receive("APAnti AlertNotice", function()
	local a,b,c,d,e = "",0,0,0,{}

	a = net.ReadString()
	b = net.ReadFloat() or 1
	c = net.ReadFloat() or 2
	d = net.ReadFloat() or 0
	e = net.ReadTable() or {}

	if not a then return end
	a = string.format(escape(a))

	-- notification.AddLegacy( a, b, c )
	Notify( a, b, c )
	
	if e and e ~= {} then
		if e[1] and e[2] then
			for k,v in next, e do e[k] = escape(e[k]) end
			MsgC(Color( 255, 0, 0 ), string.format("Your prop, %s is being obstructed by %s\n", e[1], e[2]))
		end
	end

	if d >= 1 or tobool(d) then
		surface.PlaySound("ambient/alarms/klaxon1.wav")
	end
end)