-- world_queries.lua
-- Contains functions for querying the state of the game world, like collision checks.

local Grid = require("modules.grid")
local AttackPatterns = require("modules.attack_patterns")
local AttackBlueprints = require("data.attack_blueprints")
local CharacterBlueprints = require("data.character_blueprints")
local EnemyBlueprints = require("data.enemy_blueprints")
local WeaponBlueprints = require("data.weapon_blueprints")
local PassiveBlueprints = require("data/passive_blueprints")

local WorldQueries = {}

-- A mapping from weapon type to the basic attack it grants.
-- Defined once at the module level for efficiency.
local WEAPON_TYPE_TO_BASIC_ATTACK = {
    sword = "slash", lance = "thrust", whip = "lash",
    bow = "loose", staff = "bonk", tome = "harm", dagger = "stab"
}

function WorldQueries.getObstacleAt(tileX, tileY, world)
    -- Check for object-based obstacles (like trees and walls).
    -- Walls are now created as obstacle entities when the world is loaded.
    for _, obstacle in ipairs(world.obstacles) do
        -- Obstacles are defined by their top-left tile and their pixel dimensions.
        -- We can check if the queried tile falls within the obstacle's bounding box.
        local objStartTileX, objStartTileY = obstacle.tileX, obstacle.tileY
        -- Calculate end tiles based on pixel dimensions.
        local objEndTileX, objEndTileY = Grid.toTile(obstacle.x + obstacle.width - 1, obstacle.y + obstacle.height - 1)
 
        if tileX >= objStartTileX and tileX <= objEndTileX and tileY >= objStartTileY and tileY <= objEndTileY then
            return obstacle
        end
    end
    return nil
end

-- Helper to check if a given unit is at a specific tile and is in a valid state to be interacted with.
local function is_valid_unit_at(unit, tileX, tileY, excludeUnit)
    return unit ~= excludeUnit and
           unit.hp > 0 and
           not (unit.components and unit.components.ascended) and
           unit.tileX == tileX and
           unit.tileY == tileY
end

function WorldQueries.getUnitAt(tileX, tileY, excludeSquare, world)
    -- Iterate through players and enemies separately for efficiency, instead of all_entities.
    for _, player in ipairs(world.players) do
        if is_valid_unit_at(player, tileX, tileY, excludeSquare) then return player end
    end
    for _, enemy in ipairs(world.enemies) do
        if is_valid_unit_at(enemy, tileX, tileY, excludeSquare) then return enemy end
    end
    for _, neutral in ipairs(world.neutrals) do
        if is_valid_unit_at(neutral, tileX, tileY, excludeSquare) then return neutral end
    end
    return nil
end

function WorldQueries.isTileOccupied(tileX, tileY, excludeSquare, world)
    return (WorldQueries.getObstacleAt(tileX, tileY, world) ~= nil) or (WorldQueries.getUnitAt(tileX, tileY, excludeSquare, world) ~= nil)
end

function WorldQueries.isTileOccupiedBySameTeam(tileX, tileY, originalSquare, world)
    local teamToCheck = (originalSquare.type == "player") and world.players or world.enemies
    for _, s in ipairs(teamToCheck) do
        if s ~= originalSquare and s.hp > 0 and s.tileX == tileX and s.tileY == tileY then
            return true
        end
    end
    return false
end

function WorldQueries.isTileWater(tileX, tileY, world)
    -- A frozen tile is not considered water for gameplay purposes (movement, drowning).
    local posKey = tileX .. "," .. tileY
    if world.tileStatuses and world.tileStatuses[posKey] and world.tileStatuses[posKey].type == "frozen" then
        return false
    end

    local waterLayer = world.map.layers["Water"]
    if not waterLayer then return false end
    -- Tiled data is 1-based, our grid is 0-based.
    -- The STI library replaces raw GID numbers with tile objects.
    -- So, if a tile exists at this coordinate, the value will be a table. If not, it will be nil.
    local tile = waterLayer.data[tileY + 1] and waterLayer.data[tileY + 1][tileX + 1]
    return tile ~= nil
end

-- Checks if a tile is water based on the map layer, ignoring any tile statuses like 'frozen'.
-- This is used for effects that specifically need to target water itself.
function WorldQueries.isTileWater_Base(tileX, tileY, world)
    local waterLayer = world.map.layers["Water"]
    if not waterLayer then return false end
    -- Tiled data is 1-based, our grid is 0-based.
    local tile = waterLayer.data[tileY + 1] and waterLayer.data[tileY + 1][tileX + 1]
    return tile ~= nil
