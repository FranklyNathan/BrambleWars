-- modules/input_handlers/action_menu_handler.lua
-- Handles input when the post-move action menu is open.

local InputHelpers = require("modules.input_helpers")
local Assets = require("modules.assets")
local WorldQueries = require("modules.world_queries")
local AttackBlueprints = require("data.attack_blueprints")
local Pathfinding = require("modules.pathfinding")
local RangeCalculator = require("modules.range_calculator")
local Grid = require("modules.grid")
local EventBus = require("modules.event_bus")
local AttackHandler = require("modules.attack_handler")
local WeaponBlueprints = require("data.weapon_blueprints")
local AttackPatterns = require("modules.attack_patterns")
local ShopMenuHandler = require("modules.input_handlers.shop_menu_handler")

local ActionMenuHandler = {}

-- This table maps special action menu keys to their handler functions. This approach
-- is cleaner and more extensible than a large if/elseif block.
local specialActionHandlers = {}

specialActionHandlers.wait = function(unit, world)
    InputHelpers.finalize_player_action(unit, world)
end

specialActionHandlers.shop = function(unit, world)
    local shopMenu = world.ui.menus.shop
    local shopkeep = world.shopkeep

    if not shopkeep then return end -- Failsafe

    shopMenu.active = true
    shopMenu.view = "main" -- Start at the main shop screen (Buy/Sell/Exit)
    shopMenu.options = {"Buy", "Sell", "Exit"} -- Set options for the generic navigator
    shopMenu.selectedIndex = 1

    -- Use the new helper functions to populate the lists.
    ShopMenuHandler.repopulate_buy_options(world)
    ShopMenuHandler.repopulate_sell_options(world)

    -- Transition to the new shop menu state.
    InputHelpers.set_player_turn_state("shop_menu", world)
    world.ui.menus.action.active = false -- Hide the action menu while shopping.
end

specialActionHandlers.rescue = function(unit, world)
    local rescuableUnits = WorldQueries.findRescuableUnits(unit, world)
    if #rescuableUnits > 0 then
        InputHelpers.set_player_turn_state("rescue_targeting", world)
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
    local adjacentTiles = WorldQueries.findValidDropTiles(unit, world)

    if #adjacentTiles > 0 then
        InputHelpers.set_player_turn_state("drop_targeting", world)
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
        InputHelpers.set_player_turn_state("shove_targeting", world)
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
        InputHelpers.set_player_turn_state("take_targeting", world)
        world.ui.targeting.take.active = true
        world.ui.targeting.take.targets = takeTargets
        world.ui.targeting.take.selectedIndex = 1
        world.ui.menus.action.active = false
        local firstTarget = takeTargets[1]
        world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = firstTarget.tileX, firstTarget.tileY
    end
end

