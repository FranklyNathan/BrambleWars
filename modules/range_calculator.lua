-- range_calculator.lua
-- Calculates the full attack range ("danger zone") for a given unit.

local Pathfinding = require("modules.pathfinding")
local AttackPatterns = require("modules.attack_patterns")
local AttackBlueprints = require("data.attack_blueprints")
local EnemyBlueprints = require("data.enemy_blueprints")
local CharacterBlueprints = require("data.character_blueprints")
local Grid = require("modules.grid")
local WorldQueries = require("modules.world_queries")

local RangeCalculator = {}

-- Calculates all tiles a unit can attack from any of its reachable positions.
-- It can also add new tiles to the reachableTiles table for special movement attacks like Phantom Step.
function RangeCalculator.calculateAttackableTiles(unit, world, reachableTiles)
    if not unit or not unit.movement or not reachableTiles then return {} end
 
    local attackableTiles = {} -- The final set of red "danger zone" tiles.
 
    local all_moves = WorldQueries.getUnitMoveList(unit)
    if #all_moves == 0 then return {} end
 
    -- 1. Pre-computation: Build a unified footprint for all fixed-shape attacks.
    local fixedFootprint = {}
    local complexAttacks = {} -- For attacks that need per-tile calculation.
 
    for _, attackName in ipairs(all_moves) do
        local attackData = AttackBlueprints[attackName]
        -- Check if the unit has enough wisp to use this attack.
        -- Also check if the attack is intended to create a danger zone.
        if attackData and unit.wisp >= (attackData.wispCost or 0) and attackData.createsDangerZone ~= false then
            local style = attackData.targeting_style
            local pattern = attackData.patternType and AttackPatterns[attackData.patternType]
 
            if style == "cycle_target" and pattern and type(pattern) == "table" then
                -- Case 1: Fixed shape pattern (e.g., standard_melee). Add to footprint.
                for _, pCoord in ipairs(pattern) do
                    fixedFootprint[pCoord.dx .. "," .. pCoord.dy] = true
                end
            elseif style == "cycle_target" and not pattern and attackData.range and not attackData.line_of_sight_only then
                -- Case 2: Diamond-shaped range (e.g., hookshot). Add to footprint.
                local range = attackData.range
                local minRange = attackData.min_range or 1
                for dx = -range, range do
                    for dy = -range, range do
                        if math.abs(dx) + math.abs(dy) <= range and math.abs(dx) + math.abs(dy) >= minRange then
                            fixedFootprint[dx .. "," .. dy] = true
                        end
                    end
                end
            else
                -- Case 3: All other attacks are "complex" and need per-tile calculation.
                -- This includes ground_aim, phantom_step, and directional/functional patterns.
                table.insert(complexAttacks, attackName)
            end
        end
    end

    -- 2. Apply the unified fixed footprint from every reachable tile.
    for posKey, data in pairs(reachableTiles) do
        if data.landable then
            local tileX = tonumber(string.match(posKey, "(-?%d+)"))
            local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
            for fpKey, _ in pairs(fixedFootprint) do
                local dx = tonumber(string.match(fpKey, "(-?%d+)"))
                local dy = tonumber(string.match(fpKey, ",(-?%d+)"))
                local attackTileX, attackTileY = tileX + dx, tileY + dy
                attackableTiles[attackTileX .. "," .. attackTileY] = true
            end
        end
    end

    -- 3. Process complex attacks from every reachable tile.
    if #complexAttacks > 0 then
        local tempUnit = {
            tileX = 0, tileY = 0, x = 0, y = 0,
            size = unit.size,
            lastDirection = "down",
            type = unit.type,
            movement = unit.movement
        }
        local directions = {"up", "down", "left", "right"}

        for posKey, data in pairs(reachableTiles) do
            if data.landable then
                local tileX = tonumber(string.match(posKey, "(-?%d+)"))
                local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
                tempUnit.tileX, tempUnit.tileY = tileX, tileY
                tempUnit.x, tempUnit.y = Grid.toPixels(tileX, tileY)

                for _, attackName in ipairs(complexAttacks) do
                    local attackData = AttackBlueprints[attackName]
                    if attackData then
                        if attackName == "phantom_step" then
                            local validTargets = WorldQueries.findValidTargetsForAttack(tempUnit, "phantom_step", world)
                            for _, target in ipairs(validTargets) do
                                attackableTiles[target.tileX .. "," .. target.tileY] = true
                                local dx_p, dy_p = 0, 0
                                if target.lastDirection == "up" then dy_p = 1 elseif target.lastDirection == "down" then dy_p = -1 elseif target.lastDirection == "left" then dx_p = 1 elseif target.lastDirection == "right" then dx_p = -1 end
                                local teleportTileX, teleportTileY = target.tileX + dx_p, target.tileY + dy_p
                                local newReachableKey = teleportTileX .. "," .. teleportTileY
                                if not reachableTiles[newReachableKey] then
                                    -- Add the tile to the reachable set so it's drawn in blue,
                                    -- but mark it as NOT landable so the player can't move to it directly.
                                    reachableTiles[newReachableKey] = { cost = -1, landable = false }
                                end
                            end
                        elseif attackData.targeting_style == "ground_aim" then
                            local range = attackData.range
                            if range then
                                for dx = -range, range do
                                    for dy = -range, range do
                                        if math.abs(dx) + math.abs(dy) <= range then
                                            local aimTileX, aimTileY = tileX + dx, tileY + dy
                                            if attackName == "eruption" then
                                                local aoeRadius = 2
                                                for aoeX = aimTileX - aoeRadius, aimTileX + aoeRadius do
                                                    for aoeY = aimTileY - aoeRadius, aimTileY + aoeRadius do
                                                        attackableTiles[aoeX .. "," .. aoeY] = true
                                                    end
                                                end
                                            else
                                                attackableTiles[aimTileX .. "," .. aimTileY] = true
                                            end
                                        end
                                    end
                                end
                            end
                        elseif attackData.targeting_style == "cycle_target" and attackData.patternType and type(AttackPatterns[attackData.patternType]) == "function" then
                            local patternFunc = AttackPatterns[attackData.patternType]
                            for _, dir in ipairs(directions) do
                                tempUnit.lastDirection = dir
                                local attackShapes = patternFunc(tempUnit, world)
                                for _, effectData in ipairs(attackShapes) do
                                    local s = effectData.shape
                                    local startTileX, startTileY = Grid.toTile(s.x, s.y)
                                    local endTileX, endTileY = Grid.toTile(s.x + s.w - 1, s.y + s.h - 1)
                                    for ty = startTileY, endTileY do for tx = startTileX, endTileX do attackableTiles[tx .. "," .. ty] = true end end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return attackableTiles