end

-- A new helper to check if a tile is valid for a ground-based status (Aflame, Tall Grass, etc.)
function WorldQueries.isTileValidForGroundStatus(tileX, tileY, world)
    -- Cannot be placed on water (frozen or not)
    if WorldQueries.isTileWater_Base(tileX, tileY, world) then
        return false
    end
    -- Cannot be placed on a tile with an obstacle
    if WorldQueries.getObstacleAt(tileX, tileY, world) then
        return false
    end
    return true
end

-- A comprehensive check to see if a unit can end its movement on a specific tile.
function WorldQueries.isTileLandable(tileX, tileY, unit, world)
    -- A tile is not landable if it's outside the map.
    if tileX < 0 or tileX >= world.map.width or tileY < 0 or tileY >= world.map.height then
        return false
    end

    local obstacle = WorldQueries.getObstacleAt(tileX, tileY, world)
    if obstacle then
        -- Allow landing on molehills and traps, but not other obstacles.
        if obstacle.objectType ~= "molehill" and not obstacle.isTrap then
            return false
        end
    end

    if WorldQueries.isTileWater(tileX, tileY, world) then
        -- Flying, swimming, or Frozenfoot units can land on water. A nil unit is treated as non-flying.
        local hasFrozenfoot = unit and WorldQueries.hasPassive(unit, "Frozenfoot", world)
        return unit and (unit.isFlying or unit.canSwim or hasFrozenfoot)
    end

    -- Check if another unit is on the tile.
    if WorldQueries.getUnitAt(tileX, tileY, unit, world) then
        return false
    end

    -- If none of the above, the tile is landable.
    return true
end

-- Checks if a ledge is blocking movement between two adjacent tiles.
function WorldQueries.isLedgeBlockingPath(fromTileX, fromTileY, toTileX, toTileY, world)
    local ridgesLayer = world.map.layers["Ridges"]
    if not ridgesLayer then return false end

    local dy = toTileY - fromTileY

    -- Only check vertical movement, as ledges are only defined for up/down.
    if math.abs(dy) == 1 then
        -- Moving up (dy is -1)
        if dy == -1 then
            local fromTile = ridgesLayer.data[fromTileY + 1] and ridgesLayer.data[fromTileY + 1][fromTileX + 1]
            if fromTile and fromTile.properties and fromTile.properties.Block_Up then return true end
        -- Moving down (dy is 1)
        elseif dy == 1 then
            local toTile = ridgesLayer.data[toTileY + 1] and ridgesLayer.data[toTileY + 1][toTileX + 1]
            if toTile and toTile.properties and toTile.properties.Block_Up then return true end
        end
    end

    return false
end

-- A helper function to get a unit's final movement range, accounting for status effects.
-- This should be used by the pathfinding system when calculating reachable tiles.
function WorldQueries.getUnitMovement(unit)
    if not unit or not unit.finalMovement then return 0 end

    -- New: Check for a movement override first. This is used by abilities like Burrow.
    if unit.components and unit.components.movement_override then
        return unit.components.movement_override.amount
    end

    -- Start with the unit's final, calculated movement stat.
    local finalMovement = unit.finalMovement

    -- Apply status effect penalties.
    if unit and unit.statusEffects and unit.statusEffects.paralyzed then
        return 0 -- Paralysis completely stops movement.
    end

    -- Apply rescue penalty and ensure movement doesn't go below zero.
    return math.max(0, finalMovement - (unit.rescuePenalty or 0))
end

-- Helper to check for Treacherous passive
function WorldQueries.hasPassive(unit, passiveName, world)
    if not unit or not world or not unit.type or not world.teamPassives[unit.type] or not world.teamPassives[unit.type][passiveName] then
        return false
    end
    for _, provider in ipairs(world.teamPassives[unit.type][passiveName]) do
        if provider == unit then return true end
    end
    return false
end

--- Checks if a unit has at least one weapon equipped.
-- @param unit (table) The unit to check.
-- @return (boolean) True if the unit has a weapon, false otherwise.
function WorldQueries.isUnitArmed(unit)
    if not unit or not unit.equippedWeapons then
        return false
    end
    for _, weaponKey in pairs(unit.equippedWeapons) do
        if weaponKey then
            return true -- Found a weapon, no need to check further.
        end
    end
    return false
end

