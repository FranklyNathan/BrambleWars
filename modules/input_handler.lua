-- input_handler.lua
-- Contains all logic for processing player keyboard input.

local RangeCalculator = require("modules.range_calculator")
local Pathfinding = require("modules.pathfinding")
local AttackHandler = require("modules.attack_handler")
local AttackPatterns = require("modules.attack_patterns")
local WorldQueries = require("modules.world_queries")
local Grid = require("modules.grid")
local RescueHandler = require("modules.rescue_handler")

local InputHandler = {}

-- Helper function to find attack data by name from a unit's blueprint.
local function getAttackDataByName(attackName)
    if not attackName then return nil end
    return AttackBlueprints[attackName]
end

--------------------------------------------------------------------------------
-- TURN-BASED HELPER FUNCTIONS
--------------------------------------------------------------------------------

-- Checks if all living player units have taken their action for the turn.
local function allPlayersHaveActed(world)
    for _, player in ipairs(world.players) do
        if player.hp > 0 and not player.hasActed then
            return false -- Found a player who hasn't acted yet.
        end
    end
    return true -- All living players have acted.
end

-- Jumps the cursor to the next available player unit.
local function focus_next_available_player(world)
    for _, player in ipairs(world.players) do
        if player.hp > 0 and not player.hasActed then
            world.mapCursorTile.x = player.tileX
            world.mapCursorTile.y = player.tileY
            return -- Found the first available player and focused.
        end
    end
end

-- Helper to move the cursor and update the movement path if applicable.
local function move_cursor(dx, dy, world)
    local newTileX = world.mapCursorTile.x + dx
    local newTileY = world.mapCursorTile.y + dy

    -- Clamp cursor to screen bounds
    newTileX = math.max(0, math.min(newTileX, world.map.width - 1))
    newTileY = math.max(0, math.min(newTileY, world.map.height - 1))
    world.mapCursorTile.x = newTileX
    world.mapCursorTile.y = newTileY

    -- If a unit is selected, update the movement path
    if world.playerTurnState == "unit_selected" then
        local goalPosKey = world.mapCursorTile.x .. "," .. world.mapCursorTile.y
        -- Check if the tile is reachable AND landable.
        if world.reachableTiles and world.reachableTiles[goalPosKey] and world.reachableTiles[goalPosKey].landable then
            local startPosKey = world.selectedUnit.tileX .. "," .. world.selectedUnit.tileY
            world.movementPath = Pathfinding.reconstructPath(world.came_from, startPosKey, goalPosKey)
        else
            world.movementPath = nil -- Cursor is on an unreachable or non-landable tile
        end
    end
end

-- Finds a player unit at a specific tile coordinate.
local function getPlayerUnitAt(tileX, tileY, world)
    for _, p in ipairs(world.players) do
        if p.hp > 0 and p.tileX == tileX and p.tileY == tileY then
            return p
        end
    end
    return nil
end

-- Helper to generate AoE preview for ground-targeted attacks.
local function get_ground_aim_aoe_preview(attackName, cursorTileX, cursorTileY)
    local pixelX, pixelY = Grid.toPixels(cursorTileX, cursorTileY)

    if attackName == "grovecall" then
        -- A simple 1x1 tile preview.
        return {{shape = {type = "rect", x = pixelX, y = pixelY, w = Config.SQUARE_SIZE, h = Config.SQUARE_SIZE}, delay = 0}}
    elseif attackName == "eruption" then
        -- Center the ripple on the middle of the target tile.
        local centerX = pixelX + Config.SQUARE_SIZE / 2
        local centerY = pixelY + Config.SQUARE_SIZE / 2
        return AttackPatterns.ripple(centerX, centerY, 1)
    elseif attackName == "quick_step" then
        -- A simple 1x1 tile preview for the dash destination.
        return {{shape = {type = "rect", x = pixelX, y = pixelY, w = Config.SQUARE_SIZE, h = Config.SQUARE_SIZE}, delay = 0}}
    end

    return {} -- Default to no preview
end

-- Handles input when the player is freely moving the cursor around the map.
local function handle_free_roam_input(key, world)
    if key == "j" then -- Universal "Confirm" / "Action" key
        local unit = getPlayerUnitAt(world.mapCursorTile.x, world.mapCursorTile.y, world)
        if unit and not unit.hasActed then
            -- If the cursor is on an available player unit, select it.
