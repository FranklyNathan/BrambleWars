-- status_system.lua
-- This system is event-driven and handles the effects of statuses at the end of turns.

local EventBus = require("modules.event_bus")
local StatusEffectManager = require("modules.status_effect_manager")
local WorldQueries = require("modules.world_queries")
local Assets = require("modules.assets")

local StatusSystem = {}

-- Processes end-of-turn effects for a single entity.
local function process_turn_end(entity, world)
    if not entity.statusEffects then return end

    -- Reset any turn-specific components.
    if entity.components and entity.components.total_movement_used_this_turn then
        entity.components.total_movement_used_this_turn = nil
    end

    -- New: Check for Ephemeral passive. This happens before other status ticks.
    if WorldQueries.hasPassive(entity, "Ephemeral", world) then
        -- This unit has Ephemeral. Kill it.
        entity.hp = 0
        -- The reason is important so other systems (like Necromantia) can potentially ignore it.
        EventBus:dispatch("unit_died", { victim = entity, killer = nil, world = world, reason = {type = "ephemeral"} })
        -- Stop processing other effects for this now-dead unit.
        return
    end

    for effectType, effectData in pairs(entity.statusEffects) do
        local effectDef = Assets.status_effects[effectType]
        if effectDef and effectDef.tick then
            effectDef.tick(entity, effectData, world) -- Execute the tick function defined in the status effect data.
        end

        -- Handle effect durations, but only for effects that *aren't* permanent (duration ~= math.huge)
        -- and don't have external systems managing their timing (e.g., Aetherfall for "airborne").
        if effectData.duration and effectData.duration ~= math.huge and not effectData.externalControl then
            effectData.duration = effectData.duration - 1
            if effectData.duration <= 0 then
                StatusEffectManager.remove(entity, effectType, world)
            end
        end
    end
end

-- Register listeners for turn-end events.
EventBus:register("player_turn_ended", function(data)
    for _, player in ipairs(data.world.players) do process_turn_end(player, data.world) end
end)

EventBus:register("enemy_turn_ended", function(data)
    for _, enemy in ipairs(data.world.enemies) do process_turn_end(enemy, data.world) end
end)

return StatusSystem