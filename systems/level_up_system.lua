-- systems/level_up_system.lua
-- This system handles the logic for units leveling up and gaining stats.

local LevelUpSystem = {}

-- The maximum level a unit can reach.
local MAX_LEVEL = 50

--- Calculates stat gains for a level up without applying them.
-- This is used to feed data to the level up display system.
-- @param unit (table): The unit to calculate gains for.
-- @return (table): A table of stat increases, e.g., {maxHp = 1, attackStat = 1}
function LevelUpSystem.calculateLevelGains(unit)
    local statGains = {}
    if not unit.growths then return statGains end

    -- Iterate through each stat in the unit's growth table.
    for statName, growthRate in pairs(unit.growths) do
        if love.math.random(1, 100) <= growthRate then
            -- Stat increase!
            if unit[statName] then
                statGains[statName] = (statGains[statName] or 0) + 1
            end
        end
    end
    return statGains
end

--- Processes a single level gain for a unit, applying stat increases instantly.
-- This is a helper for non-animated level ups, like for enemies created at a higher level.
-- @param unit (table): The unit to apply stats to.
function LevelUpSystem.applyInstantLevelUp(unit)
    if not unit.growths then return end

    -- Iterate through each stat in the unit's growth table.
    for statName, growthRate in pairs(unit.growths) do
        if love.math.random(1, 100) <= growthRate then
            -- Stat increase!
            if unit[statName] then
                unit[statName] = unit[statName] + 1
                -- If maxHp increases, also increase current hp by 1.
                if statName == "maxHp" then
                    unit.hp = unit.hp + 1
                end
            end
        end
    end
end

--- Checks if a player unit has enough EXP to level up and triggers the animation if so.
-- @param unit (table): The player unit to check.
-- @param world (table): The main game world table.
-- @return (boolean): True if a level up was triggered, false otherwise.
function LevelUpSystem.checkForLevelUp(unit, world)
    -- Only player units can level up from EXP, and only if they are not at max level.
    -- Lazily require the display system here to break the circular dependency.
    local LevelUpDisplaySystem = require("systems.level_up_display_system")

    if unit.type ~= "player" or not unit.exp or unit.level >= MAX_LEVEL then
        return false
    end

    if unit.exp >= unit.maxExp then
        -- Calculate the gains but don't apply them here.
        local statGains = LevelUpSystem.calculateLevelGains(unit)
        
        -- Trigger the visual display system. It will handle applying the stats, level, and EXP later.
        LevelUpDisplaySystem.start(unit, statGains, world)
        
        return true -- A level up was triggered.
    end

    return false -- No level up occurred.
end

return LevelUpSystem