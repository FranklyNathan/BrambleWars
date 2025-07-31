-- input_handler.lua
-- Contains all logic for processing player keyboard input.

local EventBus = require("modules.event_bus")
local RangeCalculator = require("modules.range_calculator")
local Pathfinding = require("modules.pathfinding")
local AttackHandler = require("modules.attack_handler")
local Assets = require("modules.assets")
local AttackPatterns = require("modules.attack_patterns")
local WorldQueries = require("modules.world_queries")
local Grid = require("modules.grid")
local ShoveHandler = require("modules/shove_handler")
local RescueHandler = require("modules.rescue_handler")
local EffectFactory = require("modules.effect_factory")
local TakeHandler = require("modules/take_handler")
local WeaponBlueprints = require("weapon_blueprints")
local ClassBlueprints = require("data/class_blueprints")
local PromotionSystem = require("systems.promotion_system")

local InputHandler = {}

--------------------------------------------------------------------------------
-- TURN-BASED HELPER FUNCTIONS
--------------------------------------------------------------------------------

-- Sets the player's turn state and dispatches an event to notify other systems.
-- This is the single source of truth for changing the player's state.
local function set_player_turn_state(newState, world)
    local oldState = world.ui.playerTurnState
    if oldState ~= newState then
        world.ui.playerTurnState = newState
        EventBus:dispatch("player_state_changed", { oldState = oldState, newState = newState, world = world })
    end
end

-- Helper function for standard vertical menu navigation.
-- Handles index wrapping, sound effects, and optional event dispatching.
local function navigate_vertical_menu(key, menu, eventName, world)
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

-- Centralized function to clean up UI and state after a player action is confirmed.
local function finalize_player_action(unit, world)
    -- 1. Flag that the unit has completed its action for this turn.
    -- The ActionFinalizationSystem will set hasActed = true when all animations are done.
    unit.components.action_in_progress = true

    -- 2. Reset all targeting states to clean up the UI.
    world.ui.targeting.cycle.active = false
    world.ui.targeting.cycle.targets = {}
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
    set_player_turn_state("free_roam", world)

    -- 5. Leave the cursor on the unit that just acted.
    world.ui.mapCursorTile.x = unit.tileX
    world.ui.mapCursorTile.y = unit.tileY
end

-- Handles input when the player is freely moving the cursor around the map.
local function handle_free_roam_input(key, world)
    if key == "j" then
        local unit = WorldQueries.getUnitAt(world.ui.mapCursorTile.x, world.ui.mapCursorTile.y, nil, world)
        if unit then
            -- A unit is on the tile
            local isStunned = unit.statusEffects and unit.statusEffects.stunned
            if unit.type == "player" and not unit.hasActed and not unit.isCarried and not isStunned then
            -- If the cursor is on an available player unit, select it.
                world.ui.selectedUnit = unit
                set_player_turn_state("unit_selected", world)
                -- Calculate movement range and pathing data
                world.ui.pathing.reachableTiles, world.ui.pathing.came_from, world.ui.pathing.cost_so_far = Pathfinding.calculateReachableTiles(unit, world)
                world.ui.pathing.attackableTiles = RangeCalculator.calculateAttackableTiles(unit, world, world.ui.pathing.reachableTiles)
                world.ui.pathing.movementPath = {} -- Start with an empty path
                world.ui.pathing.cursorPath = {} -- Start with an empty cursor path

                -- Store the unit's position at the start of this specific move action.
                -- This is crucial for the "undo" logic to work correctly for multi-move turns.
                unit.startOfMoveTileX, unit.startOfMoveTileY = unit.tileX, unit.tileY
                unit.startOfMoveDirection = unit.lastDirection

                -- Add a selection flash effect to the unit.
                unit.components.selection_flash = { timer = 0, duration = 0.25 }
            elseif unit.type == "enemy" then
                -- Pressing 'J' on an enemy now shows their range.
                -- Set up the data *before* changing the state, so event listeners have the correct info.
                local display = world.ui.menus.enemyRangeDisplay
                display.active = true
                display.unit = unit
                local reachable, _ = Pathfinding.calculateReachableTiles(unit, world)
                display.reachableTiles = reachable
                display.attackableTiles = RangeCalculator.calculateAttackableTiles(unit, world, reachable)
                set_player_turn_state("enemy_range_display", world)
            end
        else
            -- No unit on the tile, it's empty. Open map menu.
            world.ui.menus.map.active = true
            world.ui.menus.map.options = {{text = "End Turn", key = "end_turn"}}
            world.ui.menus.map.selectedIndex = 1
            set_player_turn_state("map_menu", world)
        end
    elseif key == "l" then -- Lock Unit Info Menu
        local unit = WorldQueries.getUnitAt(world.ui.mapCursorTile.x, world.ui.mapCursorTile.y, nil, world)
        if unit then
            local menu = world.ui.menus.unitInfo
            menu.isLocked = true -- The unit_info_system will now keep this menu active.
            menu.unit = unit -- Lock the current unit
            menu.selectedIndex = 1 -- Reset index
            world.ui.previousPlayerTurnState = "free_roam"
            set_player_turn_state("unit_info_locked", world)
        end
    end
end

