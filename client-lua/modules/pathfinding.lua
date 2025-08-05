-- pathfinding.lua
-- Contains pathfinding algorithms for turn-based movement.

local WorldQueries = require("modules.world_queries")
local Grid = require("modules.grid")

local Pathfinding = {}

-- Calculates all valid landing tiles for a unit using Breadth-First Search (BFS).
-- Also returns the path data required to reconstruct the path to any tile.
function Pathfinding.calculateReachableTiles(startUnit, world)
    local reachable = {} -- Stores valid landing spots and their movement cost.
    local came_from = {} -- Stores path history for reconstruction.
    local frontier = {{tileX = startUnit.tileX, tileY = startUnit.tileY, cost = 0}} -- The queue of tiles to visit.
    local cost_so_far = {} -- Stores the cost to reach any visited tile (including invalid landing spots for flying units).
    local startPosKey = startUnit.tileX .. "," .. startUnit.tileY

    cost_so_far[startPosKey] = 0
    -- The starting tile is always a valid "landing" spot. The value is now a table.
    reachable[startPosKey] = { cost = 0, landable = true }

    local unitMovement = WorldQueries.getUnitMovement(startUnit)

    local head = 1
    while head <= #frontier do
        local current = frontier[head]
        head = head + 1

        local neighbors = {
            {dx = 0, dy = -1}, -- Up
            {dx = 0, dy = 1},  -- Down
            {dx = -1, dy = 0}, -- Left
            {dx = 1, dy = 0}   -- Right
        }

        -- Explore neighbors
        for _, move in ipairs(neighbors) do
            local nextTileX, nextTileY = current.tileX + move.dx, current.tileY + move.dy
            
            -- New: Determine movement cost for the tile.
            local moveCost = 1
            if WorldQueries.isTileMud(nextTileX, nextTileY, world) and not startUnit.isFlying then
                moveCost = 2
            end

            local nextCost = current.cost + moveCost
            local nextPosKey = nextTileX .. "," .. nextTileY
            
            -- Check if the neighbor is within map boundaries before proceeding.
            if nextTileX >= 0 and nextTileX < world.map.width and nextTileY >= 0 and nextTileY < world.map.height then                
                if nextCost <= unitMovement then
                    -- If we haven't visited this tile, or found a cheaper path to it
                    if not cost_so_far[nextPosKey] or nextCost < cost_so_far[nextPosKey] then                        
                        -- New logic incorporating impassable obstacles and water tiles.
                        local obstacle = WorldQueries.getObstacleAt(nextTileX, nextTileY, world)
                        local occupyingUnit = WorldQueries.getUnitAt(nextTileX, nextTileY, startUnit, world)
                        local isLedgeBlocked = WorldQueries.isLedgeBlockingPath(current.tileX, current.tileY, nextTileX, nextTileY, world)

                        local canPass = true -- Assume passable unless a condition fails.

                        if isLedgeBlocked then
                            canPass = false
                        elseif WorldQueries.isTileWater(nextTileX, nextTileY, world) then
                            local hasFrozenfoot = WorldQueries.hasPassive(startUnit, "Frozenfoot", world)
                            if not (startUnit.isFlying or startUnit.canSwim or hasFrozenfoot) then
                                canPass = false
                            end
                        elseif obstacle then
                            if obstacle.isImpassable then
                                canPass = false
                            elseif obstacle.objectType ~= "molehill" and not obstacle.isTrap then
                                -- Regular obstacles like trees can only be passed by flying units.
                                if not startUnit.isFlying then
                                    canPass = false
                                end
                            end
                            -- Molehills and traps are always passable.
                        elseif occupyingUnit then
                            -- Flying units can pass over other units.
                            if not startUnit.isFlying then
                                if occupyingUnit.type ~= startUnit.type then -- It's an enemy
                                    local hasElusive = false
                                    if world.teamPassives[startUnit.type].Elusive then
                                        for _, provider in ipairs(world.teamPassives[startUnit.type].Elusive) do
                                            if provider == startUnit then hasElusive = true; break end
                                        end
                                    end
                                    if not hasElusive then
                                        canPass = false
                                    end
                                end
                                -- Allies are always passable for ground units.
                            end
                        end

                        if canPass then
                            cost_so_far[nextPosKey] = nextCost
                            came_from[nextPosKey] = {tileX = current.tileX, tileY = current.tileY}
                            -- Use the centralized query to determine if the tile is landable.
                            local canLand = WorldQueries.isTileLandable(nextTileX, nextTileY, startUnit, world)
                            reachable[nextPosKey] = { cost = nextCost, landable = canLand }
                            table.insert(frontier, {tileX = nextTileX, tileY = nextTileY, cost = nextCost})
                        end
                    end
                end
            end
        end
    end

    return reachable, came_from, cost_so_far
end

-- Reconstructs a path from a 'came_from' map generated by a search algorithm.
-- Returns a list of *pixel* coordinates to follow, for the MovementSystem.
-- It now prioritizes the path the cursor took if it's a valid shortest path.
function Pathfinding.reconstructPath(came_from, cost_so_far, cursorPath, startPosKey, goalPosKey)
    local path = {}
    local currentKey = goalPosKey

    -- Create a mutable copy of the cursor path to track which steps we've used.
    local cursorPathHistory = {}
    if cursorPath then
        for _, p in ipairs(cursorPath) do table.insert(cursorPathHistory, p) end
    end

    while currentKey and currentKey ~= startPosKey do
        local tileX = tonumber(string.match(currentKey, "(-?%d+)"))
        local tileY = tonumber(string.match(currentKey, ",(-?%d+)"))
        local pixelX, pixelY = Grid.toPixels(tileX, tileY)
        table.insert(path, 1, {x = pixelX, y = pixelY})

        local currentCost = cost_so_far[currentKey]
        if not currentCost then break end -- Failsafe

        local preferredPrevKey = nil

        -- Search backwards through the user's cursor path history.
        -- We want to find the most recent valid, optimal step.
        for i = #cursorPathHistory, 1, -1 do
            local historyTile = cursorPathHistory[i]
            local historyKey = historyTile.x .. "," .. historyTile.y

            -- Check if this historical tile is adjacent to our current tile.
            local isAdjacent = (math.abs(historyTile.x - tileX) + math.abs(historyTile.y - tileY)) == 1

            -- Check if it's an optimal step (cost is one less).
            if isAdjacent and cost_so_far[historyKey] and cost_so_far[historyKey] == currentCost - 1 then
                preferredPrevKey = historyKey
                -- Remove this step from history so we don't consider it again.
                table.remove(cursorPathHistory, i)
                break -- Found our preferred step, stop searching.
            end
        end

        -- If we found a preferred step in the cursor's history, use it.
        if preferredPrevKey then
            currentKey = preferredPrevKey
        -- Otherwise, fall back to the default path from the 'came_from' map.
        elseif came_from[currentKey] then
            local prevNode = came_from[currentKey]
            currentKey = prevNode.tileX .. "," .. prevNode.tileY
        else
            currentKey = nil -- Path is broken, stop.
        end
    end
    return path
end

return Pathfinding