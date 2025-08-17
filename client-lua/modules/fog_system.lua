-- modules/fog_system.lua
-- Manages the dynamic fog of war visibility.

local FogSystem = {}

FogSystem.VISION_RANGE = 5

function FogSystem.update(world)
    -- First, assume all fog tiles are not visible by setting their target alpha to 1.
    for _, fogTile in pairs(world.fogTiles) do
        fogTile.targetAlpha = 1.0
    end

    -- Then, for each player unit, mark the tiles within their vision range as visible.
    for _, player in ipairs(world.players) do
        -- Only living, active units provide vision.
        if player.hp > 0 and not player.isCarried then
            local p_tileX, p_tileY = player.tileX, player.tileY
            for dx = -FogSystem.VISION_RANGE, FogSystem.VISION_RANGE do
                for dy = -FogSystem.VISION_RANGE, FogSystem.VISION_RANGE do
                    -- Check Manhattan distance to create a diamond shape, like in Fire Emblem.
                    if math.abs(dx) + math.abs(dy) <= FogSystem.VISION_RANGE then
                        local checkX, checkY = p_tileX + dx, p_tileY + dy
                        local posKey = checkX .. "," .. checkY
                        if world.fogTiles[posKey] then
                            world.fogTiles[posKey].targetAlpha = 0.0
                        end
                    end
                end
            end
        end
    end
end

return FogSystem