-- Handles input when the weapon selection menu is open.
local function handle_weapon_select_input(key, world)
    local menu = world.ui.menus.weaponSelect
    if not menu.active then return end

    if key == "w" or key == "s" then
        navigate_vertical_menu(key, menu, nil, world)
    elseif key == "k" then -- Cancel
        if Assets.sounds.back_out then Assets.sounds.back_out:stop(); Assets.sounds.back_out:play() end
        menu.active = false
        set_player_turn_state("unit_info_locked", world)
    elseif key == "j" then -- Confirm selection
        local selectedOption = menu.options[menu.selectedIndex]

        if selectedOption == "unequip" then
            local unit = menu.unit
            if unit.equippedWeapon then
                table.insert(world.playerInventory.weapons, unit.equippedWeapon)
                unit.equippedWeapon = nil
                EventBus:dispatch("weapon_equipped", { unit = unit, world = world })
            end
            menu.active = false
            set_player_turn_state("unit_info_locked", world)
            if Assets.sounds.menu_scroll then Assets.sounds.menu_scroll:stop(); Assets.sounds.menu_scroll:play() end
        elseif not menu.equippedByOther[selectedOption] then
            local unit = menu.unit
            local oldWeaponKey = unit.equippedWeapon

            -- 1. Add the old weapon back to the inventory if one was equipped.
            if oldWeaponKey then
                table.insert(world.playerInventory.weapons, oldWeaponKey)
            end

            -- 2. Remove the new weapon from the inventory.
            for i, weaponKey in ipairs(world.playerInventory.weapons) do
                if weaponKey == selectedOption then
                    table.remove(world.playerInventory.weapons, i)
                    break
                end
            end

            -- 3. Equip the new weapon and dispatch the event.
            unit.equippedWeapon = selectedOption
            EventBus:dispatch("weapon_equipped", { unit = unit, world = world })
            -- Close the menu
            menu.active = false
            set_player_turn_state("unit_info_locked", world)
            if Assets.sounds.menu_scroll then Assets.sounds.menu_scroll:stop(); Assets.sounds.menu_scroll:play() end
        else
            -- TODO: Play an error/invalid sound if you have one.
        end
    end
end

-- New helper function for unit info menu navigation, callable from both single-press and continuous handlers.
local function move_unit_info_selection(key, world)
    local menu = world.ui.menus.unitInfo
    -- Add guard clauses to ensure we don't error if called in the wrong state
    if not menu.isLocked or not menu.unit then
        return
    end

    local oldIndex = menu.selectedIndex
    local newIndex = oldIndex

    -- Define menu sections and total number of slices
    local NAME_INDEX = 1
    local CLASS_INDEX = 2
    local WEAPON_INDEX = 3
    local HP_INDEX = 4
    local WISP_INDEX = 5
    local STATS_START = 6
    local STATS_END = 11 -- 3 rows of 2 stats each
    local MOVES_START = 12
    local numAttacks = #menu.unit.attacks
    local MOVES_END = MOVES_START + numAttacks - 1
    
    local hasCarriedUnit = menu.unit.carriedUnit and true or false
    local CARRIED_UNIT_INDEX = hasCarriedUnit and (MOVES_END + 1) or nil
    
    local totalSlices = MOVES_END
    if hasCarriedUnit then totalSlices = CARRIED_UNIT_INDEX end

    -- Vertical Navigation (W/S)
    if key == "w" then -- Up
        if oldIndex > MOVES_START then newIndex = oldIndex - 1 -- In moves or carried unit
        elseif oldIndex == MOVES_START then newIndex = STATS_END -- From first move to Wit/Wgt
        elseif oldIndex > STATS_START + 1 then newIndex = oldIndex - 2 -- In stats grid (not top row)
        elseif oldIndex > STATS_START - 1 then newIndex = WISP_INDEX -- From top row of stats to Wisp
        elseif oldIndex > NAME_INDEX then newIndex = oldIndex - 1 -- In top section
        else newIndex = totalSlices end -- Wrap from top to bottom
    elseif key == "s" then -- Down
        if oldIndex < WISP_INDEX then newIndex = oldIndex + 1 -- In top section
        elseif oldIndex == WISP_INDEX then newIndex = STATS_START -- From Wisp to Atk
        elseif oldIndex < STATS_END - 1 then newIndex = oldIndex + 2 -- In stats grid (not last row)
        elseif oldIndex <= STATS_END then newIndex = MOVES_START -- From last row of stats to first move
        elseif oldIndex < totalSlices then newIndex = oldIndex + 1 -- In moves/carried
        else newIndex = 1 end -- Wrap from bottom to top
    elseif key == "a" then -- Horizontal Navigation (A/D)
        if oldIndex >= STATS_START and oldIndex <= STATS_END and oldIndex % 2 == 1 then newIndex = oldIndex - 1 end
    elseif key == "d" then
        if oldIndex >= STATS_START and oldIndex <= STATS_END and oldIndex % 2 == 0 then newIndex = oldIndex + 1 end
    end

    if newIndex ~= oldIndex then
        menu.selectedIndex = newIndex
        if Assets.sounds.menu_scroll then Assets.sounds.menu_scroll:stop(); Assets.sounds.menu_scroll:play() end
        EventBus:dispatch("unit_info_menu_selection_changed", { world = world })
    end
