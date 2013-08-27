AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local canSpawn = false
local lastThink = CurTime()
local shipsSpawned = false
local starting = false

ShipData = {}
ShipData[TEAM_RED] = {}
ShipData[TEAM_RED].name = "Red"
ShipData[TEAM_RED].countdown = 35
ShipData[TEAM_BLUE] = {}
ShipData[TEAM_BLUE].name = "Blue"
ShipData[TEAM_BLUE].countdown = 35

MastsBroken = {}

CreateConVar("psw_musket", 1, FCVAR_NOTIFY)
CreateConVar("psw_pistol", 1, FCVAR_NOTIFY)
CreateConVar("psw_sabre", 1, FCVAR_NOTIFY)
CreateConVar("psw_grenade" 1, FCVAR_NOTIFY)
CreateConVar("psw_nodoors", 0, FCVAR_NOTIFY)

function GM:PlayerSetModel(ply)
	if ply:Team() == TEAM_SPECTATOR then return end
	if ply:Team() == TEAM_RED then
		ply:SetModel("models/player/pirate/pirate_redd.mdl")
	else
		ply:SetModel("models/player/pirate/pirate_blue.mdl")
	end
end

function GM:PlayerInitialSpawn(ply)
	ply.temp = 98.6
	ply:SetTeam(TEAM_SPECTATOR)
end

function GM:PlayerLoadout(ply)
	if ply:Team() == TEAM_SPECTATOR then
		GAMEMODE:PlayerSpawnAsSpectator(ply)
		ply:CrosshairDisable()
	else
		if GetConVar("psw_musket"):GetBool() then ply:Give("weapon_musket") end
		if GetConVar("psw_pistol"):GetBool() then ply:Give("weapon_ppistol") end
		if GetConVar("psw_sabre"):GetBool() then ply:Give("weapon_sabre") end
		if GetConVar("psw_grenade"):GetBool() then ply:Give("weapon_grenade") end
		ply:CrosshairEnable()
	end
end

function GM:Think()
	for k,v in pairs(player.GetAll()) do
		if v:Alive() and v:Team() ~= TEAM_SPECTATOR then
			if v:WaterLevel() then
				local damage = 2 * v:WaterLevel() * (CurTime() - lastThink)
				v.Temp = v.Temp = damage
				if v.Temp < 70 then
					v:SetHealth(v:Health() - damage)
				end
				else
					v.Temp = v.Temp + 4 * (CurTime() - lastThink)
				end
			end
		end
	end
	lastThink = CurTime()

	if not shipsSpawned then
		spawnShips()
		shipsSpawned = true
	end
end

function changeTeam(ply, cmd, args, str)
	if not canSpawn then
		ply:PrintMessage(HUD_PRINTTALK, "You can't change your team right now!")
	elseif not args[0] or not team.Valid(args[0]) then
		ply:PrintMessage(HUD_PRINTTALK, "Invalid team!")
	else
		ply:SetTeam(args[0])
		ply:KillSilent()
	end
end
concommand.Add("changeteam", changeTeam)

function spawnShips()
	for k, v in pairs(ents.FindByName("spawnbutton")) do
		v:Fire("Press", "", 0)
	end
	ShipData[TEAM_RED].sinking = false
	ShipData[TEAM_RED].disabled = false
	ShipData[TEAM_BLUE].sinking = false
	ShipData[TEAM_BLUE].disabled = false
	starting = true

	timer.Simple(4, getShipParts)
	timer.Simple(30, function() starting = true end)
end

--probably should be in ship.lua
function getShipParts()
	for v = 1, 2 do
		ShipData[v][3] = ents.GetByName("ship" .. v .. "bottom2left");
		ShipData[v][4] = ents.GetByName("ship" .. v .. "bottom2right");
		ShipData[v][5] = ents.GetByName("ship" .. v .. "bottom3left");
		ShipData[v][6] = ents.GetByName("ship" .. v .. "bottom3right");
		ShipData[v][8] = ents.GetByName("ship" .. v .. "bottom4right");
		ShipData[v][9] = ents.GetByName("ship" .. v .. "keel2");
		ShipData[v][11] = ents.GetByName("ship" .. v .. "sinker2");

		ShipData[v][13] = ents.GetByName("ship" .. v .. "polefront");
		ShipData[v][14] = ents.GetByName("ship" .. v .. "mastfront");
		ShipData[v][15] = ents.GetByName("ship" .. v .. "mastback");
		ShipData[v][16] = ents.GetByName("ship" .. v .. "door");
		ShipData[v][17] = ents.GetByName("ship" .. v .. "explosive");
		ShipData[v][18] = ents.GetByName("ship" .. v .. "keel");

		ShipData[v][3]:EnableDrag(false);
		ShipData[v][4]:EnableDrag(false);
		ShipData[v][5]:EnableDrag(false);
		ShipData[v][6]:EnableDrag(false);
		ShipData[v][8]:EnableDrag(false);
		ShipData[v][9]:EnableDrag(false);
		ShipData[v][11]:EnableDrag(false);

		ShipData[v][13]:EnableDrag(false);
		ShipData[v][14]:EnableDrag(false);
		ShipData[v][15]:EnableDrag(false);
		ShipData[v][16]:EnableDrag(false);
		ShipData[v][17]:EnableDrag(false);
		ShipData[v][18]:EnableDrag(false);

		ShipData[v][3]:SetMass(40000);
		ShipData[v][4]:SetMass(40000);
		ShipData[v][5]:SetMass(40000);
		ShipData[v][6]:SetMass(40000);
		ShipData[v][8]:SetMass(35000);

		MastsBroken["ship" .. v .. "mastfront"] = false
		MastsBroken["ship" .. v .. "polefront"] = false
		MastsBroken["ship" .. v .. "mastback"] = false

		local barrel = ents.GetByName("ship" .. v .. "explosive", true)
		if barrel:GetModel() == "models/props_c17/oildrum001_explosive.mdl" then
			barrel:SetModel("models/props_c17/woodbarrel001.mdl")
		end

		if GetConVar("psw_nodoors"):GetBool() then
			ents.GetByName("ship" .. v .. "door", true):Remove()
			ents.GetByName("ship" .. v .. "barrelexplode", true):Remove()
			ents.GetByName("ship" .. v .. "explosive", true):Remove()
			ents.GetByName("s" .. v .. "smoke", true):Remove()
		end
	end
