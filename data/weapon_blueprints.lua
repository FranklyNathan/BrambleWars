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