-- character_blueprints.lua
-- Defines the data-driven blueprints for all player types.
-- The 'attacks' table contains string identifiers for attack functions,
-- which are implemented in unit_attacks.lua.

local CharacterBlueprints = {
    drapionsquare = {
        displayName = "Drapion",
        originType = "cavernborn",
        maxHp = 28,
        wispStat = 2,
        portrait = "Default_Portrait.png",
        attackStat = 8, -- Physical attacks use Attack/Defense stat in calcs
        defenseStat = 6,
        magicStat = 3, -- Magical attacks use Magic/Resistance stat
        resistanceStat = 4,
        witStat = 5, -- Used when calculating if a move hits/misses and if a move is a critical hit
        movement = 6, -- How many tiles a character can move in a turn
        weight = 8, -- Heavy
        equippedWeapon = "travelers_lance",
        dominantColor = {0.5, 0.2, 0.8}, -- Drapion: Purple
        passives = {"Bloodrush"}, -- Characters can have multiple 
        growths = {
            maxHp = 90,
            attackStat = 50,
            defenseStat = 40,
            magicStat = 10,
            resistanceStat = 25,
            witStat = 35,
        },
        attacks = {
            "froggy_rush", "venom_stab", "impale", "phantom_step"
        } --The first attack must always be a basic attack, the rest can be any attack(s) defined in attack_blueprints.lua
    },
    florgessquare = {
        displayName = "Florges",
        originType = "forestborn",
        maxHp = 20,
        wispStat = 8,
        portrait = "Default_Portrait.png",
        attackStat = 3,
        defenseStat = 4,
        magicStat = 8,
        resistanceStat = 8,
        witStat = 6,
        movement = 5,
        weight = 3, -- Light
        equippedWeapon = "travelers_staff",
        dominantColor = {1.0, 0.6, 0.8}, -- Florges: Light Florges
        passives = {"HealingWinds"},
        growths = {
            maxHp = 70,
            attackStat = 15,
            defenseStat = 20,
            magicStat = 50,
            resistanceStat = 60,
            witStat = 35,
        },
        attacks = {
            "quill_jab", "mend", "invigoration"
        }
    },
    venusaursquare = {
        displayName = "Venusaur",
        originType = "cavernborn",
        maxHp = 25,
        wispStat = 4,
        portrait = "Default_Portrait.png",
        attackStat = 6,
        defenseStat = 6,
        magicStat = 6,
        resistanceStat = 6,
        witStat = 4,
        movement = 5,
        weight = 9, -- Very Heavy
        equippedWeapon = "travelers_tome",
        dominantColor = {0.6, 0.9, 0.6}, -- Venusaur: Pale Green
        passives = {},
        growths = {
            maxHp = 80,
            attackStat = 40,
            defenseStat = 40,
            magicStat = 40,
            resistanceStat = 40,
            witStat = 30,
        },
        attacks = {
            "quill_jab", "fireball", "eruption", "shockwave"
        }
    },
    magnezonesquare = {
        displayName = "Magnezone",
        originType = "cavernborn",
        maxHp = 26,
        wispStat = 4,
        portrait = "Default_Portrait.png",
        attackStat = 4,
        defenseStat = 8,
        magicStat = 7,
        resistanceStat = 6,
        witStat = 3,
        movement = 4,
        weight = 10, -- Heaviest
        equippedWeapon = "travelers_tome",
        dominantColor = {0.6, 0.6, 0.7}, -- Magnezone: Steel Grey
        passives = {},
        growths = {
            maxHp = 75,
            attackStat = 20,
            defenseStat = 55,
            magicStat = 50,
            resistanceStat = 40,
            witStat = 20,
        },
        attacks = {
            "walnut_toss", "slash", "fireball"
        }
    },
    electiviresquare = {
        displayName = "Electivire",
        originType = "cavernborn",
        maxHp = 24,
        wispStat = 4,
        portrait = "Default_Portrait.png",
        attackStat = 8,
        defenseStat = 5,
        magicStat = 4,
        resistanceStat = 5,
        witStat = 7,
        movement = 5,
        weight = 7, -- Medium-Heavy
        equippedWeapon = "travelers_sword",
        dominantColor = {1.0, 0.8, 0.1}, -- Electivire: Electric Venusaur
        passives = {},
        growths = {
            maxHp = 85,
            attackStat = 55,
            defenseStat = 30,
            magicStat = 25,
            resistanceStat = 30,
            witStat = 45,
        },
        attacks = {
            "snap", "uppercut", "quick_step", "longshot"
        }
    },
    tangrowthsquare = {
        displayName = "Tangrowth",
        originType = "marshborn",
        maxHp = 30,
        wispStat = 4,
        portrait = "Default_Portrait.png",
        attackStat = 7,
        defenseStat = 8,
        magicStat = 3,
        resistanceStat = 4,
        witStat = 3,
        movement = 4,
        weight = 9, -- Very Heavy
        equippedWeapon = "travelers_whip",
        dominantColor = {0.1, 0.3, 0.8}, -- Tangrowth: Dark Blue
        passives = {"Whiplash"},
        growths = {
            maxHp = 100,
            attackStat = 45,
            defenseStat = 55,
            magicStat = 20,
            resistanceStat = 20,
            witStat = 20,
        },
        attacks = {
            "froggy_rush", "hookshot"
        }
    },
    sceptilesquare = {
        displayName = "Sceptile",
        originType = "marshborn",
        maxHp = 22,
        wispStat = 4,
        portrait = "Sceptile_Portrait.png",
        attackStat = 7,
        defenseStat = 4,
        magicStat = 5,
        resistanceStat = 4,
        witStat = 8,
        movement = 6,
        weight = 6, -- Medium
        equippedWeapon = "travelers_knife",
        canSwim = true,
        dominantColor = {0.1, 0.8, 0.3}, -- Sceptile: Leaf Green
        passives = {},
        growths = {
            maxHp = 75,
            attackStat = 50,
            defenseStat = 30,
            magicStat = 35,
            resistanceStat = 30,
            witStat = 50,
        },
        attacks = {
            "froggy_rush", "slash", "grovecall", "hookshot"
        }
    },
    pidgeotsquare = {
        displayName = "Pidgeot",
        originType = "forestborn",
        maxHp = 21,
        wispStat = 4,
        portrait = "Default_Portrait.png",
        attackStat = 6,
        defenseStat = 4,
        magicStat = 3,
        resistanceStat = 5,
        witStat = 8,
        movement = 8,
        weight = 5, -- Medium-Light
        equippedWeapon = "travelers_bow",
        isFlying = true,
        dominantColor = {0.8, 0.7, 0.4}, -- Pidgeot: Sandy Brown
        passives = {"Aetherfall"},
        growths = {
            maxHp = 80,
            attackStat = 45,
            defenseStat = 35,
            magicStat = 20,
            resistanceStat = 30,
            witStat = 60,
        },
        attacks = {
            "froggy_rush", "slash"
        }
    }
}

return CharacterBlueprints