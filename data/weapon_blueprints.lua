-- data/weapon_blueprints.lua
-- Contains definitions for all equippable weapons in the game.

local WeaponBlueprints = {
    travelers_sword = {
        name = "Traveler's Sword",
        type = "sword",
        description = "A reliable sword for a traveler. Well-balanced for quick strikes.",
        stats = {
            witStat = 2,
            attackStat = 1,
        },
        grants_moves = { "sever" },
        grants_passives = {},
    },

    travelers_lance = {
        name = "Traveler's Lance",
        type = "lance",
        description = "A simple but sturdy lance for a journeying warrior. Grants the Impale skill.",
        stats = {
            attackStat = 2,
            defenseStat = 1,
        },
        grants_moves = { "impale" },
        grants_passives = { "Bloodrush" },
    },

    travelers_dagger = {
        name = "Traveler's Dagger",
        type = "dagger",
        description = "A sharp, concealable dagger. Perfect for applying debilitating toxins.",
        stats = {
            witStat = 3,
        },
        grants_moves = { "poison_stab" },
        grants_passives = {},
    },

    travelers_bow = {
        name = "Traveler's Bow",
        type = "bow",
        description = "A simple wooden bow for hunting beasts and fending off foes from a distance.",
        stats = {
            attackStat = 2,
        },
        grants_moves = {},
        grants_passives = {},
    },

    durendal = {
        name = "Durendal",
        type = "sword",
        stats = {
            attackStat = 6,
            witStat = 2,
            defenseStat = 1,
        },
    },
    travelers_tome = {
        name = "Traveler's Tome",
        type = "tome",
        description = "A book of basic elemental magic for the studious adventurer.",
        stats = {
            magicStat = 2,
            maxWisp = 1,
        },
        grants_moves = { "fireball" },
        grants_passives = {},
    },

    travelers_staff = {
        name = "Traveler's Staff",
        type = "staff",
        description = "A blessed staff that can mend allies' wounds.",
        stats = {
            resistanceStat = 2,
        },
        grants_moves = { "heal" },
        grants_passives = { "HealingWinds" },
    },

    travelers_whip = {
        name = "Traveler's Whip",
        type = "whip",
        description = "A leather whip that can knock foes off balance.",
        stats = {
            attackStat = 1,
            witStat = 1,
        },
        grants_moves = {},
        grants_passives = { "Whiplash" },
    },
}

return WeaponBlueprints