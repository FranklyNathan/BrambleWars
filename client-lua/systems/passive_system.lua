-- passive_system.lua
-- Manages team-wide passive abilities.

local EventBus = require("modules.event_bus")
local CharacterBlueprints = require("data.character_blueprints")
local EnemyBlueprints = require("data.enemy_blueprints")
local WorldQueries = require("modules.world_queries") -- Added for centralized logic

local PassiveSystem = {}

-- Helper to add a unit to the passive lists. Made public for Necromantia.
function PassiveSystem.add_unit_to_passives(unit, world)
    if not unit.hp or unit.hp <= 0 or not unit.type or not world.teamPassives[unit.type] then return end
    
    -- Get the definitive list of passives for this unit from the centralized query.
    local all_passives = WorldQueries.getUnitPassiveList(unit)

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

-- Helper to remove a unit from all passive lists. Made public for Necromantia.
function PassiveSystem.remove_unit_from_passives(unit, world)
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
    PassiveSystem.remove_unit_from_passives(data.unit, data.world)
    -- Then, re-add it with the new set of passives (from blueprint + new weapon).
    PassiveSystem.add_unit_to_passives(data.unit, data.world)
end

-- Listen for new units being added to the world (at startup or via party swap).
EventBus:register("unit_added", function(data) PassiveSystem.add_unit_to_passives(data.unit, data.world) end)

-- Listen for units dying to remove them from the provider lists.
EventBus:register("unit_died", function(data) PassiveSystem.remove_unit_from_passives(data.victim, data.world) end)

-- Listen for units changing their weapon.
EventBus:register("weapon_equipped", on_weapon_changed)

return PassiveSystem