-- passive_system.lua
-- Manages team-wide passive abilities.

local EventBus = require("modules.event_bus")
local CharacterBlueprints = require("data.character_blueprints")
local EnemyBlueprints = require("data.enemy_blueprints")
local WeaponBlueprints = require("data.weapon_blueprints")

local PassiveSystem = {}

-- Helper to add a unit to the passive lists.
local function add_unit_to_passives(unit, world)
    if not unit.hp or unit.hp <= 0 or not unit.type or not world.teamPassives[unit.type] then return end

    local all_passives = {}
    local passive_exists = {} -- Use a set to track existing passives and prevent duplicates

    -- 1. Get passives from the character/enemy blueprint.
    local blueprint = (unit.type == "player") and CharacterBlueprints[unit.playerType] or EnemyBlueprints[unit.enemyType]
    if blueprint and blueprint.passives then
        for _, passiveName in ipairs(blueprint.passives) do
            if not passive_exists[passiveName] then
                table.insert(all_passives, passiveName)
                passive_exists[passiveName] = true
            end
        end
    end

    -- 2. Get passives from the equipped weapon.
    if unit.equippedWeapon and WeaponBlueprints[unit.equippedWeapon] then
        local weapon = WeaponBlueprints[unit.equippedWeapon]
        if weapon.grants_passives then
            for _, passiveName in ipairs(weapon.grants_passives) do
                if not passive_exists[passiveName] then
                    table.insert(all_passives, passiveName)
                    passive_exists[passiveName] = true
                end
            end
        end
    end

    -- 3. Add the unit to the provider list for each of its unique passives.
    for _, passiveName in ipairs(all_passives) do
        -- If this passive type doesn't exist in the team's list yet, create it.
        if not world.teamPassives[unit.type][passiveName] then
            world.teamPassives[unit.type][passiveName] = {}
        end
        -- Now it's safe to add the unit to the provider list.
        table.insert(world.teamPassives[unit.type][passiveName], unit)
    end
end

-- Helper to remove a unit from all passive lists.
local function remove_unit_from_passives(unit, world)
    if not unit.type or not world.teamPassives[unit.type] then return end

    for passiveName, providers in pairs(world.teamPassives[unit.type]) do
        for i = #providers, 1, -1 do
            if providers[i] == unit then
                table.remove(providers, i)
            end
        end
    end
end

-- New event handler for weapon changes.
local function on_weapon_changed(data)
    -- When a weapon changes, we need to completely rebuild this unit's contribution to team passives.
    -- First, remove it from all lists it might currently be in.
    remove_unit_from_passives(data.unit, data.world)
    -- Then, re-add it with the new set of passives (from blueprint + new weapon).
    add_unit_to_passives(data.unit, data.world)
end

-- Listen for new units being added to the world (at startup or via party swap).
EventBus:register("unit_added", function(data) add_unit_to_passives(data.unit, data.world) end)

-- Listen for units dying to remove them from the provider lists.
EventBus:register("unit_died", function(data) remove_unit_from_passives(data.victim, data.world) end)

-- Listen for units changing their weapon.
EventBus:register("weapon_equipped", on_weapon_changed)

return PassiveSystem