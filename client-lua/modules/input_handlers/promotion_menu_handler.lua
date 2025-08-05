-- modules/input_handlers/promotion_menu_handler.lua
-- Handles input when the player is choosing a class promotion.

local InputHelpers = require("modules.input_helpers")
local PromotionSystem = require("systems.promotion_system")

local PromotionMenuHandler = {}

function PromotionMenuHandler.handle_key_press(key, world)
    local menu = world.ui.menus.promotion
    if not menu.active then return end

    if key == "w" or key == "s" then
        InputHelpers.navigate_vertical_menu(key, menu, nil, world)
    elseif key == "j" then -- Confirm
        InputHelpers.play_menu_select_sound()
        local selectedOption = menu.options[menu.selectedIndex]
        PromotionSystem.apply(menu.unit, selectedOption, world)
        menu.active = false -- Close the menu
    end
end

return PromotionMenuHandler