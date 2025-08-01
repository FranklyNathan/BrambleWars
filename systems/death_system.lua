-- death_system.lua
-- Handles all logic related to entities reaching 0 HP, triggered by events.

local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")
local EffectFactory = require("modules.effect_factory")
local RescueHandler = require("modules.rescue_handler")

local DeathSystem = {}

-- Event listener for unit deaths
EventBus:register("unit_died", function(data)
    local victim = data.victim
    local world = data.world
    local killer = data.killer
    local reason = data.reason or {} -- Default to an empty table to prevent errors.

    -- If the dying unit was carrying someone, drop them on the tile where the carrier died.
    -- This happens before the fade-out so the carried unit appears immediately.
    if victim and victim.carriedUnit then
        RescueHandler.drop(victim, victim.tileX, victim.tileY, world)
    end

    -- If a player unit dies mid-move (e.g., from a trap or drowning),
    -- ensure the visual effect on the destination tile is cleared.
    if victim and victim.type == "player" and victim.components.movement_path then
        world.ui.pathing.moveDestinationEffect = nil
    end

    if victim and victim.hp <= 0 and not victim.isMarkedForDeletion and not victim.components.fade_out then
        -- Instead of instant deletion, start a fade-out effect.
        victim.components.fade_out = {
            timer = 1, -- The duration of the fade in seconds.
            initialTimer = 1
        }
        -- The unit will be marked for deletion by the effect_timer_system once the fade is complete.
    end

    -- Check for Combustive passive, but only if the death was not from drowning.
    if victim and world and reason.type ~= "drown" then
        -- We must check the unit's blueprint/weapon directly, because the "unit_died" event
        -- may have already removed the unit from the teamPassives cache.
        local passives = WorldQueries.getUnitPassiveList(victim)
        local victimHasCombustive = false
        for _, passiveName in ipairs(passives) do
            if passiveName == "Combustive" then
                victimHasCombustive = true
                break
            end
        end

        if victimHasCombustive and not victim.components.has_exploded then
            -- The 'attacker' for the explosion should always be the unit that exploded,
            -- so any resulting kills or effects are attributed to it.
            local explosionAttacker = victim
            -- Add a flag to prevent this unit from exploding more than once.
            victim.components.has_exploded = true
            -- Trigger the explosion ripple effect.
            EffectFactory.createRippleEffect(world, explosionAttacker, "combustive_explosion", victim.x + victim.size / 2, victim.y + victim.size / 2, 1, "all")
        end
    end
end)

return DeathSystem