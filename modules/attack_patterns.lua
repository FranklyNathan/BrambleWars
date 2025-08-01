-- attack_patterns.lua
-- A library of attack patterns. Patterns can be either a table of relative
-- tile coordinates (for fixed shapes) or a function that generates shapes
-- (for dynamic or complex areas of effect).

local AttackPatterns = {}
local Grid = require("modules.grid")

--------------------------------------------------------------------------------
-- FIXED SHAPE PATTERNS (TABLES OF RELATIVE COORDINATES)
--------------------------------------------------------------------------------

-- The 4 adjacent tiles (up, down, left, right).
AttackPatterns.standard_melee = {
    {dx = 0, dy = -1}, {dx = 0, dy = 1}, {dx = -1, dy = 0}, {dx = 1, dy = 0},
}

-- Tiles at range 2 (cardinal) and diagonals at range 1. Does not hit adjacent tiles.
AttackPatterns.standard_ranged = {
    {dx = 0, dy = -2}, {dx = 0, dy = 2}, {dx = -2, dy = 0}, {dx = 2, dy = 0}, -- 2 away cardinal
    {dx = -1, dy = -1}, {dx = -1, dy = 1}, {dx = 1, dy = -1}, {dx = 1, dy = 1}, -- diagonals
}

-- A combination of standard_melee and standard_ranged. Hits all tiles up to range 2, including diagonals.
AttackPatterns.standard_all = {
    -- Melee
    {dx = 0, dy = -1}, {dx = 0, dy = 1}, {dx = -1, dy = 0}, {dx = 1, dy = 0},
    -- Ranged
    {dx = 0, dy = -2}, {dx = 0, dy = 2}, {dx = -2, dy = 0}, {dx = 2, dy = 0},
    {dx = -1, dy = -1}, {dx = -1, dy = 1}, {dx = 1, dy = -1}, {dx = 1, dy = 1},
}

-- Can only hit targets exactly 3 tiles away (Manhattan distance).
AttackPatterns.extended_range_only = {
    {dx = 0, dy = -3}, {dx = 0, dy = 3}, {dx = -3, dy = 0}, {dx = 3, dy = 0},
    {dx = -1, dy = -2}, {dx = -1, dy = 2}, {dx = 1, dy = -2}, {dx = 1, dy = 2},
    {dx = -2, dy = -1}, {dx = -2, dy = 1}, {dx = 2, dy = -1}, {dx = 2, dy = 1},
}

-- Can hit targets 2-3 tiles away (Manhattan distance).
AttackPatterns.longshot_range = {
    -- Range 2
    {dx = 0, dy = -2}, {dx = 0, dy = 2}, {dx = -2, dy = 0}, {dx = 2, dy = 0},
    {dx = -1, dy = -1}, {dx = -1, dy = 1}, {dx = 1, dy = -1}, {dx = 1, dy = 1},
    -- Range 3
    {dx = 0, dy = -3}, {dx = 0, dy = 3}, {dx = -3, dy = 0}, {dx = 3, dy = 0},
    {dx = -1, dy = -2}, {dx = -1, dy = 2}, {dx = 1, dy = -2}, {dx = 1, dy = 2},
    {dx = -2, dy = -1}, {dx = -2, dy = 1}, {dx = 2, dy = -1}, {dx = 2, dy = 1},
}

--------------------------------------------------------------------------------
-- DYNAMIC PATTERNS (FUNCTIONS)
--------------------------------------------------------------------------------
-- Used by archers, Venusaur Square, etc.
function AttackPatterns.line_of_sight(entity, world)
    local sx, sy, size = entity.x, entity.y, entity.size
    local mapWidth, mapHeight = world.map.width * world.map.tilewidth, world.map.height * world.map.tileheight
    local attackOriginX, attackOriginY, attackWidth, attackHeight

    if entity.lastDirection == "up" then
        attackOriginX, attackOriginY = sx, 0
        attackWidth, attackHeight = size, sy
    elseif entity.lastDirection == "down" then
        attackOriginX, attackOriginY = sx, sy + size
        attackWidth, attackHeight = size, mapHeight - (sy + size)
    elseif entity.lastDirection == "left" then
        attackOriginX, attackOriginY = 0, sy
        attackWidth, attackHeight = sx, size
    elseif entity.lastDirection == "right" then
        attackOriginX, attackOriginY = sx + size, sy
        attackWidth, attackHeight = mapWidth - (sx + size), size
    end
    return {{shape = {type = "rect", x = attackOriginX, y = attackOriginY, w = attackWidth, h = attackHeight}, delay = 0}}
end

-- Creates a 3-stage expanding ripple pattern.
-- This function now generates individual tiles for each stage of the explosion
-- to create non-square shapes, instead of large rectangles.
function AttackPatterns.eruption_aoe(centerX, centerY, rippleCenterSize)
    local centerTileX, centerTileY = Grid.toTile(centerX, centerY)
    local pattern = {}
    local step = Config.SQUARE_SIZE

    -- Define the tile patterns for each stage of the explosion.
    local stage1_tiles = { {dx = 0, dy = 0} } -- Center tile
    local stage2_tiles = AttackPatterns.standard_melee -- 1-range "+" shape
    local stage3_tiles = AttackPatterns.standard_ranged -- 2-range diamond shape

    -- Helper to add a stage's tiles to the main pattern list.
    local function add_stage_to_pattern(tiles, delay)
        for _, coord in ipairs(tiles) do
            local tileX, tileY = centerTileX + coord.dx, centerTileY + coord.dy
            local pixelX, pixelY = Grid.toPixels(tileX, tileY)
            table.insert(pattern, {
                shape = {type = "rect", x = pixelX, y = pixelY, w = step, h = step},
                delay = delay
            })
        end
    end

    -- Generate the full pattern with appropriate delays for each stage.
    add_stage_to_pattern(stage1_tiles, 0)
    add_stage_to_pattern(stage2_tiles, Config.FLASH_DURATION)
    add_stage_to_pattern(stage3_tiles, Config.FLASH_DURATION * 2)

    return pattern
end

-- Generates preview shapes for ground-targeted attacks.
function AttackPatterns.getGroundAimPreviewShapes(attackName, centerTileX, centerTileY)
    local pixelX, pixelY = Grid.toPixels(centerTileX, centerTileY)

    if attackName == "grovecall" or attackName == "trap_set" then
        -- A simple 1x1 tile preview.
        return {{shape = {type = "rect", x = pixelX, y = pixelY, w = Config.SQUARE_SIZE, h = Config.SQUARE_SIZE}, delay = 0}}
    elseif attackName == "eruption" then
        -- Center the ripple on the middle of the target tile.
        local centerX = pixelX + Config.SQUARE_SIZE / 2
        local centerY = pixelY + Config.SQUARE_SIZE / 2
        return AttackPatterns.eruption_aoe(centerX, centerY, 1)
    elseif attackName == "quick_step" then
        -- A simple 1x1 tile preview for the dash destination.
        return {{shape = {type = "rect", x = pixelX, y = pixelY, w = Config.SQUARE_SIZE, h = Config.SQUARE_SIZE}, delay = 0}}
    end

    return {} -- Default to no preview
end

return AttackPatterns