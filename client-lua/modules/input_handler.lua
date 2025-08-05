-- input_handler.lua
-- Contains all logic for processing player keyboard input.
local EventBus = require("modules.event_bus")
local Pathfinding = require("modules.pathfinding")
local Assets = require("modules.assets")
local WorldQueries = require("modules.world_queries")
local Grid = require("modules.grid")
local MainMenu = require("modules.main_menu")
local FreeRoamHandler = require("modules.input_handlers.free_roam_handler")
local UnitSelectedHandler = require("modules.input_handlers.unit_selected_handler")
local ActionMenuHandler = require("modules.input_handlers.action_menu_handler")
local InputHelpers = require("modules.input_helpers")
local EnemyRangeDisplayHandler = require("modules.input_handlers.enemy_range_display_handler")
local MapMenuHandler = require("modules.input_handlers.map_menu_handler")
local UnitInfoLockedHandler = require("modules.input_handlers.unit_info_locked_handler")
local ShopMenuHandler = require("modules.input_handlers.shop_menu_handler")
local PromotionMenuHandler = require("modules.input_handlers.promotion_menu_handler")
local BurrowTeleportHandler = require("modules.input_handlers.burrow_teleport_handler")
local CycleTargetingHandler = require("modules.input_handlers.cycle_targeting_handler")
local GroundAimingHandler = require("modules.input_handlers.ground_aiming_handler")
local TileCyclingHandler = require("modules.input_handlers.tile_cycling_handler")
local DraftScreenHandler = require("modules.input_handlers.draft_screen_handler")
local DropTargetingHandler = require("modules.input_handlers.drop_targeting_handler")
local ShoveTargetingHandler = require("modules.input_handlers.shove_targeting_handler")
local TakeTargetingHandler = require("modules.input_handlers.take_targeting_handler")
local SecondaryTargetingHandler = require("modules.input_handlers.secondary_targeting_handler")
local RescueTargetingHandler = require("modules.input_handlers.rescue_targeting_handler")
local WeaponSelectHandler = require("modules.input_handlers.weapon_select_handler")

local InputHandler = {}

--------------------------------------------------------------------------------

-- Checks if all living player units have taken their action for the turn.
local function allPlayersHaveActed(world)
    for _, player in ipairs(world.players) do
        if player.hp > 0 and not player.hasActed then
            -- A player's turn is not over if they are not stunned.
            if not (player.statusEffects and player.statusEffects.stunned) then
                return false -- Found an available player who hasn't acted yet.
            end
        end
    end
    return true -- All living players have acted.
end

-- Helper to move the cursor and update the movement path if applicable.
local function move_cursor(dx, dy, world, isFastMove)
    local oldTileX = world.ui.mapCursorTile.x
    local oldTileY = world.ui.mapCursorTile.y

    local newTileX = world.ui.mapCursorTile.x + dx
    local newTileY = world.ui.mapCursorTile.y + dy

    -- Clamp cursor to screen bounds
    newTileX = math.max(0, math.min(newTileX, world.map.width - 1))
    newTileY = math.max(0, math.min(newTileY, world.map.height - 1))

    -- Only update and dispatch events if the cursor has actually moved to a new tile.
    if newTileX ~= oldTileX or newTileY ~= oldTileY then
        world.ui.mapCursorTile.x = newTileX
        world.ui.mapCursorTile.y = newTileY

        -- Play sound effect for cursor movement.
        if Assets.sounds.cursor_move then
            Assets.sounds.cursor_move:stop()
            Assets.sounds.cursor_move:play()
        end

        -- Dispatch an event that other systems (like UnitInfoSystem) can listen to.
        EventBus:dispatch("cursor_moved", { tileX = newTileX, tileY = newTileY, world = world })

        world.ui.pathing.cursorPath = world.ui.pathing.cursorPath or {}
        -- If a unit is selected, update the movement path
        if world.ui.playerTurnState == "unit_selected" then
            local goalPosKey = world.ui.mapCursorTile.x .. "," .. world.ui.mapCursorTile.y
            -- Check if the tile is reachable AND landable.
            if world.ui.pathing.reachableTiles and world.ui.pathing.reachableTiles[goalPosKey] and world.ui.pathing.reachableTiles[goalPosKey].landable then
                local startPosKey = world.ui.selectedUnit.tileX .. "," .. world.ui.selectedUnit.tileY
                world.ui.pathing.movementPath = Pathfinding.reconstructPath(world.ui.pathing.came_from, world.ui.pathing.cost_so_far, world.ui.pathing.cursorPath, startPosKey, goalPosKey)

                table.insert(world.ui.pathing.cursorPath, {x = world.ui.mapCursorTile.x, y = world.ui.mapCursorTile.y})
            else
                world.ui.pathing.cursorPath = {}
                world.ui.pathing.movementPath = nil -- Cursor is on an unreachable or non-landable tile
            end
        end
    end
