-- data/tile_status_blueprints.lua
-- Defines the properties of all tile status effects.

local TileStatusBlueprints = {
    aflame = {
        name = "Aflame",
        damage = 3,
        description = "Deals damage to any non-flying unit that steps on this tile."
    },
    frozen = {
        name = "Frozen",
        weightLimit = 10, -- Breaks if a unit with weight > 10 steps on it.
        description = "A fragile sheet of ice covering a water tile."
    }
}

return TileStatusBlueprints