-- character_blueprints.lua
-- Defines the data-driven blueprints for all player types.
-- The 'attacks' table now contains string identifiers for attack functions,
-- which are implemented in unit_attacks.lua.

local CharacterBlueprints = {
    drapionsquare = {
        displayName = "Drapion",
        originType = "cavernborn",
        HpStat = 12, -- Multiply by 10 to get a charcter's maximum HP
        wispStat = 2, -- Starting (and max) Wisp
        attackStat = 15, -- Physical attacks use Attack/Defense stat in calcs
        defenseStat = 10,
        magicStat = 10, -- Magical attacks use Magic/Resistance stat
        resistanceStat = 10,
        witStat = 8, -- Used when calculating if a move hits/misses and if a move is a critical hit
        movement = 7, -- How many tiles a character can move in a turn
        weight = 8, -- Heavy
        dominantColor = {0.5, 0.2, 0.8}, -- Drapion: Purple
        passives = {"Bloodrush"}, -- Characters can have multiple 
        attacks = {
            "froggy_rush", "venom_stab", "phantom_step"
        } --The first attack must always be a basic attack, the rest can be any attack(s) defined in attack_blueprints.lua
    },
    florgessquare = {
        displayName = "Florges",
        originType = "forestborn",
        HpStat = 10,
        wispStat = 8,
        attackStat = 4,
        defenseStat = 7,
        magicStat = 13,
        resistanceStat = 17,
        witStat = 8,
        movement = 5,
        weight = 3, -- Light
        dominantColor = {1.0, 0.6, 0.8}, -- Florges: Light Florges
        passives = {"HealingWinds"},
        attacks = {
            "quill_jab", "mend", "invigoration"
        }
    },
    venusaursquare = {
        displayName = "Venusaur",
        originType = "cavernborn",
        HpStat = 10,
        wispStat = 4,
        attackStat = 10,
        defenseStat = 10,
        magicStat = 10,
        resistanceStat = 10,
        witStat = 8,
        movement = 5,
        weight = 9, -- Very Heavy
        dominantColor = {0.6, 0.9, 0.6}, -- Venusaur: Pale Green
        passives = {},
        attacks = {
            "quill_jab", "fireball", "eruption", "shockwave"
        }
    },
    magnezonesquare = {
        displayName = "Magnezone",
        originType = "cavernborn",
        HpStat = 11,
        wispStat = 4,
        attackStat = 7,
        defenseStat = 12,
        magicStat = 13,
        resistanceStat = 10,
        witStat = 8,
        movement = 4,
        weight = 10, -- Heaviest
        dominantColor = {0.6, 0.6, 0.7}, -- Magnezone: Steel Grey
        passives = {},
        attacks = {
            "snap", "slash", "fireball"
        }
    },
    electiviresquare = {
        displayName = "Electivire",
        originType = "cavernborn",
        HpStat = 12,
        wispStat = 4,
        attackStat = 10,
        defenseStat = 10,
        magicStat = 10,
        resistanceStat = 10,
        witStat = 8,
        movement = 6,
        weight = 7, -- Medium-Heavy
        dominantColor = {1.0, 0.8, 0.1}, -- Electivire: Electric Venusaur
        passives = {},
        attacks = {
            "snap", "uppercut", "quick_step", "longshot"
        }
    },
    tangrowthsquare = {
        displayName = "Tangrowth",
        originType = "marshborn",
        HpStat = 12,
        wispStat = 4,
        attackStat = 10,
        defenseStat = 10,
        magicStat = 10,
        resistanceStat = 10,
        witStat = 8,
        movement = 4,
        weight = 9, -- Very Heavy
        dominantColor = {0.1, 0.3, 0.8}, -- Tangrowth: Dark Blue
        passives = {"Whiplash"},
        attacks = {
            "froggy_rush", "hookshot"
        }
    },
    sceptilesquare = {
        displayName = "Sceptile",
        originType = "marshborn",
        HpStat = 12,
        wispStat = 4,
        attackStat = 10,
        defenseStat = 10,
        magicStat = 10,
        resistanceStat = 10,
        witStat = 8,
        movement = 8,
        weight = 6, -- Medium
        dominantColor = {0.1, 0.8, 0.3}, -- Sceptile: Leaf Green
        passives = {},
        attacks = {
            "froggy_rush", "slash", "grovecall", "hookshot"
        }
    },
    pidgeotsquare = {
        displayName = "Pidgeot",
        originType = "forestborn",
        HpStat = 12,
        wispStat = 4,
        attackStat = 10,
        defenseStat = 10,
        magicStat = 10,
        resistanceStat = 10,
        witStat = 8,
        movement = 9,
        weight = 5, -- Medium-Light
        isFlying = true,
        dominantColor = {0.8, 0.7, 0.4}, -- Pidgeot: Sandy Brown
        passives = {"Aetherfall"},
        attacks = {
            "froggy_rush", "slash"
        }
    }
}

return CharacterBlueprints