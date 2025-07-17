-- character_blueprints.lua
-- Defines the data-driven blueprints for all player types.
-- The 'attacks' table now contains string identifiers for attack functions,
-- which are implemented in unit_attacks.lua.

local CharacterBlueprints = {
    drapionsquare = {
        displayName = "Drapion",
        maxHp = 120,
        attackStat = 50,
        defenseStat = 50,
        movement = 7,
        weight = 8, -- Heavy
        dominantColor = {0.5, 0.2, 0.8}, -- Drapion: Purple
        passives = {"Bloodrush"},
        attacks = {
            "venom_stab", "phantom_step"
        }
    },
    florgessquare = {
        displayName = "Florges",
        maxHp = 100,
        attackStat = 40,
        defenseStat = 50,
        movement = 5,
        weight = 3, -- Light
        dominantColor = {1.0, 0.6, 0.8}, -- Florges: Light Florges
        passives = {"HealingWinds"},
        attacks = {
            "invigorating_aura"
        }
    },
    venusaursquare = {
        displayName = "Venusaur",
        maxHp = 60,
        attackStat = 60,
        defenseStat = 50,
        movement = 5,
        weight = 9, -- Very Heavy
        dominantColor = {0.6, 0.9, 0.6}, -- Venusaur: Pale Green
        passives = {},
        attacks = {
            "fireball", "eruption", "shockwave"
        }
    },
    magnezonesquare = {
        displayName = "Magnezone",
        maxHp = 80,
        attackStat = 50,
        defenseStat = 50,
        movement = 4,
        weight = 10, -- Heaviest
        dominantColor = {0.6, 0.6, 0.7}, -- Magnezone: Steel Grey
        passives = {},
        attacks = {
            "slash", "fireball"
        }
    },
    electiviresquare = {
        displayName = "Electivire",
        maxHp = 100,
        attackStat = 50,
        defenseStat = 50,
        movement = 6,
        weight = 7, -- Medium-Heavy
        dominantColor = {1.0, 0.8, 0.1}, -- Electivire: Electric Venusaur
        passives = {},
        attacks = {
            "uppercut", "quick_step", "longshot"
        }
    },
    tangrowthsquare = {
        displayName = "Tangrowth",
        maxHp = 101,
        attackStat = 50,
        defenseStat = 50,
        movement = 4,
        weight = 9, -- Very Heavy
        dominantColor = {0.1, 0.3, 0.8}, -- Tangrowth: Dark Blue
        passives = {"Whiplash"},
        attacks = {
            "hookshot"
        }
    },
    sceptilesquare = {
        displayName = "Sceptile",
        maxHp = 110,
        attackStat = 50,
        defenseStat = 50,
        movement = 8,
        weight = 6, -- Medium
        dominantColor = {0.1, 0.8, 0.3}, -- Sceptile: Leaf Green
        passives = {},
        attacks = {
        "slash", "grovecall", "hookshot"
        }
    },
    pidgeotsquare = {
        displayName = "Pidgeot",
        maxHp = 90,
        attackStat = 50,
        defenseStat = 50,
        movement = 9,
        weight = 5, -- Medium-Light
        isFlying = true,
        dominantColor = {0.8, 0.7, 0.4}, -- Pidgeot: Sandy Brown
        passives = {"Aetherfall"},
        attacks = {
            "slash"
        }
    }
}

return CharacterBlueprints