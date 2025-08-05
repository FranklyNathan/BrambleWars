-- modules/map_menu_handler.lua
-- modules/input_handlers/map_menu_handler.lua
-- Handles input when the map menu is open.

local InputHelpers = require("modules.input_helpers")

local MapMenuHandler = {}

function MapMenuHandler.handle_key_press(key, world)
    local menu = world.ui.menus.map
    if not menu.active then return end

    -- Navigation (for future expansion)
    if key == "w" or key == "s" then
        InputHelpers.navigate_vertical_menu(key, menu, nil, world)
    elseif key == "k" then -- Cancel
        menu.active = false
        InputHelpers.set_player_turn_state("free_roam", world)
    elseif key == "j" then -- Confirm
        InputHelpers.play_confirm_sound()
        local selectedOption = menu.options[menu.selectedIndex]
        if selectedOption and selectedOption.key == "end_turn" then
            menu.active = false
            InputHelpers.set_player_turn_state("free_roam", world)
            world.ui.turnShouldEnd = true
        end
    end
end

return MapMenuHandler