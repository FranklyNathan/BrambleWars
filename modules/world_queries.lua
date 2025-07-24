-- world_queries.lua
-- Contains functions for querying the state of the game world, like collision checks.

local Grid = require("modules.grid")
local AttackPatterns = require("modules.attack_patterns")
local AttackBlueprints = require("data.attack_blueprints")

local WorldQueries = {}

function WorldQueries.isTileAnObstacle(tileX, tileY, world)
    -- Check for object-based obstacles (like trees and walls).
    -- Walls are now created as obstacle entities when the world is loaded.
    for _, obstacle in ipairs(world.obstacles) do
        -- Obstacles are defined by their top-left tile and their pixel dimensions.
        -- We can check if the queried tile falls within the obstacle's bounding box.
        local objStartTileX, objStartTileY = obstacle.tileX, obstacle.tileY
        -- Calculate end tiles based on pixel dimensions.
        local objEndTileX, objEndTileY = Grid.toTile(obstacle.x + obstacle.width - 1, obstacle.y + obstacle.height - 1)
 
        if tileX >= objStartTileX and tileX <= objEndTileX and tileY >= objStartTileY and tileY <= objEndTileY then
            return true
        end
    end
    return false
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
    return WorldQueries.isTileAnObstacle(tileX, tileY, world) or (WorldQueries.getUnitAt(tileX, tileY, excludeSquare, world) ~= nil)
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

    if affects == "enemies" then
        for _, unit in ipairs(targetEnemies) do table.insert(potentialTargets, unit) end
    elseif affects == "allies" then
        for _, unit in ipairs(targetAllies) do table.insert(potentialTargets, unit) end
    elseif affects == "all" then
        for _, unit in ipairs(targetEnemies) do table.insert(potentialTargets, unit) end
        for _, unit in ipairs(targetAllies) do table.insert(potentialTargets, unit) end
    end
    return potentialTargets
end

-- Finds all valid targets for a given attack, based on its blueprint properties.
function WorldQueries.findValidTargetsForAttack(attacker, attackName, world)
    local attackData = AttackBlueprints[attackName]
    if not attackData then return {} end

    local validTargets = {}
    local style = attackData.targeting_style

    if style == "cycle_target" then
        local pattern = AttackPatterns[attackData.patternType]

        if pattern and type(pattern) == "table" then
            -- New logic for fixed-shape patterns (standard_melee, etc.)
            local potentialTargets = getPotentialTargets(attacker, attackData, world)
            for _, target in ipairs(potentialTargets) do
                local isSelf = (target == attacker)
                local canBeTargeted = not isSelf and not (target.hp and target.hp <= 0)

                -- For healing moves, don't target units at full health.
                if attackData.useType == "support" and (attackData.power or 0) > 0 and target.hp >= target.maxHp then
                    canBeTargeted = false
                end

                if canBeTargeted then
                    local dx = target.tileX - attacker.tileX
                    local dy = target.tileY - attacker.tileY

                    -- Check if the target's relative position matches any coordinate in the pattern table.
                    for _, patternCoord in ipairs(pattern) do
                        if patternCoord.dx == dx and patternCoord.dy == dy then
                            table.insert(validTargets, target)
                            break -- Found a match, no need to check other coords in this pattern.
                        end
                    end
                end
            end
        else
            -- Fallback to legacy range-based logic for attacks without a fixed pattern table
            -- (e.g., fireball, phantom_step, hookshot, shockwave).
            local potentialTargets = getPotentialTargets(attacker, attackData, world)

            -- Special case for hookshot: also allow targeting any obstacle.
            if attackName == "hookshot" then
                for _, obstacle in ipairs(world.obstacles) do
                    table.insert(potentialTargets, obstacle)
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
                    local distance = math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY)
                    local inRange = distance >= minRange and distance <= range

                    if inRange then
                        if attackData.line_of_sight_only then
                            local isStraightLine = (attacker.tileX == target.tileX or attacker.tileY == target.tileY)
                            if isStraightLine then
                                local dist = math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY)
                                local isBlocked = false
                                if attacker.tileX == target.tileX then -- Vertical line
                                    local dirY = (target.tileY > attacker.tileY) and 1 or -1
                                    for i = 1, dist - 1 do
                                        if WorldQueries.isTileOccupied(attacker.tileX, attacker.tileY + i * dirY, attacker, world) then
                                            if attackName ~= "fireball" then
                                                isBlocked = true
                                                break
                                            end
                                        elseif WorldQueries.isLedgeBlockingPath(attacker.tileX, attacker.tileY + (i - 1) * dirY, attacker.tileX, attacker.tileY + i * dirY, world) then
                                            if attackName ~= "fireball" then
                                                isBlocked = true
                                                break
                                            end
                                        end
                                    end
                                else -- Horizontal line
                                    local dirX = (target.tileX > attacker.tileX) and 1 or -1
                                    for i = 1, dist - 1 do
                                        if WorldQueries.isTileOccupied(attacker.tileX + i * dirX, attacker.tileY, attacker, world) then
                                            if attackName ~= "fireball" then
                                                isBlocked = true
                                                break
                                            end
                                        end
                                    end
                                end

                                if not isBlocked then
                                    table.insert(validTargets, target)
                                end
                            end
                        elseif attackName == "phantom_step" then
                            local dx, dy = 0, 0
                            if target.lastDirection == "up" then dy = 1 elseif target.lastDirection == "down" then dy = -1 elseif target.lastDirection == "left" then dx = 1 elseif target.lastDirection == "right" then dx = -1 end
                            local behindTileX, behindTileY = target.tileX + dx, target.tileY + dy
                            if not WorldQueries.isTileOccupied(behindTileX, behindTileY, nil, world) then
                                table.insert(validTargets, target)
                            end
                        else
                            table.insert(validTargets, target)
                        end
                    end
                end
            end
        end
    elseif style == "auto_hit_all" then
        -- This style finds all valid targets within a given range.
        local potentialTargets = getPotentialTargets(attacker, attackData, world)
        local range = attackData.range

        if not range then return {} end

        for _, target in ipairs(potentialTargets) do
            if target.hp > 0 and math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY) <= range then
                table.insert(validTargets, target)
            end
        end

    elseif style == "directional_aim" then
        local patternFunc = AttackPatterns[attackName]
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
    end

    return validTargets    
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

return WorldQueries