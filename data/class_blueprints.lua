-- data/class_blueprints.lua
-- Defines the data for all character classes, including their promotions and stat bonuses.

--[[
    Structure:
    - Each key is a class identifier (e.g., "thief").
    - `name`: The display name of the class.
    - `weaponTypes`: A list of weapon type identifiers this class can equip.
    - `promotions`: A table where each key is the identifier of a class it can promote to.
        - `name`: The display name of the promoted class.
        - `stat_bonuses`: A table of flat stat increases gained upon promotion.
--]]

local ClassBlueprints = {
    -- =============================================================================
    -- == Basic Classes
    -- =============================================================================
    thief = {
        name = "Thief",
        weaponTypes = {"dagger"},
        promotions = {
            rogue = {
                name = "Rogue",
                stat_bonuses = {
                    maxHp = 2, wispStat = 1, attackStat = 4, defenseStat = 3,
                    magicStat = 1, resistanceStat = 2, witStat = 2, movement = 1, weight = 0,
                }
            },
            assassin = {
                name = "Assassin",
                stat_bonuses = {
                    maxHp = 1, wispStat = 1, attackStat = 5, defenseStat = 1,
                    magicStat = 1, resistanceStat = 1, witStat = 4, movement = 1, weight = 0,
                }
            }
        }
    },

    warrior = {
        name = "Warrior",
        weaponTypes = {"sword"},
        promotions = {
            executioner = {
                name = "Executioner",
                stat_bonuses = {
                    maxHp = 3, wispStat = 0, attackStat = 5, defenseStat = 2,
                    magicStat = 0, resistanceStat = 1, witStat = 3, movement = 0, weight = 1,
                }
            },
            sentinel = {
                name = "Sentinel",
                stat_bonuses = {
                    maxHp = 5, wispStat = 0, attackStat = 2, defenseStat = 5,
                    magicStat = 0, resistanceStat = 3, witStat = 1, movement = 0, weight = 2,
                }
            }
        }
    },

    scout = {
        name = "Scout",
        weaponTypes = {"bow"},
        promotions = {
            ranger = {
                name = "Ranger",
                stat_bonuses = {
                    maxHp = 2, wispStat = 1, attackStat = 3, defenseStat = 2,
                    magicStat = 1, resistanceStat = 2, witStat = 3, movement = 1, weight = 0,
                }
            },
            sniper = {
                name = "Sniper",
                stat_bonuses = {
                    maxHp = 1, wispStat = 1, attackStat = 4, defenseStat = 1,
                    magicStat = 1, resistanceStat = 1, witStat = 5, movement = 0, weight = 0,
                }
            }
        }
    },

    mage = {
        name = "Mage",
        weaponTypes = {"tome"},
        promotions = {
            wizard = {
                name = "Wizard",
                stat_bonuses = {
                    maxHp = 1, wispStat = 2, attackStat = 0, defenseStat = 1,
                    magicStat = 5, resistanceStat = 3, witStat = 2, movement = 0, weight = 0,
                }
            },
            luminary = {
                name = "Luminary",
                stat_bonuses = {
                    maxHp = 2, wispStat = 2, attackStat = 0, defenseStat = 2,
                    magicStat = 3, resistanceStat = 5, witStat = 1, movement = 0, weight = 0,
                }
            }
        }
    },

    knight = {
        name = "Knight",
        weaponTypes = {"lance"},
        promotions = {
            paladin = {
                name = "Paladin",
                stat_bonuses = {
                    maxHp = 4, wispStat = 1, attackStat = 2, defenseStat = 4,
                    magicStat = 2, resistanceStat = 4, witStat = 0, movement = 0, weight = 1,
                }
            },
            cavalier = {
                name = "Cavalier",
                stat_bonuses = {
                    maxHp = 3, wispStat = 0, attackStat = 4, defenseStat = 3,
                    magicStat = 0, resistanceStat = 1, witStat = 2, movement = 2, weight = 1,
                }
            }
        }
    },

    druid = {
        name = "Druid",
        weaponTypes = {"tome"},
        promotions = {
            warlock = {
                name = "Warlock",
                stat_bonuses = {
                    maxHp = 2, wispStat = 1, attackStat = 0, defenseStat = 2,
                    magicStat = 4, resistanceStat = 4, witStat = 2, movement = 0, weight = 0,
                }
            },
            necromancer = {
                name = "Necromancer",
                stat_bonuses = {
                    maxHp = 3, wispStat = 1, attackStat = 1, defenseStat = 3,
                    magicStat = 3, resistanceStat = 3, witStat = 1, movement = 0, weight = 0,
                }
            }
        }
    },

    bard = {
        name = "Bard",
        weaponTypes = {"staff"},
        promotions = {
            soothsayer = {
                name = "Soothsayer",
                stat_bonuses = {
                    maxHp = 2, wispStat = 3, attackStat = 0, defenseStat = 1,
                    magicStat = 2, resistanceStat = 5, witStat = 2, movement = 0, weight = 0,
                }
            },
            troubadour = {
                name = "Troubadour",
                stat_bonuses = {
                    maxHp = 2, wispStat = 2, attackStat = 1, defenseStat = 2,
                    magicStat = 1, resistanceStat = 3, witStat = 3, movement = 1, weight = 0,
                }
            }
        }
    },

    lancer = {
        name = "Lancer",
        weaponTypes = {"lance"},
        promotions = {
            dragonlord = {
                name = "Dragonlord",
                stat_bonuses = {
                    maxHp = 4, wispStat = 0, attackStat = 4, defenseStat = 4,
                    magicStat = 0, resistanceStat = 2, witStat = 1, movement = 1, weight = 2,
                }
            },
            stormrider = {
                name = "Stormrider",
                stat_bonuses = {
                    maxHp = 3, wispStat = 1, attackStat = 4, defenseStat = 2,
                    magicStat = 1, resistanceStat = 2, witStat = 3, movement = 1, weight = 1,
                }
            },
            dragoon = {
                name = "Dragoon",
                stat_bonuses = {
                    maxHp = 3, wispStat = 0, attackStat = 5, defenseStat = 3,
                    magicStat = 0, resistanceStat = 2, witStat = 2, movement = 0, weight = 1,
                }
            }
        }
    },

    trickster = {
        name = "Trickster",
        weaponTypes = {"whip"},
        promotions = {
            illusionist = {
                name = "Illusionist",
                stat_bonuses = {
                    maxHp = 2, wispStat = 2, attackStat = 1, defenseStat = 2,
                    magicStat = 3, resistanceStat = 3, witStat = 4, movement = 0, weight = 0,
                }
            },
            harlequin = {
                name = "Harlequin",
                stat_bonuses = {
                    maxHp = 2, wispStat = 1, attackStat = 3, defenseStat = 2,
                    magicStat = 1, resistanceStat = 2, witStat = 5, movement = 1, weight = 0,
                }
            }
        }
    },

    -- =============================================================================
    -- == Advanced Classes (no further promotions)
    -- =============================================================================

    -- Thief Promotions
    rogue = { name = "Rogue", weaponTypes = {"dagger", "sword"}, promotions = {} },
    assassin = { name = "Assassin", weaponTypes = {"dagger"}, promotions = {} },

    -- Warrior Promotions
    executioner = { name = "Executioner", weaponTypes = {"sword", "whip"}, promotions = {} },
    sentinel = { name = "Sentinel", weaponTypes = {"sword"}, promotions = {} },

    -- Scout Promotions
    ranger = { name = "Ranger", weaponTypes = {"bow", "dagger"}, promotions = {} },
    sniper = { name = "Sniper", weaponTypes = {"bow"}, promotions = {} },

    -- Mage Promotions
    wizard = { name = "Wizard", weaponTypes = {"tome"}, promotions = {} },
    luminary = { name = "Luminary", weaponTypes = {"tome", "staff"}, promotions = {} },

    -- Knight Promotions
    paladin = { name = "Paladin", weaponTypes = {"lance", "staff"}, promotions = {} },
    cavalier = { name = "Cavalier", weaponTypes = {"lance", "sword"}, promotions = {} },

    -- Druid Promotions
    warlock = { name = "Warlock", weaponTypes = {"tome"}, promotions = {} },
    necromancer = { name = "Necromancer", weaponTypes = {"tome"}, promotions = {} },

    -- Bard Promotions
    soothsayer = { name = "Soothsayer", weaponTypes = {"staff"}, promotions = {} },
    troubadour = { name = "Troubadour", weaponTypes = {"staff"}, promotions = {} },

    -- Lancer Promotions
    dragonlord = { name = "Dragonlord", weaponTypes = {"lance", "bow"}, promotions = {} },
    stormrider = { name = "Stormrider", weaponTypes = {"lance", "whip"}, promotions = {} },
    dragoon = { name = "Dragoon", weaponTypes = {"lance"}, promotions = {} },

    -- Trickster Promotions
    illusionist = { name = "Illusionist", weaponTypes = {"whip"}, promotions = {} },
    harlequin = { name = "Harlequin", weaponTypes = {"whip"}, promotions = {} },
}

return ClassBlueprints