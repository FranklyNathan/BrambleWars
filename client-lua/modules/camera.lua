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
    local targetX, targetY

    -- Prioritize focusing on a specific entity if one is set (e.g., for watching enemy turns).
    if world.ui.cameraFocusEntity then
        local entity = world.ui.cameraFocusEntity
        -- Target the center of the entity.
        targetX = entity.x - (Config.VIRTUAL_WIDTH / 2) + (entity.size / 2)
        targetY = entity.y - (Config.VIRTUAL_HEIGHT / 2) + (entity.size / 2)
    else
        -- Original cursor-following logic for when there's no specific focus.
        local cursorPixelX, cursorPixelY = Grid.toPixels(world.ui.mapCursorTile.x, world.ui.mapCursorTile.y)
        local cursorSize = Config.SQUARE_SIZE

        -- By default, the camera's target is its current position (it doesn't move).
        targetX, targetY = Camera.x, Camera.y

        -- Define a margin for edge-scrolling.
        local horizontalScrollMargin = 4 * Config.SQUARE_SIZE
        local verticalScrollMargin = 3 * Config.SQUARE_SIZE

        -- Horizontal Scrolling
        if cursorPixelX < Camera.x + horizontalScrollMargin then
            targetX = cursorPixelX - horizontalScrollMargin
        elseif cursorPixelX + cursorSize > Camera.x + Config.VIRTUAL_WIDTH - horizontalScrollMargin then
            targetX = cursorPixelX + cursorSize - (Config.VIRTUAL_WIDTH - horizontalScrollMargin)
        end

        -- Vertical Scrolling
        if cursorPixelY < Camera.y + verticalScrollMargin then
            targetY = cursorPixelY - verticalScrollMargin
        elseif cursorPixelY + cursorSize > Camera.y + Config.VIRTUAL_HEIGHT - verticalScrollMargin then
            targetY = cursorPixelY + cursorSize - (Config.VIRTUAL_HEIGHT - verticalScrollMargin)
        end
    end

    -- Get map dimensions in pixels to check against boundaries.
    local mapPixelWidth = world.map.width * world.map.tilewidth
    local mapPixelHeight = world.map.height * world.map.tileheight

    -- Clamp the TARGET position to the map boundaries.
    targetX = math.max(0, math.min(targetX, mapPixelWidth - Config.VIRTUAL_WIDTH))
    targetY = math.max(0, math.min(targetY, mapPixelHeight - Config.VIRTUAL_HEIGHT))

    -- If there is a focus entity, we want the camera to be locked, not smoothly moving.
    -- However, we still need a smooth pan *to* the focus entity. This is handled in the
    -- EnemyTurnSystem's "panning_camera" phase. For all other times, we check if we are
    -- already focused. If not, we lerp. If we are, we stay put.
    if world.ui.cameraFocusEntity then
        local snapThreshold = 0.5
        local isAtTarget = math.abs(targetX - Camera.x) < snapThreshold and math.abs(targetY - Camera.y) < snapThreshold
        if not isAtTarget then
            -- Smoothly move towards the target.
            local lerpFactor = 0.2
            Camera.x = Camera.x + (targetX - Camera.x) * lerpFactor
            Camera.y = Camera.y + (targetY - Camera.y) * lerpFactor
        end
        -- Once at the target, the camera will stop moving until the focus changes.
    else
        -- No focus entity, so always use smooth movement for the player cursor.
        local lerpFactor = 0.2
        Camera.x = Camera.x + (targetX - Camera.x) * lerpFactor
        Camera.y = Camera.y + (targetY - Camera.y) * lerpFactor
    end

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

-- New helper function to check if an entity is currently visible on screen.
function Camera.isEntityVisible(entity)
    if not entity then return false end
    local entityRight = entity.x + entity.size
    local entityBottom = entity.y + entity.size
    local cameraRight = Camera.x + Config.VIRTUAL_WIDTH
    local cameraBottom = Camera.y + Config.VIRTUAL_HEIGHT
    return entityRight > Camera.x and entity.x < cameraRight and entityBottom > Camera.y and entity.y < cameraBottom
end

return Camera