--- Checks if two units are hostile to each other.
-- Hostility rules:
-- - Player vs Enemy: Hostile
-- - Player vs Neutral: Hostile
-- - Enemy vs Neutral: Hostile
-- - Same team (Player vs Player, etc.): Not hostile
-- - Neutral vs Neutral: Not hostile
-- @param unit1 (table) The first unit.
-- @param unit2 (table) The second unit.
-- @return (boolean) True if the units are hostile.
function WorldQueries.areUnitsHostile(unit1, unit2)
    if not unit1 or not unit2 or not unit1.type or not unit2.type then return false end
    if unit1.type == unit2.type then return false end -- Same team is never hostile.
    if unit1.type == "neutral" and unit2.type == "neutral" then return false end -- Neutrals don't fight each other.
    return true -- All other cross-team interactions are hostile.
end

-- Helper to check for Treacherous passive
function WorldQueries.hasTreacherous(unit, world)
    return WorldQueries.hasPassive(unit, "Treacherous", world)
end
-- Helper to get a list of potential targets based on an attack's 'affects' property.
local function getPotentialTargets(attacker, attackData, world)
    local potentialTargets = {}
    -- Default to affecting allies for support, enemies for damage. Use 'useType' for consistency.
    local affects = attackData.affects or (attackData.useType == "support" and "allies" or "enemies")

    -- A helper to add destructible obstacles to a target list.
    local function addDestructibleObstacles(list)
        for _, obstacle in ipairs(world.obstacles) do
            -- An obstacle is destructible if it has health.
            if obstacle.hp and obstacle.hp > 0 then
                table.insert(list, obstacle)
            end
        end
    end

    if affects == "enemies" then
        -- Find all units hostile to the attacker.
        for _, unit in ipairs(world.all_entities) do
            if unit.type and WorldQueries.areUnitsHostile(attacker, unit) then
                table.insert(potentialTargets, unit)
            end
        end
        addDestructibleObstacles(potentialTargets)
        -- If treacherous, also add allies to the list of potential targets for damaging moves.
        if WorldQueries.hasTreacherous(attacker, world) then
            local targetAllies = (attacker.type == "player") and world.players or world.enemies
            for _, unit in ipairs(targetAllies) do
                if unit ~= attacker then -- Can't target self
                    table.insert(potentialTargets, unit)
                end
            end
        end
    elseif affects == "allies" then
        local targetAllies = (attacker.type == "player") and world.players or world.enemies
        for _, unit in ipairs(targetAllies) do table.insert(potentialTargets, unit) end
    elseif affects == "all" then
        -- "all" includes every unit type except the attacker itself.
        for _, unit in ipairs(world.all_entities) do
            if unit.type and unit ~= attacker then
                table.insert(potentialTargets, unit)
            end
        end
        addDestructibleObstacles(potentialTargets)
    end
    return potentialTargets
end

-- Helper to calculate the Manhattan distance from a point to the closest point on a rectangle.
local function calculateDistanceToRect(pointX, pointY, rectStartX, rectStartY, rectEndX, rectEndY)
    local dx = math.max(rectStartX - pointX, 0, pointX - rectEndX)
    local dy = math.max(rectStartY - pointY, 0, pointY - rectEndY)
    return dx + dy
end

-- Helper for findValidTargets_Cycle: Handles fixed-shape patterns (e.g., standard_melee)
local function findTargetsInFixedPattern(attacker, attackData, potentialTargets, world)
    local validTargets = {}
    local pattern = AttackPatterns[attackData.patternType]
    if not pattern then return {} end

    for _, target in ipairs(potentialTargets) do
        local isSelf = (target == attacker)
        local canBeTargeted = not isSelf and not (target.hp and target.hp <= 0)

        -- For healing moves, don't target units at full health.
        if attackData.useType == "support" and (attackData.power or 0) > 0 and target.hp and target.finalMaxHp and target.hp >= target.finalMaxHp then
            canBeTargeted = false
        end

        if canBeTargeted then
            if target.isObstacle then
                -- For obstacles, check if any of the attack tiles overlap with the obstacle's area.
                local objStartTileX, objStartTileY = target.tileX, target.tileY
                local objEndTileX, objEndTileY = Grid.toTile(target.x + target.width - 1, target.y + target.height - 1)
                for _, patternCoord in ipairs(pattern) do
                    local attackTileX, attackTileY = attacker.tileX + patternCoord.dx, attacker.tileY + patternCoord.dy
                    if attackTileX >= objStartTileX and attackTileX <= objEndTileX and attackTileY >= objStartTileY and attackTileY <= objEndTileY then
                        table.insert(validTargets, target)
                        break -- Found a match, no need to check other coords for this obstacle.
                    end
                end
            else
                -- For units, check if their single tile matches a pattern coordinate.
                local dx = target.tileX - attacker.tileX
                local dy = target.tileY - attacker.tileY
                for _, patternCoord in ipairs(pattern) do
                    if patternCoord.dx == dx and patternCoord.dy == dy then
                        table.insert(validTargets, target)
                        break -- Found a match, no need to check other coords in this pattern.
                    end
                end
            end
        end
    end
    return validTargets
