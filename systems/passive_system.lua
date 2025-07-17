-- passive_system.lua
-- Manages team-wide passive abilities.

local EffectFactory = require("modules.effect_factory")
local CharacterBlueprints = require("data.character_blueprints")
local EnemyBlueprints = require("data.enemy_blueprints")
local CombatActions = require("modules.combat_actions")

local PassiveSystem = {}

-- This system updates the state of team-wide passives and applies their continuous effects.
function PassiveSystem.update(dt, world)
    -- 1. Reset all passive provider lists for both teams.
    for team, passives in pairs(world.teamPassives) do
        for passiveName, providers in pairs(passives) do
            -- Clear the list by setting it to a new empty table.
            world.teamPassives[team][passiveName] = {}
        end
    end

    -- 2. Populate lists for the player team with living units.
    for _, p in ipairs(world.players) do
        if p.hp > 0 then
            local blueprint = CharacterBlueprints[p.playerType]
            if blueprint and blueprint.passives then
                for _, passiveName in ipairs(blueprint.passives) do
                    -- Add the unit to the list of providers for this passive.
                    table.insert(world.teamPassives.player[passiveName], p)
                end
            end
        end
    end

    -- 3. Populate lists for the enemy team with living units.
    for _, e in ipairs(world.enemies) do
        if e.hp > 0 then
            local blueprint = EnemyBlueprints[e.enemyType]
            if blueprint and blueprint.passives then
                for _, passiveName in ipairs(blueprint.passives) do
                    -- Add the unit to the list of providers for this passive.
                    table.insert(world.teamPassives.enemy[passiveName], e)
                end
            end
        end
    end
end

return PassiveSystem