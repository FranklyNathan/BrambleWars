-- modules/input_handlers/drop_targeting_handler.lua
-- Handles input when the player is selecting a tile to drop a unit.

local InputHelpers = require("modules.input_helpers")
local Assets = require("modules.assets")
local RescueHandler = require("modules.rescue_handler")

local DropTargetingHandler = {}

function DropTargetingHandler.handle_key_press(key, world)
    local drop = world.ui.targeting.drop
    if not drop.active then return end

    local rescuer = world.ui.menus.action.unit
    if not rescuer then return end

    local directionMap = {
        w = { dx = 0, dy = -1 }, -- Up
        a = { dx = -1, dy = 0 }, -- Left
        s = { dx = 0, dy = 1 },  -- Down
        d = { dx = 1, dy = 0 }   -- Right
    }

    local indexChanged = false
    if directionMap[key] then
        local dir = directionMap[key]
        local targetTileX = rescuer.tileX + dir.dx
        local targetTileY = rescuer.tileY + dir.dy

        -- Find the index of this tile in the drop.tiles list
        for i, tile in ipairs(drop.tiles) do
            if tile.tileX == targetTileX and tile.tileY == targetTileY then
                if drop.selectedIndex ~= i then
                    drop.selectedIndex = i
                    indexChanged = true
                end
                break -- Found it
            end
        end
    elseif key == "k" then -- Cancel
        InputHelpers.play_back_out_sound()
        InputHelpers.set_player_turn_state("action_menu", world)
        world.ui.menus.action.active = true
        drop.active = false
        drop.tiles = {}
    elseif key == "j" then -- Confirm
        InputHelpers.play_confirm_sound()
        local tile = drop.tiles[drop.selectedIndex]

        if RescueHandler.drop(rescuer, tile.tileX, tile.tileY, world) then InputHelpers.finalize_player_action(rescuer, world) end
    end

    if indexChanged then
        if Assets.sounds.cursor_move then Assets.sounds.cursor_move:stop(); Assets.sounds.cursor_move:play() end
        local newTile = drop.tiles[drop.selectedIndex]
        if newTile then
            world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = newTile.tileX, newTile.tileY
        end
    end
end

return DropTargetingHandler