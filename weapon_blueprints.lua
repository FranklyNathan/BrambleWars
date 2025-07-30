-- data/weapon_blueprints.lua
-- Contains definitions for all equippable weapons in the game.

local WeaponBlueprints = {
    travelers_sword = {
        name = "Traveler's Sword",
        type = "Sword",
        description = "A reliable sword for a traveler. Well-balanced for quick strikes.",
        stats = {
            witStat = 2,
            attackStat = 1,
        },
        grants_moves = { "slash" },
        grants_passives = {},
    },

    travelers_lance = {
        name = "Traveler's Lance",
        type = "Lance",
        description = "A simple but sturdy lance for a journeying warrior. Grants the Impale skill.",
        stats = {
            attackStat = 2,
            defenseStat = 1,
        },
        grants_moves = { "impale" },
        grants_passives = { "Bloodrush" },
    },

    travelers_knife = {
        name = "Traveler's Knife",
        type = "Knife",
        description = "A sharp, concealable knife. Perfect for applying debilitating toxins.",
        stats = {
            witStat = 3,
        },
        grants_moves = { "poison_stab" },
        grants_passives = {},
    },

    travelers_bow = {
        name = "Traveler's Bow",
        type = "Bow",
        description = "A simple wooden bow for hunting beasts and fending off foes from a distance.",
        stats = {
            attackStat = 2,
        },
        grants_moves = {},
        grants_passives = {},
    },

    travelers_tome = {
        name = "Traveler's Tome",
        type = "Tome",
        description = "A book of basic elemental magic for the studious adventurer.",
        stats = {
            magicStat = 2,
            maxWisp = 5,
        },
        grants_moves = { "fireball" },
        grants_passives = {},
    },

    travelers_staff = {
        name = "Traveler's Staff",
        type = "Staff",
        description = "A blessed staff that can mend allies' wounds.",
        stats = {
            resistanceStat = 2,
        },
        grants_moves = { "heal" },
        grants_passives = { "HealingWinds" },
    },

    travelers_whip = {
        name = "Traveler's Whip",
        type = "Whip",
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