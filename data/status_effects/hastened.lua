-- data/status_effects/hastened.lua
-- Defines the "Hastened" status effect.

local Hastened = {
    name = "Hastened",
    description = "Unit has increased Movement for one turn.",
    statModifiers = {
        movement = 2
    }
}

return Hastened