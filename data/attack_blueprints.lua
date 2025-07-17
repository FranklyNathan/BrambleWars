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
        power = 20,
        wispCost = 0,
        originType = "marshborn", 
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        range = 1,
        rangetype = "melee_only"
    },

    quill_jab = {
        power = 20,
        wispCost = 0,
        originType = "forestborn", 
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        range = 2,
        rangetype = "standard_range"
    },

    snap = {
        power = 20,
        wispCost = 0,
        originType = "cavernborn", 
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        range = 1,
        rangetype = "melee_only"
    },

    walnut_toss = {
        power = 20,
        wispCost = 1,
        originType = "cavernborn", 
        Accuracy = 100,
        CritChance = 5,
        useType = "magical",
        targeting_style = "cycle_target",
        range = 2,
        rangetype = "ranged_only"
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
        range = 1,
        rangetype = "melee_only"
    },
    uppercut = {
        power = 40,
        wispCost = 2,
        originType = "forestborn", 
        Accuracy = 90,
        CritChance = 10,
        useType = "physical",
        targeting_style = "cycle_target",
        range = 1,
        rangetype = "melee_only"
    },
    slash = {
        power = 35,
        wispCost = 1,
        originType = "forestborn", 
        Accuracy = 100,
        CritChance = 15,
        useType = "physical",
        targeting_style = "cycle_target",
        range = 1,
        rangetype = "melee_only"
    },
    shunt = {
        power = 15,
        wispCost = 1,
        originType = "caverborn", 
        Accuracy = 100,
        CritChance = 0,
        useType = "physical",
        targeting_style = "cycle_target",
        range = 1,
        rangetype = "melee_only"
    },
    shockstrike = {
        power = 20,
        wispCost = 1,
        originType = "cavernborn", 
        Accuracy = 100,
        CritChance = 5,
        useType = "physical",
        targeting_style = "cycle_target",
        range = 1,
        rangetype = "melee_only"
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
        range = 6,
        affects = "enemies",
        line_of_sight_only = true
    },
    longshot = {
        power = 50,
        wispCost = 3,
        originType = "forestborn", 
        Accuracy = 85,
        CritChance = 20,
        useType = "physical",
        targeting_style = "cycle_target",
        range = 4,
        min_range = 3
    },
    eruption = {
        power = 60,
        wispCost = 4,
        originType = "cavernborn", 
        Accuracy = 90,
        CritChance = 0,
        useType = "magical",
        targeting_style = "ground_aim",
        range = 7
    },

    -- Damaging Special Attacks
    phantom_step = {
        power = 0, -- This attack does no damage, it is for movement.
        wispCost = 2,
        originType = "marshborn", 
        Accuracy = 100,
        CritChance = 5,
        useType = "utility",
        targeting_style = "cycle_target"
    }, -- Range is dynamic (user's movement stat)

    -- Support Attacks
    invigorating_aura = {
        power = 0,
        wispCost = 1,
        originType = "cavernborn", 
        useType = "support",
        targeting_style = "cycle_target",
        range = 1,
        affects = "allies"
    },
    mend = {
        power = 0,
        wispCost = 1,
        originType = "cavernborn", 
        useType = "support",
        targeting_style = "cycle_target",
        range = 1,
        affects = "allies"
    },

    -- Status Attacks
    shockwave = {
        power = 0,
        wispCost = 1,
        originType = "cavernborn", 
        useType = "utility",
        targeting_style = "cycle_target",
        range = 99,
        affects = "enemies"
    },

    -- Movement Attacks
    quick_step = {
        power = 0,
        wispCost = 1,
        originType = "cavernborn", 
        useType = "utility",
        targeting_style = "ground_aim",
        range = 3,
        line_of_sight_only = true
    },

    -- Environment Attacks
    grovecall = {
        power = 0,
        wispCost = 6,
        originType = "cavernborn", 
        useType = "utility",
        targeting_style = "ground_aim",
        range = 6
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
        line_of_sight_only = true
    },

}

return AttackBlueprints