end

-- Calculates the attack range for a single, specific attack from the unit's current position.
function RangeCalculator.calculateSingleAttackRange(unit, attackName, world)
    local attackData = AttackBlueprints[attackName]
    if not attackData then return {} end

    local attackableTiles = {}
    local tempUnit = { -- Use a temp unit to avoid modifying the real one's direction
        tileX = unit.tileX,
        tileY = unit.tileY,
        x = unit.x,
        y = unit.y,
        size = unit.size,
        lastDirection = unit.lastDirection,
        type = unit.type
    }
    local directions = {"up", "down", "left", "right"}

    if attackData.targeting_style == "cycle_target" then
        local pattern = attackData.patternType and AttackPatterns[attackData.patternType]
        if pattern and type(pattern) == "table" then
            -- Fixed-shape patterns (melee, longshot_range, etc.)
            for _, patternCoord in ipairs(pattern) do
                local attackTileX = tempUnit.tileX + patternCoord.dx
                local attackTileY = tempUnit.tileY + patternCoord.dy
                if attackTileX >= 0 and attackTileX < world.map.width and attackTileY >= 0 and attackTileY < world.map.height then
                    attackableTiles[attackTileX .. "," .. attackTileY] = true
                end
            end
        elseif pattern and type(pattern) == "function" then
            -- Functional patterns (line_of_sight)
            for _, dir in ipairs(directions) do
                tempUnit.lastDirection = dir
                local attackShapes = pattern(tempUnit, world)
                for _, effectData in ipairs(attackShapes) do
                    local s = effectData.shape
                    local startTileX, startTileY = Grid.toTile(s.x, s.y)
                    local endTileX, endTileY = Grid.toTile(s.x + s.w - 1, s.y + s.h - 1)
                    for ty = startTileY, endTileY do
                        for tx = startTileX, endTileX do
                            attackableTiles[tx .. "," .. ty] = true
                        end
                    end
                end
            end
        end
    elseif attackData.targeting_style == "ground_aim" then
        local range = attackData.range
        if range then
            -- For ground_aim, the "danger zone" is the set of all tiles that can be aimed at.
            for dx = -range, range do
                for dy = -range, range do
                    if math.abs(dx) + math.abs(dy) <= range then
                        local aimTileX, aimTileY = tempUnit.tileX + dx, tempUnit.tileY + dy
                        if aimTileX >= 0 and aimTileX < world.map.width and aimTileY >= 0 and aimTileY < world.map.height then
                            attackableTiles[aimTileX .. "," .. aimTileY] = true
                        end
                    end
                end
            end
        end
    elseif attackData.targeting_style == "auto_hit_all" then
        -- For auto_hit_all, the danger zone is all tiles within range.
        local range = attackData.range
        if range then
            for dx = -range, range do
                for dy = -range, range do
                    if math.abs(dx) + math.abs(dy) <= range then
                        local attackTileX, attackTileY = tempUnit.tileX + dx, tempUnit.tileY + dy
                        if attackTileX >= 0 and attackTileX < world.map.width and attackTileY >= 0 and attackTileY < world.map.height then
                            attackableTiles[attackTileX .. "," .. attackTileY] = true
                        end
                    end
                end
            end
        end
    end

    return attackableTiles
end

return RangeCalculator