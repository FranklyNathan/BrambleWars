-- character_blueprints.lua
-- Defines the data-driven blueprints for all player types.
-- The 'attacks' table contains string identifiers for attack functions,
-- which are implemented in unit_attacks.lua.

local CharacterBlueprints = {
    clementine = {
        displayName = "Clementine",
        species = "Duckling",
        originType = "marshborn",
        class = "warrior",
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
        equippedWeapon = "blightblade",
        canSwim = true,
        dominantColor = {0.5, 0.2, 0.8}, -- Clementine: Purple
        passives = {"Desperate", "Treacherous", "Unbound"}, -- Characters can have multiple
        growths = {
            maxHp = 90,
            attackStat = 50,
            defenseStat = 40,
            magicStat = 10,
            resistanceStat = 25,
            witStat = 35,
        },
        attacks = {
            "venom_stab", "sever", "phantom_step"
        }
    },
    biblo = {
        displayName = "Biblo",
        species = "Owl",
        originType = "forestborn",
        class = "bard",
        maxHp = 20,
        wispStat = 8,
        portrait = "Default_Portrait.png",
        attackStat = 3,
        defenseStat = 4,
        magicStat = 8,
        resistanceStat = 8,
        witStat = 6,
        movement = 20,
        weight = 13,
        equippedWeapon = "travelers_staff",
        isFlying = true,
        dominantColor = {1.0, 0.6, 0.8}, -- Biblo: Light Pink
        passives = {"HealingWinds", "Hustle", "Captor"},
        growths = {
            maxHp = 70,
            attackStat = 15,
            defenseStat = 20,
            magicStat = 50,
            resistanceStat = 60,
            witStat = 35,
        },
        attacks = {
            -- Melee Attacks
            "venom_stab", "uppercut", "sever", "shunt", "shockstrike", "impale", "disarm", "slipstep",
            -- Ranged & Special Attacks
            "phantom_step", "shockwave", "quick_step", "grovecall", "trap_set", "ascension", "hookshot", "homecoming", "kindle",
            -- Support Attacks
            "mend", "invigoration"
        }
    },
    winthrop = {
        displayName = "Winthrop",
        species = "Beaver",
        originType = "marshborn",
        class = "mage",
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
        canSwim = true,
        dominantColor = {0.6, 0.9, 0.6}, -- Winthrop: Pale Green
        passives = {"Thunderguard"},
        growths = {
            maxHp = 80,
            attackStat = 40,
            defenseStat = 40,
            magicStat = 40,
            resistanceStat = 40,
            witStat = 30,
        },
        attacks = {
            "fireball", "eruption", "shockwave", "ice_beam"
        }
    },
    mortimer = {
        displayName = "Mortimer",
        species = "Toad",
        originType = "forestborn",
        class = "druid",
        maxHp = 26,
        wispStat = 4,
        portrait = "Default_Portrait.png",
        attackStat = 4,
        defenseStat = 8,
        magicStat = 7,
        resistanceStat = 6,
        witStat = 3,
        movement = 14,
        weight = 10, -- Heaviest
        equippedWeapon = "travelers_tome",
        dominantColor = {0.6, 0.6, 0.7}, -- Mortimer: Steel Grey,
        passives = {"Soulsnatcher", "Elusive"},
        growths = {
            maxHp = 75,
            attackStat = 20,
            defenseStat = 55,
            magicStat = 50,
            resistanceStat = 40,
            witStat = 20,
        },
        attacks = {
            "sever", "fireball", "hookshot"
        }
    },
    cedric = {
        displayName = "Cedric",
        species = "Mole",
        originType = "cavernborn",
        class = "trickster",
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
        equippedWeapon = "travelers_whip",
        dominantColor = {1.0, 0.8, 0.1}, -- Cedric: Electric Yellow
        passives = {"Whiplash", "Captor"},
        growths = {
            maxHp = 85,
            attackStat = 55,
            defenseStat = 30,
            magicStat = 25,
            resistanceStat = 30,
            witStat = 45,
        },
        attacks = {
            "uppercut", "quick_step", "disarm"
        }
    },
    ollo = {
        displayName = "Ollo",
        species = "Fox",
        originType = "forestborn",
        class = "scout",
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
        equippedWeapon = "blightbow",
        dominantColor = {0.1, 0.3, 0.8}, -- Ollo: Dark Blue
        passives = {},
        growths = {
            maxHp = 100,
            attackStat = 45,
            defenseStat = 55,
            magicStat = 20,
            resistanceStat = 20,
            witStat = 20,
        },
        attacks = {
            "longshot", "hookshot"
        }
    },
    plop = {
        displayName = "Plop",
        species = "Frog",
        originType = "marshborn",
        class = "lancer",
        maxHp = 22,
        wispStat = 4,
        portrait = "Default_Portrait.png",
        attackStat = 7,
        defenseStat = 4,
        magicStat = 5,
        resistanceStat = 4,
        witStat = 8,
        movement = 6,
        weight = 6, -- Medium
        equippedWeapon = "travelers_lance",
        canSwim = true,
        dominantColor = {0.1, 0.8, 0.3}, -- Plop: Leaf Green
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
            "impale", "grovecall", "hookshot", "bodyguard"
        }
    },
    dupe = {
        displayName = "Dupe",
        species = "Bat",
        originType = "cavernborn",
        class = "thief",
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
        equippedWeapon = "travelers_dagger",
        isFlying = true,
        dominantColor = {0.8, 0.7, 0.4}, -- Dupe: Sandy Brown,
        passives = {"Aetherfall", "Elusive"},
        growths = {
            maxHp = 80,
            attackStat = 45,
            defenseStat = 35,
            magicStat = 20,
            resistanceStat = 30,
            witStat = 60,
        },
        attacks = {
            "sever", "slipstep"
        }
    }
}

return CharacterBlueprints