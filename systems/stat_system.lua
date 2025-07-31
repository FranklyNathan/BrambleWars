-- stat_system.lua
-- Manages unit stats by recalculating them only when necessary (e.g., on status changes).

-- Calculates the final, combat-ready stats for all entities based on their
-- base stats, equipment, and status effects.

local EventBus = require("modules.event_bus")
local WeaponBlueprints = require("data.weapon_blueprints")

local StatSystem = {}

-- Helper to capitalize the first letter of a string (e.g., "attackStat" -> "AttackStat").
local function capitalize(str)
    if not str or #str == 0 then return "" end
    return str:sub(1,1):upper() .. str:sub(2)
end

-- A list of all stats that can be modified by effects or equipment.
local MODIFIABLE_STATS = {
    "attackStat", "defenseStat", "magicStat", "resistanceStat",
    "witStat", "maxHp", "maxWisp", "speed", "movement", "weight"
}

-- This is the core logic. It recalculates all final stats for a single unit.
function StatSystem.recalculate_for_unit(unit)

    -- 1. Start with base stats.
    for _, statName in ipairs(MODIFIABLE_STATS) do
        local finalStatName = "final" .. capitalize(statName)
        -- The base value is the stat on the unit object itself (e.g., unit.attackStat).
        unit[finalStatName] = unit[statName] or 0
    end

    -- 2. Apply modifiers from the equipped weapon.
    if unit.equippedWeapon and WeaponBlueprints[unit.equippedWeapon] then
        local weapon = WeaponBlueprints[unit.equippedWeapon]
        if weapon.stats then
            for statName, bonus in pairs(weapon.stats) do
                local finalStatName = "final" .. capitalize(statName)
                if unit[finalStatName] ~= nil then
                    unit[finalStatName] = unit[finalStatName] + bonus
                end
            end
        end
    end

    -- 3. Apply modifiers from status effects.
    if unit.statusEffects then
        for _, effect in pairs(unit.statusEffects) do
            if effect.statModifiers then
                for statName, modifier in pairs(effect.statModifiers) do
                    local finalStatName = "final" .. capitalize(statName)
                    if unit[finalStatName] ~= nil then
                        unit[finalStatName] = unit[finalStatName] + modifier
                    end
                end
            end
        end
    end

    -- 4. Ensure stats don't fall below a minimum (e.g., 0).
    for _, statName in ipairs(MODIFIABLE_STATS) do
        local finalStatName = "final" .. capitalize(statName)
        unit[finalStatName] = math.max(0, unit[finalStatName])
    end
end

-- Event handler for when a unit is added to the world.
local function on_unit_added(data)
    StatSystem.recalculate_for_unit(data.unit)
end

-- Event handler for when a status is applied or removed.
-- The logic is the same for both: just recalculate everything.
local function on_status_changed(data)
    -- The event payload for status effects uses 'target' for the unit.
    StatSystem.recalculate_for_unit(data.target)
end

-- Event handler for when a unit equips a new weapon.
local function on_weapon_changed(data)
    StatSystem.recalculate_for_unit(data.unit)
end

-- Register the event listeners. This code runs when the module is required.
EventBus:register("unit_added", on_unit_added)
EventBus:register("status_applied", on_status_changed)
EventBus:register("status_removed", on_status_changed)
-- This event will be dispatched by the UI when a weapon is equipped.
EventBus:register("weapon_equipped", on_weapon_changed)

return StatSystem