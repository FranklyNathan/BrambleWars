-- camera.lua
-- Manages the position and movement of the game's camera.

local Grid = require("modules.grid")
local Config = require("config")

local Camera = {}

-- Initialize the camera's state
Camera.x = 0
Camera.y = 0

-- The update function is called every frame to move the camera smoothly.
function Camera.update(dt, world)
    -- Get cursor position in pixels.
    local cursorPixelX, cursorPixelY = Grid.toPixels(world.mapCursorTile.x, world.mapCursorTile.y)
    local cursorSize = Config.SQUARE_SIZE

    -- 1. By default, the camera's target is its current position (it doesn't move).
    local targetX, targetY = Camera.x, Camera.y

    -- 2. Define a margin for edge-scrolling. The camera will move when the cursor enters this area.
    local scrollMargin = 0 -- Scroll only when the cursor is at the very edge of the screen.

    -- Get map dimensions in pixels to check against boundaries.
    local mapPixelWidth = world.map.width * world.map.tilewidth
    local mapPixelHeight = world.map.height * world.map.tileheight

    -- 3. Check if the cursor is in the margin and update the camera's target position.
    -- This creates a "dead zone" in the center of the screen where the camera doesn't move.

    -- Horizontal Scrolling
    if cursorPixelX < Camera.x + scrollMargin then
        -- Cursor is in the left margin, move camera left.
        targetX = cursorPixelX - scrollMargin
    elseif cursorPixelX + cursorSize > Camera.x + Config.VIRTUAL_WIDTH - scrollMargin then
        -- Cursor is in the right margin, move camera right.
        targetX = cursorPixelX + cursorSize - (Config.VIRTUAL_WIDTH - scrollMargin)
    end

    -- Vertical Scrolling
    if cursorPixelY < Camera.y + scrollMargin then
        -- Cursor is in the top margin, move camera up.
        targetY = cursorPixelY - scrollMargin
    elseif cursorPixelY + cursorSize > Camera.y + Config.VIRTUAL_HEIGHT - scrollMargin then
        -- Cursor is in the bottom margin, move camera down.
        targetY = cursorPixelY + cursorSize - (Config.VIRTUAL_HEIGHT - scrollMargin)
    end

    -- 4. Clamp the TARGET position to the map boundaries. This ensures the camera
    -- never tries to move towards a point outside the map, allowing the lerp
    -- to function correctly at the edges.
    targetX = math.max(0, math.min(targetX, mapPixelWidth - Config.VIRTUAL_WIDTH))
    targetY = math.max(0, math.min(targetY, mapPixelHeight - Config.VIRTUAL_HEIGHT))

    -- 5. Smoothly move the camera towards the (now clamped) target position.
    local lerpFactor = 0.2 -- A higher value makes the camera "snappier".
    Camera.x = Camera.x + (targetX - Camera.x) * lerpFactor
    Camera.y = Camera.y + (targetY - Camera.y) * lerpFactor
    
    -- Snap to the target position if the camera is very close. This prevents the
    -- camera from having tiny decimal values when it should be stationary, and
    -- ensures it can reach its final destination perfectly. This fixes the "sticking"
    -- at the edge of the screen.
    local snapThreshold = 0.5 -- Snap if within half a pixel.
    if math.abs(targetX - Camera.x) < snapThreshold then Camera.x = targetX end
    if math.abs(targetY - Camera.y) < snapThreshold then Camera.y = targetY end

end

-- Applies the camera's transformation to the graphics stack.
function Camera.apply()
    love.graphics.push()
    love.graphics.translate(-math.floor(Camera.x), -math.floor(Camera.y))
end

-- Reverts the camera's transformation.
function Camera.revert()
    love.graphics.pop()
end

return Camera