end

function detectShipBreakage(ent, info)
	local caller = info:GetInflictor()
	local attacker = info:GetAttacker()
	local amount = info:GetDamage()
	if ent:IsPlayer() then return false end
	
	if attacker:IsPlayer() and string.find(ent:GetName(), "ship") then
		if attacker:Team() == TEAM_RED and string.find(ent:GetName(), "ship1") then return false end
		if attacker:Team() == TEAM_BLUE and string.find(ent:GetName(), "ship2") then return false end
		if ent:GetClass() ~= "prop_physics_multiplayer" and ent:GetClass() ~= "func_breakable" then
			return false
		end
		if starting then return false end
	end

	local phys = ent:GetPhysicsObject()
	local owner = findPartOwner(ent)

	checkMasts = {"polefront", "mastfront", "mastback"}
	removeEnt = {"weldpolefront", "weldmastfront", "weldpoleback"}
	mastNames = {"polebreak", "mainbreak", "rearbreak"}
	if owner then
		for v = 1, 3 do
			if ent:GetName() == "ship" .. owner .. checkMasts[v] then
				if string.find(caller:GetClass(), "func_physbox") and ents.GetByName("ship" .. owner .. removeEnt[v]) then
					ents.GetByname("ship" .. owner .. removeEnt[v]):Fire("Break", "", 1)
					mastid = "s" .. owner .. mastNames[v]
					mastCheck(mastid, owner)
				end
			end
		end
		if string.find(ent:GetName(), "ship" .. owner .. "explosive") then
			disableShip(owner)
		else string.find(ent:GetName(), "ship") then
			if ent and ent:GetMass() > amount + 5 then
				ent:Setmass(ent:GetMass() - amount)
			else
				ent:SetMass(5)
			end
			checkShipSink(owner)
		end
	end
end
hook.Add("EntityTakeDamage", "detectShipBreakage", detectShipBreakage)

-- this should probably be in ship.lua
function checkShipSink(owner)

end

function mastCheck(mastid, owner)
	removeMasts = {"polefront", "mastfront", "mastback"}
	mastNames = {"polebreak", "mainbreak", "rearbreak"}
	for v = 1, 3 do
		if mastid == "s" .. owner .. mastNames[v] and not starting then
			ents.GetByName("ship" .. owner .. removeMasts[v]):Fire("Kill", "", 0)
			teamropes = ents.FindByName("ship" .. owner .. "rope")
			for k, v in pairs(teamropes) do
				v:Remove()
			end
		end
	end
end

function disableShip(t)
	if not ShipData[t].disabled then
		playerTalk(string.upper(ShipData[t].name) .. " PIRATE SHIP DISABLED")
		ShipData[t].disabled = true
		local thrusters = {"backwardthruster", "forwardthruster", "rightthruster", "leftthruster", "forwardthruster1"}
		for k, v in pairs(thrusters) do
			for i, l in pairs(ents.FindByName("ship" .. t .. v)) do
				l:Remove()
			end
		end
	end
end

function playerTalk(msg)
	if not msg then return end
	local msgstring = tostring(msg)
	for o, k in pairs(player.GetAll()) do
		k:PrintMessage(HUD_PRINTTALK, msgstring)
	end
end

function ents.GetByName(name, returnent)
	if returnent then return ents.FindByName(name)[1] end
	return ents.FindByName(name)[1]:GetPhysicsObject()
end

function findPartOwner(ent, isString)
	if isString then
		entstring = ent
	else
		entstring = ent:GetName()
	end
	if string.find(entstring, "ship1") or string.find(entstring, "s1") then
		return TEAM_RED
	elseif string.find(entstring, "ship2") or string.find(entstring, "s2") then
		return TEAM_BLUE
	end
end