function ActionMenuHandler.handle_key_press(key, world)
    local menu = world.ui.menus.action
    if not menu.active then return end

    if key == "w" or key == "s" then
        InputHelpers.navigate_vertical_menu(key, menu, "action_menu_selection_changed", world)
    elseif key == "k" then -- Cancel action menu
        InputHelpers.play_back_out_sound()
 
        local unit = menu.unit
        -- New: Check if the move has been "committed" by an action like shopping.
        if unit and unit.components.move_is_committed then
            -- Play an "error" or "back" sound, but do not allow the undo.
            -- The sound is already played above, so we just need to exit.
            return
        end

        -- Use the new centralized helper function. It returns true if a revert was performed.
        if InputHelpers.revert_player_move(unit, world) then
            -- The revert was successful. Now, handle the UI state changes specific to this handler.
            
            -- Re-select the unit and allow them to move again
            InputHelpers.set_player_turn_state("unit_selected", world)
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

        -- Use the new handler table for special actions.
        local handler = specialActionHandlers[selectedOption.key]
        if handler then
            -- Special actions like "Wait" or "Shop" bypass the standard attack validation.
            InputHelpers.play_menu_select_sound()
            handler(menu.unit, world)
        else -- It's an attack.
            -- Check for wisp cost and target validity before proceeding.
            local attackData = selectedOption.key and AttackBlueprints[selectedOption.key]
            if attackData then
                if attackData.wispCost and menu.unit.wisp < attackData.wispCost then
                    return -- Not enough wisp, do nothing.
                end
                if attackData.targeting_style == "cycle_target" and #WorldQueries.findValidTargetsForAttack(menu.unit, selectedOption.key, world) == 0 then
                    return -- No valid targets, do nothing.
                end
            else
                return -- Not a special action and not a valid attack, do nothing.
            end

            -- If we passed validation, play the sound.
            InputHelpers.play_menu_select_sound()

            local attackName = selectedOption.key
            local unit = menu.unit
            world.ui.targeting.selectedAttackName= attackName
            menu.active = false

            -- Calculate the range for this specific attack to be displayed during targeting.
            world.ui.pathing.attackableTiles = RangeCalculator.calculateSingleAttackRange(unit, attackName, world)

            if attackData.targeting_style == "cycle_valid_tiles" then
                local tileType = attackData.valid_tile_type -- e.g., "win_tiles"
                local validTiles = {}
                if world[tileType] then
                    for _, tile in ipairs(world[tileType]) do
                        -- A tile is valid if the attacker can land on it.
                        if WorldQueries.isTileLandable(tile.x, tile.y, unit, world) then
                            table.insert(validTiles, {tileX = tile.x, tileY = tile.y})
                        end
                    end
                end

                if #validTiles > 0 then
                    local tileCycle = world.ui.targeting.tile_cycle
                    tileCycle.active = true
                    tileCycle.tiles = validTiles
                    tileCycle.selectedIndex = 1
                    InputHelpers.set_player_turn_state("tile_cycling", world)
                    
                    -- Snap cursor to first valid tile
                    local firstTile = validTiles[1]
                    world.ui.mapCursorTile.x = firstTile.tileX
                    world.ui.mapCursorTile.y = firstTile.tileY
                end
            elseif attackData.targeting_style == "cycle_target" then
                local validTargets = WorldQueries.findValidTargetsForAttack(unit, attackName, world)
                -- The menu logic should prevent this, but as a failsafe:
                if #validTargets > 0 then
                    world.ui.targeting.cycle.active = true
                    world.ui.targeting.cycle.targets = validTargets
                    world.ui.targeting.cycle.selectedIndex = 1
                    InputHelpers.set_player_turn_state("cycle_targeting", world) -- Dispatch event *after* setting up state.
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
                    InputHelpers.set_player_turn_state("action_menu", world)
                    menu.active = true
                    world.ui.targeting.selectedAttackName= nil
                end
            elseif attackData.targeting_style == "ground_aim" then
                InputHelpers.set_player_turn_state("ground_aiming", world)
                -- The cursor is already on the unit, which is a fine starting point for aiming.
                -- Immediately calculate the AoE preview for the starting position.
                world.ui.targeting.attackAoETiles = AttackPatterns.getGroundAimPreviewShapes(attackName, unit.tileX, unit.tileY)

                -- Helper to check if a tile is a valid aiming destination.
                local function is_valid_aim_tile(tileX, tileY)
                    if tileX < 0 or tileX >= world.map.width or tileY < 0 or tileY >= world.map.height then
                        return false
                    end
                    -- For dash-like attacks, the target tile must be landable.
                    -- This requires a property like `requires_landable_target = true` in the attack blueprint.
                    if attackData.requires_landable_target then
                        return WorldQueries.isTileLandable(tileX, tileY, unit, world)
                    end
                    return true -- For non-dash attacks, any tile on the map is valid to aim at.
                end

                -- Calculate the grid of valid aiming tiles, if the attack has a range.
                if attackData.range then
                    world.ui.pathing.groundAimingGrid= {}
                    if attackData.line_of_sight_only then
                        -- For line-of-sight dashes, only add tiles in cardinal directions.
                        for i = 1, attackData.range do
                            local directions = {{0, -i}, {0, i}, {-i, 0}, {i, 0}}
                            for _, dir in ipairs(directions) do
                                local tileX, tileY = unit.tileX + dir[1], unit.tileY + dir[2]
                                if is_valid_aim_tile(tileX, tileY) then
                                    world.ui.pathing.groundAimingGrid[tileX .. "," .. tileY] = true                     
                                end
                            end
                        end
                    else
                        -- For standard AoE ground aim, create a diamond-shaped grid.
                        for dx = -attackData.range, attackData.range do
                            for dy = -attackData.range, attackData.range do
                                if math.abs(dx) + math.abs(dy) <= attackData.range then
                                    local tileX = unit.tileX + dx
                                    local tileY = unit.tileY + dy
                                    if is_valid_aim_tile(tileX, tileY) then
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
                InputHelpers.finalize_player_action(unit, world)
            end
        end
    end
end

return ActionMenuHandler