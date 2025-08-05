-- modules/input_handlers/cycle_targeting_handler.lua
-- Handles input when the player is cycling through targets for an attack.

local EventBus = require("modules.event_bus")
local InputHelpers = require("modules.input_helpers")
local AttackHandler = require("modules.attack_handler")
local AttackBlueprints = require("data.attack_blueprints")
local WorldQueries = require("modules.world_queries")
local Assets = require("modules.assets")

local CycleTargetingHandler = {}

function CycleTargetingHandler.handle_key_press(key, world)
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
        InputHelpers.set_player_turn_state("action_menu", world)
        world.ui.menus.action.active = true
        cycle.active = false
        cycle.targets = {}
        world.ui.targeting.selectedAttackName= nil
    elseif key == "l" then
        -- Lock Unit Info Menu on the current target, but only if it's a unit (not an obstacle).
        local target = cycle.targets[cycle.selectedIndex]
        if target and not target.isObstacle then
            local menu = world.ui.menus.unitInfo
            menu.isLocked = true
            menu.unit = target
            menu.selectedIndex = 1
            world.ui.previousPlayerTurnState = "cycle_targeting"
            InputHelpers.set_player_turn_state("unit_info_locked", world)
        end
    elseif key == "j" then -- Confirm
        InputHelpers.play_confirm_sound()
        local attacker = world.ui.menus.action.unit
        local attackName = world.ui.targeting.selectedAttackName
        local attackData = attackName and AttackBlueprints[attackName]
        if not attackData then return end

        -- Check if this attack requires a secondary targeting step.
        if attackData.secondary_targeting_style == "adjacent_tiles" then
            local primaryTarget = cycle.targets[cycle.selectedIndex]
            if not primaryTarget then return end -- Failsafe

            -- Find all valid, landable adjacent tiles.
            -- The filter needs the attacker to correctly check landability.
            local filter = function(tileX, tileY, _, wrld)
                return WorldQueries.isTileLandable(tileX, tileY, attacker, wrld)
           
            end
            local adjacentTiles = WorldQueries.getAdjacentTiles(primaryTarget, world, filter)

            if #adjacentTiles > 0 then
                -- Transition to the secondary targeting state.
                local secondary = world.ui.targeting.secondary
                secondary.active = true
                secondary.primaryTarget = primaryTarget
                secondary.tiles = adjacentTiles
                secondary.selectedIndex = 1 
                InputHelpers.set_player_turn_state("secondary_targeting", world)
                
                -- Snap cursor to the first available tile.
                local firstTile = adjacentTiles[1]
                world.ui.mapCursorTile.x = firstTile.tileX
                world.ui.mapCursorTile.y = firstTile.tileY
            end
        else
            -- Standard attack execution
            if AttackHandler.execute(attacker, attackName, world) then
                InputHelpers.finalize_player_action(attacker, world) end
        end
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

return CycleTargetingHandler