world.selectedUnit = unit
            world.playerTurnState = "unit_selected"
            -- Calculate movement range and pathing data
            world.reachableTiles, world.came_from = Pathfinding.calculateReachableTiles(unit, world)
            world.attackableTiles = RangeCalculator.calculateAttackableTiles(unit, world, world.reachableTiles)
            world.movementPath = {} -- Start with an empty path

            print("Selected unit:", unit.playerType)

        else
            local anyUnit = WorldQueries.getUnitAt(world.mapCursorTile.x, world.mapCursorTile.y, nil, world)
            if anyUnit and anyUnit.type == "enemy" then
                -- Pressing 'J' on an enemy now shows their range.
                world.playerTurnState = "enemy_range_display"
                local display = world.enemyRangeDisplay
                display.active = true
                display.unit = anyUnit
                local reachable, _ = Pathfinding.calculateReachableTiles(anyUnit, world)
                display.reachableTiles = reachable
                display.attackableTiles = RangeCalculator.calculateAttackableTiles(anyUnit, world, reachable)
            elseif not anyUnit then
                -- The tile is empty, so open the map menu.
                world.mapMenu.active = true
                world.mapMenu.options = {{text = "End Turn", key = "end_turn"}}
                world.mapMenu.selectedIndex = 1
                world.playerTurnState = "map_menu"
            end
        end
    end

    if not world.selectedUnit then
        local unit = WorldQueries.getUnitAt(world.mapCursorTile.x, world.mapCursorTile.y, nil, world)
        if unit then print("Cursor over unit (no selection):", unit.displayName) end
    end

end


