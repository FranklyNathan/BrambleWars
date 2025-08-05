-- modules/input_handlers/weapon_select_handler.lua
-- Handles input when the weapon selection menu is open.

local InputHelpers = require("modules.input_helpers")
local EventBus = require("modules.event_bus")

local WeaponSelectHandler = {}

function WeaponSelectHandler.handle_key_press(key, world)
    local menu = world.ui.menus.weaponSelect
    if not menu.active then return end

    if key == "w" or key == "s" then
        InputHelpers.navigate_vertical_menu(key, menu, nil, world)
    elseif key == "k" then -- Cancel
        InputHelpers.play_back_out_sound()
        menu.unit = nil
        menu.slot = nil
        menu.active = false
        InputHelpers.set_player_turn_state("unit_info_locked", world)
    elseif key == "j" then -- Confirm selection
        InputHelpers.play_menu_select_sound()
        local selectedOption = menu.options[menu.selectedIndex]
        local unit = menu.unit
        local slot = menu.slot

        if selectedOption == "unequip" then
            if unit.equippedWeapons[slot] then
                local weaponKey = unit.equippedWeapons[slot]
                world.playerInventory.weapons[weaponKey] = (world.playerInventory.weapons[weaponKey] or 0) + 1
                unit.equippedWeapons[slot] = nil
                EventBus:dispatch("weapon_equipped", { unit = unit, world = world })
            end
            menu.active = false
            menu.unit = nil
            menu.slot = nil 
            InputHelpers.set_player_turn_state("unit_info_locked", world)
        elseif selectedOption ~= "unequip" then
            local oldWeaponKey = unit.equippedWeapons[slot]
            local newWeaponKey = selectedOption

            if oldWeaponKey then
                world.playerInventory.weapons[oldWeaponKey] = (world.playerInventory.weapons[oldWeaponKey] or 0) + 1
            end

            world.playerInventory.weapons[newWeaponKey] = world.playerInventory.weapons[newWeaponKey] - 1
            unit.equippedWeapons[slot] = newWeaponKey
            EventBus:dispatch("weapon_equipped", { unit = unit, world = world })
            menu.unit = nil
            menu.slot = nil
            menu.active = false
            InputHelpers.set_player_turn_state("unit_info_locked", world)
        end
    end
end

return WeaponSelectHandler