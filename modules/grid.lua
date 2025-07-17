-- grid.lua
-- A helper module for converting between tile coordinates and pixel coordinates.

local Grid = {}

-- Converts tile coordinates (e.g., 5, 3) to pixel coordinates (e.g., 160, 96).
function Grid.toPixels(tileX, tileY)
    local pixelX = tileX * Config.SQUARE_SIZE
    local pixelY = tileY * Config.SQUARE_SIZE
    return pixelX, pixelY
end

-- Converts pixel coordinates to the tile coordinates they fall within.
function Grid.toTile(pixelX, pixelY)
    local tileX = math.floor(pixelX / Config.SQUARE_SIZE)
    local tileY = math.floor(pixelY / Config.SQUARE_SIZE)
    return tileX, tileY
end

-- Calculates a destination point given a starting point, direction, and distance.
function Grid.getDestination(startX, startY, direction, distance)
    local destX, destY = startX, startY
    if direction == "up" then
        destY = startY - distance
    elseif direction == "down" then
        destY = startY + distance
    elseif direction == "left" then
        destX = startX - distance
    elseif direction == "right" then
        destX = startX + distance
    end
    return destX, destY
end

return Grid