-- stat_system.lua
-- Manages unit stats by recalculating them only when necessary (e.g., on status changes).

-- Calculates the final, combat-ready stats for all entities based on their
-- base stats, equipment, and status effects.

local EventBus = require("modules.event_bus")
local WeaponBlueprints = require("data.weapon_blueprints")
local TileStatusBlueprints = require("data.tile_status_blueprints")
local WorldQueries = require("modules.world_queries")

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
function StatSystem.recalculate_for_unit(unit, world)
    -- Failsafe if world is not passed (e.g., from an older event call)
    if not world then return end

    -- 1. Start with base stats.
    for _, statName in ipairs(MODIFIABLE_STATS) do
        local finalStatName = "final" .. capitalize(statName)
        -- The base value is the stat on the unit object itself (e.g., unit.attackStat).
        unit[finalStatName] = unit[statName] or 0
    end

    -- 2. Apply modifiers from all equipped weapons.
    if unit.equippedWeapons then
        for _, weaponName in ipairs(unit.equippedWeapons) do
            local weapon = WeaponBlueprints[weaponName]
            if weapon and weapon.stats then
                for statName, bonus in pairs(weapon.stats) do
                    local finalStatName = "final" .. capitalize(statName)
                    if unit[finalStatName] ~= nil then
                        unit[finalStatName] = unit[finalStatName] + bonus
                    end
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

    -- 4. Apply modifiers from passives based on conditions (e.g., Infernal).
    if unit.type and world.teamPassives[unit.type] and world.teamPassives[unit.type].Infernal then
        local unitHasInfernal = false
        for _, provider in ipairs(world.teamPassives[unit.type].Infernal) do
            if provider == unit then
                unitHasInfernal = true
                break
            end
        end

        if unitHasInfernal then
            local posKey = unit.tileX .. "," .. unit.tileY
            if world.tileStatuses[posKey] and world.tileStatuses[posKey].type == "aflame" then
                local INFERNAL_BONUS = 5
                unit.finalAttackStat = unit.finalAttackStat + INFERNAL_BONUS
                unit.finalDefenseStat = unit.finalDefenseStat + INFERNAL_BONUS
                unit.finalMagicStat = unit.finalMagicStat + INFERNAL_BONUS
                unit.finalResistanceStat = unit.finalResistanceStat + INFERNAL_BONUS
            end
        end
    end

    -- 4.5. Apply modifiers from other conditional passives (like Unburdened).
    if unit.type and WorldQueries.hasPassive(unit, "Unburdened", world) then
        -- If the unit has the "Unburdened" passive and no weapon is equipped, grant a movement bonus.
        if not WorldQueries.isUnitArmed(unit) then
            unit.finalMovement = unit.finalMovement + 3
        end
    end

    -- 4.6. Apply modifiers from Bogbound passive.
    if WorldQueries.hasPassive(unit, "Bogbound", world) then
        if WorldQueries.isTileMud(unit.tileX, unit.tileY, world) then
            unit.finalDefenseStat = math.floor(unit.finalDefenseStat * 1.25)
            unit.finalResistanceStat = math.floor(unit.finalResistanceStat * 1.25)
        end
    end

    -- 5. Apply modifiers from the tile the unit is standing on.
    if unit.tileX and unit.tileY then
        local posKey = unit.tileX .. "," .. unit.tileY
        if world.tileStatuses[posKey] then
            local tileStatus = world.tileStatuses[posKey]
            local blueprint = TileStatusBlueprints[tileStatus.type]
            -- Apply Tall Grass Wit bonus
            if blueprint and blueprint.witMultiplier then
                unit.finalWitStat = math.floor(unit.finalWitStat * blueprint.witMultiplier)
            end
        end
    end

    -- 6. Ensure stats don't fall below a minimum (e.g., 0).
    for _, statName in ipairs(MODIFIABLE_STATS) do
        local finalStatName = "final" .. capitalize(statName)
        unit[finalStatName] = math.max(0, unit[finalStatName])
    end
end

-- Event handler for when a unit is added to the world.
local function on_unit_added(data)
    StatSystem.recalculate_for_unit(data.unit, data.world)
end

-- Event handler for when a status is applied or removed.
-- The logic is the same for both: just recalculate everything.
local function on_status_changed(data)
    -- The event payload for status effects uses 'target' for the unit.
    StatSystem.recalculate_for_unit(data.target, data.world)
end

-- Event handler for when a unit equips a new weapon.
local function on_weapon_changed(data)
    StatSystem.recalculate_for_unit(data.unit, data.world)
end

-- Event handler for when a unit moves to a new tile.
-- This is crucial for conditional passives like Infernal.
local function on_unit_tile_changed(data)
    StatSystem.recalculate_for_unit(data.unit, data.world)
end

-- Register the event listeners. This code runs when the module is required.
EventBus:register("unit_added", on_unit_added)
EventBus:register("status_applied", on_status_changed)
EventBus:register("status_removed", on_status_changed)
-- This event will be dispatched by the UI when a weapon is equipped.
EventBus:register("weapon_equipped", on_weapon_changed)
EventBus:register("unit_tile_changed", on_unit_tile_changed)

return StatSystem