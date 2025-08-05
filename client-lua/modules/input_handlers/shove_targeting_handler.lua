-- modules/input_handlers/shove_targeting_handler.lua
-- Handles input when the player is cycling through units to shove.

local InputHelpers = require("modules.input_helpers")
local ShoveHandler = require("modules.shove_handler")
local Assets = require("modules.assets")

local ShoveTargetingHandler = {}

function ShoveTargetingHandler.handle_key_press(key, world)
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
        InputHelpers.play_back_out_sound()
        InputHelpers.set_player_turn_state("action_menu", world)
        world.ui.menus.action.active = true
        shove.active = false
        shove.targets = {}
    elseif key == "j" then -- Confirm
        InputHelpers.play_confirm_sound()
        local shover = world.ui.menus.action.unit
        local target = shove.targets[shove.selectedIndex]

        -- Make the shover face the target before shoving for the lunge animation.
        local dx, dy = target.tileX - shover.tileX, target.tileY - shover.tileY
        if math.abs(dx) > math.abs(dy) then shover.lastDirection = (dx > 0) and "right" or "left"
        else shover.lastDirection = (dy > 0) and "down" or "up" end

        if ShoveHandler.shove(shover, target, world) then InputHelpers.finalize_player_action(shover, world) end
    end

    if indexChanged then
        if Assets.sounds.cursor_move then Assets.sounds.cursor_move:stop(); Assets.sounds.cursor_move:play() end
        local newTarget = shove.targets[shove.selectedIndex]
        if newTarget then
            world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = newTarget.tileX, newTarget.tileY
        end
    end
end

return ShoveTargetingHandler