-- world_queries.lua
-- Contains functions for querying the state of the game world, like collision checks.

local Grid = require("modules.grid")
local AttackPatterns = require("modules.attack_patterns")
local LevelUpDisplaySystem = require("systems.level_up_display_system")
local AttackBlueprints = require("data.attack_blueprints")

local WorldQueries = {}

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

function WorldQueries.getUnitAt(tileX, tileY, excludeSquare, world)
    for _, s in ipairs(world.all_entities) do
        -- Only check against players and enemies, not projectiles etc.
        if (s.type == "player" or s.type == "enemy") and s ~= excludeSquare and s.hp > 0 then
            if s.tileX == tileX and s.tileY == tileY then
                return s
            end
        end
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
    local waterLayer = world.map.layers["Water"]
    if not waterLayer then return false end
    -- Tiled data is 1-based, our grid is 0-based.
    -- The STI library replaces raw GID numbers with tile objects.
    -- So, if a tile exists at this coordinate, the value will be a table. If not, it will be nil.
    local tile = waterLayer.data[tileY + 1] and waterLayer.data[tileY + 1][tileX + 1]
    return tile ~= nil
end

-- A comprehensive check to see if a unit can end its movement on a specific tile.
function WorldQueries.isTileLandable(tileX, tileY, unit, world)
    -- A tile is not landable if it's outside the map.
    if tileX < 0 or tileX >= world.map.width or tileY < 0 or tileY >= world.map.height then
        return false
    end

    local obstacle = WorldQueries.getObstacleAt(tileX, tileY, world)
    if obstacle then
        -- Cannot land on any obstacle, impassable or not.
        return false
    end

    if WorldQueries.isTileWater(tileX, tileY, world) then
        -- Only flying units can land on water. A nil unit is treated as non-flying.
        return unit and unit.isFlying
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

function WorldQueries.isTargetInPattern(attacker, patternFunc, targets, world)
    if not patternFunc or not targets then return false end

    local effects = patternFunc(attacker, world) -- Pass world to the pattern generator
    for _, effectData in ipairs(effects) do
        local s = effectData.shape

        if s.type == "rect" then
            -- Convert the pixel-based rectangle into tile boundaries.
            local startTileX, startTileY = Grid.toTile(s.x, s.y)
            -- Important: The end tile is the one containing the bottom-right corner pixel.
            local endTileX, endTileY = Grid.toTile(s.x + s.w - 1, s.y + s.h - 1)

            for _, target in ipairs(targets) do
                -- We only care about living targets. The `target.hp == nil` check is for the flag.
                if target and (target.hp == nil or target.hp > 0) then
                    -- Check if the target's single tile falls within the pattern's tile-based AABB.
                    if target.tileX >= startTileX and target.tileX <= endTileX and
                       target.tileY >= startTileY and target.tileY <= endTileY then
                        return true -- Found a target within one of the pattern's shapes
                    end
                end
            end
        end
    end
    return false -- No targets were found within the entire pattern
end

-- A helper function to get a unit's final movement range, accounting for status effects.
-- This should be used by the pathfinding system when calculating reachable tiles.
function WorldQueries.getUnitMovement(unit)
    if not unit or not unit.movement then return 0 end

    -- Start with the unit's base movement.
    local finalMovement = unit.movement

    -- Apply status effect penalties.
    if unit and unit.statusEffects and unit.statusEffects.paralyzed then
        return 0 -- Paralysis completely stops movement.
    end

    -- Apply rescue penalty and ensure movement doesn't go below zero.
    return math.max(0, finalMovement - (unit.rescuePenalty or 0))
end

-- Helper to get a list of potential targets based on an attack's 'affects' property.
local function getPotentialTargets(attacker, attackData, world)
    local potentialTargets = {}
    -- Default to affecting allies for support, enemies for damage.
    local affects = attackData.affects or (attackData.type == "support" and "allies" or "enemies")

    -- Correctly determine the target list based on the attacker's perspective.
    local targetEnemies = (attacker.type == "player") and world.enemies or world.players
    local targetAllies = (attacker.type == "player") and world.players or world.enemies

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
        for _, unit in ipairs(targetEnemies) do table.insert(potentialTargets, unit) end
        addDestructibleObstacles(potentialTargets)
    elseif affects == "allies" then
        for _, unit in ipairs(targetAllies) do table.insert(potentialTargets, unit) end
    elseif affects == "all" then
        for _, unit in ipairs(targetEnemies) do table.insert(potentialTargets, unit) end
        for _, unit in ipairs(targetAllies) do table.insert(potentialTargets, unit) end
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
        if attackData.useType == "support" and (attackData.power or 0) > 0 and target.hp and target.maxHp and target.hp >= target.maxHp then
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

-- Helper function to find targets for "directional_aim" style attacks.
local function findValidTargets_Directional(attacker, attackData, world)
    local validTargets = {}
    local patternFunc = AttackPatterns[attackData.name] -- Assuming attackData has a name field
    if not patternFunc then return {} end

    local potentialTargets = getPotentialTargets(attacker, attackData, world)

    -- Check all 4 directions from the attacker's current position
    local tempAttacker = { tileX = attacker.tileX, tileY = attacker.tileY, x = attacker.x, y = attacker.y, size = attacker.size }
    local directions = {"up", "down", "left", "right"}
    for _, dir in ipairs(directions) do
        tempAttacker.lastDirection = dir
        local effects = patternFunc(tempAttacker, world)
        for _, effectData in ipairs(effects) do
            local s = effectData.shape
            local startTileX, startTileY = Grid.toTile(s.x, s.y)
            local endTileX, endTileY = Grid.toTile(s.x + s.w - 1, s.y + s.h - 1)

            for _, target in ipairs(potentialTargets) do
                if target.hp > 0 and target ~= attacker and target.tileX >= startTileX and target.tileX <= endTileX and target.tileY >= startTileY and target.tileY <= endTileY then
                    -- Found a valid target. Add it to the list if not already there.
                    local found = false
                    for _, vt in ipairs(validTargets) do if vt == target then found = true; break end end
                    if not found then table.insert(validTargets, target) end
                end
            end
        end
    end
    return validTargets
end

-- A dispatch table to call the correct targeting helper function.
local targetFinders = {
    cycle_target    = findValidTargets_Cycle,
    auto_hit_all    = findValidTargets_AutoHitAll,
    directional_aim = findValidTargets_Directional,
}

-- Finds all valid targets for a given attack, based on its blueprint properties.
function WorldQueries.findValidTargetsForAttack(attacker, attackName, world)
    local attackData = AttackBlueprints[attackName]
    if not attackData then return {} end

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
    if not rescuer or rescuer.carriedUnit then return {} end -- Can't rescue if already carrying.
    local filter = function(actor, target, wrld)
        return target.weight < actor.weight
    end
    return findAdjacentAllies(rescuer, world, filter)
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
        return target.carriedUnit and actor.baseWeight > target.carriedUnit.baseWeight
    end
    return findAdjacentAllies(taker, world, filter)
end

-- Checks if any major game action (attack, movement, animation) is currently in progress.
-- This is used to lock UI elements and delay turn finalization.
function WorldQueries.isActionOngoing(world)
    -- An action is considered ongoing if there are active global effects...
    -- Check if the level up display sequence is active.
    if LevelUpDisplaySystem.active then return true end

    -- An action is ongoing if a projectile is in flight, or a counter-attack is pending.
    -- We don't check attackEffects here, as those are purely visual and shouldn't block game state.
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

return WorldQueries