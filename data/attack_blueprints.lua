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
    -- Damaging Melee Attacks
    venom_stab = {power = 20, type = "damage", targeting_style = "cycle_target", range = 1},
    uppercut = {power = 20, type = "damage", targeting_style = "cycle_target", range = 1},
    slash = {power = 20, type = "damage", targeting_style = "cycle_target", range = 1},
    shunt = {power = 20, type = "damage", targeting_style = "cycle_target", range = 1},
    shockstrike = {power = 20, type = "damage", targeting_style = "cycle_target", range = 1},

    -- Damaging Ranged Attacks
    fireball = {power = 20, type = "damage", targeting_style = "cycle_target", range = 99, affects = "enemies", line_of_sight_only = true},
    longshot = {power = 20, type = "damage", targeting_style = "cycle_target", range = 3, min_range = 3},
    eruption = {power = 20, type = "damage", targeting_style = "ground_aim", range = 7},

    -- Damaging Special Attacks
    phantom_step = {power = 40, type = "damage", targeting_style = "cycle_target"}, -- Range is dynamic (user's movement stat)

    -- Support Attacks
    invigorating_aura = {power = 0, type = "support", targeting_style = "cycle_target", range = 1, affects = "allies"},
    mend = {power = 0, type = "support", targeting_style = "cycle_target", range = 1, affects = "allies"},

    -- Status Attacks
    shockwave = {power = 0, type = "utility", targeting_style = "cycle_target", range = 14, affects = "enemies"},

    -- Movement Attacks
    quick_step = {power = 0, type = "utility", targeting_style = "ground_aim", range = 3, line_of_sight_only = true},

    -- Environment Attacks
    grovecall = {power = 0, type = "utility", targeting_style = "ground_aim", range = 6},

    -- Shared Attacks
    hookshot = {power = 30, type = "damage", targeting_style = "cycle_target", range = 7, affects = "all", line_of_sight_only = true},

}

return AttackBlueprints