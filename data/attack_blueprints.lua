-- attack_blueprints.lua
-- A central library defining the properties of all unique attacks in the game.

--[[
    Targeting Styles:
    - "cycle_target": Player cycles through valid targets within range.
        - `range`: The maximum distance (in tiles) to check for targets.
        - `min_range`: (Optional) The minimum distance. Defaults to 1.
        - `affects`: (Optional) "enemies", "allies", "all". Defaults to "enemies" for damage, "allies" for support.
    - "directional_aim": Player uses WASD to aim in a direction. The attack pattern is projected from the user.
    - "auto_hit_all": The attack automatically hits all valid targets on the map (e.g., all airborne enemies).
    - "no_target": The attack has no target and executes immediately (e.g., a self-buff or dash).
]]

local AttackBlueprints = {
    -- New Weapon-Based Basic Attacks
    slash = {
        name = "Slash",
        power = 5, -- Base power of the move, used in damage calculations
        wispCost = 0, -- Cost of the move is Wisp, a resource used for attacks
        Accuracy = 100, -- Odds of hitting, used in accuracy calculations
        CritChance = 5, -- Odds of a critical hit (which does double damage), used in crit calculations
        useType = "physical", -- Physical uses Attack/Defense stat in calcs, Magical uses Magic/Resistance stat, other options don't do damage
        targeting_style = "cycle_target", --See above for targeting styles
        patternType = "standard_melee", -- The 4 adjacent tiles.
        description = "A standard sword attack."
    },
    thrust = {
        name = "Thrust",
        power = 5,
        wispCost = 0,
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee",
        description = "A standard lance attack."
    },
    lash = {
        name = "Lash",
        power = 5,
        wispCost = 0,
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_all",
        description = "A standard whip attack."
    },
    loose = {
        name = "Loose",
        power = 5,
        wispCost = 0,
        Accuracy = 100,
        CritChance = 5,
        useType = "magical",
        targeting_style = "cycle_target",
        patternType = "standard_ranged", -- Can hit ranged tiles, but not adjacent ones.
        description = "A standard bow attack."
    },
    bonk = {
        name = "Bonk",
        power = 5,
        wispCost = 0,
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee",
        description = "A standard staff attack."
    },
    harm = {
        name = "Harm",
        power = 5,
        wispCost = 0,
        Accuracy = 100,
        CritChance = 5,
        useType = "magical",
        targeting_style = "cycle_target",
        patternType = "standard_all", -- Can hit adjacent melee and ranged tiles.
        description = "A standard tome attack."
    },
    stab = {
        name = "Stab",
        power = 5,
        wispCost = 0,
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee",
        description = "A standard dagger attack."
    },

    -- Damaging Melee Attacks
    venom_stab = {
        name = "Venom Stab",
        power = 6,
        wispCost = 1,
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        statusEffect = {type = "poison", duration = 3},
        description = "A physical attack that poisons the target."
    },
    uppercut = {
        name = "Uppercut",
        power = 7,
        wispCost = 2,
        Accuracy = 90,
        CritChance = 10,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        statusEffect = {type = "airborne", duration = 1.2},
        description = "A powerful physical attack that sends the target airborne."
    },
    sever = {
        name = "Sever",
        power = 6,
        wispCost = 1,
        Accuracy = 100,
        CritChance = 15,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        description = "A physical attack with a high critical hit chance."
    },
    shunt = {
        name = "Shunt",
        power = 6,
        wispCost = 1,
        Accuracy = 100,
        CritChance = 0,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        description = "A weak physical attack that pushes the target back."
    },
    shockstrike = {
        name = "Shockstrike",
        power = 6,
        wispCost = 1,
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        statusEffect = {type = "paralyzed", duration = 1},
        statusChance = 0.9, -- 90% chance to apply the status effect.
        description = "A physical attack that may paralyze the target."
    },
    impale = {
        name = "Impale",
        power = 7,
        wispCost = 1,
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        description = "A physical attack that deals extra damage if it pierces through to another enemy."
    },

    disarm = {
        name = "Disarm",
        power = 6,
        wispCost = 2,
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee",
        description = "A swift strike that knocks the target's weapon from their grasp, preventing counter-attacks for one turn."
    },

    -- Damaging Ranged Attacks
    fireball = {
        name = "Fireball",
        power = 3,
        wispCost = 2,
        Accuracy = 95,
        CritChance = 5,
        useType = "magical",
        targeting_style = "cycle_target",
        range = 99, -- Set to a very large number to simulate infinite range.
        affects = "enemies",
        line_of_sight_only = true,
        patternType = "line_of_sight", -- For the attack preview.
        drawsTile = true,
        description = "Launches a piercing fireball in a straight line."
    },
    longshot = {
        name = "Longshot",
        power = 5,
        wispCost = 3,
        Accuracy = 85,
        CritChance = 20,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "longshot_range", -- Can hit targets 2-3 tiles away.
        description = "A powerful, long-range physical attack with a high critical hit chance."
    },
    ice_beam = {
        name = "Ice Beam",
        power = 5,
        wispCost = 1,
        Accuracy = 100,
        CritChance = 5,
        useType = "magical",
        targeting_style = "cycle_target",
        range = 7,
        line_of_sight_only = true,
        canTargetTileType = "water", -- New: Allows targeting specific tile types.
        appliesTileStatus = { type = "frozen" }, -- Freezes water tiles it hits.
        drawsTile = true, -- So the effect is visible.
        description = "Fires a beam of ice that damages the first target hit and freezes water tiles in its path."
    },
    slipstep = {
        name = "Slipstep",
        power = 6,
        wispCost = 2,
        Accuracy = 100,
        CritChance = 0,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee",
        description = "A quick strike that causes the user and target to switch places."
    },
    eruption = {
        name = "Eruption",
        power = 5,
        wispCost = 4,
        Accuracy = 90,
        CritChance = 0,
        useType = "magical",
        targeting_style = "ground_aim",
        range = 7,
        patternType = "eruption_aoe", -- The 5x5 ripple effect.
        drawsTile = true,
        description = "Causes a delayed, multi-stage explosion at a target location, setting the ground aflame.",
        appliesTileStatus = { type = "aflame", duration = 2 }
    },

    -- Damaging Special Attacks
    phantom_step = {
        name = "Phantom Step",
        power = 7, -- A light utility attack.
        wispCost = 2,
        Accuracy = 100,
        CritChance = 0,
        useType = "utility",
        targeting_style = "cycle_target",
        affects = "enemies",
        statusEffect = {type = "stunned", duration = 1},
        description = "Teleport behind an enemy and strike them, causing stun."
    }, -- Range is dynamic (user's movement stat)

    -- Support Attacks
    invigoration = {
        name = "Invigoration",
        power = 0,
        wispCost = 1,
        Accuracy = 100,
        useType = "support",
        targeting_style = "cycle_target",
        affects = "allies",
        patternType = "standard_melee",
        drawsTile = true,
        description = "Refreshes an ally's turn if they have already acted."
    },
    mend = {
        name = "Mend",
        power = 5,
        wispCost = 1,
        Accuracy = 100,
        useType = "support",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        affects = "all", -- Can target allies and enemies.
        drawsTile = true,
        description = "Restores a small amount of HP to any unit."
    },
    kindle = {
        name = "Kindle",
        power = 0,
        wispCost = 1,
        useType = "support",
        targeting_style = "cycle_target",
        affects = "allies",
        patternType = "standard_melee",
        drawsTile = true,
        description = "Restores 3 Wisp to an adjacent ally."
    },
    bodyguard = {
        name = "Bodyguard",
        power = 0,
        wispCost = 2,
        useType = "utility",
        targeting_style = "cycle_target",
        affects = "allies",
        range = 99, -- Global range
        secondary_targeting_style = "adjacent_tiles", -- New: Triggers a second targeting step.
        drawsTile = true,
        description = "Instantly teleport to a vacant tile next to an ally. Ends the turn.",
        ends_turn_immediately = true,
        createsDangerZone = false -- This is a teleport, not a threat.
    },

    -- Status Attacks
    shockwave = {
        name = "Shockwave",
        power = 0,
        wispCost = 3,
        useType = "utility",
        targeting_style = "auto_hit_all",
        range = 12, -- This is a large radius around the user
        affects = "enemies",
        statusEffect = {type = "paralyzed", duration = 2},
        description = "Paralyzes all enemies within a wide radius."
    },

    taunt = {
        name = "Taunt",
        power = 0,
        wispCost = 2,
        useType = "utility",
        targeting_style = "cycle_target",
        range = 5,
        statusEffect = {type = "taunted", duration = 2},
        description = "Forces an enemy to target only you for 2 turns."
    },

    aegis = {
        name = "Aegis",
        power = 0,
        wispCost = 2,
        useType = "utility",
        targeting_style = "no_target",
        statusEffect = {type = "invincible", duration = 1.5},
        description = "Become immune to damage for 1 turn."
    },

    battle_cry = {
        name = "Battle Cry",
        power = 0,
        wispCost = 3,
        useType = "utility",
        targeting_style = "auto_hit_all",
        range = 8, -- For the taunt effect
        affects = "enemies",
        description = "Taunts all enemies within 8 range for 1 turn and grants user Invincibility for 1 turn."
    },

    -- Movement Attacks
    quick_step = {
        name = "Quick Step",
        power = 0,
        wispCost = 1,
        useType = "utility",
        targeting_style = "ground_aim",
        range = 3,
        line_of_sight_only = true,
        description = "A quick dash that makes enemies passed through airborne."
    },

    homecoming = {
        name = "Homecoming",
        power = 0,
        wispCost = 3,
        useType = "utility",
        targeting_style = "cycle_valid_tiles",
        valid_tile_type = "winTiles", -- The type of tile to look for in the world object.
        range = 99, -- Can be used from anywhere, so range check is not needed.
        drawsTile = true, -- So the cursor is visible
        description = "Instantly teleport to a friendly goal tile. Ends the turn.",
        ends_turn_immediately = true,
        createsDangerZone = false -- This is a teleport, not a threat.
    },

    -- Environment Attacks
    grovecall = {
        name = "Grovecall",
        power = 0,
        wispCost = 1,
        useType = "utility",
        targeting_style = "ground_aim",
        range = 6,
        drawsTile = true,
        description = "Summons a tree obstacle on the battlefield."
    },
    trap_set = {
        name = "Trap Set",
        power = 0,
        wispCost = 2,
        useType = "utility",
        targeting_style = "ground_aim",
        range = 2,
        drawsTile = true,
        description = "Summons a bear trap on an empty tile."
    },
    sow_seeds = {
        name = "Sow Seeds",
        power = 0,
        wispCost = 1,
        useType = "utility",
        targeting_style = "no_target",
        drawsTile = true,
        description = "Creates a patch of Tall Grass in a '+' shape around the user."
    },
    burrow = {
        name = "Burrow",
        power = 0,
        wispCost = 1,
        useType = "utility",
        targeting_style = "no_target", -- The first part of the move has no target.
        description = "Create a Molehill, then teleport to a Molehill on the map, refreshing your turn.",
        createsDangerZone = false -- This is a utility/movement ability.
    },
    ascension = {
        name = "Ascension",
        power = 0,
        wispCost = 5,
        useType = "utility",
        targeting_style = "ground_aim",
        range = 5,
        drawsTile = true,
        displayPower = "KO", -- Special display text for the UI.
        description = "Ascend, becoming untargetable. Descend at the end of the enemy turn, killing any unit on the chosen tile.",
        ends_turn_immediately = true -- This move will end the turn even if the user has Hustle.
    },
    ascension_strike = {
        name = "Ascension Strike",
        power = 9999, -- Instant kill
        wispCost = 0,
        Accuracy = 100,
        CritChance = 0,
        useType = "physical",
        targeting_style = "none", -- System-triggered, not player-targeted
        description = "The killing blow from Ascension."
    },

    thunderguard_retaliation = {
        name = "Thunderguard Retaliation",
        power = 0,
        useType = "utility",
        targeting_style = "none",
        drawsTile = true, -- This is used by the effect created in combat_actions.lua
        description = "A burst of retaliatory energy."
    },

    -- Shared Attacks
    hookshot = {
        name = "Hookshot",
        power = 5,
        wispCost = 2,
        useType = "physical",
        targeting_style = "cycle_target",
        range = 7,
        affects = "all",
        line_of_sight_only = true,
        description = "Fires a hook that pulls the user and target towards each other."
    },
}

-- Special System-Triggered Attacks (not used by players/AI directly)
AttackBlueprints.combustive_explosion = {
    name = "Combustive Explosion",
    power = 10,
    wispCost = 0,
    Accuracy = 100,
    useType = "utility",
    targeting_style = "none",
    patternType = "eruption_aoe", -- Use the same visual pattern as Eruption.
    drawsTile = true,             -- This flag tells the renderer to draw the attack's visual effect.
    deals_true_damage = true, -- New flag for flat damage that ignores stats and defenses.
    appliesTileStatus = { type = "aflame", duration = 2 },
    description = "The fiery explosion from a dying unit."
}

return AttackBlueprints