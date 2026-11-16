-- Reliable Jaw Stab
-- A jaw stab starts when a zombie is closer than the knife's MinRange (0.61), but the hit is decided
-- later, at the swing's hit point, against MaxRange (0.9) and the swing angle. Nothing holds the zombie
-- still in between. In multiplayer the zombie on this client follows the server with corrections, so a
-- stab started near 0.61 often finds no target at the hit point: no hit packet goes out and the zombie
-- walks on while the player plays the kill animation.
-- Fix: at the hit point of a jaw stab (OnWeaponSwingHitPoint runs right before the target search),
-- if the nearest standing zombie drifted out of reach but is still close, put it back in front of the
-- player on this client. The target search then finds it and the normal hit packet goes to the server.

ReliableJawStab = ReliableJawStab or {}
local M = ReliableJawStab

M.enabled = true      -- tests switch this off to see the vanilla miss
M.REACH = 1.5         -- a zombie farther than this is not pulled back (tiles)
M.SAFE_DIST = 0.7     -- closer than this and ...
M.SAFE_DOT = 0.8      -- ... at least this much in front: vanilla hits it, leave it alone
M.PLACE_DIST = 0.45   -- where the zombie is put, straight in front of the player
M.moves = 0           -- how many times the zombie was put back (tests read this)

local function log(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
	print("[ReliableJawStab] " .. table.concat(parts, " "))
end

-- the current swing is a jaw stab: the knife crit animation set ZombieHitReaction=KnifeDeath
-- (KnifeCrit.xml / KnifeCritStart.xml, at 10% of the animation, before the hit point)
function M.isJawStab(player, weapon)
	if not player or not weapon or not instanceof(weapon, "HandWeapon") then return false end
	if weapon:isRanged() then return false end
	if player:isDoShove() or player:isAimAtFloor() then return false end
	if not player:isCriticalHit() then return false end
	return player:getVariableString("ZombieHitReaction") == "KnifeDeath"
end

local function isStandingZombie(z, floorZ)
	return z and not z:isDead() and not z:isOnFloor() and not z:isProne()
		and math.floor(z:getZ()) == floorZ
end

-- nearest standing zombie on the player's floor within REACH, and its distance
function M.nearestZombie(player)
	local px, py = player:getX(), player:getY()
	local floorZ = math.floor(player:getZ())
	local best, bestD = nil, M.REACH
	local list = getCell():getZombieList()
	for i = 0, list:size() - 1 do
		local z = list:get(i)
		if isStandingZombie(z, floorZ) then
			local dx, dy = z:getX() - px, z:getY() - py
			local d = math.sqrt(dx * dx + dy * dy)
			if d <= bestD then best, bestD = z, d end
		end
	end
	return best, bestD
end

-- square checks: the zombie may only come back across open ground (same or neighbouring squares,
-- no wall, closed door or window between), so the fix never stabs through anything
local function openBetween(a, b)
	if not a or not b then return false end
	if a == b then return true end
	if math.abs(a:getX() - b:getX()) > 1 or math.abs(a:getY() - b:getY()) > 1 then return false end
	return not a:isBlockedTo(b)
end

function M.onHitPoint(player, weapon)
	if not M.enabled then return end
	if not player or not player:isLocalPlayer() then return end
	if not M.isJawStab(player, weapon) then return end
	local z, d = M.nearestZombie(player)
	if not z then return end
	local dot = player:getDotWithForwardDirection(z:getX(), z:getY())
	if d <= M.SAFE_DIST and dot >= M.SAFE_DOT then return end

	local fwd = player:getForwardDirection()
	local fx, fy = fwd:getX(), fwd:getY()
	local len = math.sqrt(fx * fx + fy * fy)
	if len < 0.001 then return end
	local nx = player:getX() + fx / len * M.PLACE_DIST
	local ny = player:getY() + fy / len * M.PLACE_DIST
	local nz = z:getZ()
	local cell = getCell()
	local pSq = player:getCurrentSquare()
	local zSq = z:getCurrentSquare()
	local dSq = cell:getGridSquare(math.floor(nx), math.floor(ny), math.floor(nz))
	if not dSq or not openBetween(pSq, dSq) or not openBetween(pSq, zSq) then
		log("skip: no open path", string.format("d=%.2f dot=%.2f", d, dot))
		return
	end

	z:setX(nx); z:setY(ny)
	z:setLastX(nx); z:setLastY(ny)
	z:setNextX(nx); z:setNextY(ny)
	z:setCurrentSquareFromPosition()
	M.moves = M.moves + 1
	log(string.format("put zombie %d back in reach: d=%.2f dot=%.2f -> %.2f", z:getOnlineID(), d, dot, M.PLACE_DIST))
end

if not M.registered then
	Events.OnWeaponSwingHitPoint.Add(function(player, weapon) M.onHitPoint(player, weapon) end)
	M.registered = true
end
