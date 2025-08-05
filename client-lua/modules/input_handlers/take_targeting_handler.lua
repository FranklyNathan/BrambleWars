-- modules/input_handlers/take_targeting_handler.lua
-- Handles input when the player is cycling through units to take from.

local InputHelpers = require("modules.input_helpers")
local TakeHandler = require("modules.take_handler")
local Assets = require("modules.assets")

local TakeTargetingHandler = {}

function TakeTargetingHandler.handle_key_press(key, world)
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
        InputHelpers.play_back_out_sound()
        InputHelpers.set_player_turn_state("action_menu", world)
        world.ui.menus.action.active = true
        take.active = false
        take.targets = {}
    elseif key == "j" then -- Confirm
        InputHelpers.play_confirm_sound()
        local taker = world.ui.menus.action.unit
        local carrier = take.targets[take.selectedIndex]

        if TakeHandler.take(taker, carrier, world) then InputHelpers.finalize_player_action(taker, world) end
    end

    if indexChanged then
        if Assets.sounds.cursor_move then Assets.sounds.cursor_move:stop(); Assets.sounds.cursor_move:play() end
        local newTarget = take.targets[take.selectedIndex]
        if newTarget then
            world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = newTarget.tileX, newTarget.tileY
        end
    end
end

return TakeTargetingHandler