end

-- Helper for findValidTargets_Cycle: Handles line-of-sight checks
local function findTargetsInLineOfSight(attacker, target, world)
    local isStraightLine = (attacker.tileX == target.tileX or attacker.tileY == target.tileY)
    if not isStraightLine then return false end

    local dist = math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY)
    if attacker.tileX == target.tileX then -- Vertical line
        local dirY = (target.tileY > attacker.tileY) and 1 or -1
        for i = 1, dist - 1 do
            local checkY = attacker.tileY + i * dirY
            if WorldQueries.isTileOccupied(attacker.tileX, checkY, attacker, world) then
                return false -- Path is blocked
            end
            if WorldQueries.isLedgeBlockingPath(attacker.tileX, checkY - dirY, attacker.tileX, checkY, world) then
                return false -- Ledge is blocking
            end
        end
    else -- Horizontal line
        local dirX = (target.tileX > attacker.tileX) and 1 or -1
        for i = 1, dist - 1 do
            if WorldQueries.isTileOccupied(attacker.tileX + i * dirX, attacker.tileY, attacker, world) then
                return false -- Path is blocked
            end
        end
    end
    return true
end

-- Helper for findValidTargets_Cycle: Handles special logic for Phantom Step
local function findTargetsForPhantomStep(target, world)
    local dx, dy = 0, 0
    if target.lastDirection == "up" then dy = 1 elseif target.lastDirection == "down" then dy = -1 elseif target.lastDirection == "left" then dx = 1 elseif target.lastDirection == "right" then dx = -1 end
    local behindTileX, behindTileY = target.tileX + dx, target.tileY + dy
    return not WorldQueries.isTileOccupied(behindTileX, behindTileY, nil, world)
end

-- Helper for findValidTargets_Cycle: Checks for line-of-sight that is blocked only by obstacles, not units.
local function isLineOfSightBlockedByObstacle(attacker, target, world)
    local isStraightLine = (attacker.tileX == target.tileX or attacker.tileY == target.tileY)
    if not isStraightLine then return true end -- Not a straight line, so it's "blocked" for this purpose

    local dist = math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY)
    if attacker.tileX == target.tileX then -- Vertical line
        local dirY = (target.tileY > attacker.tileY) and 1 or -1
        for i = 1, dist - 1 do
            local checkY = attacker.tileY + i * dirY
            if WorldQueries.getObstacleAt(attacker.tileX, checkY, world) then
                return true -- Path is blocked by an obstacle
            end
        end
    else -- Horizontal line
        local dirX = (target.tileX > attacker.tileX) and 1 or -1
        for i = 1, dist - 1 do
            if WorldQueries.getObstacleAt(attacker.tileX + i * dirX, attacker.tileY, world) then
                return true -- Path is blocked by an obstacle
            end
        end
    end
    return false -- Path is clear of obstacles
end

