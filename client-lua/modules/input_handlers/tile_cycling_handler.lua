-- modules/input_handlers/tile_cycling_handler.lua
-- Handles input when the player is cycling through specific ground tiles (e.g., for Homecoming).

local Assets = require("modules.assets")
local InputHelpers = require("modules.input_helpers")
local AttackHandler = require("modules.attack_handler")
local EventBus = require("modules.event_bus")

local TileCyclingHandler = {}

function TileCyclingHandler.handle_key_press(key, world)
    local tileCycle = world.ui.targeting.tile_cycle
    if not tileCycle.active then return end

    local indexChanged = false
    if key == "a" or key == "d" then -- Cycle tiles
        if key == "a" then
            tileCycle.selectedIndex = tileCycle.selectedIndex - 1
            if tileCycle.selectedIndex < 1 then tileCycle.selectedIndex = #tileCycle.tiles end
        else -- key == "d"
            tileCycle.selectedIndex = tileCycle.selectedIndex + 1
            if tileCycle.selectedIndex > #tileCycle.tiles then tileCycle.selectedIndex = 1 end
        end
        indexChanged = true
    elseif key == "k" then -- Cancel
        if Assets.sounds.back_out then Assets.sounds.back_out:stop(); Assets.sounds.back_out:play() end
        InputHelpers.set_player_turn_state("action_menu", world)
        world.ui.menus.action.active = true
        tileCycle.active = false
        tileCycle.tiles = {}
        world.ui.targeting.selectedAttackName = nil
    elseif key == "j" then -- Confirm
        InputHelpers.play_confirm_sound()
        local attacker = world.ui.menus.action.unit
        local attackName = world.ui.targeting.selectedAttackName
        if AttackHandler.execute(attacker, attackName, world) then InputHelpers.finalize_player_action(attacker, world) end
    end

    if indexChanged then
        if Assets.sounds.cursor_move then Assets.sounds.cursor_move:stop(); Assets.sounds.cursor_move:play() end
        local newTile = tileCycle.tiles[tileCycle.selectedIndex]
        if newTile then
            world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = newTile.tileX, newTile.tileY
            EventBus:dispatch("cursor_moved", { tileX = newTile.tileX, tileY = newTile.tileY, world = world })
        end
    end
end

return TileCyclingHandler