-- modules/input_handlers/rescue_targeting_handler.lua
-- Handles input when the player is cycling through units to rescue.

local InputHelpers = require("modules.input_helpers")
local RescueHandler = require("modules.rescue_handler")
local Assets = require("modules.assets")

local RescueTargetingHandler = {}

function RescueTargetingHandler.handle_key_press(key, world)
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
        InputHelpers.play_back_out_sound()
        InputHelpers.set_player_turn_state("action_menu", world)
        world.ui.menus.action.active = true
        rescue.active = false
        rescue.targets = {}
    elseif key == "j" then -- Confirm
        InputHelpers.play_confirm_sound()
        local rescuer = world.ui.menus.action.unit
        local target = rescue.targets[rescue.selectedIndex]

        if RescueHandler.rescue(rescuer, target, world) then InputHelpers.finalize_player_action(rescuer, world) end
    end

    if indexChanged then
        if Assets.sounds.cursor_move then Assets.sounds.cursor_move:stop(); Assets.sounds.cursor_move:play() end
        local newTarget = rescue.targets[rescue.selectedIndex]
        if newTarget then
            world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = newTarget.tileX, newTarget.tileY
        end
    end
end

return RescueTargetingHandler