-- Helper function to find targets for "cycle_target" style attacks.
local function findValidTargets_Cycle(attacker, attackData, world)
    local validTargets = {}
    local attackName = attackData.name -- Assuming attackData has a name field
    local pattern = AttackPatterns[attackData.patternType]

    if pattern and type(pattern) == "table" then
        -- New logic for fixed-shape patterns (standard_melee, etc.)
        return findTargetsInFixedPattern(attacker, attackData, getPotentialTargets(attacker, attackData, world), world)
    else
        -- Fallback to legacy range-based logic for attacks without a fixed pattern table
        -- (e.g., fireball, phantom_step, hookshot, shockwave).
        local potentialTargets = getPotentialTargets(attacker, attackData, world)

        -- Special case for hookshot: also allow targeting any *non-destructible* obstacle.
        -- Destructible obstacles are already handled by getPotentialTargets.
        if attackName == "hookshot" then
            for _, obstacle in ipairs(world.obstacles) do
                if not obstacle.hp then
                    table.insert(potentialTargets, obstacle)
                end
            end
        end

        -- New: If the attack can target a specific tile type, add valid tiles to the list.
        if attackData.canTargetTileType == "water" then
            local range = attackData.range or 0
            local minRange = attackData.min_range or 1
            for dx = -range, range do
                for dy = -range, range do
                    local dist = math.abs(dx) + math.abs(dy)
                    if dist >= minRange and dist <= range then
                        local tileX, tileY = attacker.tileX + dx, attacker.tileY + dy
                        -- Check if it's a water tile and has line of sight.
                        if WorldQueries.isTileWater_Base(tileX, tileY, world) then
                            local tileTarget = { tileX = tileX, tileY = tileY, isTileTarget = true, hp = 1, weight = 1 } -- Add dummy properties to pass checks
                            if not attackData.line_of_sight_only or findTargetsInLineOfSight(attacker, tileTarget, world) then
                                table.insert(potentialTargets, tileTarget)
                            end
                        end
                    end
                end
            end
        end

        local range = attackData.range
        if attackName == "phantom_step" then range = WorldQueries.getUnitMovement(attacker) end -- Dynamic range
        local minRange = attackData.min_range or 1

        if not range then return {} end -- Can't find targets for an attack without a defined range

        for _, target in ipairs(potentialTargets) do
            local isSelf = (target == attacker)
            local canBeTargeted = false
            if attackName == "hookshot" then
                canBeTargeted = not isSelf and target.weight and not (target.hp and target.hp <= 0)
            else
                canBeTargeted = not isSelf and not (target.hp and target.hp <= 0)
            end

            if canBeTargeted then
                local distance
                if target.isObstacle then
                    local objStartTileX, objStartTileY = target.tileX, target.tileY
                    local objEndTileX, objEndTileY = Grid.toTile(target.x + target.width - 1, target.y + target.height - 1)
                    distance = calculateDistanceToRect(attacker.tileX, attacker.tileY, objStartTileX, objStartTileY, objEndTileX, objEndTileY)
                elseif target.isTileTarget then
                    -- For tile targets, it's a simple Manhattan distance.
                    distance = math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY)
                else
                    distance = math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY)
                end
                local inRange = distance >= minRange and distance <= range

                if inRange then
                    if attackData.line_of_sight_only then
                        -- Fireball ignores blocking units/ledges for its LOS check.
                        if attackName == "fireball" and not isLineOfSightBlockedByObstacle(attacker, target, world) then
                            table.insert(validTargets, target)
                        elseif findTargetsInLineOfSight(attacker, target, world) and attackName ~= "fireball" then
                            table.insert(validTargets, target)
                        end
                    elseif attackName == "phantom_step" then
                        if findTargetsForPhantomStep(target, world) then
                                table.insert(validTargets, target)
                        end
                    else
                        table.insert(validTargets, target)
                    end
                end
            end
        end
    end
    return validTargets
end

-- Helper function to find targets for "auto_hit_all" style attacks.
local function findValidTargets_AutoHitAll(attacker, attackData, world)
    local validTargets = {}
    local potentialTargets = getPotentialTargets(attacker, attackData, world)
    local range = attackData.range

    if not range then return {} end

    for _, target in ipairs(potentialTargets) do
        if target.hp > 0 and math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY) <= range then
            table.insert(validTargets, target)
        end
    end
    return validTargets
end

-- A dispatch table to call the correct targeting helper function.
local targetFinders = {
    cycle_target    = findValidTargets_Cycle,
    auto_hit_all    = findValidTargets_AutoHitAll
}

-- Finds all valid targets for a given attack, based on its blueprint properties.
function WorldQueries.findValidTargetsForAttack(attacker, attackName, world)
    local attackData = AttackBlueprints[attackName]
    if not attackData then return {} end

    -- New: Check if the attacker is taunted.
    if attacker.statusEffects and attacker.statusEffects.taunted then
        local tauntData = attacker.statusEffects.taunted
        local taunter = tauntData.attacker

            if taunter and taunter.hp > 0 and WorldQueries.areUnitsHostile(attacker, taunter) then
            -- The unit is taunted. They can only target the taunter.
            -- We need to check if the taunter is a valid target for the selected attack.
            -- To do this, we can run the normal targeting logic but only check against the taunter.
            attackData.name = attackName -- Ensure name is set for helpers
            local finder = targetFinders[attackData.targeting_style]
            if finder then
                local allPossibleTargets = finder(attacker, attackData, world)
                for _, possibleTarget in ipairs(allPossibleTargets) do
                    if possibleTarget == taunter then
                        return { taunter } -- The taunter is a valid target. Return ONLY them.
                    end
                end
            end
            return {} -- The taunter is not a valid target for this move (e.g., out of range).
        else
            -- Taunter is dead or gone, so the effect is broken.
            local StatusEffectManager = require("modules.status_effect_manager")
            StatusEffectManager.remove(attacker, "taunted", world)
        end
    end

    -- Add the attack name to the data table for the helper functions to use.
    attackData.name = attackName

    local finder = targetFinders[attackData.targeting_style]
    if finder then
        return finder(attacker, attackData, world)
    end

    return {} -- Return an empty table if no handler is found.
