-- modules/shove_handler.lua
-- Contains the logic for executing the Shove command.

local Grid = require("modules.grid")

local ShoveHandler = {}

-- Executes the Shove action.
-- The shover pushes the target unit one tile away.
function ShoveHandler.shove(shover, target, world)
    if not shover or not target then return false end

    -- 1. Calculate the destination tile for the shoved unit.
    local dx = target.tileX - shover.tileX
    local dy = target.tileY - shover.tileY
    local destTileX, destTileY = target.tileX + dx, target.tileY + dy

    -- 2. Update the target's logical and visual position.
    target.tileX, target.tileY = destTileX, destTileY
    target.targetX, target.targetY = Grid.toPixels(destTileX, destTileY)
    -- Give it a small speed boost for a quick slide.
    target.speedMultiplier = 2

    -- 3. Apply a lunge animation to the shover.
    shover.components.lunge = { timer = 0.2, initialTimer = 0.2, direction = shover.lastDirection }

    print(shover.displayName .. " shoved " .. target.displayName)
    return true
end

return ShoveHandler