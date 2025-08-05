-- modules/input_handlers/enemy_range_display_handler.lua
-- Handles input when an enemy's range is being displayed.

local InputHelpers = require("modules.input_helpers")

local EnemyRangeDisplayHandler = {}

function EnemyRangeDisplayHandler.handle_key_press(key, world)
    -- Pressing J or K will cancel the display and return to free roam.
    if key == "j" or key == "k" then
        InputHelpers.set_player_turn_state("free_roam", world)
        local display = world.ui.menus.enemyRangeDisplay
        display.active = false
        display.unit = nil
        display.reachableTiles = nil
        display.attackableTiles = nil
    end
    -- Cursor movement is handled by the main gameplay handler.
    -- No other input is processed in this state.
end

return EnemyRangeDisplayHandler