local function handle_unit_selected_input(key, world)
    if key == "j" then -- Confirm Move
        local cursorOnUnit = world.mapCursorTile.x == world.selectedUnit.tileX and
                             world.mapCursorTile.y == world.selectedUnit.tileY

        -- Allow move confirmation if a valid path exists, OR if the cursor is on the unit's start tile (to attack without moving).
        if (world.movementPath and #world.movementPath > 0) or cursorOnUnit then
            -- If cursor is on the unit, the path is nil/empty. Assign an empty table `{}`
            -- to trigger the movement system's completion logic immediately.
            world.selectedUnit.components.movement_path = world.movementPath or {}
            world.playerTurnState = "unit_moving"
            world.selectedUnit = nil
            world.reachableTiles = nil
            world.attackableTiles = nil
            world.movementPath = nil
        end
        return -- Exit to prevent cursor update on confirm
    elseif key == "k" then -- Cancel
        -- Snap the cursor back to the unit's position before deselecting.
        world.mapCursorTile.x = world.selectedUnit.tileX
        world.mapCursorTile.y = world.selectedUnit.tileY

        world.playerTurnState = "free_roam"
        world.selectedUnit = nil
        world.reachableTiles = nil
        world.attackableTiles = nil
        world.movementPath = nil
        return -- Exit to prevent cursor update on cancel
    end
end

-- Handles input when the post-move action menu is open.
local function handle_action_menu_input(key, world)
    local menu = world.actionMenu
    if not menu.active then return end

    if key == "w" then
        -- Wrap around to the bottom when moving up from the top.
        menu.selectedIndex = (menu.selectedIndex - 2 + #menu.options) % #menu.options + 1
    elseif key == "s" then
        -- Wrap around to the top when moving down from the bottom.
        menu.selectedIndex = menu.selectedIndex % #menu.options + 1
    elseif key == "k" then -- Cancel action menu
        local unit = menu.unit
        if unit and unit.startOfTurnTileX then
            -- Teleport unit back to its starting position
            unit.tileX, unit.tileY = unit.startOfTurnTileX, unit.startOfTurnTileY
            unit.x, unit.y = Grid.toPixels(unit.tileX, unit.tileY)
            unit.targetX, unit.targetY = unit.x, unit.y

            -- Re-select the unit and allow them to move again
            world.playerTurnState = "unit_selected"
            world.selectedUnit = unit
            world.reachableTiles, world.came_from = Pathfinding.calculateReachableTiles(unit, world)
            world.attackableTiles = RangeCalculator.calculateAttackableTiles(unit, world, world.reachableTiles)

            -- Close the action menu
            menu.active = false

            -- After undoing the move, immediately recalculate the path to the current cursor position.
            -- This makes the UI feel more responsive and matches user expectation.
            local goalPosKey = world.mapCursorTile.x .. "," .. world.mapCursorTile.y
            if world.reachableTiles and world.reachableTiles[goalPosKey] and world.reachableTiles[goalPosKey].landable then
                local startPosKey = unit.tileX .. "," .. unit.tileY
                world.movementPath = Pathfinding.reconstructPath(world.came_from, startPosKey, goalPosKey)
            else
                world.movementPath = nil -- No valid path to the current cursor tile.
            end
        end
    elseif key == "j" then -- Confirm action

        local selectedOption = menu.options[menu.selectedIndex]
        if not selectedOption then return end

        if selectedOption.key == "wait" then
            menu.unit.hasActed = true
            menu.active = false
            world.playerTurnState = "free_roam"
            if allPlayersHaveActed(world) then
                world.turnShouldEnd = true
            else
                -- Leave the cursor on the unit that just acted.
                world.mapCursorTile.x = menu.unit.tileX
                world.mapCursorTile.y = menu.unit.tileY
            end
        elseif selectedOption.key == "rescue" then
            local unit = menu.unit
            local rescuableUnits = WorldQueries.findRescuableUnits(unit, world)
            if #rescuableUnits > 0 then
                world.playerTurnState = "rescue_targeting"
                world.rescueTargeting.active = true
                world.rescueTargeting.targets = rescuableUnits
                world.rescueTargeting.selectedIndex = 1
                menu.active = false
                -- Snap cursor to first target
                local firstTarget = rescuableUnits[1]
                world.mapCursorTile.x = firstTarget.tileX
                world.mapCursorTile.y = firstTarget.tileY
            end
        elseif selectedOption.key == "drop" then
            local unit = menu.unit
            local adjacentTiles = {}
            local neighbors = {{dx = 0, dy = -1}, {dx = 0, dy = 1}, {dx = -1, dy = 0}, {dx = 1, dy = 0}}
            for _, move in ipairs(neighbors) do
                local tileX, tileY = unit.tileX + move.dx, unit.tileY + move.dy
                if not WorldQueries.isTileOccupied(tileX, tileY, nil, world) and tileX >= 0 and tileX < world.map.width and tileY >= 0 and tileY < world.map.height then
                    table.insert(adjacentTiles, {tileX = tileX, tileY = tileY})
                end
            end

            if #adjacentTiles > 0 then
                world.playerTurnState = "drop_targeting"
                world.dropTargeting.active = true
                world.dropTargeting.tiles = adjacentTiles
                world.dropTargeting.selectedIndex = 1
                menu.active = false
                -- Snap cursor to first tile
                local firstTile = adjacentTiles[1]
                world.mapCursorTile.x = firstTile.tileX
                world.mapCursorTile.y = firstTile.tileY
            end
        else -- It's an attack.
            local attackName = selectedOption.key
            local attackData = getAttackDataByName(attackName)
            local unit = menu.unit

            world.selectedAttackName = attackName
            menu.active = false

            print("Selected attack:", attackName)
            if attackData.targeting_style == "cycle_target" then
                local validTargets = WorldQueries.findValidTargetsForAttack(unit, attackName, world)
                -- The menu logic should prevent this, but as a failsafe:
                if #validTargets > 0 then
                    world.playerTurnState = "cycle_targeting"
                    world.cycleTargeting.active = true
                    world.cycleTargeting.targets = validTargets
                    world.cycleTargeting.selectedIndex = 1
                    -- Set cursor to first target
                    local firstTarget = validTargets[1]
                    world.mapCursorTile.x = firstTarget.tileX
                    world.mapCursorTile.y = firstTarget.tileY

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
                    world.playerTurnState = "action_menu"
                    menu.active = true
                    world.selectedAttackName = nil
                end
            elseif attackData.targeting_style == "ground_aim" then
                world.playerTurnState = "ground_aiming"
                -- The cursor is already on the unit, which is a fine starting point for aiming.
                -- Immediately calculate the AoE preview for the starting position.
                world.attackAoETiles = get_ground_aim_aoe_preview(attackName, unit.tileX, unit.tileY)

                -- Calculate the grid of valid aiming tiles, if the attack has a range.
                if attackData.range then
                    world.groundAimingGrid = {}
                    if attackData.line_of_sight_only then
                        -- For line-of-sight dashes, only add tiles in cardinal directions.
                        for i = 1, attackData.range do
                            -- Up, Down, Left, Right
                            local directions = {{0, -i}, {0, i}, {-i, 0}, {i, 0}}
                            for _, dir in ipairs(directions) do
                                local tileX, tileY = unit.tileX + dir[1], unit.tileY + dir[2]
                                if tileX >= 0 and tileX < world.map.width and tileY >= 0 and tileY < world.map.height then
                                    table.insert(world.groundAimingGrid, {x = tileX, y = tileY})
                                end
                            end
                        end
                    else
                        -- For standard AoE ground aim, create a square grid.
                        for dx = -attackData.range, attackData.range do
                            for dy = -attackData.range, attackData.range do
                                local tileX = unit.tileX + dx
                                local tileY = unit.tileY + dy
                                if tileX >= 0 and tileX < world.map.width and tileY >= 0 and tileY < world.map.height then
                                    table.insert(world.groundAimingGrid, {x = tileX, y = tileY})
                                end
                            end
                        end
                    end
                end
            -- Directional and no-target attacks execute immediately without further aiming.
            elseif attackData.targeting_style == "no_target" or attackData.targeting_style == "directional_aim" or attackData.targeting_style == "auto_hit_all" then
                AttackHandler.execute(unit, attackName, world)
                print("AttackHandler.execute called for", attackName)
                world.playerTurnState = "free_roam"
                world.selectedAttackName = nil
                if allPlayersHaveActed(world) then
                    world.turnShouldEnd = true
                else
                    -- Leave the cursor on the unit that just acted.
                    world.mapCursorTile.x = unit.tileX
                    world.mapCursorTile.y = unit.tileY
                end
            end
        end
    end
end

-- Handles input when the map menu is open.
local function handle_map_menu_input(key, world)
    local menu = world.mapMenu
    if not menu.active then return end

    -- Navigation (for future expansion)
    if key == "w" then
        menu.selectedIndex = (menu.selectedIndex - 2 + #menu.options) % #menu.options + 1
    elseif key == "s" then
        menu.selectedIndex = menu.selectedIndex % #menu.options + 1
    elseif key == "k" then -- Cancel
        menu.active = false
        world.playerTurnState = "free_roam"
    elseif key == "j" then -- Confirm
        local selectedOption = menu.options[menu.selectedIndex]
        if selectedOption and selectedOption.key == "end_turn" then
            menu.active = false
            world.playerTurnState = "free_roam" -- State will change to "enemy" anyway
            world.turnShouldEnd = true
        end
    elseif world.unitInfoMenu.active then
        world.unitInfoMenu.active = false
    end
end

-- Helper to move the cursor for ground aiming, clamping to map bounds.
local function move_ground_aim_cursor(dx, dy, world)
    local newTileX = world.mapCursorTile.x + dx
    local newTileY = world.mapCursorTile.y + dy

    local attacker = world.actionMenu.unit
    local attackData = getAttackDataByName(world.selectedAttackName)

    -- By default, clamp to map bounds
    local minX, maxX = 0, world.map.width - 1
    local minY, maxY = 0, world.map.height - 1

    -- If the attack has a specific range, clamp to that range around the attacker
    if attackData and attackData.range and attacker then
        if attackData.line_of_sight_only then
            -- For line-of-sight attacks, snap to the attacker's axis when changing direction.
            if dx ~= 0 then -- Moving horizontally
                newTileY = attacker.tileY
            elseif dy ~= 0 then -- Moving vertically
                newTileX = attacker.tileX
            end
        end
        -- Clamp to the attack's range box regardless of aiming style.
        minX = math.max(minX, attacker.tileX - attackData.range)
        maxX = math.min(maxX, attacker.tileX + attackData.range)
        minY = math.max(minY, attacker.tileY - attackData.range)
        maxY = math.min(maxY, attacker.tileY + attackData.range)
    end

    -- Clamp cursor to the calculated bounds
    newTileX = math.max(minX, math.min(newTileX, maxX))
    newTileY = math.max(minY, math.min(newTileY, maxY))
    world.mapCursorTile.x = newTileX
    world.mapCursorTile.y = newTileY

    -- After moving, update the AoE preview
    world.attackAoETiles = get_ground_aim_aoe_preview(world.selectedAttackName, newTileX, newTileY)
end

-- Handles input when the player is aiming an attack at a ground tile.
local function handle_ground_aiming_input(key, world)
    local unit = world.actionMenu.unit -- The unit who is attacking
    if not unit then return end
    
    -- WASD movement is handled by the continuous input handler for smooth scrolling.
    -- This function only needs to process confirm/cancel actions.
    if key == "j" then -- Confirm Attack
        local attackName = world.selectedAttackName

        -- The attack implementation itself will validate the target tile.
        -- AttackHandler.execute returns true if the attack was successful.
        if AttackHandler.execute(unit, attackName, world) then
            unit.hasActed = true
            world.playerTurnState = "free_roam"
            world.actionMenu = { active = false, unit = nil, options = {}, selectedIndex = 1 }
            world.selectedAttackName = nil
            world.attackAoETiles = nil
            world.groundAimingGrid = nil -- Clear the grid
            if allPlayersHaveActed(world) then
                world.turnShouldEnd = true
            else
                -- Leave the cursor on the unit that just acted.
                world.mapCursorTile.x = unit.tileX
                world.mapCursorTile.y = unit.tileY
            end
        end
    elseif key == "k" then -- Cancel Attack
        world.playerTurnState = "action_menu"
        world.actionMenu.active = true
        world.selectedAttackName = nil
        world.attackAoETiles = nil
        world.groundAimingGrid = nil -- Clear the grid
    end
end

-- Handles input when the player is cycling through targets for an attack.
local function handle_cycle_targeting_input(key, world)
    local cycle = world.cycleTargeting
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
        world.playerTurnState = "action_menu"
        world.actionMenu.active = true
        cycle.active = false
        cycle.targets = {}
        world.selectedAttackName = nil
    elseif key == "j" then -- Confirm
        local attacker = world.actionMenu.unit
        local attackName = world.selectedAttackName

        -- The attack implementation will read the selected target from world.cycleTargeting
        AttackHandler.execute(attacker, attackName, world)

        -- Reset state after execution
        attacker.hasActed = true
        world.playerTurnState = "free_roam"
        world.actionMenu = { active = false, unit = nil, options = {}, selectedIndex = 1 }
        world.selectedAttackName = nil
        cycle.active = false
        cycle.targets = {}

        if allPlayersHaveActed(world) then
            world.turnShouldEnd = true
        else
            -- Leave the cursor on the unit that just acted.
            world.mapCursorTile.x, world.mapCursorTile.y = attacker.tileX, attacker.tileY
        end
    end

    -- If the selection changed, snap the cursor to the new target.
    if indexChanged then
        local newTarget = cycle.targets[cycle.selectedIndex]
        if newTarget then
            world.mapCursorTile.x, world.mapCursorTile.y = newTarget.tileX, newTarget.tileY

            -- Make the attacker face the new target
            local attacker = world.actionMenu.unit
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
    local rescue = world.rescueTargeting
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
        world.playerTurnState = "action_menu"
        world.actionMenu.active = true
        rescue.active = false
        rescue.targets = {}
    elseif key == "j" then -- Confirm
        local rescuer = world.actionMenu.unit
        local target = rescue.targets[rescue.selectedIndex]

        if RescueHandler.rescue(rescuer, target, world) then
            rescuer.hasActed = true
            world.playerTurnState = "free_roam"
            -- Reset menus and targeting states
            world.actionMenu = { active = false, unit = nil, options = {}, selectedIndex = 1 }
            rescue.active = false
            rescue.targets = {}

            if allPlayersHaveActed(world) then
                world.turnShouldEnd = true
            else
                -- Leave cursor on the rescuer
                world.mapCursorTile.x, world.mapCursorTile.y = rescuer.tileX, rescuer.tileY
            end
        end
    end

    if indexChanged then
        local newTarget = rescue.targets[rescue.selectedIndex]
        if newTarget then
            world.mapCursorTile.x, world.mapCursorTile.y = newTarget.tileX, newTarget.tileY
        end
    end
end

-- Handles input when the player is cycling through tiles to drop a unit.
local function handle_drop_targeting_input(key, world)
    local drop = world.dropTargeting
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
        world.playerTurnState = "action_menu"
        world.actionMenu.active = true
        drop.active = false
        drop.tiles = {}
    elseif key == "j" then -- Confirm
        local rescuer = world.actionMenu.unit
        local tile = drop.tiles[drop.selectedIndex]

        if RescueHandler.drop(rescuer, tile.tileX, tile.tileY, world) then
            rescuer.hasActed = true
            world.playerTurnState = "free_roam"
            world.actionMenu = { active = false, unit = nil, options = {}, selectedIndex = 1 }
            drop.active = false
            drop.tiles = {}
        end
    end

    if indexChanged then
        local newTile = drop.tiles[drop.selectedIndex]
        if newTile then
            world.mapCursorTile.x, world.mapCursorTile.y = newTile.tileX, newTile.tileY
        end
    end
end

-- Handles input when an enemy's range is being displayed.
local function handle_enemy_range_display_input(key, world)
    -- Pressing J or K will cancel the display and return to free roam.
    if key == "j" or key == "k" then
        world.playerTurnState = "free_roam"
        local display = world.enemyRangeDisplay
        display.active = false
        display.unit = nil
        display.reachableTiles = nil
        display.attackableTiles = nil
    end
    -- Cursor movement is handled by the main gameplay handler.
    -- No other input is processed in this state.
end















--------------------------------------------------------------------------------
-- STATE-SPECIFIC HANDLERS
--------------------------------------------------------------------------------

local stateHandlers = {}

-- Handles all input during active gameplay.
stateHandlers.gameplay = function(key, world)
    if world.turn ~= "player" then return end -- Only accept input on the player's turn

    -- Handle cursor movement for states that allow it. This is for single key taps.
    if world.playerTurnState == "free_roam" or world.playerTurnState == "unit_selected" or world.playerTurnState == "enemy_range_display" then
        if key == "w" then move_cursor(0, -1, world)
        elseif key == "s" then move_cursor(0, 1, world)
        elseif key == "a" then move_cursor(-1, 0, world)
        elseif key == "d" then move_cursor(1, 0, world)
        end
    elseif world.playerTurnState == "ground_aiming" then
        -- Ground aiming has its own cursor movement logic with different bounds.
        if key == "w" then move_ground_aim_cursor(0, -1, world)
        elseif key == "s" then move_ground_aim_cursor(0, 1, world)
        elseif key == "a" then move_ground_aim_cursor(-1, 0, world)
        elseif key == "d" then move_ground_aim_cursor(1, 0, world)
        end
    end

    -- Delegate to the correct handler based on the player's current action.
    if world.playerTurnState == "free_roam" then
        handle_free_roam_input(key, world)
    elseif world.playerTurnState == "unit_selected" then
        handle_unit_selected_input(key, world)
    elseif world.playerTurnState == "unit_moving" then
        -- Input is locked while a unit is moving.
    elseif world.playerTurnState == "action_menu" then
        handle_action_menu_input(key, world)
    elseif world.playerTurnState == "ground_aiming" then
        handle_ground_aiming_input(key, world)
    elseif world.playerTurnState == "cycle_targeting" then
        handle_cycle_targeting_input(key, world)
    elseif world.playerTurnState == "rescue_targeting" then
        handle_rescue_targeting_input(key, world)
    elseif world.playerTurnState == "drop_targeting" then
        handle_drop_targeting_input(key, world)
    elseif world.playerTurnState == "enemy_range_display" then
        handle_enemy_range_display_input(key, world)
    elseif world.playerTurnState == "map_menu" then
        handle_map_menu_input(key, world)
    end
end

-- Handles all input for the party selection menu.
stateHandlers.party_select = function(key, world)
    if key == "w" then world.cursorPos.y = math.max(1, world.cursorPos.y - 1)
    elseif key == "s" then world.cursorPos.y = math.min(3, world.cursorPos.y + 1)
    elseif key == "a" then world.cursorPos.x = math.max(1, world.cursorPos.x - 1)
    elseif key == "d" then world.cursorPos.x = math.min(3, world.cursorPos.x + 1)
    elseif key == "j" then
        if not world.selectedSquare then
            if world.characterGrid[world.cursorPos.y] and world.characterGrid[world.cursorPos.y][world.cursorPos.x] then
                world.selectedSquare = {x = world.cursorPos.x, y = world.cursorPos.y}
            end
        else
            local secondSquareType = world.characterGrid[world.cursorPos.y] and world.characterGrid[world.cursorPos.y][world.cursorPos.x]
            if secondSquareType then
                local firstSquareType = world.characterGrid[world.selectedSquare.y][world.selectedSquare.x]
                world.characterGrid[world.selectedSquare.y][world.selectedSquare.x] = secondSquareType
                world.characterGrid[world.cursorPos.y][world.cursorPos.x] = firstSquareType
            end
        end
    elseif world.unitInfoMenu.active then
        world.unitInfoMenu.active = false
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
        if currentGameState == "gameplay" then
            return "party_select" -- Switch to the menu
        elseif currentGameState == "party_select" then
            -- This is where the logic for applying party changes when unpausing lives now.
            local oldPlayerTypes = {}
            for _, p in ipairs(world.players) do table.insert(oldPlayerTypes, p.playerType) end
            local newPlayerTypes = {}
            for i = 1, 3 do if world.characterGrid[1][i] then table.insert(newPlayerTypes, world.characterGrid[1][i]) end end

            local partyChanged = #oldPlayerTypes ~= #newPlayerTypes
            if not partyChanged then
                for i = 1, #oldPlayerTypes do if oldPlayerTypes[i] ~= newPlayerTypes[i] then partyChanged = true; break end end
            end

            if partyChanged then
                -- Store the positions of the current party members to assign to the new party
                local oldPositions = {}
                for _, p in ipairs(world.players) do
                    table.insert(oldPositions, {x = p.x, y = p.y, targetX = p.targetX, targetY = p.targetY})
                end

                -- Mark all current players for deletion
                for _, p in ipairs(world.players) do
                    p.isMarkedForDeletion = true
                end

                -- Queue the new party members for addition
                for i, playerType in ipairs(newPlayerTypes) do
                    local playerObject = world.roster[playerType]
                    -- We only add them if they are alive. The roster preserves their state (HP, etc.)
                    if playerObject.hp > 0 then
                        -- Assign the position of the player being replaced. This prevents new members from spawning off-screen.
                        if oldPositions[i] then
                            playerObject.x, playerObject.y, playerObject.targetX, playerObject.targetY = oldPositions[i].x, oldPositions[i].y, oldPositions[i].targetX, oldPositions[i].targetY
                        else
                            -- If there's no old position (e.g., adding a new member to a smaller party),
                            -- give them a default starting position to avoid spawning at (0,0).
                            local newX = 100 + (i - 1) * 50
                            local newY = 100
                            playerObject.x, playerObject.y, playerObject.targetX, playerObject.targetY = newX, newY, newX, newY
                        end

                        world:queue_add_entity(playerObject)
                    end
                end
                -- Immediately process the additions and deletions to prevent visual glitches.
                -- This is the key fix for units vanishing on unpause.
                world:process_additions_and_deletions()
            end
            world.selectedSquare = nil -- Reset selection on unpause
            return "gameplay" -- Switch back to gameplay
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
    local state = world.playerTurnState
    local movement_allowed = state == "free_roam" or state == "unit_selected" or state == "ground_aiming" or state == "enemy_range_display"

    if world.turn ~= "player" or not movement_allowed then
        world.cursorInput.activeKey = nil -- Reset when not in a valid state
        return
    end

    local cursor = world.cursorInput
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
                if world.playerTurnState == "ground_aiming" then
                    move_ground_aim_cursor(dx, dy, world)
                else
                    move_cursor(dx, dy, world)
                end
                cursor.timer = cursor.timer + cursor.repeatDelay -- Add to prevent timer drift
            end
        end
    else
        -- No key is pressed. Reset the state.
        cursor.activeKey = nil
    end
end

return InputHandler