end

-- Helper to find adjacent allied units that satisfy a given condition.
local function findAdjacentAllies(actor, world, filterFunc)
    local validTargets = {}
    if not actor then return validTargets end

    -- Iterate through all player units.
    -- This assumes these actions are player-only for now.
    for _, potentialTarget in ipairs(world.players) do
        -- A unit cannot target itself, and must be alive.
        if potentialTarget ~= actor and potentialTarget.hp > 0 then
            -- Check if the target is adjacent (Manhattan distance of 1).
            local distance = math.abs(actor.tileX - potentialTarget.tileX) + math.abs(actor.tileY - potentialTarget.tileY)
            
            if distance == 1 then
                -- Apply the custom filter logic.
                if filterFunc(actor, potentialTarget, world) then
                    table.insert(validTargets, potentialTarget)
                end
            end
        end
    end
    return validTargets
end

-- Finds all adjacent, lighter player units that can be rescued by the given unit.
function WorldQueries.findRescuableUnits(rescuer, world)
    if not rescuer or rescuer.carriedUnit then return {} end

    local validTargets = {}
    local potentialTargets = {}

    -- 1. Add all adjacent allies to the potential list.
    local allies = (rescuer.type == "player") and world.players or world.enemies
    for _, unit in ipairs(allies) do
        if unit ~= rescuer and unit.hp > 0 then
            local distance = math.abs(rescuer.tileX - unit.tileX) + math.abs(rescuer.tileY - unit.tileY)
            if distance == 1 then
                table.insert(potentialTargets, unit)
            end
        end
    end

    -- 2. If the rescuer has "Captor", add adjacent enemies to the potential list.
    local rescuerHasCaptor = false
    if world.teamPassives[rescuer.type].Captor then
        for _, provider in ipairs(world.teamPassives[rescuer.type].Captor) do
            if provider == rescuer then rescuerHasCaptor = true; break end
        end
    end

    if rescuerHasCaptor then
        local enemies = (rescuer.type == "player") and world.enemies or world.players
        for _, unit in ipairs(enemies) do
            if unit.hp > 0 then
                local distance = math.abs(rescuer.tileX - unit.tileX) + math.abs(rescuer.tileY - unit.tileY)
                if distance == 1 then
                    table.insert(potentialTargets, unit)
                end
            end
        end
    end

    -- 3. Filter all potential targets by weight.
    for _, target in ipairs(potentialTargets) do
        if target.weight < rescuer.weight then
            table.insert(validTargets, target)
        end
    end

    return validTargets
end

-- Finds all adjacent, lighter allied units that can be shoved by the given unit.
function WorldQueries.findShoveTargets(shover, world)
    local filter = function(actor, target, wrld)
        if actor.weight > target.weight then
            local dx = target.tileX - actor.tileX
            local dy = target.tileY - actor.tileY
            local destTileX, destTileY = target.tileX + dx, target.tileY + dy
            return destTileX >= 0 and destTileX < wrld.map.width and
                   destTileY >= 0 and destTileY < wrld.map.height and
                   not WorldQueries.isTileOccupied(destTileX, destTileY, nil, wrld)
        end
        return false
    end
    return findAdjacentAllies(shover, world, filter)
end

-- Finds all adjacent player units who are carrying a unit that the 'taker' can take.
function WorldQueries.findTakeTargets(taker, world)
    if not taker or taker.carriedUnit then return {} end -- A unit already carrying someone cannot take.

    local filter = function(actor, target, wrld)
        if not target.carriedUnit then return false end

        -- Standard check: Can the taker carry the unit?
        if actor.baseWeight <= target.carriedUnit.baseWeight then
            return false
        end

        -- New Captor check: If the carried unit is an enemy, the taker must have Captor.
        if target.carriedUnit.type ~= actor.type then
            local takerHasCaptor = false
            if wrld.teamPassives[actor.type].Captor then
                for _, provider in ipairs(wrld.teamPassives[actor.type].Captor) do
                    if provider == actor then takerHasCaptor = true; break end
                end
            end
            if not takerHasCaptor then return false end
        end
        return true
    end
    return findAdjacentAllies(taker, world, filter)
