-- weapon_blueprints.lua
-- Defines the data-driven blueprints for all weapon types.

local WeaponBlueprints = {
    -- Standard Traveler's Weapons (no special stats)
    travelers_sword = {
        name = "Traveler's Sword",
        type = "sword",
        value = 50,
        description = "A basic sword for a journeying warrior."
    },
    travelers_staff = {
        name = "Traveler's Staff",
        type = "staff",
        value = 50,
        description = "A basic staff for a journeying spellcaster."
    },
    travelers_tome = {
        name = "Traveler's Tome",
        type = "tome",
        value = 50,
        description = "A basic tome for a journeying mage."
    },
    travelers_whip = {
        name = "Traveler's Whip",
        type = "whip",
        value = 50,
        description = "A basic whip for a journeying trickster."
    },
    travelers_bow = {
        name = "Traveler's Bow",
        type = "bow",
        value = 50,
        description = "A basic bow for a journeying scout."
    },
    travelers_lance = {
        name = "Traveler's Lance",
        type = "lance",
        value = 50,
        description = "A basic lance for a journeying lancer."
    },
    travelers_dagger = {
        name = "Traveler's Dagger",
        type = "dagger",
        value = 50,
        description = "A basic dagger for a journeying thief."
    },

    vampiric_dagger = {
        name = "Vampiric Dagger",
        type = "dagger",
        value = 500,
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
        value = 500,
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
        value = 500,
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
        value = 400,
        description = "A volatile blade that consumes 1 Wisp to deal 1.5x damage.",
        spiritburn_bonus = 1.5,
        stats = {
            attackStat = 2
        }
    },
    spiritburn_lance = {
        name = "Spiritburn Lance",
        type = "lance",
        value = 400,
        description = "A volatile lance that consumes 1 Wisp to deal 1.5x damage.",
        spiritburn_bonus = 1.5,
        stats = {
            attackStat = 2
        }
    },
    spiritburn_whip = {
        name = "Spiritburn Whip",
        type = "whip",
        value = 400,
        description = "A volatile whip that consumes 1 Wisp to deal 1.5x damage.",
        spiritburn_bonus = 1.5,
        stats = {
            attackStat = 2
        }
    },
    spiritburn_bow = {
        name = "Spiritburn Bow",
        type = "bow",
        value = 400,
        description = "A volatile bow that consumes 1 Wisp to deal 1.5x damage.",
        spiritburn_bonus = 1.5,
        stats = {
            attackStat = 2
        }
    },
    spiritburn_staff = {
        name = "Spiritburn Staff",
        type = "staff",
        value = 400,
        description = "A volatile staff that consumes 1 Wisp to deal 1.5x damage.",
        spiritburn_bonus = 1.5,
        stats = {
            magicStat = 2
        }
    },
    spiritburn_tome = {
        name = "Spiritburn Tome",
        type = "tome",
        value = 400,
        description = "A volatile tome that consumes 1 Wisp to deal 1.5x damage.",
        spiritburn_bonus = 1.5,
        stats = {
            magicStat = 2
        }
    },
    spiritburn_dagger = {
        name = "Spiritburn Dagger",
        type = "dagger",
        value = 400,
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
        value = 600,
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
        value = 600,
        description = "A cursed bow that drains the wielder's spirit for physical power.",
        stats = {
            attackStat = 7,
            magicStat = -3,
            maxWisp = -1
        }
    },

    -- New Wisdom Weapons
    wisdoms_blade = {
        name = "Wisdom's Blade",
        type = "sword",
        value = 300,
        description = "A blade that seems to sharpen the mind of its wielder, accelerating their learning.",
        stats = {
            attackStat = 1
        },
        grants_passives = {"FastLearner"}
    },
    tome_of_wisdom = {
        name = "Tome of Wisdom",
        type = "tome",
        value = 300,
        description = "A tome that seems to sharpen the mind of its wielder, accelerating their learning.",
        stats = {
            magicStat = 1
        },
        grants_passives = {"FastLearner"}
    },
    wisdoms_lance = {
        name = "Wisdom's Lance",
        type = "lance",
        value = 300,
        description = "A lance that seems to sharpen the mind of its wielder, accelerating their learning.",
        stats = {
            attackStat = 1
        },
        grants_passives = {"FastLearner"}
    },
    wisdoms_bow = {
        name = "Wisdom's Bow",
        type = "bow",
        value = 300,
        description = "A bow that seems to sharpen the mind of its wielder, accelerating their learning.",
        stats = {
            attackStat = 1
        },
        grants_passives = {"FastLearner"}
    },
    wisdoms_dagger = {
        name = "Wisdom's Dagger",
        type = "dagger",
        value = 300,
        description = "A dagger that seems to sharpen the mind of its wielder, accelerating their learning.",
        stats = {
            attackStat = 1
        },
        grants_passives = {"FastLearner"}
    },
    wisdoms_whip = {
        name = "Wisdom's Whip",
        type = "whip",
        value = 300,
        description = "A whip that seems to sharpen the mind of its wielder, accelerating their learning.",
        stats = {
            attackStat = 1
        },
        grants_passives = {"FastLearner"}
    },
    wisdoms_staff = {
        name = "Wisdom's Staff",
        type = "staff",
        value = 300,
        description = "A staff that seems to sharpen the mind of its wielder, accelerating their learning.",
        stats = {
            magicStat = 1
        },
        grants_passives = {"FastLearner"}
    }
}

return WeaponBlueprints