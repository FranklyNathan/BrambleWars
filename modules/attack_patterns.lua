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
function AttackPatterns.eruption_aoe(centerX, centerY, rippleCenterSize)
    local step = Config.SQUARE_SIZE
    local size1 = rippleCenterSize * step
    local size2 = (rippleCenterSize + 2) * step
    local size3 = (rippleCenterSize + 4) * step
    return {
        {shape = {type = "rect", x = centerX - size1 / 2, y = centerY - size1 / 2, w = size1, h = size1}, delay = 0},
        {shape = {type = "rect", x = centerX - size2 / 2, y = centerY - size2 / 2, w = size2, h = size2}, delay = Config.FLASH_DURATION},
        {shape = {type = "rect", x = centerX - size3 / 2, y = centerY - size3 / 2, w = size3, h = size3}, delay = Config.FLASH_DURATION * 2},
    }
end

return AttackPatterns