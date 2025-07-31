-- death_system.lua
-- Handles all logic related to entities reaching 0 HP, triggered by events.

local EventBus = require("modules.event_bus")

local DeathSystem = {}

-- Event listener for unit deaths
EventBus:register("unit_died", function(data)
    local victim = data.victim
    if victim and victim.hp <= 0 and not victim.isMarkedForDeletion and not victim.components.fade_out then
        -- Instead of instant deletion, start a fade-out effect.
        victim.components.fade_out = {
            timer = 1, -- The duration of the fade in seconds.
            initialTimer = 1
        }
        -- The unit will be marked for deletion by the effect_timer_system once the fade is complete.
    end
end)

return DeathSystem