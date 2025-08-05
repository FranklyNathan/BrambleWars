-- modules/input_handlers/ground_aiming_handler.lua
-- Handles input when the player is aiming an attack at a ground tile.

local InputHelpers = require("modules.input_helpers")
local AttackHandler = require("modules.attack_handler")
local AttackBlueprints = require("data.attack_blueprints")
local AttackPatterns = require("modules.attack_patterns")

local GroundAimingHandler = {}

-- This function is exported to be called by the main continuous input handler.
-- It takes dx and dy directly for efficiency.
function GroundAimingHandler.handle_continuous_input(dx, dy, world)
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

function GroundAimingHandler.handle_key_press(key, world)
    local unit = world.ui.menus.action.unit -- The unit who is attacking
    if not unit then return end
    
    -- WASD movement is now handled by the continuous input handler.
    -- This function only needs to process confirm/cancel actions.
    if key == "j" then -- Confirm Attack
        InputHelpers.play_confirm_sound()
        local attackName = world.ui.targeting.selectedAttackName

        -- The attack implementation itself will validate the target tile.
        -- AttackHandler.execute returns true if the attack was successful.
        if AttackHandler.execute(unit, attackName, world) then InputHelpers.finalize_player_action(unit, world) end
    elseif key == "k" then -- Cancel Attack
        InputHelpers.play_back_out_sound()
        InputHelpers.set_player_turn_state("action_menu", world)
        world.ui.menus.action.active = true
        world.ui.targeting.selectedAttackName= nil
        world.ui.targeting.attackAoETiles = nil
        world.ui.pathing.groundAimingGrid= nil -- Clear the grid
    end
end

return GroundAimingHandler