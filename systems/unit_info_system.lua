-- systems/unit_info_system.lua
-- Manages the display of the unit info menu based on game events.

local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")
local Pathfinding = require("modules.pathfinding")
local RangeCalculator = require("modules.range_calculator")

local UnitInfoSystem = {}

-- This is the core logic. It's called by event handlers to update the UI.
function UnitInfoSystem.refresh_display(world)
    -- If a major action is happening (animations, etc.), or a menu is open that should
    -- hide the info box, then we ensure it's hidden.
    local shouldHide = WorldQueries.isActionOngoing(world) or
                       world.actionMenu.active or
                       world.mapMenu.active

    if shouldHide then
        world.unitInfoMenu.active = false
        world.hoverReachableTiles = nil
        world.hoverAttackableTiles = nil
        return
    end

    -- Get the unit under the current cursor position.
    local unit = WorldQueries.getUnitAt(world.mapCursorTile.x, world.mapCursorTile.y, nil, world)

    if unit then
        -- A unit is being hovered over.
        world.unitInfoMenu.active = true
        world.unitInfoMenu.unit = unit

        -- Only calculate and show hover previews (movement/attack range) when the player
        -- is in the 'free_roam' state. This prevents visual clutter during other actions.
        if world.playerTurnState == "free_roam" and not unit.hasActed then
            local reachable, _, _ = Pathfinding.calculateReachableTiles(unit, world)
            world.hoverReachableTiles = reachable
            world.hoverAttackableTiles = RangeCalculator.calculateAttackableTiles(unit, world, reachable)
        else
            -- In any other state (like 'unit_selected'), clear the hover previews.
            world.hoverReachableTiles = nil
            world.hoverAttackableTiles = nil
        end
    else
        -- No unit is being hovered over.
        world.unitInfoMenu.active = false
        world.unitInfoMenu.unit = nil
        world.hoverReachableTiles = nil
        world.hoverAttackableTiles = nil
    end
end

-- Event handler for when the cursor moves to a new tile.
local function on_cursor_moved(data)
    UnitInfoSystem.refresh_display(data.world)
end

-- Event handler for when the player's turn state changes.
-- This helps hide/show the menu correctly when selecting/deselecting units or opening menus.
local function on_player_state_changed(data)
    UnitInfoSystem.refresh_display(data.world)
end

-- We also need to refresh when an action completes, as this might change what should be displayed.
local function on_action_finalized(data)
    UnitInfoSystem.refresh_display(data.world)
end

-- Register the event listeners. This code runs when the module is required.
EventBus:register("cursor_moved", on_cursor_moved)
EventBus:register("player_state_changed", on_player_state_changed)
EventBus:register("action_finalized", on_action_finalized)

return UnitInfoSystem