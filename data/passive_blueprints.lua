-- data/passive_blueprints.lua
-- Contains the display names and descriptions for all passive abilities.

local PassiveBlueprints = {
    Hustle = {
        name = "Hustle",
        description = "Allows this unit to take a second action after their first."
    },
    HealingWinds = {
        name = "Healing Winds",
        description = "At the end of your turn, all allied units recover 5 HP."
    },
    Bloodrush = {
        name = "Bloodrush",
        description = "If this unit defeats an enemy, their turn is refreshed, allowing them to act again."
    },
    Whiplash = {
        name = "Whiplash",
        description = "Doubles the force of any push or pull effects caused by this unit's attacks."
    },
    Aetherfall = {
        name = "Aetherfall",
        description = "If an enemy becomes airborne, this unit may instantly teleport adjacent to them and strike."
    },
    Captor = {
        name = "Captor",
        description = "Allows this unit to rescue adjacent enemies."
    },
    Soulsnatcher = {
        name = "Soulsnatcher",
        description = "When this unit damages an enemy with an attack, they steal 1 Wisp from the target."
    },
    Desperate = {
        name = "Desperate",
        description = "Increases damage dealt as HP decreases. The lower the HP, the higher the damage."
    },
    Elusive = {
        name = "Elusive",
        description = "Allows this unit to move through tiles occupied by enemies."
    },
    Treacherous = {
        name = "Treacherous",
        description = "Can target and attack allies. Doing so stuns the ally and permanently increases this unit's Attack and Wit by 1."
    },
    Thunderguard = {
        name = "Thunderguard",
        description = "When damaged, retaliates with a burst of energy that paralyzes all nearby enemy units."
    },
    Unbound = {
        name = "Unbound",
        description = "Deals 1.5x damage while at 0 Wisp."
    },
    Combustive = {
        name = "Combustive",
        description = "Explodes upon death, dealing 10 damage to all units within 1 range."
    },
    Infernal = {
        name = "Infernal",
        description = "Immune to Aflame tile damage. Gains +5 Atk/Def/Mag/Res while on an Aflame tile."
    }
}

return PassiveBlueprints