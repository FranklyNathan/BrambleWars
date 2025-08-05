-- modules/input_handlers/secondary_targeting_handler.lua
-- Handles input when the player is choosing a secondary target tile (e.g., for Bodyguard).

local Assets = require("modules.assets")
local InputHelpers = require("modules.input_helpers")
local AttackHandler = require("modules.attack_handler")
local EventBus = require("modules.event_bus")

local SecondaryTargetingHandler = {}

function SecondaryTargetingHandler.handle_key_press(key, world)
    local secondary = world.ui.targeting.secondary
    if not secondary.active then return end

    local indexChanged = false
    if key == "a" or key == "d" then -- Cycle tiles
        if key == "a" then
            secondary.selectedIndex = secondary.selectedIndex - 1
            if secondary.selectedIndex < 1 then secondary.selectedIndex = #secondary.tiles end
        else -- key == "d"
            secondary.selectedIndex = secondary.selectedIndex + 1
            if secondary.selectedIndex > #secondary.tiles then secondary.selectedIndex = 1 end
        end
        indexChanged = true
    elseif key == "k" then -- Cancel secondary targeting
        if Assets.sounds.back_out then Assets.sounds.back_out:stop(); Assets.sounds.back_out:play() end
        -- Return to the primary cycle targeting state
        InputHelpers.set_player_turn_state("cycle_targeting", world)
        secondary.active = false
        secondary.tiles = {}
        secondary.primaryTarget = nil
    elseif key == "j" then -- Confirm final target tile
        InputHelpers.play_confirm_sound()
        local attacker = world.ui.menus.action.unit
        local attackName = world.ui.targeting.selectedAttackName
        
        -- The attack implementation will now read the selected tile from world.ui.targeting.secondary
        if AttackHandler.execute(attacker, attackName, world) then InputHelpers.finalize_player_action(attacker, world) end
    end

    if indexChanged then
        if Assets.sounds.cursor_move then Assets.sounds.cursor_move:stop(); Assets.sounds.cursor_move:play() end
        local newTile = secondary.tiles[secondary.selectedIndex]
        if newTile then
            world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = newTile.tileX, newTile.tileY
            EventBus:dispatch("cursor_moved", { tileX = newTile.tileX, tileY = newTile.tileY, world = world })
        end
    end
end

return SecondaryTargetingHandler