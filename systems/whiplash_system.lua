-- whiplash_system.lua
-- Manages the reactive "Whiplash" passive.

local EventBus = require("modules.event_bus")

local WhiplashSystem = {}

-- Whiplash triggers when a status effect is applied.
EventBus:register("status_applied", function(data)
    local world = data.world
    local effect = data.effect
    
    -- Check if the attacker's team has Whiplash active.
    if effect.attacker and #world.teamPassives[effect.attacker.type].Whiplash > 0 then
        -- Apply Whiplash effect: Double the force of careening effects.
        if effect.type == "careening" then
            effect.force = effect.force * 2
        end
    end
end)


return WhiplashSystem