end

-- This is the table for top-level game states.
local stateHandlers = {}

-- A dispatch table for player state input handlers.
local playerStateInputHandlers = {
    free_roam = FreeRoamHandler.handle_key_press,
    unit_selected = UnitSelectedHandler.handle_key_press,
    unit_moving = function() end, -- Input is locked while a unit is moving.
    action_menu = ActionMenuHandler.handle_key_press,
    tile_cycling = TileCyclingHandler.handle_key_press,
    secondary_targeting = SecondaryTargetingHandler.handle_key_press,
    ground_aiming = GroundAimingHandler.handle_key_press,
    cycle_targeting = CycleTargetingHandler.handle_key_press,
    rescue_targeting = RescueTargetingHandler.handle_key_press,
    drop_targeting = DropTargetingHandler.handle_key_press,
    shove_targeting = ShoveTargetingHandler.handle_key_press,
    take_targeting = TakeTargetingHandler.handle_key_press,
    enemy_range_display = EnemyRangeDisplayHandler.handle_key_press,
    unit_info_locked = UnitInfoLockedHandler.handle_key_press,
    weapon_select = WeaponSelectHandler.handle_key_press,
    map_menu = MapMenuHandler.handle_key_press,
    shop_menu = ShopMenuHandler.handle_key_press,
    promotion_select = PromotionMenuHandler.handle_key_press,
    burrow_teleport_selecting = BurrowTeleportHandler.handle_key_press,
    draft_mode = DraftScreenHandler.handle_key_press,
}

-- Handles all input during active gameplay.
stateHandlers.gameplay = function(key, world)
    -- Only accept input on the player's turn, with an exception for promotion selection,
    -- which can happen during the enemy's turn after a player unit levels up.
    if world.turn ~= "player" and world.ui.playerTurnState ~= "promotion_select" then
        return
    end

    local state = world.ui.playerTurnState

    -- Block most input if a world action or a blocking UI is active.
    -- The promotion menu is the only state that should be interactive during these times.
    local isGameBusy = WorldQueries.isActionOngoing(world) or WorldQueries.isUIBlockingInput(world)
    if isGameBusy and state ~= "promotion_select" then
        return
    end

    local state = world.ui.playerTurnState

    -- Handle cursor movement for states that allow it. This is for single key taps.
    if state == "free_roam" or state == "unit_selected" or state == "enemy_range_display" then
        if key == "w" then move_cursor(0, -1, world, false)
        elseif key == "s" then move_cursor(0, 1, world, false)
        elseif key == "a" then move_cursor(-1, 0, world, false)
        elseif key == "d" then move_cursor(1, 0, world, false)
        end
    elseif state == "ground_aiming" then
        if key == "w" then GroundAimingHandler.handle_continuous_input(0, -1, world)
        elseif key == "s" then GroundAimingHandler.handle_continuous_input(0, 1, world)
        elseif key == "a" then GroundAimingHandler.handle_continuous_input(-1, 0, world)
        elseif key == "d" then GroundAimingHandler.handle_continuous_input(1, 0, world)
        end
    end

    -- Delegate to the correct handler based on the player's current action state.
    local handler = playerStateInputHandlers[state]
    if handler then
        handler(key, world)
    end
end

-- NEW: Add handler for main menu
stateHandlers.main_menu = function(key, world) -- world is nil here
    return MainMenu.handle_key_press(key)
end

-- Handles input on the game over screen.
stateHandlers.game_over = function(key, world)
    if key == "escape" then
        love.event.quit()
    end
end

-- Handles input when the game is paused.
stateHandlers.paused = function(key, world)
    -- The global 'escape' handler in handle_key_press will unpause.
    if key == "l" then
        -- Signal to the main game loop that a reset is requested.
        return "reset"
    end
end

--------------------------------------------------------------------------------
-- MAIN HANDLER FUNCTIONS
--------------------------------------------------------------------------------

-- This function handles discrete key presses and delegates to the correct state handler.
function InputHandler.handle_key_press(key, currentGameState, world)
    -- Global keybinds that should work in any state
    if key == "f11" then
        local isFullscreen, fstype = love.window.getFullscreen()
        love.window.setFullscreen(not isFullscreen, fstype)
    end

    -- The Escape key is a global toggle that switches between states.
    if key == "escape" then
        if currentGameState == "paused" then
            return "gameplay" -- Switch back to gameplay
        elseif currentGameState == "gameplay" then
            return "paused" -- Switch to the paused state
        elseif currentGameState == "draft_mode" then
            return "main_menu"
        end
    end

    -- Find the correct handler for the current state and call it.
    local handler = stateHandlers[currentGameState]
    if handler then        
        -- The handler can return a new state string to trigger a change.
        local newState = handler(key, world)
        if newState then
            return newState        
        end
    end

    -- Return the current state, as no state change was triggered by this key.
    return currentGameState
