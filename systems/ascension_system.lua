-- systems/ascension_system.lua
-- Manages the descent of units using the Ascension move.

local Grid = require("modules.grid")
local WorldQueries = require("modules.world_queries")
local EffectFactory = require("modules.effect_factory")

local AscensionSystem = {}

-- This function is called at the end of the enemy turn to resolve all ascensions.
function AscensionSystem.descend_units(world)
    -- Iterate backwards as we might modify the list of shadows.
    for i = #world.all_entities, 1, -1 do
        local entity = world.all_entities[i]

        if entity.components and entity.components.ascended then
            local ascensionData = entity.components.ascended
            local targetTileX, targetTileY = ascensionData.targetTileX, ascensionData.targetTileY

            -- 1. Check for a victim on the landing tile.
            local victim = WorldQueries.getUnitAt(targetTileX, targetTileY, nil, world)
            if victim then
                -- 2. If there is a victim, create an instant-kill attack effect.
                EffectFactory.addAttackEffect(world, {
                    attacker = entity,
                    attackName = "ascension_strike",
                    x = victim.x, y = victim.y,
                    width = victim.size, height = victim.size,
                    color = {1, 0, 0, 1},
                    targetType = victim.type,
                    specialProperties = { isAetherfallAttack = true } -- Reuse this to prevent counters
                })
            end

            -- 3. Set up the descent animation.
            local destPixelX, destPixelY = Grid.toPixels(targetTileX, targetTileY)
            -- Start the unit high above the target tile, off-screen.
            entity.x = destPixelX
            entity.y = destPixelY - 200 -- Start 200 pixels above the landing spot.
            -- Set the target destination for the movement system.
            entity.targetX, entity.targetY = destPixelX, destPixelY
            -- Update the logical tile position immediately so it's correctly placed for game logic.
            entity.tileX, entity.tileY = targetTileX, targetTileY
            -- Give it a high speed multiplier for a rapid descent.
            entity.speedMultiplier = 8
            -- Force the unit to face down for the descent animation.
            entity.lastDirection = "down"

            -- 4. Remove the ascended component to make the unit visible and active again.
            entity.components.ascended = nil

            -- 5. Remove the corresponding shadow marker by finding the unit in the shadow list.
            for j = #world.ascension_shadows, 1, -1 do
                if world.ascension_shadows[j].unit == entity then
                    table.remove(world.ascension_shadows, j)
                    break
                end
            end
        end
    end
end

return AscensionSystem