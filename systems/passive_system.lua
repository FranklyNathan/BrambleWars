-- passive_system.lua
-- Manages team-wide passive abilities.

local EventBus = require("modules.event_bus")
local CharacterBlueprints = require("data.character_blueprints")
local EnemyBlueprints = require("data.enemy_blueprints")

local PassiveSystem = {}

-- Helper to add a unit to the passive lists.
local function add_unit_to_passives(unit, world)
    if not unit.hp or unit.hp <= 0 or not unit.type or not world.teamPassives[unit.type] then return end

    local blueprint = (unit.type == "player") and CharacterBlueprints[unit.playerType] or EnemyBlueprints[unit.enemyType]
    if blueprint and blueprint.passives then
        for _, passiveName in ipairs(blueprint.passives) do
            -- Ensure the passive list exists before trying to insert.
            if world.teamPassives[unit.type][passiveName] then
                table.insert(world.teamPassives[unit.type][passiveName], unit)
            end
        end
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

-- Listen for new units being added to the world (at startup or via party swap).
EventBus:register("unit_added", function(data) add_unit_to_passives(data.unit, data.world) end)

-- Listen for units dying to remove them from the provider lists.
EventBus:register("unit_died", function(data) remove_unit_from_passives(data.victim, data.world) end)

return PassiveSystem