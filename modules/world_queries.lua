-- world_queries.lua
-- Contains functions for querying the state of the game world, like collision checks.

local Grid = require("modules.grid")
local AttackPatterns = require("modules.attack_patterns")
local AttackBlueprints = require("data.attack_blueprints")

local WorldQueries = {}

function WorldQueries.isTileAnObstacle(tileX, tileY, world)
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
    if unit and unit.statusEffects and unit.statusEffects.paralyzed then
        return 0
    end
    -- In the future, this could also account for buffs/debuffs.
    return unit and unit.movement or 0
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
        local potentialTargets = getPotentialTargets(attacker, attackData, world)

        -- Special case for hookshot: also allow targeting any obstacle.
        if attackName == "hookshot" then
            for _, obstacle in ipairs(world.obstacles) do
                table.insert(potentialTargets, obstacle)
            end
        end

        -- Determine range
        local range = attackData.range
        if attackName == "phantom_step" then range = WorldQueries.getUnitMovement(attacker) end -- Dynamic range
        local minRange = attackData.min_range or 1

        if not range then return {} end -- Can't find targets for an attack without a defined range

        for _, target in ipairs(potentialTargets) do
            local isSelf = (target == attacker)
            
            local canBeTargeted = false
            if attackName == "hookshot" then
                -- Hookshot can target any non-self entity with weight, but not dead units.
                canBeTargeted = not isSelf and target.weight and not (target.hp and target.hp <= 0)
            else
                -- Standard targeting: not self, and not dead.
                canBeTargeted = not isSelf and not (target.hp and target.hp <= 0)
            end

            if canBeTargeted then
                local dist = math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY)
                if dist >= minRange and dist <= range then
                    -- Special validation for line-of-sight attacks (must be in a straight, unblocked line)
                    if attackData.line_of_sight_only then
                        local isStraightLine = (attacker.tileX == target.tileX or attacker.tileY == target.tileY)
                        if isStraightLine then
                            local isBlocked = false
                            if attacker.tileX == target.tileX then -- Vertical line
                                local dirY = (target.tileY > attacker.tileY) and 1 or -1
                                for i = 1, dist - 1 do
                                    if WorldQueries.isTileOccupied(attacker.tileX, attacker.tileY + i * dirY, attacker, world) then
                                        if attackName ~= "fireball" then isBlocked = true end
                                        break
                                    end
                                end
                            else -- Horizontal line
                                local dirX = (target.tileX > attacker.tileX) and 1 or -1
                                for i = 1, dist - 1 do
                                    if WorldQueries.isTileOccupied(attacker.tileX + i * dirX, attacker.tileY, attacker, world) then
                                        if attackName ~= "fireball" then isBlocked = true end
                                        break
                                    end
                                end
                            end

                            if not isBlocked then
                                table.insert(validTargets, target)
                            end
                        end
                    -- Special validation for phantom_step (tile behind must be empty)
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
    elseif style == "auto_hit_all" then
        -- This style doesn't need pre-calculated targets, it just hits.
        -- We can return a dummy table to indicate the attack is always valid if conditions are met.
        if attackName == "shockwave" then
            return {true}
        end -- Always available if you have enemies (validation done elsewhere).
        
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
        
    elseif style == "cycle_target" and attackName == "shockwave" then
        local potentialTargets = getPotentialTargets(attacker, attackData, world)
    
            -- Determine range
            local range = attackData.range
            if not range then return {} end -- Can't find targets for an attack without a defined range

            for _, target in ipairs(potentialTargets) do
                local isSelf = (target == attacker)
                local canBeTargeted = not isSelf and not (target.hp and target.hp <= 0)

                if canBeTargeted then
                    local dist = math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY)
                    if dist <= range then
                            table.insert(validTargets, target)
                    end
                end
            end
        end        
    return validTargets    
end

return WorldQueries