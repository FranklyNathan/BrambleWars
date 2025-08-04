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
        weight = 500, -- A very high number to make it effectively permanent/immovable
        sprite = Assets.images.Flag, -- The tree sprite
        attacks = {}, -- Empty attack list to prevent errors in systems that iterate over attacks.
    }
    ,
    beartrap = {
        displayName = "Bear Trap",
        objectType = "beartrap",
        maxHp = 10,
        defenseStat = 0, resistanceStat = 0, witStat = 0,
        weight = 500, -- Effectively immovable
        sprite = Assets.images.BearTrap,
        attacks = {},
        isTrap = true,
        trapDamage = 5,
        trapStatus = {type = "stunned", duration = 1}
    },
    molehill = {
        displayName = "Molehill",
        objectType = "molehill",
        maxHp = 10,
        defenseStat = 0,
        resistanceStat = 0,
        witStat = 0, -- Needed for hit calculations
        weight = 1, -- Very light, doesn't block shoves
        isImpassable = false, -- Units can move through this tile.
        isTeleportTarget = true, -- Can be targeted by Burrow.
        attacks = {},
        sprite = Assets.images.Molehill,
        isObstacle = true -- So it's treated as an obstacle by the world.
    }
}

return ObjectBlueprints