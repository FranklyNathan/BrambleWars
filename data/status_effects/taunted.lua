-- data/status_effects/taunted.lua
local Taunted = {
    name = "Taunted",
    description = "Can only target the unit that applied this effect.",
    -- The taunt effect is passive and checked by other systems (AI, targeting).
    tick = function(target, effectData, world) end
}
return Taunted