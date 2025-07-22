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
    -- Basic Attacks
    froggy_rush = {
        power = 20, -- Base power of the move, used in damage calculations
        wispCost = 0, -- Cost of the move is Wisp, a resource used for attacks
        originType = "marshborn", -- Similar to types in Pokemon. Currently marshborn, forestborn, cavernborn
        Accuracy = 100, -- Odds of hitting, used in accuracy calculations
        CritChance = 5, -- Odds of a critical hit (which does double damage), used in crit calculations
        useType = "physical", -- Physical uses Attack/Defense stat in calcs, Magical uses Magic/Resistance stat, other options don't do damage
        targeting_style = "cycle_target", --See above for targeting styles
        patternType = "standard_melee", -- The 4 adjacent tiles.
        description = "A standard physical attack."
    },

    quill_jab = {
        power = 20,
        wispCost = 0,
        originType = "forestborn", 
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_all", -- Can hit adjacent and standard ranged tiles.
        description = "A standard physical attack that can hit from a distance."
    },

    snap = {
        power = 20,
        wispCost = 0,
        originType = "cavernborn", 
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        description = "A standard physical attack."
    },

    walnut_toss = {
        power = 20,
        wispCost = 0,
        originType = "cavernborn", 
        Accuracy = 100,
        CritChance = 5,
        useType = "magical",
        targeting_style = "cycle_target",
        patternType = "standard_ranged", -- Can hit ranged tiles, but not adjacent ones.
        description = "A standard magical attack from a distance."
    },

    -- Damaging Melee Attacks
    venom_stab = {
        power = 30,
        wispCost = 1,
        originType = "marshborn", 
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        description = "A physical attack that poisons the target."
    },
    uppercut = {
        power = 40,
        wispCost = 2,
        originType = "forestborn", 
        Accuracy = 90,
        CritChance = 10,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        description = "A powerful physical attack that sends the target airborne."
    },
    slash = {
        power = 35,
        wispCost = 1,
        originType = "forestborn", 
        Accuracy = 100,
        CritChance = 15,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        description = "A physical attack with a high critical hit chance."
    },
    shunt = {
        power = 15,
        wispCost = 1,
        originType = "caverborn", 
        Accuracy = 100,
        CritChance = 0,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        description = "A weak physical attack that pushes the target back."
    },
    shockstrike = {
        power = 20,
        wispCost = 1,
        originType = "cavernborn", 
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        description = "A physical attack that may paralyze the target."
    },
    impale = {
        power = 30,
        wispCost = 1,
        originType = "cavernborn", 
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        description = "A physical attack that deals extra damage if it pierces through to another enemy."
    },

    -- Damaging Ranged Attacks
    fireball = {
        power = 45,
        wispCost = 2,
        originType = "cavernborn", 
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
        power = 50,
        wispCost = 3,
        originType = "forestborn", 
        Accuracy = 85,
        CritChance = 20,
        useType = "physical",
        targeting_style = "cycle_target",
        patternType = "longshot_range", -- Can hit targets 2-3 tiles away.
        description = "A powerful, long-range physical attack with a high critical hit chance."
    },
    eruption = {
        power = 60,
        wispCost = 4,
        originType = "cavernborn", 
        Accuracy = 90,
        CritChance = 0,
        useType = "magical",
        targeting_style = "ground_aim",
        range = 7,
        patternType = "eruption_aoe", -- The 5x5 ripple effect.
        drawsTile = true,
        description = "Causes a delayed, multi-stage explosion at a target location."
    },

    -- Damaging Special Attacks
    phantom_step = {
        power = 15, -- A light utility attack.
        wispCost = 2,
        originType = "marshborn", 
        Accuracy = 100,
        CritChance = 0,
        useType = "utility",
        targeting_style = "cycle_target",
        affects = "enemies",
        description = "Teleport behind an enemy and strike them, causing stun."
    }, -- Range is dynamic (user's movement stat)

    -- Support Attacks
    invigoration = {
        power = 0,
        wispCost = 1,
        originType = "cavernborn", 
        Accuracy = 100,
        useType = "support",
        targeting_style = "cycle_target",
        affects = "allies",
        patternType = "standard_melee",
        drawsTile = true,
        description = "Refreshes an ally's turn if they have already acted."
    },
    mend = {
        power = 20,
        wispCost = 1,
        originType = "cavernborn", 
        Accuracy = 100,
        useType = "support",
        targeting_style = "cycle_target",
        patternType = "standard_melee", -- The 4 adjacent tiles.
        affects = "all", -- Can target allies and enemies.
        drawsTile = true,
        description = "Restores a small amount of HP to any unit."
    },

    -- Status Attacks
    shockwave = {
        power = 0,
        wispCost = 1,
        originType = "cavernborn", 
        useType = "utility",
        targeting_style = "auto_hit_all",
        range = 12, -- This is a large radius around the user
        affects = "enemies",
        description = "Paralyzes all enemies within a wide radius."
    },

    -- Movement Attacks
    quick_step = {
        power = 0,
        wispCost = 1,
        originType = "cavernborn", 
        useType = "utility",
        targeting_style = "ground_aim",
        range = 3,
        line_of_sight_only = true,
        description = "A quick dash that makes enemies passed through airborne."
    },

    -- Environment Attacks
    grovecall = {
        power = 0,
        wispCost = 1,
        originType = "cavernborn", 
        useType = "utility",
        targeting_style = "ground_aim",
        range = 6,
        drawsTile = true,
        description = "Summons a tree obstacle on the battlefield."
    },

    -- Shared Attacks
    hookshot = {
        power = 30,
        wispCost = 2,
        originType = "forestborn", 
        useType = "physical",
        targeting_style = "cycle_target",
        range = 7,
        affects = "all",
        line_of_sight_only = true,
        description = "Fires a hook that pulls the user and target towards each other."
    },

}

return AttackBlueprints