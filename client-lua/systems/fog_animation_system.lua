-- systems/fog_animation_system.lua
-- Manages the smooth fading animation for fog of war tiles.

local FogAnimationSystem = {}

-- The speed at which fog fades in or out. A value of 2.0 means it takes 0.5 seconds to fade completely.
local FADE_SPEED = 2.0

function FogAnimationSystem.update(dt, world)
    if not world.fogTiles then return end

    for _, fogTile in pairs(world.fogTiles) do
        if fogTile.currentAlpha ~= fogTile.targetAlpha then
            if fogTile.currentAlpha < fogTile.targetAlpha then
                -- Fading in (becoming more foggy)
                fogTile.currentAlpha = math.min(fogTile.targetAlpha, fogTile.currentAlpha + FADE_SPEED * dt)
            else
                -- Fading out (becoming more visible)
                fogTile.currentAlpha = math.max(fogTile.targetAlpha, fogTile.currentAlpha - FADE_SPEED * dt)
            end
        end
    end
end

return FogAnimationSystem