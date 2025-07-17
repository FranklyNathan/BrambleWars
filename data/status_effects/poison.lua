-- data/status_effects/poison.lua
local CombatActions = require("modules.combat_actions")

return {
    type = "poison",
    tick = function(target, world)
        -- Apply damage at the end of the turn. The specific amount is handled in StatusEffectManager.
        CombatActions.applyDirectDamage(target, 5, false, nil, {createPopup = false})
    end,
    -- Other poison properties (if any) can be defined here.
}