-- modules/map_generator.lua
-- Contains logic for procedurally generating map content.

local Grid = require("modules.grid")
local ObjectBlueprints = require("data.object_blueprints")
local Config = require("config")

local MapGenerator = {}

-- Helper function to create a horizontal tunnel in the generation grid.
local function create_h_tunnel(x1, x2, y, grid)
    for x = math.min(x1, x2), math.max(x1, x2) do
        if grid[y] and grid[y][x] then
            grid[y][x] = 0 -- 0 represents a floor tile
        end
    end
end

-- Helper function to create a vertical tunnel in the generation grid.
local function create_v_tunnel(y1, y2, x, grid)
    for y = math.min(y1, y2), math.max(y1, y2) do
        if grid[y] and grid[y][x] then
            grid[y][x] = 0 -- 0 represents a floor tile
        end
    end
end

-- Helper function to create a room in the generation grid.
local function create_room(room, grid)
    for y = room.y, room.y + room.h - 1 do
        for x = room.x, room.x + room.w - 1 do
            if grid[y] and grid[y][x] then
                grid[y][x] = 0 -- Carve out the floor
            end
        end
    end
end

-- Generates content within a specific zone defined by a Tiled object.
function MapGenerator.generate(world, zone)
    -- Convert pixel coordinates of the zone to tile coordinates.
    local startTileX, startTileY = Grid.toTile(zone.x, zone.y)
    local endTileX, endTileY = Grid.toTile(zone.x + zone.width - 1, zone.y + zone.height - 1)
    local zoneWidth = endTileX - startTileX + 1
    local zoneHeight = endTileY - startTileY + 1

    -- Generation parameters are now defined earlier for the guard clause.
    local ROOM_MAX_SIZE = 10
    local ROOM_MIN_SIZE = 5

    -- New Guard Clause: Check if the zone is large enough to even attempt generation.
    if zoneWidth < ROOM_MIN_SIZE or zoneHeight < ROOM_MIN_SIZE then
        print(string.format("Map Generator SKIPPED: Zone at (%.0f, %.0f) is too small. Calculated tile size: %dx%d. Minimum required: %dx%d.", zone.x, zone.y, zoneWidth, zoneHeight, ROOM_MIN_SIZE, ROOM_MIN_SIZE))
        return -- Skip generation for this zone entirely.
    end

    local MAX_ROOMS = 15 -- The target number of rooms.
    local MAX_ATTEMPTS = 100 -- The number of times to try placing a room.

    -- A 2D grid to represent our generated zone. 1 = wall, 0 = floor.
    local zoneGrid = {}
    for y = 1, zoneHeight do
        zoneGrid[y] = {}
        for x = 1, zoneWidth do
            zoneGrid[y][x] = 1 -- Initialize everything as a wall
        end
    end

    local rooms = {}
    -- The loop now runs for MAX_ATTEMPTS, but will break early if enough rooms are placed.
    for i = 1, MAX_ATTEMPTS do
        -- Generate random room dimensions and position (relative to the zoneGrid)
        local w = love.math.random(ROOM_MIN_SIZE, ROOM_MAX_SIZE)
        local h = love.math.random(ROOM_MIN_SIZE, ROOM_MAX_SIZE)
        -- Ensure the zone is large enough for the room. If not, skip this attempt.
        if zoneWidth < w or zoneHeight < h then goto continue_room_loop end

        -- To ensure our guaranteed entrance logic works correctly, we prevent rooms from
        -- being placed flush against the left, right, and bottom edges. This creates a
        -- 1-tile border, forcing the generator to create explicit tunnels.
        local min_x = 2
        local max_x = zoneWidth - w
        -- Failsafe for very narrow zones where a border isn't possible.
        if max_x < min_x then
            min_x = 1
            max_x = zoneWidth - w + 1
        end

        local min_y = 1 -- No border needed at the top.
        local max_y = zoneHeight - h
        if max_y < min_y then
            max_y = zoneHeight - h + 1
        end

        local x = love.math.random(min_x, max_x)
        local y = love.math.random(min_y, max_y)

        local newRoom = { x = x, y = y, w = w, h = h }

        -- Check for intersections with existing rooms
        local failed = false
        for _, otherRoom in ipairs(rooms) do
            if newRoom.x < otherRoom.x + otherRoom.w and newRoom.x + newRoom.w > otherRoom.x and newRoom.y < otherRoom.y + otherRoom.h and newRoom.y + newRoom.h > otherRoom.y then
                failed = true
                break
            end
        end

        if not failed then
            create_room(newRoom, zoneGrid)
            local new_center_x = math.floor(newRoom.x + newRoom.w / 2)
            local new_center_y = math.floor(newRoom.y + newRoom.h / 2)

            if #rooms > 0 then
                local prev_room = rooms[#rooms]
                local prev_center_x = math.floor(prev_room.x + prev_room.w / 2)
                local prev_center_y = math.floor(prev_room.y + prev_room.h / 2)

                if love.math.random(2) == 1 then
                    create_h_tunnel(prev_center_x, new_center_x, prev_center_y, zoneGrid)
                    create_v_tunnel(prev_center_y, new_center_y, new_center_x, zoneGrid)
                else
                    create_v_tunnel(prev_center_y, new_center_y, prev_center_x, zoneGrid)
                    create_h_tunnel(prev_center_x, new_center_x, new_center_y, zoneGrid)
                end
            end
            table.insert(rooms, newRoom)

            -- New: Check if we have enough rooms and can exit the loop.
            if #rooms >= MAX_ROOMS then
                break
            end
        end
        ::continue_room_loop::
    end

    -- Failsafe: If no rooms were placed (e.g., zone is too small or too many collisions),
    -- carve out a single, simple room in the center to ensure the area is not a solid wall.
    if #rooms == 0 then
        print("Map Generator Warning: No rooms were placed. Carving a failsafe room.")
        -- New logic: Make the room proportional to the zone size, ensuring it always fits.
        -- The -2 ensures there's at least a 1-tile border for walls, if possible.
        local failsafe_w = math.max(1, math.min(zoneWidth - 2, math.floor(zoneWidth * 0.8)))
        local failsafe_h = math.max(1, math.min(zoneHeight - 2, math.floor(zoneHeight * 0.8)))
        local failsafe_x = math.floor((zoneWidth - failsafe_w) / 2) + 1
        local failsafe_y = math.floor((zoneHeight - failsafe_h) / 2) + 1

        -- Ensure failsafe room fits
        if failsafe_x > 0 and failsafe_y > 0 and failsafe_w > 0 and failsafe_h > 0 then
            local failsafe_room = { x = failsafe_x, y = failsafe_y, w = failsafe_w, h = failsafe_h }
            create_room(failsafe_room, zoneGrid)
            table.insert(rooms, failsafe_room) -- Add to rooms list for potential future logic
        end
    end

    -- New: Ensure the generated zone connects to the main map from the left, bottom, and right sides.
    do
        -- Helper to count contiguous segments of floor tiles on a given edge.
        local function count_entrances_on_edge(grid, edge_coords)
            local count = 0
            local in_segment = false
            for _, coord in ipairs(edge_coords) do
                if grid[coord.y] and grid[coord.y][coord.x] == 0 then
                    if not in_segment then
                        count = count + 1
                        in_segment = true
                    end
                else
                    in_segment = false
                end
            end
            return count
        end

        -- Helper to create a new entrance on a specified edge.
        local function create_entrance(edge_name, grid, floor_tiles)
            if #floor_tiles == 0 then
                print("Map Generator: Cannot create entrance, no floor tiles exist to connect to.")
                return
            end

            local start_x, start_y
            if edge_name == "left" then start_x, start_y = 1, love.math.random(2, zoneHeight - 1)
            elseif edge_name == "bottom" then start_x, start_y = love.math.random(2, zoneWidth - 1), zoneHeight
            elseif edge_name == "right" then start_x, start_y = zoneWidth, love.math.random(2, zoneHeight - 1)
            else return end -- Only handle specified edges.

            -- Find the closest floor tile to this new entrance point.
            local closest_tile = nil; local min_dist_sq = math.huge
            for _, tile in ipairs(floor_tiles) do
                local dist_sq = (tile.x - start_x)^2 + (tile.y - start_y)^2
                if dist_sq < min_dist_sq then min_dist_sq = dist_sq; closest_tile = tile end
            end

            -- Carve a tunnel from the new entrance to the closest floor tile.
            if closest_tile then
                if love.math.random(2) == 1 then create_h_tunnel(start_x, closest_tile.x, start_y, grid); create_v_tunnel(start_y, closest_tile.y, closest_tile.x, grid)
                else create_v_tunnel(start_y, closest_tile.y, start_x, grid); create_h_tunnel(start_x, closest_tile.x, closest_tile.y, grid) end
                print(string.format("Map Generator: Creating a guaranteed entrance on the %s edge.", edge_name))
            end
        end

        -- 1. Define the edges we need to check.
        local bottom_edge = {}
        for x = 1, zoneWidth do table.insert(bottom_edge, {x = x, y = zoneHeight}) end
        local left_edge = {}
        for y = 1, zoneHeight do table.insert(left_edge, {x = 1, y = y}) end
        local right_edge = {}
        for y = 1, zoneHeight do table.insert(right_edge, {x = zoneWidth, y = y}) end

        -- 2. Sequentially check each required edge. If an entrance is missing, we regenerate
        -- the list of all current floor tiles and then create a new entrance. This ensures
        -- that each new tunnel can connect to the full, updated dungeon layout.
        if count_entrances_on_edge(zoneGrid, left_edge) == 0 then
            local floor_tiles = {}
            for y = 1, zoneHeight do for x = 1, zoneWidth do if zoneGrid[y][x] == 0 then table.insert(floor_tiles, {x = x, y = y}) end end end
            create_entrance("left", zoneGrid, floor_tiles)
        end
        if count_entrances_on_edge(zoneGrid, bottom_edge) == 0 then
            local floor_tiles = {}
            for y = 1, zoneHeight do for x = 1, zoneWidth do if zoneGrid[y][x] == 0 then table.insert(floor_tiles, {x = x, y = y}) end end end
            create_entrance("bottom", zoneGrid, floor_tiles)
        end
        if count_entrances_on_edge(zoneGrid, right_edge) == 0 then
            local floor_tiles = {}
            for y = 1, zoneHeight do for x = 1, zoneWidth do if zoneGrid[y][x] == 0 then table.insert(floor_tiles, {x = x, y = y}) end end end
            create_entrance("right", zoneGrid, floor_tiles)
        end
    end

    -- Now, "paint" environmental features onto the floor tiles (0s) using noise.
    local NOISE_SCALE = 15 -- Smaller numbers = larger, smoother features. Larger numbers = more chaotic.
    for y = 1, zoneHeight do
        for x = 1, zoneWidth do
            if zoneGrid[y][x] == 0 then -- It's a floor tile
                -- We use the world tile coordinates for the noise function to ensure seamless noise across zones.
                local worldTileX = startTileX + x - 1
                local worldTileY = startTileY + y - 1
                local noiseVal = love.math.noise(worldTileX / NOISE_SCALE, worldTileY / NOISE_SCALE)

                -- The thresholds for noise values have been increased to make water and mud much rarer,
                -- resulting in more standard ground tiles.
                if noiseVal > 0.85 and world.map.template_water_tile then
                    zoneGrid[y][x] = 3 -- Mark as water
                elseif noiseVal > 0.7 and world.map.template_mud_tile then
                    zoneGrid[y][x] = 2 -- Mark as mud
                end
            end
        end
    end

    -- Finally, translate our zoneGrid into actual entities and map tiles in the world.
    -- We only need the ground layer to check if it exists.
    local groundLayer = world.map.layers["Ground"]

    -- Add a warning if the essential Ground layer is missing from the Tiled map.
    if not groundLayer then
        print("Map Generator ERROR: 'Ground' tile layer not found in map. Cannot place floor tiles.")
        return -- Stop generation if we can't place floors.
    end

    -- This table will be returned to the World to be processed into a single SpriteBatch.
    local procedural_tiles = { Ground = {}, Mud = {}, Water = {} }

    for y = 1, zoneHeight do
        for x = 1, zoneWidth do
            local tileType = zoneGrid[y][x]
            local worldTileX = startTileX + x - 1
            local worldTileY = startTileY + y - 1

            if tileType == 1 then -- Wall
                local blueprint = ObjectBlueprints.generated_wall
                if blueprint then
                    local pixelX, pixelY = Grid.toPixels(worldTileX, worldTileY)
                    local obstacle = { x = pixelX, y = pixelY, tileX = worldTileX, tileY = worldTileY, width = Config.SQUARE_SIZE, height = Config.SQUARE_SIZE, size = Config.SQUARE_SIZE, components = {} }
                    for k, v in pairs(blueprint) do obstacle[k] = v end
                    if obstacle.maxHp then obstacle.hp = obstacle.maxHp end
                    if not obstacle.statusEffects then obstacle.statusEffects = {} end
                    world:queue_add_entity(obstacle)
                end
            elseif tileType == 0 then -- Ground
                table.insert(procedural_tiles.Ground, { x = worldTileX, y = worldTileY })
            elseif tileType == 2 then -- Mud
                table.insert(procedural_tiles.Mud, { x = worldTileX, y = worldTileY })
            elseif tileType == 3 then -- Water
                table.insert(procedural_tiles.Water, { x = worldTileX, y = worldTileY })
            end
        end
    end

    print("Map generation complete for one zone. Returning tile data.")
    return procedural_tiles
end

return MapGenerator
