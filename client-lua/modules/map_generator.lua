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

        -- Correctly calculate the max starting position for the room.
        local x = love.math.random(1, zoneWidth - w + 1)
        local y = love.math.random(1, zoneHeight - h + 1)

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

    -- Now, "paint" environmental features onto the floor tiles (0s) using noise.
    local NOISE_SCALE = 15 -- Smaller numbers = larger, smoother features. Larger numbers = more chaotic.
    for y = 1, zoneHeight do
        for x = 1, zoneWidth do
            if zoneGrid[y][x] == 0 then -- It's a floor tile
                -- We use the world tile coordinates for the noise function to ensure seamless noise across zones.
                local worldTileX = startTileX + x - 1
                local worldTileY = startTileY + y - 1
                local noiseVal = love.math.noise(worldTileX / NOISE_SCALE, worldTileY / NOISE_SCALE)

                if noiseVal > 0.6 and world.map.template_water_tile then
                    zoneGrid[y][x] = 3 -- Mark as water
                elseif noiseVal > 0.3 and world.map.template_mud_tile then
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
