-- weapon_blueprints.lua
-- Defines the data-driven blueprints for all weapon types.

local WeaponBlueprints = {
    -- Standard Traveler's Weapons (no special stats)
    travelers_sword = {
        name = "Traveler's Sword",
        type = "sword",
        description = "A basic sword for a journeying warrior."
    },
    travelers_staff = {
        name = "Traveler's Staff",
        type = "staff",
        description = "A basic staff for a journeying spellcaster."
    },
    travelers_tome = {
        name = "Traveler's Tome",
        type = "tome",
        description = "A basic tome for a journeying mage."
    },
    travelers_whip = {
        name = "Traveler's Whip",
        type = "whip",
        description = "A basic whip for a journeying trickster."
    },
    travelers_bow = {
        name = "Traveler's Bow",
        type = "bow",
        description = "A basic bow for a journeying scout."
    },
    travelers_lance = {
        name = "Traveler's Lance",
        type = "lance",
        description = "A basic lance for a journeying lancer."
    },
    travelers_dagger = {
        name = "Traveler's Dagger",
        type = "dagger",
        description = "A basic dagger for a journeying thief."
    },

    vampiric_dagger = {
        name = "Vampiric Dagger",
        type = "dagger",
        description = "A grim dagger that siphons life from its victims.",
        stats = {
            attackStat = 3,
            witStat = -2,
        },
        lifesteal_percent = 0.5 -- Heals for 50% of damage dealt
    },

    vampiric_whip = {
        name = "Vampiric Whip",
        type = "whip",
        description = "A grim whip that siphons life from its victims.",
        stats = {
            attackStat = 3,
            witStat = -2,
        },
        lifesteal_percent = 0.5 -- Heals for 50% of damage dealt
    },

    vampiric_lance = {
        name = "Vampiric Lance",
        type = "lance",
        description = "A grim lance that siphons life from its victims.",
        stats = {
            attackStat = 3,
            witStat = -2,
        },
        lifesteal_percent = 0.5 -- Heals for 50% of damage dealt
    },

    -- New Spiritburn Weapons
    spiritburn_sword = {
        name = "Spiritburn Sword",
        type = "sword",
        description = "A volatile blade that consumes 1 Wisp to deal 1.5x damage.",
        spiritburn_bonus = 1.5,
        stats = {
            attackStat = 2
        }
    },
    spiritburn_lance = {
        name = "Spiritburn Lance",
        type = "lance",
        description = "A volatile lance that consumes 1 Wisp to deal 1.5x damage.",
        spiritburn_bonus = 1.5,
        stats = {
            attackStat = 2
        }
    },
    spiritburn_whip = {
        name = "Spiritburn Whip",
        type = "whip",
        description = "A volatile whip that consumes 1 Wisp to deal 1.5x damage.",
        spiritburn_bonus = 1.5,
        stats = {
            attackStat = 2
        }
    },
    spiritburn_bow = {
        name = "Spiritburn Bow",
        type = "bow",
        description = "A volatile bow that consumes 1 Wisp to deal 1.5x damage.",
        spiritburn_bonus = 1.5,
        stats = {
            attackStat = 2
        }
    },
    spiritburn_staff = {
        name = "Spiritburn Staff",
        type = "staff",
        description = "A volatile staff that consumes 1 Wisp to deal 1.5x damage.",
        spiritburn_bonus = 1.5,
        stats = {
            magicStat = 2
        }
    },
    spiritburn_tome = {
        name = "Spiritburn Tome",
        type = "tome",
        description = "A volatile tome that consumes 1 Wisp to deal 1.5x damage.",
        spiritburn_bonus = 1.5,
        stats = {
            magicStat = 2
        }
    },
    spiritburn_dagger = {
        name = "Spiritburn Dagger",
        type = "dagger",
        description = "A volatile dagger that consumes 1 Wisp to deal 1.5x damage.",
        spiritburn_bonus = 1.5,
        stats = {
            attackStat = 2
        }
    },

    -- New Blight Weapons
    blightblade = {
        name = "Blightblade",
        type = "sword",
        description = "A cursed blade that drains the wielder's spirit for physical power.",
        stats = {
            attackStat = 7,
            magicStat = -3,
            maxWisp = -1
        }
    },
    blightbow = {
        name = "Blightbow",
        type = "bow",
        description = "A cursed bow that drains the wielder's spirit for physical power.",
        stats = {
            attackStat = 7,
            magicStat = -3,
            maxWisp = -1
        }
    }
}

return WeaponBlueprints