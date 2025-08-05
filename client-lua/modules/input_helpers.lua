-- modules/input_handlers/input_helpers.lua
-- Contains shared helper functions for the various input state handlers.

local Assets = require("modules.assets")
local EventBus = require("modules.event_bus")
local Grid = require("modules.grid")

local InputHelpers = {}

-- Helper to play the confirmation sound
function InputHelpers.play_confirm_sound()
    if Assets.sounds.confirm then
        Assets.sounds.confirm:stop()
        Assets.sounds.confirm:play()
    end
end

-- Helper to play the menu selection sound
function InputHelpers.play_menu_select_sound()
    if Assets.sounds.menu_select then
        Assets.sounds.menu_select:stop()
        Assets.sounds.menu_select:play()
    end
end

-- Helper to play the main menu selection sound
function InputHelpers.play_main_menu_select_sound()
    if Assets.sounds.main_menu_select then
        Assets.sounds.main_menu_select:stop()
        Assets.sounds.main_menu_select:play()
    end
end

-- Helper to play the back out sound effect
function InputHelpers.play_back_out_sound()
    if Assets.sounds.back_out then
        Assets.sounds.back_out:stop()
        Assets.sounds.back_out:play()
    end
end

-- Sets the player's turn state and dispatches an event to notify other systems.
function InputHelpers.set_player_turn_state(newState, world)
    local oldState = world.ui.playerTurnState
    if oldState ~= newState then
        world.ui.playerTurnState = newState
        EventBus:dispatch("player_state_changed", { oldState = oldState, newState = newState, world = world })

        -- When the player state changes, hide the non-modal unit info menu
        -- if it's not locked and the new state is one where it shouldn't be visible.
        local unitInfoMenu = world.ui.menus.unitInfo
        if unitInfoMenu and not unitInfoMenu.isLocked then
            local isInfoVisibleState = (newState == "free_roam" or newState == "unit_selected" or newState == "enemy_range_display")
            if not isInfoVisibleState then
                unitInfoMenu.active = false
                unitInfoMenu.unit = nil -- Also clear the unit to prevent stale data
            end
        end
    end
end

-- Helper function for standard vertical menu navigation.
-- Handles index wrapping, sound effects, and optional event dispatching.
function InputHelpers.navigate_vertical_menu(key, menu, eventName, world)
    if not menu or not menu.options or #menu.options == 0 then return end

    local oldIndex = menu.selectedIndex
    if key == "w" then
        menu.selectedIndex = (menu.selectedIndex - 2 + #menu.options) % #menu.options + 1
    elseif key == "s" then
        menu.selectedIndex = menu.selectedIndex % #menu.options + 1
    end

    if oldIndex ~= menu.selectedIndex then
        if Assets.sounds.menu_scroll then
            Assets.sounds.menu_scroll:stop()
            Assets.sounds.menu_scroll:play()
        end
        -- Dispatch an event if one is provided.
        if eventName and world then
            EventBus:dispatch(eventName, { world = world })
        end
    end
end

-- Centralized function to clean up UI and state after a player action is confirmed.
function InputHelpers.finalize_player_action(unit, world)
    -- 1. Flag that the unit has completed its action for this turn.
    -- The ActionFinalizationSystem will set hasActed = true when all animations are done.
    unit.components.action_in_progress = true

    -- 1a. Reset the move commitment flag.
    unit.components.move_is_committed = false

    -- 2. Reset all targeting states to clean up the UI.
    world.ui.targeting.cycle.active = false
    world.ui.targeting.cycle.targets = {}
    world.ui.targeting.secondary.active = false
    world.ui.targeting.secondary.tiles = {}
    world.ui.targeting.secondary.primaryTarget = nil
    world.ui.targeting.tile_cycle.active = false
    world.ui.targeting.tile_cycle.tiles = {}
    world.ui.targeting.tile_cycle.selectedIndex = 1
    world.ui.targeting.rescue.active = false
    world.ui.targeting.rescue.targets = {}
    world.ui.targeting.drop.active = false
    world.ui.targeting.drop.tiles = {}
    world.ui.targeting.shove.active = false
    world.ui.targeting.shove.targets = {}
    world.ui.targeting.take.active = false
    world.ui.targeting.take.targets = {}
    world.ui.targeting.selectedAttackName = nil
    world.ui.targeting.attackAoETiles = nil
    world.ui.pathing.groundAimingGrid = nil

    -- 3. Reset other UI state.
    world.ui.selectedUnit = nil
    world.ui.menus.action.active = false
    world.ui.menus.battleInfo.active = false

    -- 4. Return to the free roam state.
    InputHelpers.set_player_turn_state("free_roam", world)

    -- 5. Leave the cursor on the unit that just acted.
    world.ui.mapCursorTile.x = unit.tileX
    world.ui.mapCursorTile.y = unit.tileY
end

-- Centralized function to revert a player's move before an action is committed.
-- This handles reverting the unit's data and any environmental changes from passives.
-- It does NOT handle UI state changes, which are the responsibility of the calling handler.
function InputHelpers.revert_player_move(unit, world)
    if not unit or not unit.components.pre_move_state then
        return false -- Nothing to revert
    end

    local state = unit.components.pre_move_state

    -- Revert any tiles that were frozen by the Frozenfoot passive during this move.
    if state.frozenTiles and #state.frozenTiles > 0 then
        for _, posKey in ipairs(state.frozenTiles) do
            -- Setting the status to nil reverts it to its base state (water).
            world.tileStatuses[posKey] = nil
        end
    end

    -- Remove any tadpoles spawned by the Spawnstride passive during this move.
    if state.spawned_tadpoles and #state.spawned_tadpoles > 0 then
        for _, tadpole in ipairs(state.spawned_tadpoles) do
            tadpole.isMarkedForDeletion = true
        end
    end

    -- Revert HP, position, and direction.
    unit.hp = state.hp
    unit.tileX, unit.tileY = state.tileX, state.tileY
    unit.lastDirection = state.direction

    -- Instantly snap pixel position to match the reverted tile position.
    unit.x, unit.y = Grid.toPixels(unit.tileX, unit.tileY)
    unit.targetX, unit.targetY = unit.x, unit.y
    EventBus:dispatch("unit_tile_changed", { unit = unit, world = world, isUndo = true })

    -- The move has been reverted. Clear the stored state to prevent double-reverts.
    unit.components.pre_move_state = nil

    return true -- Revert was successful
end

return InputHelpers