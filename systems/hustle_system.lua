-- hustle_system.lua
-- Manages the "Hustle" passive, allowing a unit to act twice.

local EventBus = require("modules.event_bus")
local EffectFactory = require("modules.effect_factory")

local HustleSystem = {}

-- This will be called when a unit's action is finalized.
local function on_action_finalized(data)
    local unit = data.unit
    local world = data.world

    if not unit or not world or not unit.type or not unit.hasActed then return end

    -- Check if the turn was ended by a specific move that overrides Hustle.
    -- This flag is set by the attack function itself (e.g., in unit_attacks.lua).
    if unit.components.turn_ended_by_move then
        unit.components.turn_ended_by_move = nil -- Clean up the flag.
        return -- Do not trigger Hustle.
    end

    -- Check if the unit has the "Hustle" passive.
    -- The PassiveSystem populates world.teamPassives with lists of units providing each passive.
    local hustle_providers = world.teamPassives[unit.type] and world.teamPassives[unit.type].Hustle
    if not hustle_providers then return end

    local hasHustle = false
    for _, provider in ipairs(hustle_providers) do
        if provider == unit then
            hasHustle = true
            break
        end
    end

    if not hasHustle then return end

    -- If the unit has Hustle, check if they've already used their second action this turn.
    -- We use a component on the unit to track this state.
    if not unit.components.hustle_used_this_turn then
        -- This was the first action. Refresh the unit for a second move.
        unit.hasActed = false
        unit.components.hustle_used_this_turn = true

        -- Create a visual effect to show the refresh.
        EffectFactory.createDamagePopup(world, unit, "Hustle!", false, {0.5, 1, 0.5, 1}) -- Green text
    end
end

-- We need to reset the 'hustle_used_this_turn' flag at the start of each team's turn.
local function on_turn_started(data)
    local team_list = data.world.turn == "player" and data.world.players or data.world.enemies
    for _, unit in ipairs(team_list) do
        if unit.components.hustle_used_this_turn then
            unit.components.hustle_used_this_turn = nil
        end
    end
end

EventBus:register("action_finalized", on_action_finalized)
EventBus:register("player_turn_started", on_turn_started)
EventBus:register("enemy_turn_started", on_turn_started)

return HustleSystem