end

-- Handles input when the unit info menu is locked.
local function handle_unit_info_locked_input(key, world)
    local menu = world.ui.menus.unitInfo
    if not menu.isLocked or not menu.unit then
        return
    end
    print("[DEBUG] handle_unit_info_locked_input called with key: " .. key)

    if key == "k" then -- Unlock menu
        if Assets.sounds.back_out then
            Assets.sounds.back_out:stop(); Assets.sounds.back_out:play()
        end
        menu.isLocked = false
        menu.selectedIndex = 1
        -- Return to the previous state.
        local returnState = world.ui.previousPlayerTurnState or "free_roam"
        set_player_turn_state(returnState, world)
        world.ui.previousPlayerTurnState = nil -- Clean up the stored state.
    elseif key == "w" or key == "s" or key == "a" or key == "d" then
        move_unit_info_selection(key, world)
    elseif key == "j" then -- Confirm/Select
        local WEAPON_INDEX = 3 -- The weapon slice is now the 3rd item in the menu.
        if menu.selectedIndex == WEAPON_INDEX then
            -- Open the weapon selection menu
            local weaponMenu = world.ui.menus.weaponSelect
            weaponMenu.active = true
            weaponMenu.unit = menu.unit
            weaponMenu.options = {}
            weaponMenu.equippedByOther = {}
            weaponMenu.selectedIndex = 1

            -- Get the unit's allowed weapon types from its class
            local allowedWeaponTypes = {}
            if menu.unit.class and ClassBlueprints[menu.unit.class] then
                allowedWeaponTypes = ClassBlueprints[menu.unit.class].weaponTypes
            end

            -- Helper to check if a value is in a table
            local function table_contains(tbl, val)
                for _, value in ipairs(tbl) do
                    if value == val then return true end
                end
                return false
            end

            -- Populate the options from the player's global inventory, filtered by class
            for _, weaponKey in ipairs(world.playerInventory.weapons) do
                local weaponData = WeaponBlueprints[weaponKey]
                if weaponData and table_contains(allowedWeaponTypes, weaponData.type) then
                    table.insert(weaponMenu.options, weaponKey)
                end
            end

            -- Add an "Unequip" option at the bottom if the unit has a weapon equipped.
            if weaponMenu.unit.equippedWeapon then
                table.insert(weaponMenu.options, "unequip")
            end

            -- Find which weapons are equipped by other units
            for _, p in ipairs(world.players) do
                if p ~= weaponMenu.unit and p.equippedWeapon then
                    weaponMenu.equippedByOther[p.equippedWeapon] = true
                end
            end

            -- Set the initial selected index to the currently equipped weapon
            for i, weaponKey in ipairs(weaponMenu.options) do
                if weaponKey == weaponMenu.unit.equippedWeapon then
                    weaponMenu.selectedIndex = i
                    break
                end
            end

            set_player_turn_state("weapon_select", world)
        end
    end
end