end

-- This function handles continuous key-down checks for cursor movement.
function InputHandler.handle_continuous_input(dt, world)
    -- Add a guard clause for nil world, which will be the case in the main menu.
    if not world then return end

    -- This function should only run during the player's turn in specific states.
    local state = world.ui.playerTurnState
    local movement_allowed = state == "free_roam" or
                             state == "unit_selected" or
                             state == "ground_aiming" or
                             state == "enemy_range_display" or
                             state == "unit_info_locked" or 
                             state == "shop_menu" or
                             state == "action_menu" or state == "map_menu" or
                             state == "weapon_select" or state == "promotion_select"

    if world.turn ~= "player" or not movement_allowed then
        world.ui.cursorInput.activeKey = nil -- Reset when not in a valid state
        return
    end

    -- Block continuous input if a world action or a blocking UI is active.
    local isGameBusy = WorldQueries.isActionOngoing(world) or WorldQueries.isUIBlockingInput(world)
    if isGameBusy and state ~= "promotion_select" then
        world.ui.cursorInput.activeKey = nil
        return
    end

    local cursor = world.ui.cursorInput
    local dx, dy = 0, 0
    local keyString = ""

    -- Check for vertical and horizontal movement independently to allow diagonals.
    if love.keyboard.isDown("w") then dy = -1; keyString = keyString .. "w" end
    if love.keyboard.isDown("s") then dy = 1; keyString = keyString .. "s" end
    if love.keyboard.isDown("a") then dx = -1; keyString = keyString .. "a" end
    if love.keyboard.isDown("d") then dx = 1; keyString = keyString .. "d" end

    -- Prevent opposite keys from cancelling movement (e.g., W+S or A+D).
    if love.keyboard.isDown("w") and love.keyboard.isDown("s") then dy = 0 end
    if love.keyboard.isDown("a") and love.keyboard.isDown("d") then dx = 0 end

    -- Only process if there is a direction to move.
    if dx ~= 0 or dy ~= 0 then
        if keyString ~= cursor.activeKey then
            -- A new key is pressed. Don't move immediately (that's handled by handle_key_press).
            -- Just set the state and the timer for the *first repeat*.
            cursor.activeKey = keyString
            cursor.timer = cursor.initialDelay
        else
            -- The same key is being held. Wait for the timer.
            cursor.timer = cursor.timer - dt
            if cursor.timer <= 0 then
                if state == "unit_info_locked" then
                    local keyToMove = nil
                    if dy < 0 then keyToMove = "w"
                    elseif dy > 0 then keyToMove = "s"
                    elseif dx < 0 then keyToMove = "a"
                    elseif dx > 0 then keyToMove = "d"
                    end
                    if keyToMove then
                        UnitInfoLockedHandler.handle_continuous_input(keyToMove, world)
                    end
                elseif state == "shop_menu" then
                    -- For the shop menu, only vertical navigation is continuous.
                    local keyToMove = nil
                    if dy < 0 then keyToMove = "w"
                    elseif dy > 0 then keyToMove = "s"
                    end
                    if keyToMove then
                        InputHelpers.navigate_vertical_menu(keyToMove, world.ui.menus.shop, nil, world)
                    end
                elseif state == "ground_aiming" then
                    GroundAimingHandler.handle_continuous_input(dx, dy, world)
                elseif state == "action_menu" or state == "map_menu" or state == "weapon_select" or state == "promotion_select" then
                    -- New logic for standard vertical menus
                    local keyToMove = nil
                    if dy < 0 then keyToMove = "w"
                    elseif dy > 0 then keyToMove = "s"
                    end

                    if keyToMove then
                        -- Get the correct menu object based on state
                        local menu, eventName = nil, nil
                        if state == "action_menu" then
                            menu = world.ui.menus.action
                            eventName = "action_menu_selection_changed"
                        elseif state == "map_menu" then menu = world.ui.menus.map
                        elseif state == "weapon_select" then menu = world.ui.menus.weaponSelect
                        elseif state == "promotion_select" then menu = world.ui.menus.promotion
                        end

                        if menu then InputHelpers.navigate_vertical_menu(keyToMove, menu, eventName, world) end
                    end
                -- Only move the map cursor in specific states.
                elseif state == "free_roam" or state == "unit_selected" or state == "enemy_range_display" then
                    move_cursor(dx, dy, world, true)
                end
                cursor.timer = cursor.timer + cursor.repeatDelay -- Add to prevent timer drift
            end
        end
    else
        -- No key is pressed. Reset the state.
        cursor.activeKey = nil
    end
end

-- After an action is fully resolved (including animations), check if the turn should end.
EventBus:register("action_finalized", function(data)
    local world = data.world
    if allPlayersHaveActed(world) then
        world.ui.turnShouldEnd = true
    end
end)

return InputHandler