-- data/status_effects/poison.lua
local CombatActions = require("modules.combat_actions")

return {
    type = "poison",
    tick = function(target, effectData, world)
        -- The attacker is stored in the effect data when it's applied.
        local attacker = effectData.attacker
        -- Apply damage at the end of the turn with the correct arguments.
        CombatActions.applyDirectDamage(world, target, 5, false, attacker, {createPopup = false})
    end,
    -- Other poison properties (if any) can be defined here.
}