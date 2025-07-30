-- data/object_blueprints.lua
-- Defines the data-driven blueprints for all interactable object types.

local Assets = require("modules.assets")

local ObjectBlueprints = {
    tree = {
        displayName = "Tree",
        objectType = "tree",
        maxHp = 20,
        defenseStat = 2,
        resistanceStat = 2,
        witStat = 0, -- Needed for hit calculations
        weight = "Permanent", -- Ensures hookshot pulls the user to the tree
        sprite = Assets.images.Flag, -- The tree sprite
        attacks = {}, -- Empty attack list to prevent errors in systems that iterate over attacks.
    }
    -- Other obstacles like 'boulder' or 'wall' could be added here.
}

return ObjectBlueprints