local function handle_unit_selected_input(key, world)
    if key == "j" then -- Confirm Move
        local cursorOnUnit = world.ui.mapCursorTile.x == world.ui.selectedUnit.tileX and
                             world.ui.mapCursorTile.y == world.ui.selectedUnit.tileY

        -- Allow move confirmation if a valid path exists, OR if the cursor is on the unit's start tile (to attack without moving).
        if (world.ui.pathing.movementPath and #world.ui.pathing.movementPath > 0) or cursorOnUnit then
            -- If cursor is on the unit, the path is nil/empty. Assign an empty table `{}`
            -- to trigger the movement system's completion logic immediately.
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

            set_player_turn_state("unit_moving", world)
            world.ui.selectedUnit = nil
            -- Clear the original tile sets so they are not drawn by the regular logic.
            world.ui.pathing.reachableTiles = nil
            world.ui.pathing.attackableTiles = nil
            world.ui.pathing.movementPath = nil
        end
        return -- Exit to prevent cursor update on confirm
    elseif key == "k" then -- Cancel
        -- Play the back out sound effect
        if Assets.sounds.back_out then
            Assets.sounds.back_out:stop()
            Assets.sounds.back_out:play()
        end

        -- Snap the cursor back to the unit's position before deselecting.
        world.ui.mapCursorTile.x = world.ui.selectedUnit.tileX
        world.ui.mapCursorTile.y = world.ui.selectedUnit.tileY

        set_player_turn_state("free_roam", world)
        world.ui.selectedUnit = nil
        world.ui.pathing.reachableTiles = nil
        world.ui.pathing.attackableTiles = nil
        world.ui.pathing.movementPath = nil
        world.ui.pathing.cursorPath = nil
        return -- Exit to prevent cursor update on cancel
    end
end

-- This table maps special action menu keys to their handler functions. This approach
-- is cleaner and more extensible than a large if/elseif block.
local specialActionHandlers = {}

specialActionHandlers.wait = function(unit, world)
    finalize_player_action(unit, world)
end

specialActionHandlers.rescue = function(unit, world)
    local rescuableUnits = WorldQueries.findRescuableUnits(unit, world)
    if #rescuableUnits > 0 then
        set_player_turn_state("rescue_targeting", world)
        world.ui.targeting.rescue.active = true
        world.ui.targeting.rescue.targets = rescuableUnits
        world.ui.targeting.rescue.selectedIndex = 1
        world.ui.menus.action.active = false
        -- Snap cursor to first target
        local firstTarget = rescuableUnits[1]
        world.ui.mapCursorTile.x = firstTarget.tileX
        world.ui.mapCursorTile.y = firstTarget.tileY
    end
end

specialActionHandlers.drop = function(unit, world)
    local adjacentTiles = {}
    local neighbors = {{dx = 0, dy = -1}, {dx = 0, dy = 1}, {dx = -1, dy = 0}, {dx = 1, dy = 0}}
    for _, move in ipairs(neighbors) do
        local tileX, tileY = unit.tileX + move.dx, unit.tileY + move.dy
        if not WorldQueries.isTileOccupied(tileX, tileY, nil, world) and tileX >= 0 and tileX < world.map.width and tileY >= 0 and tileY < world.map.height then
            table.insert(adjacentTiles, {tileX = tileX, tileY = tileY})
        end
    end

    if #adjacentTiles > 0 then
        set_player_turn_state("drop_targeting", world)
        world.ui.targeting.drop.active = true
        world.ui.targeting.drop.tiles = adjacentTiles
        world.ui.targeting.drop.selectedIndex = 1
        world.ui.menus.action.active = false
        -- Snap cursor to first tile
        local firstTile = adjacentTiles[1]
        world.ui.mapCursorTile.x = firstTile.tileX
        world.ui.mapCursorTile.y = firstTile.tileY
    end
end

specialActionHandlers.shove = function(unit, world)
    local shoveTargets = WorldQueries.findShoveTargets(unit, world)
    if #shoveTargets > 0 then
        set_player_turn_state("shove_targeting", world)
        world.ui.targeting.shove.active = true
        world.ui.targeting.shove.targets = shoveTargets
        world.ui.targeting.shove.selectedIndex = 1
        world.ui.menus.action.active = false
        local firstTarget = shoveTargets[1]
        world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = firstTarget.tileX, firstTarget.tileY
    end
end

specialActionHandlers.take = function(unit, world)
    local takeTargets = WorldQueries.findTakeTargets(unit, world)
    if #takeTargets > 0 then
        set_player_turn_state("take_targeting", world)
        world.ui.targeting.take.active = true
        world.ui.targeting.take.targets = takeTargets
        world.ui.targeting.take.selectedIndex = 1
        world.ui.menus.action.active = false
        local firstTarget = takeTargets[1]
        world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = firstTarget.tileX, firstTarget.tileY
    end
end

-- Handles input when the post-move action menu is open.
local function handle_action_menu_input(key, world)
    local menu = world.ui.menus.action
    if not menu.active then return end

    if key == "w" or key == "s" then
        navigate_vertical_menu(key, menu, "action_menu_selection_changed", world)
    elseif key == "k" then -- Cancel action menu
        if Assets.sounds.back_out then
            Assets.sounds.back_out:stop()
            Assets.sounds.back_out:play()
        end

        local unit = menu.unit
        if unit and unit.startOfMoveTileX then
            -- Teleport unit back to its starting position
            unit.tileX, unit.tileY = unit.startOfMoveTileX, unit.startOfMoveTileY
            unit.x, unit.y = Grid.toPixels(unit.tileX, unit.tileY)
            unit.targetX, unit.targetY = unit.x, unit.y

            -- Restore the unit's direction to what it was at the start of the turn.
            if unit.startOfMoveDirection then
                unit.lastDirection = unit.startOfMoveDirection
            end

            -- Re-select the unit and allow them to move again
            set_player_turn_state("unit_selected", world)
            world.ui.selectedUnit = unit
            world.ui.pathing.reachableTiles, world.ui.pathing.came_from, world.ui.pathing.cost_so_far = Pathfinding.calculateReachableTiles(unit, world)
            world.ui.pathing.attackableTiles = RangeCalculator.calculateAttackableTiles(unit, world, world.ui.pathing.reachableTiles)

            -- Close the action menu
            menu.active = false

            -- Reset the cursor path since the move was undone.
            world.ui.pathing.cursorPath = {}
            -- After undoing the move, immediately recalculate the path to the current cursor position.
            -- This makes the UI feel more responsive and matches user expectation.
            local goalPosKey = world.ui.mapCursorTile.x .. "," .. world.ui.mapCursorTile.y
            if world.ui.pathing.reachableTiles and world.ui.pathing.reachableTiles[goalPosKey] and world.ui.pathing.reachableTiles[goalPosKey].landable then
                local startPosKey = unit.tileX .. "," .. unit.tileY
                world.ui.pathing.movementPath = Pathfinding.reconstructPath(world.ui.pathing.came_from, world.ui.pathing.cost_so_far, world.ui.pathing.cursorPath, startPosKey, goalPosKey)
            else
                world.ui.pathing.movementPath = nil -- No valid path to the current cursor tile.
            end
        end
    elseif key == "j" then -- Confirm action

        local selectedOption = menu.options[menu.selectedIndex]
        if not selectedOption then return end

        -- Check for wisp cost and target validity before proceeding.
        local attackData = selectedOption.key and AttackBlueprints[selectedOption.key]
        if attackData then
            if attackData.wispCost and menu.unit.wisp < attackData.wispCost then
                return -- Not enough wisp, do nothing.
            end
            if attackData.targeting_style == "cycle_target" and #WorldQueries.findValidTargetsForAttack(menu.unit, selectedOption.key, world) == 0 then
                return -- No valid targets, do nothing.
            end
        end

        -- Use the new handler table for special actions.
        local handler = specialActionHandlers[selectedOption.key]
        if handler then
            handler(menu.unit, world)
        else -- It's an attack.
            local attackName = selectedOption.key
            local unit = menu.unit
            world.ui.targeting.selectedAttackName= attackName
            menu.active = false

            -- Calculate the range for this specific attack to be displayed during targeting.
            world.ui.pathing.attackableTiles = RangeCalculator.calculateSingleAttackRange(unit, attackName, world)

            if attackData.targeting_style == "cycle_target" then
                local validTargets = WorldQueries.findValidTargetsForAttack(unit, attackName, world)
                -- The menu logic should prevent this, but as a failsafe:
                if #validTargets > 0 then
                    world.ui.targeting.cycle.active = true
                    world.ui.targeting.cycle.targets = validTargets
                    world.ui.targeting.cycle.selectedIndex = 1
                    set_player_turn_state("cycle_targeting", world) -- Dispatch event *after* setting up state.
                    -- Snap cursor to first target
                    local firstTarget = validTargets[1]
                    world.ui.mapCursorTile.x = firstTarget.tileX
                    world.ui.mapCursorTile.y = firstTarget.tileY

                    -- Make the attacker face the initial target
                    local dx, dy = firstTarget.tileX - unit.tileX, firstTarget.tileY - unit.tileY
                    if math.abs(dx) > math.abs(dy) then
                        unit.lastDirection = (dx > 0) and "right" or "left"
                    else
                        unit.lastDirection = (dy > 0) and "down" or "up"
                    end
                else
                    -- This case should not be reached due to the turn_based_movement_system check.
                    -- If it is, we cancel back to the menu.
                    set_player_turn_state("action_menu", world)
                    menu.active = true
                    world.ui.targeting.selectedAttackName= nil
                end
            elseif attackData.targeting_style == "ground_aim" then
                set_player_turn_state("ground_aiming", world)
                -- The cursor is already on the unit, which is a fine starting point for aiming.
                -- Immediately calculate the AoE preview for the starting position.
                world.ui.targeting.attackAoETiles = AttackPatterns.getGroundAimPreviewShapes(attackName, unit.tileX, unit.tileY)

                -- Calculate the grid of valid aiming tiles, if the attack has a range.
                if attackData.range then
                    world.ui.pathing.groundAimingGrid= {}
                    if attackData.line_of_sight_only then
                        -- For line-of-sight dashes, only add tiles in cardinal directions.
                        for i = 1, attackData.range do
                            -- Up, Down, Left, Right
                            local directions = {{0, -i}, {0, i}, {-i, 0}, {i, 0}}
                            for _, dir in ipairs(directions) do
                                local tileX, tileY = unit.tileX + dir[1], unit.tileY + dir[2]
                                -- The tile must be on the map. The attack itself will validate if it's occupied.
                                if tileX >= 0 and tileX < world.map.width and tileY >= 0 and tileY < world.map.height then
                                    world.ui.pathing.groundAimingGrid[tileX .. "," .. tileY] = true
                                end
                            end
                        end
                    else
                        -- For standard AoE ground aim, create a diamond-shaped grid based on Manhattan distance.
                        for dx = -attackData.range, attackData.range do
                            for dy = -attackData.range, attackData.range do
                                if math.abs(dx) + math.abs(dy) <= attackData.range then
                                    local tileX = unit.tileX + dx
                                    local tileY = unit.tileY + dy
                                    if tileX >= 0 and tileX < world.map.width and tileY >= 0 and tileY < world.map.height then
                                        world.ui.pathing.groundAimingGrid[tileX .. "," .. tileY] = true
                                    end
                                end
                            end
                        end
                    end
                end
            -- Directional and no-target attacks execute immediately without further aiming.
            elseif attackData.targeting_style == "no_target" or attackData.targeting_style == "directional_aim" or attackData.targeting_style == "auto_hit_all" then
                AttackHandler.execute(unit, attackName, world)
                -- Use the new centralized finalization function.
                finalize_player_action(unit, world)
            end
        end
    end
end

-- Handles input when the map menu is open.
local function handle_map_menu_input(key, world)
    local menu = world.ui.menus.map
    if not menu.active then return end

    -- Navigation (for future expansion)
    if key == "w" or key == "s" then
        navigate_vertical_menu(key, menu, nil, world)
    elseif key == "k" then -- Cancel
        menu.active = false
        set_player_turn_state("free_roam", world)
    elseif key == "j" then -- Confirm
        local selectedOption = menu.options[menu.selectedIndex]
        if selectedOption and selectedOption.key == "end_turn" then
            menu.active = false
            set_player_turn_state("free_roam", world)
            world.ui.turnShouldEnd = true
        end
    elseif world.ui.menus.unitInfo.active then
        world.ui.menus.unitInfo.active = false
    end
end

-- Helper to move the cursor for ground aiming, clamping to map bounds.
local function move_ground_aim_cursor(dx, dy, world)
    local attacker = world.ui.menus.action.unit
    local attackData = world.ui.targeting.selectedAttackName and AttackBlueprints[world.ui.targeting.selectedAttackName]
    local newTileX = world.ui.mapCursorTile.x + dx
    local newTileY = world.ui.mapCursorTile.y + dy

    -- If the attack has a specific range, validate against the pre-calculated grid.
    if attackData and attackData.range and world.ui.pathing.groundAimingGrid then
        if attackData.line_of_sight_only then
            -- For line-of-sight attacks, snap to the attacker's axis when changing direction.
            if dx ~= 0 then -- Moving horizontally
                newTileY = attacker.tileY
            elseif dy ~= 0 then -- Moving vertically
                newTileX = attacker.tileX
            end
        end

        -- Check if the new tile is in the valid grid.
        if world.ui.pathing.groundAimingGrid[newTileX .. "," .. newTileY] then
            world.ui.mapCursorTile.x = newTileX
            world.ui.mapCursorTile.y = newTileY
            -- After moving, update the AoE preview
            world.ui.targeting.attackAoETiles = AttackPatterns.getGroundAimPreviewShapes(world.ui.targeting.selectedAttackName, newTileX, newTileY)
        end
        -- If the tile is not valid, do nothing (the cursor doesn't move).
    else
        -- Fallback for attacks without a range grid: just clamp to map bounds.
        newTileX = math.max(0, math.min(newTileX, world.map.width - 1))
        newTileY = math.max(0, math.min(newTileY, world.map.height - 1))
        world.ui.mapCursorTile.x = newTileX
        world.ui.mapCursorTile.y = newTileY
        -- After moving, update the AoE preview
        world.ui.targeting.attackAoETiles = AttackPatterns.getGroundAimPreviewShapes(world.ui.targeting.selectedAttackName, newTileX, newTileY)
    end
end

-- Handles input when the player is aiming an attack at a ground tile.
local function handle_ground_aiming_input(key, world)
    local unit = world.ui.menus.action.unit -- The unit who is attacking
    if not unit then return end
    
    -- WASD movement is handled by the continuous input handler for smooth scrolling.
    -- This function only needs to process confirm/cancel actions.
    if key == "j" then -- Confirm Attack
        local attackName = world.ui.targeting.selectedAttackName

        -- The attack implementation itself will validate the target tile.
        -- AttackHandler.execute returns true if the attack was successful.
        if AttackHandler.execute(unit, attackName, world) then
            finalize_player_action(unit, world)
        end
    elseif key == "k" then -- Cancel Attack
        set_player_turn_state("action_menu", world)
        world.ui.menus.action.active = true
        world.ui.targeting.selectedAttackName= nil
        world.ui.targeting.attackAoETiles = nil
        world.ui.pathing.groundAimingGrid= nil -- Clear the grid
    end
end

-- Handles input when the player is cycling through targets for an attack.
local function handle_cycle_targeting_input(key, world)
    local cycle = world.ui.targeting.cycle
    if not cycle.active then return end

    local indexChanged = false
    if key == "a" then -- Cycle left
        cycle.selectedIndex = cycle.selectedIndex - 1
        if cycle.selectedIndex < 1 then cycle.selectedIndex = #cycle.targets end
        indexChanged = true
    elseif key == "d" then -- Cycle right
        cycle.selectedIndex = cycle.selectedIndex + 1
        if cycle.selectedIndex > #cycle.targets then cycle.selectedIndex = 1 end
        indexChanged = true
    elseif key == "k" then -- Cancel
        if Assets.sounds.back_out then
            Assets.sounds.back_out:stop()
            Assets.sounds.back_out:play()
        end
        set_player_turn_state("action_menu", world)
        world.ui.menus.action.active = true
        cycle.active = false
        cycle.targets = {}
        world.ui.targeting.selectedAttackName= nil
    elseif key == "l" then -- Lock Unit Info Menu on the current target
        local target = cycle.targets[cycle.selectedIndex]
        if target then
            local menu = world.ui.menus.unitInfo
            menu.isLocked = true
            menu.unit = target
            menu.selectedIndex = 1
            world.ui.previousPlayerTurnState = "cycle_targeting"
            set_player_turn_state("unit_info_locked", world)
        end
    elseif key == "j" then -- Confirm
        local attacker = world.ui.menus.action.unit
        local attackName = world.ui.targeting.selectedAttackName

        -- The attack implementation will read the selected target from world.ui.targeting.cycle
        AttackHandler.execute(attacker, attackName, world)

        -- Reset state after execution
        finalize_player_action(attacker, world)
    end

    -- If the selection changed, snap the cursor to the new target.
    if indexChanged then
        -- Dispatch an event so the BattleInfoSystem can update its forecast.
        EventBus:dispatch("cycle_target_changed", { world = world })
        local newTarget = cycle.targets[cycle.selectedIndex]
        if newTarget then
            world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = newTarget.tileX, newTarget.tileY

            -- Make the attacker face the new target
            local attacker = world.ui.menus.action.unit
            if attacker then
                local dx, dy = newTarget.tileX - attacker.tileX, newTarget.tileY - attacker.tileY
                if math.abs(dx) > math.abs(dy) then
                    attacker.lastDirection = (dx > 0) and "right" or "left"
                else attacker.lastDirection = (dy > 0) and "down" or "up" end
            end
        end
    end
end

-- Handles input when the player is cycling through units to rescue.
local function handle_rescue_targeting_input(key, world)
    local rescue = world.ui.targeting.rescue
    if not rescue.active then return end

    local indexChanged = false
    if key == "a" or key == "d" then -- Cycle targets
        if key == "a" then
            rescue.selectedIndex = rescue.selectedIndex - 1
            if rescue.selectedIndex < 1 then rescue.selectedIndex = #rescue.targets end
        else -- key == "d"
            rescue.selectedIndex = rescue.selectedIndex + 1
            if rescue.selectedIndex > #rescue.targets then rescue.selectedIndex = 1 end
        end
        indexChanged = true
    elseif key == "k" then -- Cancel
        set_player_turn_state("action_menu", world)
        world.ui.menus.action.active = true
        rescue.active = false
        rescue.targets = {}
    elseif key == "j" then -- Confirm
        local rescuer = world.ui.menus.action.unit
        local target = rescue.targets[rescue.selectedIndex]

        if RescueHandler.rescue(rescuer, target, world) then
            finalize_player_action(rescuer, world)
        end
    end

    if indexChanged then
        local newTarget = rescue.targets[rescue.selectedIndex]
        if newTarget then
            world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = newTarget.tileX, newTarget.tileY
        end
    end
end

-- Handles input when the player is cycling through tiles to drop a unit.
local function handle_drop_targeting_input(key, world)
    local drop = world.ui.targeting.drop
    if not drop.active then return end

    local indexChanged = false
    if key == "a" or key == "d" then -- Cycle tiles
        if key == "a" then
            drop.selectedIndex = drop.selectedIndex - 1
            if drop.selectedIndex < 1 then drop.selectedIndex = #drop.tiles end
        else -- key == "d"
            drop.selectedIndex = drop.selectedIndex + 1
            if drop.selectedIndex > #drop.tiles then drop.selectedIndex = 1 end
        end
        indexChanged = true
    elseif key == "k" then -- Cancel
        set_player_turn_state("action_menu", world)
        world.ui.menus.action.active = true
        drop.active = false
        drop.tiles = {}
    elseif key == "j" then -- Confirm
        local rescuer = world.ui.menus.action.unit
        local tile = drop.tiles[drop.selectedIndex]

        if RescueHandler.drop(rescuer, tile.tileX, tile.tileY, world) then
            finalize_player_action(rescuer, world)
        end
    end

    if indexChanged then
        local newTile = drop.tiles[drop.selectedIndex]
        if newTile then
            world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = newTile.tileX, newTile.tileY
        end
    end
end

-- Handles input when the player is cycling through units to shove.
local function handle_shove_targeting_input(key, world)
    local shove = world.ui.targeting.shove
    if not shove.active then return end

    local indexChanged = false
    if key == "a" or key == "d" then -- Cycle targets
        if key == "a" then
            shove.selectedIndex = shove.selectedIndex - 1
            if shove.selectedIndex < 1 then shove.selectedIndex = #shove.targets end
        else -- key == "d"
            shove.selectedIndex = shove.selectedIndex + 1
            if shove.selectedIndex > #shove.targets then shove.selectedIndex = 1 end
        end
        indexChanged = true
    elseif key == "k" then -- Cancel
        set_player_turn_state("action_menu", world)
        world.ui.menus.action.active = true
        shove.active = false
        shove.targets = {}
    elseif key == "j" then -- Confirm
        local shover = world.ui.menus.action.unit
        local target = shove.targets[shove.selectedIndex]

        -- Make the shover face the target before shoving for the lunge animation.
        local dx, dy = target.tileX - shover.tileX, target.tileY - shover.tileY
        if math.abs(dx) > math.abs(dy) then shover.lastDirection = (dx > 0) and "right" or "left"
        else shover.lastDirection = (dy > 0) and "down" or "up" end

        if ShoveHandler.shove(shover, target, world) then
            finalize_player_action(shover, world)
        end
    end

    if indexChanged then
        local newTarget = shove.targets[shove.selectedIndex]
        if newTarget then
            world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = newTarget.tileX, newTarget.tileY
        end
    end
end

-- Handles input when the player is cycling through units to take from.
local function handle_take_targeting_input(key, world)
    local take = world.ui.targeting.take
    if not take.active then return end

    local indexChanged = false
    if key == "a" or key == "d" then -- Cycle targets
        if key == "a" then
            take.selectedIndex = take.selectedIndex - 1
            if take.selectedIndex < 1 then take.selectedIndex = #take.targets end
        else -- key == "d"
            take.selectedIndex = take.selectedIndex + 1
            if take.selectedIndex > #take.targets then take.selectedIndex = 1 end
        end
        indexChanged = true
    elseif key == "k" then -- Cancel
        set_player_turn_state("action_menu", world)
        world.ui.menus.action.active = true
        take.active = false
        take.targets = {}
    elseif key == "j" then -- Confirm
        local taker = world.ui.menus.action.unit
        local carrier = take.targets[take.selectedIndex]

        if TakeHandler.take(taker, carrier, world) then
            finalize_player_action(taker, world)
        end
    end

    if indexChanged then
        local newTarget = take.targets[take.selectedIndex]
        if newTarget then
            world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = newTarget.tileX, newTarget.tileY
        end
    end
end

-- Handles input when an enemy's range is being displayed.
local function handle_enemy_range_display_input(key, world)
    -- Pressing J or K will cancel the display and return to free roam.
    if key == "j" or key == "k" then
        set_player_turn_state("free_roam", world)
        local display = world.ui.menus.enemyRangeDisplay
        display.active = false
        display.unit = nil
        display.reachableTiles = nil
        display.attackableTiles = nil
    end
    -- Cursor movement is handled by the main gameplay handler.
    -- No other input is processed in this state.
end

-- Handles input when the player is choosing a class promotion.
local function handle_promotion_select_input(key, world)
    local menu = world.ui.menus.promotion
    if not menu.active then return end

    if key == "w" or key == "s" then
        navigate_vertical_menu(key, menu, nil, world)
    elseif key == "j" then -- Confirm
        local selectedOption = menu.options[menu.selectedIndex]
        PromotionSystem.apply(menu.unit, selectedOption, world)
        menu.active = false -- Close the menu
    end
end

-- A dispatch table for player state input handlers. This is more scalable than a long if/elseif chain.
local playerStateInputHandlers = {
    free_roam = handle_free_roam_input,
    unit_selected = handle_unit_selected_input,
    unit_moving = function() end, -- Input is locked while a unit is moving.
    action_menu = handle_action_menu_input,
    ground_aiming = handle_ground_aiming_input,
    cycle_targeting = handle_cycle_targeting_input,
    rescue_targeting = handle_rescue_targeting_input,
    drop_targeting = handle_drop_targeting_input,
    shove_targeting = handle_shove_targeting_input,
    take_targeting = handle_take_targeting_input,
    enemy_range_display = handle_enemy_range_display_input,
    unit_info_locked = handle_unit_info_locked_input,
    weapon_select = handle_weapon_select_input,
    map_menu = handle_map_menu_input,
    promotion_select = handle_promotion_select_input,
}



--------------------------------------------------------------------------------
-- STATE-SPECIFIC HANDLERS
--------------------------------------------------------------------------------

local stateHandlers = {}

-- Handles all input during active gameplay.
stateHandlers.gameplay = function(key, world)
    -- Only accept input on the player's turn, with an exception for promotion selection,
    -- which can happen during the enemy's turn after a player unit levels up.
    if world.turn ~= "player" and world.ui.playerTurnState ~= "promotion_select" then
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
        if key == "w" then move_ground_aim_cursor(0, -1, world)
        elseif key == "s" then move_ground_aim_cursor(0, 1, world)
        elseif key == "a" then move_ground_aim_cursor(-1, 0, world)
        elseif key == "d" then move_ground_aim_cursor(1, 0, world)
        end
    end

    -- Delegate to the correct handler based on the player's current action state.
    local handler = playerStateInputHandlers[state]
    if handler then
        handler(key, world)
    end
end

-- Handles input on the game over screen.
stateHandlers.game_over = function(key, world)
    if key == "escape" then
        love.event.quit()
    end
end

-- Handles input when the game is paused.
stateHandlers.paused = function(key, world)
    -- Most input is blocked. The global 'escape' handler in handle_key_press will unpause.
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
        end
    end

    -- Find the correct handler for the current state and call it.
    local handler = stateHandlers[currentGameState]
    if handler then
        handler(key, world)
    end

    -- Return the current state, as no state change was triggered by this key.
    return currentGameState
end

-- This function handles continuous key-down checks for cursor movement.
function InputHandler.handle_continuous_input(dt, world)
    -- This function should only run during the player's turn in specific states.
    local state = world.ui.playerTurnState
    local movement_allowed = state == "free_roam" or
                             state == "unit_selected" or
                             state == "ground_aiming" or
                             state == "enemy_range_display" or
                             state == "unit_info_locked" or
                             state == "action_menu" or state == "map_menu" or
                             state == "weapon_select" or state == "promotion_select"

    if world.turn ~= "player" or not movement_allowed then
        world.ui.cursorInput.activeKey = nil -- Reset when not in a valid state
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
                    -- For the menu, we handle one direction at a time, prioritizing vertical.
                    local keyToMove = nil
                    if dy < 0 then keyToMove = "w"
                    elseif dy > 0 then keyToMove = "s"
                    elseif dx < 0 then keyToMove = "a"
                    elseif dx > 0 then keyToMove = "d"
                    end
                    if keyToMove then
                        move_unit_info_selection(keyToMove, world)
                    end
                elseif state == "ground_aiming" then
                    move_ground_aim_cursor(dx, dy, world)
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

                        if menu then navigate_vertical_menu(keyToMove, menu, eventName, world) end
                    end
                else
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