-- modules/input_handlers/free_roam_handler.lua
-- Handles input when the player is freely moving the cursor around the map.

local WorldQueries = require("modules.world_queries")
local Pathfinding = require("modules.pathfinding")
local RangeCalculator = require("modules.range_calculator")
local InputHelpers = require("modules.input_helpers")

local FreeRoamHandler = {}

function FreeRoamHandler.handle_key_press(key, world)
    if key == "j" then
        InputHelpers.play_confirm_sound()
        local unit = WorldQueries.getUnitAt(world.ui.mapCursorTile.x, world.ui.mapCursorTile.y, nil, world)
        if unit then
            local isStunned = unit.statusEffects and unit.statusEffects.stunned
            if unit.type == "player" and not unit.hasActed and not unit.isCarried and not isStunned then
                world.ui.selectedUnit = unit
                InputHelpers.set_player_turn_state("unit_selected", world)
                world.ui.pathing.reachableTiles, world.ui.pathing.came_from, world.ui.pathing.cost_so_far = Pathfinding.calculateReachableTiles(unit, world)
                world.ui.pathing.attackableTiles = RangeCalculator.calculateAttackableTiles(unit, world, world.ui.pathing.reachableTiles)
                world.ui.pathing.movementPath = {}
                world.ui.pathing.cursorPath = {}
                unit.components.selection_flash = { timer = 0, duration = 0.25 }
            elseif unit.type == "enemy" then
                local display = world.ui.menus.enemyRangeDisplay
                display.active = true
                display.unit = unit
                local reachable, _ = Pathfinding.calculateReachableTiles(unit, world)
                display.reachableTiles = reachable
                display.attackableTiles = RangeCalculator.calculateAttackableTiles(unit, world, reachable)
                InputHelpers.set_player_turn_state("enemy_range_display", world)
            end
        else
            world.ui.menus.map.active = true
            world.ui.menus.map.options = {{text = "End Turn", key = "end_turn"}}
            world.ui.menus.map.selectedIndex = 1
            InputHelpers.set_player_turn_state("map_menu", world)
        end
    elseif key == "l" then
        local unit = WorldQueries.getUnitAt(world.ui.mapCursorTile.x, world.ui.mapCursorTile.y, nil, world)
        if unit then
            local menu = world.ui.menus.unitInfo
            menu.isLocked = true
            menu.unit = unit
            menu.selectedIndex = 1
            menu.moveListScrollOffset = 0
            world.ui.previousPlayerTurnState = "free_roam"
            InputHelpers.set_player_turn_state("unit_info_locked", world)
        end
    end
end

function FreeRoamHandler.handle_continuous_input(dt, world)
    -- The main input handler will still manage cursor movement,
    -- so this can remain empty for now unless free_roam gets
    -- specific continuous input needs.
end

return FreeRoamHandler