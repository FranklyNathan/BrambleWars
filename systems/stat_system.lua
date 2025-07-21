-- stat_system.lua
-- Manages unit stats by recalculating them only when necessary (e.g., on status changes).

-- Calculates the final, combat-ready stats for all entities based on their
-- base stats, equipment, and status effects.

local EventBus = require("modules.event_bus")

local StatSystem = {}

-- This is the core logic. It recalculates all final stats for a single unit.
function StatSystem.recalculate_for_unit(unit)
    -- Only operate on units that have stats.
    if not unit.baseAttackStat then return end

    -- 1. Start with base stats.
    unit.finalAttackStat = unit.baseAttackStat
    unit.finalDefenseStat = unit.baseDefenseStat
    unit.finalSpeed = unit.speed or 0 -- Use base speed, default to 0 if not present.

    -- 2. Apply modifiers from status effects.
    if unit.statusEffects then
        for _, effect in pairs(unit.statusEffects) do
            if effect.statModifiers then
                unit.finalAttackStat = unit.finalAttackStat + (effect.statModifiers.attack or 0)
                unit.finalDefenseStat = unit.finalDefenseStat + (effect.statModifiers.defense or 0)
                unit.finalSpeed = unit.finalSpeed + (effect.statModifiers.speed or 0)
            end
        end
    end

        -- TODO: In the future, add logic here to apply bonuses from:
    -- 1. Items in entity.inventory
    -- 2. Team-wide passives (e.g., from world.teamPassives)

    -- Ensure stats don't fall below a minimum (e.g., 0).
    unit.finalAttackStat = math.max(0, unit.finalAttackStat)
    unit.finalDefenseStat = math.max(0, unit.finalDefenseStat)
    unit.finalSpeed = math.max(0, unit.finalSpeed)
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

-- Register the event listeners. This code runs when the module is required.
EventBus:register("unit_added", on_unit_added)
EventBus:register("status_applied", on_status_changed)
EventBus:register("status_removed", on_status_changed)

return StatSystem