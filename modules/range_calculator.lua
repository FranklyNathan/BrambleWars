-- range_calculator.lua
-- Calculates the full attack range ("danger zone") for a given unit.

local Pathfinding = require("modules.pathfinding")
local AttackPatterns = require("modules.attack_patterns")
local AttackBlueprints = require("data.attack_blueprints")
local CharacterBlueprints = require("data.character_blueprints")
local Grid = require("modules.grid")
local WorldQueries = require("modules.world_queries")

local RangeCalculator = {}

-- Calculates all tiles a unit can attack from any of its reachable positions.
-- It can also add new tiles to the reachableTiles table for special movement attacks like Phantom Step.
function RangeCalculator.calculateAttackableTiles(unit, world, reachableTiles)
    if not unit or not unit.movement or not unit.playerType or not reachableTiles then return {} end

    local attackableTiles = {} -- The final set of red "danger zone" tiles.
    local processedReachable = {} -- A set to track tiles we've already processed to prevent infinite loops.
    local tileQueue = {} -- A queue of reachable tiles to process.

    -- 1. Initialize the queue with all starting reachable tiles.
    for posKey, _ in pairs(reachableTiles) do
        table.insert(tileQueue, posKey)
    end

    local blueprint = CharacterBlueprints[unit.playerType]
    if not blueprint or not blueprint.attacks then return {} end

    -- Create a temporary unit to simulate positions and directions.
    local tempUnit = {
        tileX = 0, tileY = 0,
        x = 0, y = 0,
        size = unit.size,
        lastDirection = "down",
        -- Copy necessary fields for WorldQueries to work correctly
        type = unit.type,
        movement = unit.movement
    }
    local directions = {"up", "down", "left", "right"}

    -- 2. Process the queue until it's empty. This is more robust than a simple for loop.
    local head = 1
    while head <= #tileQueue do
        local posKey = tileQueue[head]
        head = head + 1

        if not processedReachable[posKey] then
            processedReachable[posKey] = true

            local tileX = tonumber(string.match(posKey, "(-?%d+)"))
            local tileY = tonumber(string.match(posKey, ",(-?%d+)"))

            -- Update the temp unit's position
            tempUnit.tileX, tempUnit.tileY = tileX, tileY
            tempUnit.x, tempUnit.y = Grid.toPixels(tileX, tileY)

            -- ...check every attack it has...
            for _, attackName in ipairs(blueprint.attacks) do
                local attackData = AttackBlueprints[attackName]
                if attackData then
                    if attackName == "phantom_step" then
                        -- Find valid targets for Phantom Step from the current simulated position.
                        local validTargets = WorldQueries.findValidTargetsForAttack(tempUnit, "phantom_step", world)
                        for _, target in ipairs(validTargets) do
                            -- The target's tile is part of the danger zone.
                            attackableTiles[target.tileX .. "," .. target.tileY] = true
                            -- Calculate the destination tile behind the target.
                            local dx, dy = 0, 0
                            if target.lastDirection == "up" then dy = 1
                            elseif target.lastDirection == "down" then dy = -1
                            elseif target.lastDirection == "left" then dx = 1
                            elseif target.lastDirection == "right" then dx = -1
                            end
                            local teleportTileX, teleportTileY = target.tileX + dx, target.tileY + dy
                            local newReachableKey = teleportTileX .. "," .. teleportTileY

                            -- If this is a new reachable tile, add it to the list of blue tiles.
                            -- We do NOT add it to the tileQueue, because Phantom Step is a turn-ending attack.
                            -- This prevents the danger zone from showing attacks from the teleport destination.
                            if not reachableTiles[newReachableKey] then
                                reachableTiles[newReachableKey] = true
                            end
                        end
                    elseif attackData.targeting_style == "cycle_target" then
                        -- Handle cycle_target attacks (like slash) by calculating their Manhattan distance range.
                        local range = attackData.range
                        local minRange = attackData.min_range or 1
                        if range then
                            -- From the current reachable tile (tileX, tileY), find all tiles within attack range.
                            for dx = -range, range do
                                for dy = -range, range do
                                    local manhattanDist = math.abs(dx) + math.abs(dy)
                                    if manhattanDist >= minRange and manhattanDist <= range then
                                        local attackTileX, attackTileY = tileX + dx, tileY + dy
                                        -- Check map bounds before adding.
                                        if attackTileX >= 0 and attackTileX < world.map.width and attackTileY >= 0 and attackTileY < world.map.height then
                                            attackableTiles[attackTileX .. "," .. attackTileY] = true
                                        end
                                    end
                                end
                            end
                        end
                    elseif attackData.targeting_style == "ground_aim" then
                        local range = attackData.range
                        if range then
                            -- From the current reachable tile (tileX, tileY), find all possible aim points.
                            for dx = -range, range do
                                for dy = -range, range do
                                    if math.abs(dx) + math.abs(dy) <= range then
                                        local aimTileX, aimTileY = tileX + dx, tileY + dy

                                        -- Now, for each aim point, calculate the attack's AoE.
                                        -- For Eruption, the final AoE is a 5x5 square.
                                        -- We add a specific check for the attack name to avoid affecting other ground_aim attacks.
                                        if attackName == "eruption" then
                                            local aoeRadius = 2 -- 2 tiles in each direction for a 5x5 area.
                                            for aoeX = aimTileX - aoeRadius, aimTileX + aoeRadius do
                                                for aoeY = aimTileY - aoeRadius, aimTileY + aoeRadius do
                                                    attackableTiles[aoeX .. "," .. aoeY] = true
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    else -- Handle directional patterns
                        local patternFunc = AttackPatterns[attackName]
                        if patternFunc then
                            -- ...in every possible direction.
                            for _, dir in ipairs(directions) do
                                tempUnit.lastDirection = dir
                                local attackShapes = patternFunc(tempUnit, world)
                                -- Convert the shapes' pixel coordinates back to tiles and add to the set.
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

return RangeCalculator