-- modules/input_handlers/unit_selected_handler.lua
-- Handles input when a player unit is selected and awaiting a move command.

local Config = require("config")
local InputHelpers = require("modules.input_helpers")
local WorldQueries = require("modules.world_queries")

local UnitSelectedHandler = {}

function UnitSelectedHandler.handle_key_press(key, world)
    if key == "j" then -- Confirm Move
        InputHelpers.play_confirm_sound()
        local cursorOnUnit = world.ui.mapCursorTile.x == world.ui.selectedUnit.tileX and
                             world.ui.mapCursorTile.y == world.ui.selectedUnit.tileY

        -- Allow move confirmation if a valid path exists, OR if the cursor is on the unit's start tile (to attack without moving).
        if (world.ui.pathing.movementPath and #world.ui.pathing.movementPath > 0) or cursorOnUnit then
            -- Save the unit's state before they move, so the action can be undone.
            local unit = world.ui.selectedUnit
            unit.components.pre_move_state = {
                tileX = unit.tileX,
                tileY = unit.tileY,
                direction = unit.lastDirection,
                hp = unit.hp,
                frozenTiles = {}, -- For the Frozenfoot passive to record its changes.
                spawned_tadpoles = {} -- For the new Spawnstride passive.
            }

            -- If cursor is on the unit, the path is nil/empty. Assign an empty table `{}` to trigger the movement system's completion logic immediately.
            world.ui.selectedUnit.components.movement_path = world.ui.pathing.movementPath or {}

            -- Create the destination effect: a descending cursor and a glowing tile.
            world.ui.pathing.moveDestinationEffect = {
                tileX = world.ui.mapCursorTile.x,
                tileY = world.ui.mapCursorTile.y,
                state = "descending", -- 'descending', 'glowing'
                timer = 0.4, -- duration of the new morphing animation
                initialTimer = 0.4
            }

            -- Create the range fade-out effect.
            world.ui.pathing.rangeFadeEffect = {
                active = true,
                reachableTiles = world.ui.pathing.reachableTiles,
                attackableTiles = world.ui.pathing.attackableTiles
            }
            -- Calculate the duration of the unit's movement to sync the fade animation.
            local path_length = world.ui.pathing.movementPath and #world.ui.pathing.movementPath or 0
            local time_per_tile = Config.SQUARE_SIZE / Config.SLIDE_SPEED -- Time to cross one tile
            local total_move_duration = path_length * time_per_tile
            local fade_duration = math.max(0, total_move_duration) -- Set a minimum fade time of 0s
            world.ui.pathing.rangeFadeEffect.timer = fade_duration
            world.ui.pathing.rangeFadeEffect.initialTimer = fade_duration

            InputHelpers.set_player_turn_state("unit_moving", world)
            world.ui.selectedUnit = nil
            -- Clear the original tile sets so they are not drawn by the regular logic.
            world.ui.pathing.reachableTiles = nil
            world.ui.pathing.attackableTiles = nil
            world.ui.pathing.movementPath = nil
        end
        return -- Exit to prevent cursor update on confirm
    elseif key == "k" then -- Cancel
        InputHelpers.play_back_out_sound()

        -- Snap the cursor back to the unit's position before deselecting.
        world.ui.mapCursorTile.x = world.ui.selectedUnit.tileX
        world.ui.mapCursorTile.y = world.ui.selectedUnit.tileY

        InputHelpers.set_player_turn_state("free_roam", world)
        world.ui.selectedUnit = nil
        world.ui.pathing.reachableTiles = nil
        world.ui.pathing.attackableTiles = nil
        world.ui.pathing.movementPath = nil
        world.ui.pathing.cursorPath = nil
        return -- Exit to prevent cursor update on cancel
    elseif key == "l" then
        -- Allow inspecting another unit while one is selected.
        local unit = WorldQueries.getUnitAt(world.ui.mapCursorTile.x, world.ui.mapCursorTile.y, nil, world)
        if unit then
            local menu = world.ui.menus.unitInfo
            menu.isLocked = true
            menu.unit = unit
            menu.selectedIndex = 1
            menu.moveListScrollOffset = 0
            world.ui.previousPlayerTurnState = "unit_selected"
            InputHelpers.set_player_turn_state("unit_info_locked", world)
        end
    end
end

return UnitSelectedHandler