end

-- Checks if any major game action (attack, movement, animation) is currently in progress.
-- This is used to lock UI elements and delay turn finalization.
function WorldQueries.isActionOngoing(world)
    -- Lazily require to break circular dependency with level_up_display_system
    local LevelUpDisplaySystem = require("systems.level_up_display_system")

    -- An action is considered ongoing if there are active global effects...
    -- Check if the level up display sequence is active.
    if LevelUpDisplaySystem.active then return true end

    -- Check if the EXP gain animation is active.
    if world.ui.expGainAnimation and world.ui.expGainAnimation.active then return true end

    -- Check if the promotion menu is active, as this also pauses the game flow.
    if world.ui.menus.promotion.active then return true end

    -- An action is ongoing if there are pending attack effects or ripples.
    -- These can trigger further game logic like damage, death, and other effects.
    if #world.attackEffects > 0 or #world.rippleEffectQueue > 0 then return true end

    -- An action is ongoing if a projectile is in flight, or a counter-attack is pending.
    if #world.projectiles > 0 or #world.pendingCounters > 0 then return true end

    -- ...or if any single unit is still performing a visual action.
    for _, entity in ipairs(world.all_entities) do
        -- Check for animations like lunges, careening, or any entity that is currently moving towards a target pixel.
        if entity.components.lunge or
           entity.components.pending_damage or
           (entity.statusEffects and entity.statusEffects.careening) or
           (entity.targetX and (math.abs(entity.x - entity.targetX) > 0.5 or math.abs(entity.y - entity.targetY) > 0.5)) then
            return true -- Found a busy unit.
        end
    end

    return false -- No ongoing actions found.
end

-- Checks if a unit is currently involved in a combat display (for UI purposes like enlarging health bars).
function WorldQueries.isUnitInCombat(unit, world)
    -- A unit is "in combat" if its health bar is animating (draining or shrinking).
    if unit.components.pending_damage or unit.components.shrinking_health_bar then
        return true
    end

    -- We also need to check if the unit is an ATTACKER whose target has pending_damage.
    -- This ensures the attacker's health bar also becomes large during the combat sequence.
    for _, entity in ipairs(world.all_entities) do
        if entity.components.pending_damage and entity.components.pending_damage.attacker == unit then
            return true
        end
    end
    return false
end

-- Calculates the current visual height of a unit's health bar, accounting for combat animations.
function WorldQueries.getUnitHealthBarHeight(unit, world)
    local inCombat = WorldQueries.isUnitInCombat(unit, world)
    if unit.components.shrinking_health_bar then
        local shrink = unit.components.shrinking_health_bar
        local progress = shrink.timer / shrink.initialTimer
        return math.floor(6 + (6 * progress)) -- Lerp from 12 down to 6
    else
        return inCombat and 12 or 6
    end
end

--- Builds a complete, ordered list of a unit's available attacks.
-- This is the single source of truth for what moves a unit has.
-- It prioritizes the weapon's basic attack, then granted moves, then innate moves.
-- @param unit (table): The unit to get the move list for.
-- @return (table): An ordered list of attack name strings.
function WorldQueries.getUnitMoveList(unit)
    if not unit then return {} end

    -- If the unit is disarmed, they are considered "unarmed" and have no moves.
    -- This prevents counter-attacks and AI from trying to use moves.
    if unit.statusEffects and unit.statusEffects.disarmed then
        return {}
    end

    local all_moves = {}
    local move_exists = {} -- Use a set to track existing moves and prevent duplicates

    -- 1. Add basic attacks from all equipped weapons first. This is crucial for counter-attack logic.
    if unit.equippedWeapons then
        for _, weaponName in ipairs(unit.equippedWeapons) do
            local weapon = WeaponBlueprints[weaponName]
            if weapon then
                local basicAttackName = WEAPON_TYPE_TO_BASIC_ATTACK[weapon.type]
                if basicAttackName and not move_exists[basicAttackName] then
                    table.insert(all_moves, basicAttackName)
                    move_exists[basicAttackName] = true
                end
            end
        end
    end

    -- 2. Add any special moves the weapons grant.
    if unit.equippedWeapons then
        for _, weaponName in ipairs(unit.equippedWeapons) do
            local weapon = WeaponBlueprints[weaponName]
            if weapon and weapon.grants_moves then
                for _, attackName in ipairs(weapon.grants_moves) do
                    if not move_exists[attackName] then table.insert(all_moves, attackName); move_exists[attackName] = true end
                end
            end
        end
    end

    -- 3. Add moves from the character's innate blueprint list.
    local blueprint
    if unit.type == "player" then
        blueprint = CharacterBlueprints[unit.playerType]
    elseif unit.type == "enemy" then
        blueprint = EnemyBlueprints[unit.enemyType]
    elseif unit.type == "neutral" then
        blueprint = CharacterBlueprints[unit.playerType]
    end
    if blueprint and blueprint.attacks then
        for _, attackName in ipairs(blueprint.attacks) do
            if not move_exists[attackName] then table.insert(all_moves, attackName); move_exists[attackName] = true end
        end
    end

    return all_moves
