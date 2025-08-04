-- data/passive_blueprints.lua
-- Contains an alphabetized list of the display names and descriptions for all passive abilities.

local PassiveBlueprints = {
    Aetherfall = {
        name = "Aetherfall",
        description = "If an enemy becomes airborne, this unit may instantly teleport adjacent to them and strike."
    },
    Bloodrush = {
        name = "Bloodrush",
        description = "If this unit defeats an enemy, their turn is refreshed, allowing them to act again."
    },
    Captor = {
        name = "Captor",
        description = "Allows this unit to rescue adjacent enemies."
    },
    Combustive = {
        name = "Combustive",
        description = "Explodes upon death, dealing 10 damage to all units within 1 range.",
        trigger = "on_death", -- The event that triggers this passive.
        on_death_effect = { -- The effect to create when triggered.
            type = "ripple",
            attackName = "combustive_explosion",
            targetType = "all"
        }
    },
    Desperate = {
        name = "Desperate",
        description = "Increases damage dealt as HP decreases. The lower the HP, the higher the damage."
    },
    Devourer = {
        name = "Devourer",
        description = "When this unit kills an enemy, it gains that unit's passives."
    },
    DualWielder = {
        name = "Dual Wielder",
        description = "Allows this unit to equip a second weapon."
    },
    Elusive = {
        name = "Elusive",
        description = "Allows this unit to move through tiles occupied by enemies."
    },
    Ephemeral = {
        name = "Ephemeral",
        description = "This unit dies at the end of the turn."
    },
    Frozenfoot = {
        name = "Frozenfoot",
        description = "Can walk on water, freezing it. Immune to breaking ice."
    },
    HealingWinds = {
        name = "Healing Winds",
        description = "At the end of your turn, all allied units recover 5 HP."
    },
    Hustle = {
        name = "Hustle",
        description = "Allows this unit to take a second action after their first."
    },
    Infernal = {
        name = "Infernal",
        description = "Immune to Aflame tile damage. Powers up while on an Aflame tile."
    },
    LastStand = {
        name = "Last Stand",
        description = "Deals 2x damage while standing on a WinTile."
    },
    Necromantia = {
        name = "Necromantia",
        description = "When this unit kills an enemy, the slain foe is revived to fight on your team.",
    },
    Proliferate = {
        name = "Proliferate",
        description = "When this unit revives an enemy, the revived unit inherits this unit's passives."
    },
    Soulsnatcher = {
        name = "Soulsnatcher",
        description = "When this unit damages an enemy with an attack, they steal 1 Wisp from the target."
    },
    Thunderguard = {
        name = "Thunderguard",
        description = "When damaged, retaliates with a burst of energy that paralyzes all nearby enemy units."
    },
    Treacherous = {
        name = "Treacherous",
        description = "Can attack allies. Doing so stuns the ally and permanently increases this unit's Attack and Wit by 1."
    },
    Unbound = {
        name = "Unbound",
        description = "Deals 1.5x damage while at 0 Wisp."
    },
    Unburdened = {
        name = "Unburdened",
        description = "Grants +3 Movement when no weapon is equipped."
    },
    Vampirism = {
        name = "Vampirism",
        description = "Heals for 25% of damage dealt by attacks.",
        lifesteal_percent = 0.25
    },
    Whiplash = {
        name = "Whiplash",
        description = "Doubles the force of any push or pull effects caused by this unit's attacks."
    }
}

return PassiveBlueprints