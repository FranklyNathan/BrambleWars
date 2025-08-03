-- data/tile_status_blueprints.lua
-- Defines the properties of all tile status effects.

local TileStatusBlueprints = {
    aflame = {
        name = "Aflame",
        damage = 3,
        description = "Deals damage to any non-flying unit that steps on this tile.",
        renderLayer = "foreground"
    },
    frozen = {
        name = "Frozen",
        weightLimit = 10, -- Breaks if a unit with weight > 10 steps on it.
        description = "A fragile sheet of ice covering a water tile.",
        renderLayer = "background"
    },
    tall_grass = {
        name = "Tall Grass",
        witMultiplier = 1.2,
        description = "Unit gains 1.2x Wit while standing in this tile. Spreads fire when ignited.",
        renderLayer = "foreground",
        spreads_fire = true -- When set aflame, spreads to adjacent tiles with this property.
    }
}

return TileStatusBlueprints