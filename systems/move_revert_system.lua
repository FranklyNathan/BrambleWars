-- systems/move_revert_system.lua
-- Manages the "undo move" functionality for player units.

local EventBus = require("modules.event_bus")
local Grid = require("modules.grid")

local MoveRevertSystem = {}

-- Tracks the last unit that was selected to handle deselection logic correctly.
local last_selected_unit = nil

-- Helper to clear the pre-move state from a unit.
local function clear_pre_move_state(unit)
    if unit and unit.components and unit.components.pre_move_state then
        unit.components.pre_move_state = nil
    end
end

-- Core logic to handle state changes related to unit selection and deselection.
local function on_player_state_changed(data)
    local world = data.world
    local newState = data.newState
    local current_selected_unit = world.ui.selectedUnit

    -- Case 1: A unit is newly selected. Store its initial state for a potential revert.
    -- This happens when moving from free_roam to unit_selected.
    if newState == "unit_selected" and current_selected_unit then
        -- Only store state if it hasn't been stored already (e.g., re-selecting after moving).
        if not current_selected_unit.components.pre_move_state then
            current_selected_unit.components.pre_move_state = {
                hp = current_selected_unit.hp,
                tileX = current_selected_unit.tileX,
                tileY = current_selected_unit.tileY,
                direction = current_selected_unit.lastDirection,
                frozenTiles = {} -- For Frozenfoot passive
            }
        end
    end

    -- Case 2: A unit is deselected (by pressing 'B'). Revert its move.
    -- This happens when moving from a selection state back to free_roam.
    -- It should only trigger on a cancel, not on a committed action like "Wait".
    if newState == "free_roam" and last_selected_unit then
        -- Check if the unit is still alive, has a stored state, and has NOT committed an action.
        if last_selected_unit.hp > 0 and last_selected_unit.components.pre_move_state and not last_selected_unit.components.action_in_progress then
            local state = last_selected_unit.components.pre_move_state

            -- Revert HP and position.
            last_selected_unit.hp = state.hp
            last_selected_unit.tileX = state.tileX
            last_selected_unit.tileY = state.tileY

            -- Restore the unit's direction to what it was at the start of the move.
            if state.direction then
                last_selected_unit.lastDirection = state.direction
            end

            -- Instantly snap pixel position to match the reverted tile position.
            last_selected_unit.x, last_selected_unit.y = Grid.toPixels(state.tileX, state.tileY)
            last_selected_unit.targetX, last_selected_unit.targetY = last_selected_unit.x, last_selected_unit.y

            -- New: Revert any tiles that were frozen by the Frozenfoot passive during this move.
            if state.frozenTiles and #state.frozenTiles > 0 then
                for _, posKey in ipairs(state.frozenTiles) do
                    -- Setting the status to nil reverts it to its base state (water).
                    world.tileStatuses[posKey] = nil
                end
            end

            -- The move has been reverted, so clear the stored state.
            clear_pre_move_state(last_selected_unit)
        end
    end

    -- After processing, update the tracker for the next state change.
    last_selected_unit = current_selected_unit
end

-- When a shop transaction is completed, the move is committed and cannot be undone.
EventBus:register("shop_transaction_complete", function(data)
    -- The data must contain the player unit that was shopping.
    clear_pre_move_state(data.unit)
end)

EventBus:register("action_finalized", function(data) clear_pre_move_state(data.unit) end)
EventBus:register("unit_died", function(data) clear_pre_move_state(data.victim) end)
EventBus:register("player_state_changed", on_player_state_changed)

return MoveRevertSystem