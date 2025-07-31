-- bloodrush_system.lua
-- Manages the reactive "Bloodrush" passive.

local EventBus = require("modules.event_bus")
local EffectFactory = require("modules.effect_factory")

local BloodrushSystem = {}

EventBus:register("unit_died", function(data)
    local world = data.world
    local victim, killer = data.victim, data.killer
    if not victim or not killer then return end

    -- This handles the "Bloodrush" passive. Check if the list of living providers is not empty.
    if #world.teamPassives[killer.type].Bloodrush > 0 and killer.type ~= victim.type then
        -- Check if the killer has Bloodrush.
        local killerHasBloodrush = false
        for _, unit in ipairs(world.teamPassives[killer.type].Bloodrush) do
            if unit == killer then killerHasBloodrush = true; break end
        end
        if killerHasBloodrush and killer.hp > 0 then
            killer.hasActed = false
            EffectFactory.createDamagePopup(world, killer, "Refreshed!", false, {0.5, 1, 0.5, 1}) -- Green text
        end
    end
end)

return BloodrushSystem