-- Reliable Jaw Stab in-game test (pzt TEST_FILES only, not shipped). One client, every scenario.
-- RJSTest.start() runs the scenarios as a coroutine on OnTick; RJSTest.poll() re-queues itself until done.
-- Results: "[RJSTest] PASS/FAIL/INFO" lines; failures also "[PZTest] FAIL". No error() (debugger freezes).
-- Single player only: the multiplayer drift is imitated by moving the zombie after the jaw stab starts.

RJSTest = RJSTest or {}
local T = RJSTest
local M = function() return ReliableJawStab end

local function log(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
	print("[RJSTest] " .. table.concat(parts, " "))
end

local function check(ok, label, extra)
	if ok then T.pass = T.pass + 1 else T.fail = T.fail + 1 end
	log(ok and "PASS" or "FAIL", T.scenario or "", label, extra ~= nil and tostring(extra) or "")
	if not ok and PZTest and PZTest.fail then PZTest.fail("RJSTest " .. tostring(T.scenario) .. " " .. label .. " " .. tostring(extra or "")) end
	return ok
end

local function p() return getPlayer() end
local function yield() coroutine.yield() end
local function waitTicks(n) for _ = 1, n do yield() end end

-- protected test character, re-set every frame while the test runs
local function protect(on)
	local pl = p()
	if not pl then return end
	pl:setGodMod(on)
	pl:setInvisible(on)
	pl:setZombiesDontAttack(on)
	if pl.setGhostMode then pl:setGhostMode(on) end
end

local function clearZombies()
	local pl = p()
	local list = getCell():getZombieList()
	for i = list:size() - 1, 0, -1 do
		local z = list:get(i)
		if z and z:DistTo(pl) < 60 then z:removeFromSquare(); z:removeFromWorld() end
	end
end

local function spawnZombie(dx, dy)
	local pl = p()
	local list = addZombiesInOutfit(math.floor(pl:getX()) + dx, math.floor(pl:getY()) + dy, math.floor(pl:getZ()), 1, nil, 50)
	if list and list:size() > 0 then return list:get(0) end
	return nil
end

local function place(o, x, y)
	o:setX(x); o:setY(y); o:setLastX(x); o:setLastY(y); o:setNextX(x); o:setNextY(y)
	o:setCurrentSquareFromPosition()
end

local function dist(a, b)
	local dx, dy = a:getX() - b:getX(), a:getY() - b:getY()
	return math.sqrt(dx * dx + dy * dy)
end

------------------------------------------------------------------ scenarios

local function sIsJawStab()
	T.scenario = "isJawStab"
	local pl = p()
	local knife = instanceItem("Base.HuntingKnife")
	local saved = pl:getVariableString("ZombieHitReaction")
	pl:setCriticalHit(true)
	pl:setVariable("ZombieHitReaction", "KnifeDeath")
	check(M().isJawStab(pl, knife) == true, "crit + KnifeDeath + knife")
	check(M().isJawStab(pl, nil) == false, "no weapon")
	pl:setCriticalHit(false)
	check(M().isJawStab(pl, knife) == false, "no crit")
	pl:setCriticalHit(true)
	pl:setVariable("ZombieHitReaction", "Uppercut")
	check(M().isJawStab(pl, knife) == false, "other hit reaction")
	pl:setCriticalHit(false)
	pl:setVariable("ZombieHitReaction", saved or "")
end

-- one real jaw stab from behind. drift = nil: zombie stays; drift = {dx, dy}: once the jaw stab has
-- started (ZombieHitReaction=KnifeDeath, before the hit point), the zombie is moved by (dx, dy) relative
-- to the player, the way a multiplayer correction moves it on the client.
-- Returns started (a jaw stab played), dead, knifeDeath, moves made by the mod.
local function jawStab(drift)
	local pl = p()
	clearZombies()
	waitTicks(5)
	local z = spawnZombie(2, 0)
	if not z then check(false, "zombie spawned"); return false end
	local knife = instanceItem("Base.HuntingKnife")
	pl:getInventory():AddItem(knife)
	pl:setPrimaryHandItem(knife)
	pl:setSecondaryHandItem(nil)
	waitTicks(20)
	-- zombie faces east, player stands 0.45 behind it (west), facing east
	local zx, zy = math.floor(pl:getX()) + 2.5, math.floor(pl:getY()) + 0.5
	place(z, zx, zy)
	z:setDir(IsoDirections.E)
	z:setTarget(nil)
	place(pl, zx - 0.45, zy)
	pl:setDir(IsoDirections.E)
	pl:faceThisObject(z)
	waitTicks(10)
	pl:setVariable("ZombieHitReaction", "")
	local movesBefore = M().moves
	local ok, err = pcall(function() pl:DoAttack(0) end)
	if not ok then log("INFO DoAttack error", err) end
	local started, moved = false, false
	for _ = 1, 150 do
		yield()
		if not started and pl:getVariableString("ZombieHitReaction") == "KnifeDeath" then started = true end
		if started and drift and not moved and not z:isDead() then
			place(z, pl:getX() + drift[1], pl:getY() + drift[2])
			moved = true
			log("INFO drifted zombie to d=" .. string.format("%.2f", dist(pl, z)))
		end
		if z:isDead() then break end
	end
	waitTicks(30)
	local dead, kd = z:isDead(), z:isKnifeDeath()
	local moves = M().moves - movesBefore
	log("INFO result started=" .. tostring(started) .. " dead=" .. tostring(dead) .. " knifeDeath=" .. tostring(kd) .. " modMoves=" .. moves)
	pl:setPrimaryHandItem(nil)
	pl:getInventory():clear()
	return started, dead, kd, moves
end

-- run one case until a jaw stab actually plays (a crit is not guaranteed every swing)
local function tryJawStab(drift, label)
	for attempt = 1, 6 do
		local started, dead, kd, moves = jawStab(drift)
		if started then return true, dead, kd, moves end
		log("INFO " .. label .. ": no jaw stab on attempt " .. attempt)
	end
	check(false, label .. ": a jaw stab played")
	return false
end

local function sNoDrift()
	T.scenario = "noDrift"
	M().enabled = true
	local started, dead, kd, moves = tryJawStab(nil, "no drift")
	if not started then return end
	check(dead and kd, "zombie killed by the jaw stab", tostring(dead) .. "/" .. tostring(kd))
	check(moves == 0, "mod did not move a zombie in reach", moves)
end

-- 1.1 tiles to the side: outside MaxRange 0.9 and outside the swing angle
local SIDE = { 0.0, 1.1 }

local function sDriftVanilla()
	T.scenario = "driftVanilla"
	M().enabled = false
	local started, dead, kd, moves = tryJawStab(SIDE, "drift, mod off")
	M().enabled = true
	if not started then return end
	-- this is the bug: the jaw stab plays but the drifted zombie is not hit
	check(not dead, "vanilla misses the drifted zombie (bug reproduced)", tostring(dead))
	check(moves == 0, "mod off made no move", moves)
end

local function sDriftFixed()
	T.scenario = "driftFixed"
	M().enabled = true
	local started, dead, kd, moves = tryJawStab(SIDE, "drift, mod on")
	if not started then return end
	check(moves == 1, "mod put the zombie back once", moves)
	check(dead and kd, "drifted zombie killed by the jaw stab", tostring(dead) .. "/" .. tostring(kd))
end

-- too far: 2.0 tiles is beyond REACH, the mod leaves it
local function sTooFar()
	T.scenario = "tooFar"
	M().enabled = true
	local started, dead, kd, moves = tryJawStab({ 0.0, 2.0 }, "too far")
	if not started then return end
	check(moves == 0, "zombie beyond REACH not moved", moves)
	check(not dead, "zombie beyond REACH not killed", tostring(dead))
end

------------------------------------------------------------------ driver

local function run()
	T.pass, T.fail = 0, 0
	local pl = p()
	pl:getInventory():clear()
	check(M() ~= nil and M().registered, "mod loaded")
	local ok, err = pcall(sIsJawStab)
	if not ok then check(false, "isJawStab ran", err) end
	sNoDrift()
	sDriftVanilla()
	sDriftFixed()
	sTooFar()
	clearZombies()
	pl:getInventory():clear()
	M().enabled = true
end

function T.start()
	T.done = false
	T.co = coroutine.create(function()
		run()
		T.done = true
	end)
	log("start")
end

function T.poll()
	if T.done then
		protect(false)
		log("RESULT pass=" .. tostring(T.pass) .. " fail=" .. tostring(T.fail))
		if PZTest and PZTest.log then PZTest.log("RJSTest done pass=" .. T.pass .. " fail=" .. T.fail) end
	else
		PZTest.step("wait 60")
		PZTest.step("lua RJSTest.poll()")
	end
end

local function onTick()
	if not T.co then return end
	protect(true)
	if coroutine.status(T.co) == "dead" then T.co = nil; return end
	local ok, err = coroutine.resume(T.co)
	if not ok then
		T.fail = (T.fail or 0) + 1
		log("FAIL coroutine", tostring(err))
		if PZTest and PZTest.fail then PZTest.fail("RJSTest coroutine " .. tostring(err)) end
		T.co = nil
		T.done = true
	end
end
Events.OnTick.Add(onTick)
