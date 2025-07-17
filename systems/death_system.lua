-- death_system.lua
-- Handles all logic related to entities reaching 0 HP, triggered by events.

local EventBus = require("modules.event_bus")
local EffectFactory = require("modules.effect_factory")

local DeathSystem = {}

-- Event listener for unit deaths
EventBus:register("unit_died", function(data)
    local victim = data.victim
    if victim and victim.hp <= 0 and not victim.isMarkedForDeletion then
        -- Apply death effects (shatter, etc.)
        EffectFactory.createShatterEffect(victim.x, victim.y, victim.size, victim.color)

        -- Mark the entity for deletion
        victim.isMarkedForDeletion = true
    end
end)

return DeathSystem