end

--- Builds a complete, ordered list of a unit's available passives.
-- @param unit (table): The unit to get the passive list for.
-- @return (table): An ordered list of passive name strings.
function WorldQueries.getUnitPassiveList(unit)
    if not unit then return {} end

    -- If passives are overridden (e.g., by Necromantia + Proliferate),
    -- return that list directly. It is the single source of truth.
    if unit.overriddenPassives then
        return unit.overriddenPassives
    end

    local all_passives = {}
    local passive_exists = {} -- Use a set to track existing passives and prevent duplicates

    -- 1. Get passives from the character/enemy blueprint.
    local blueprint
    if unit.type == "player" then
        blueprint = CharacterBlueprints[unit.playerType]
    elseif unit.type == "enemy" then
        blueprint = EnemyBlueprints[unit.enemyType]
    elseif unit.type == "neutral" then
        blueprint = CharacterBlueprints[unit.playerType]
    end
    if blueprint and blueprint.passives then
        for _, passiveName in ipairs(blueprint.passives) do
            if not passive_exists[passiveName] then table.insert(all_passives, passiveName); passive_exists[passiveName] = true end
        end
    end

    -- 2. Get passives from all equipped weapons.
    if unit.equippedWeapons then
        for _, weaponName in ipairs(unit.equippedWeapons) do
            local weapon = WeaponBlueprints[weaponName]
            if weapon and weapon.grants_passives then
                for _, passiveName in ipairs(weapon.grants_passives) do
                    if not passive_exists[passiveName] then table.insert(all_passives, passiveName); passive_exists[passiveName] = true end
                end
            end
        end
    end

    return all_passives
end

--- Gets the total lifesteal percentage for a unit from all sources (weapon, passives).
-- @param unit (table): The unit to check.
-- @param world (table): The game world.
-- @return (number): The total lifesteal percentage (e.g., 0.5 for 50%).
function WorldQueries.getUnitLifestealPercent(unit, world)
    if not unit then return 0 end

    local totalLifesteal = 0

    -- 1. Get lifesteal from all equipped weapons.
    if unit.equippedWeapons then
        for _, weaponName in ipairs(unit.equippedWeapons) do
            local weapon = WeaponBlueprints[weaponName]
            if weapon and weapon.lifesteal_percent then
                totalLifesteal = totalLifesteal + weapon.lifesteal_percent
            end
        end
    end

    -- 2. Get lifesteal from passives (future-proofing).
    if unit.type and world.teamPassives[unit.type] and world.teamPassives[unit.type].Vampirism then
        local unitHasVampirism = false
        for _, provider in ipairs(world.teamPassives[unit.type].Vampirism) do
            if provider == unit then
                unitHasVampirism = true
                break
            end
        end
        if unitHasVampirism then
            local passiveData = PassiveBlueprints.Vampirism
            if passiveData and passiveData.lifesteal_percent then
                totalLifesteal = totalLifesteal + passiveData.lifesteal_percent
            end
        end
    end

    return totalLifesteal
end

--- Counts the number of living, non-carried allied units adjacent to a given unit.
-- @param unit (table): The unit to check around.
-- @param world (table): The game world.
-- @return (number): The count of adjacent allies.
function WorldQueries.countAdjacentAllies(unit, world)
    if not unit then return 0 end
    local count = 0
    local allies = (unit.type == "player") and world.players or world.enemies
    local neighbors = {{dx=0,dy=-1},{dx=0,dy=1},{dx=-1,dy=0},{dx=1,dy=0}}

    for _, move in ipairs(neighbors) do
        local checkX, checkY = unit.tileX + move.dx, unit.tileY + move.dy
        local occupyingUnit = WorldQueries.getUnitAt(checkX, checkY, unit, world)
        if occupyingUnit and occupyingUnit.type == unit.type then
            count = count + 1
        end
    end
    return count
end

return WorldQueries