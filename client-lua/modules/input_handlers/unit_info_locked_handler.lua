-- modules/input_handlers/unit_info_locked_handler.lua
-- Handles input when the unit info menu is locked.

local InputHelpers = require("modules.input_helpers")
local WorldQueries = require("modules.world_queries")
local EventBus = require("modules.event_bus")
local Assets = require("modules.assets")
local ClassBlueprints = require("data.class_blueprints")
local WeaponBlueprints = require("data.weapon_blueprints")

local UnitInfoLockedHandler = {}

-- Builds a dynamic map of the selectable items in the unit info menu.
-- This decouples the navigation logic from the rendering layout.
-- Returns a list of items, where each item is { index, key, [sibling] }.
local function build_menu_map(menu, world)
    local map = {}
    local currentIndex = 0

    local unit = menu.unit
    if not unit then return map end

    -- Helper to add an item to the map. Sibling indices are resolved in a second pass.
    local function addItem(key, siblingKey)
        currentIndex = currentIndex + 1
        local item = { index = currentIndex, key = key }
        if siblingKey then item.siblingKey = siblingKey end
        table.insert(map, item)
    end

    -- 1. Name (for toggling details)
    addItem("name")

    -- 2. Class
    addItem("class")

    -- 3. Weapons
    local passiveList = WorldQueries.getUnitPassiveList(unit)
    local hasDualWielder = false
    for _, p in ipairs(passiveList) do
        if p == "DualWielder" then hasDualWielder = true; break; end
    end
    local numWeaponSlots = hasDualWielder and 2 or 1
    for i = 1, numWeaponSlots do
        addItem("weapon" .. i)
    end

    -- 4. HP/Wisp (paired as siblings)
    addItem("maxHp", "maxWisp") -- The keys must match those used in unit_info_menu.lua
    addItem("maxWisp", "maxHp")

    -- 5. Passives
    local passives = WorldQueries.getUnitPassiveList(unit)
    for i = 1, #passives do
        addItem("passive" .. i)
    end

    -- 6. Moves
    local moves = WorldQueries.getUnitMoveList(unit)
    for i = 1, #moves do
        addItem("move" .. i)
    end

    -- 7. Carried Unit (if applicable)
    if unit.carriedUnit then
        addItem("carried")
    end

    -- Second pass to resolve sibling indices by their keys.
    local keyToIndex = {}
    for _, item in ipairs(map) do
        keyToIndex[item.key] = item.index
    end

    for _, item in ipairs(map) do
        if item.siblingKey then
            item.sibling = keyToIndex[item.siblingKey]
        end
    end

    return map
end

-- New data-driven navigation logic.
local function move_unit_info_selection(key, world)
    local menu = world.ui.menus.unitInfo
    if not menu.isLocked or not menu.unit then return end

    -- This constant should match the one in unit_info_menu.lua
    local MAX_VISIBLE_MOVES = 5

    local map = build_menu_map(menu, world)
    if #map == 0 then return end

    -- Find the current item in our generated map based on the menu's selectedIndex
    local currentMapIndex = -1
    for i, item in ipairs(map) do
        if item.index == menu.selectedIndex then
            currentMapIndex = i
            break
        end
    end

    if currentMapIndex == -1 then return end -- Failsafe

    local oldIndex = menu.selectedIndex
    local newMapIndex = currentMapIndex
    local currentItem = map[currentMapIndex]

    if key == "w" then
        newMapIndex = newMapIndex - 1
        if newMapIndex < 1 then newMapIndex = #map end
    elseif key == "s" then
        newMapIndex = newMapIndex + 1
        if newMapIndex > #map then newMapIndex = 1 end
    elseif (key == "a" or key == "d") and currentItem.sibling then
        -- Jump to sibling if one exists (for HP/Wisp, etc.)
        for i, item in ipairs(map) do
            if item.index == currentItem.sibling then
                newMapIndex = i
                break
            end
        end
    end

    -- If the selection changed, update the index and handle scrolling
    if newMapIndex ~= currentMapIndex then
        local newItem = map[newMapIndex]
        menu.selectedIndex = newItem.index

        if Assets.sounds.menu_scroll then Assets.sounds.menu_scroll:stop(); Assets.sounds.menu_scroll:play() end
        EventBus:dispatch("unit_info_menu_selection_changed", { world = world })

        -- Scrolling logic for the moves list
        local moves = WorldQueries.getUnitMoveList(menu.unit)
        local numMoves = #moves
        if numMoves > MAX_VISIBLE_MOVES then
            -- Check if the new selection is a move
            if string.sub(newItem.key, 1, 4) == "move" then
                -- The relative index of the move in the full move list (1-based)
                local relativeMoveIndex = tonumber(string.sub(newItem.key, 5))

                -- The range of currently visible moves
                local firstVisibleRelative = menu.moveListScrollOffset + 1
                local lastVisibleRelative = menu.moveListScrollOffset + MAX_VISIBLE_MOVES

                -- Scroll down if the new selection is below the visible area
                if relativeMoveIndex > lastVisibleRelative then
                    menu.moveListScrollOffset = relativeMoveIndex - MAX_VISIBLE_MOVES
                -- Scroll up if the new selection is above the visible area
                elseif relativeMoveIndex < firstVisibleRelative then
                    menu.moveListScrollOffset = relativeMoveIndex - 1
                end
            else
                -- If we moved out of the moves list, reset the scroll
                local oldItem = map[currentMapIndex]
                if string.sub(oldItem.key, 1, 4) == "move" then
                    menu.moveListScrollOffset = 0
                end
            end
        end
    end
end

function UnitInfoLockedHandler.handle_key_press(key, world)
    local menu = world.ui.menus.unitInfo
    if not menu.isLocked or not menu.unit then
        return
    end

    if key == "k" then -- Unlock menu
        InputHelpers.play_back_out_sound()
        menu.isLocked = false
        menu.selectedIndex = 1
        menu.moveListScrollOffset = 0 -- Reset scroll on unlock
        -- Return to the previous state.
        local returnState = world.ui.previousPlayerTurnState or "free_roam"
        InputHelpers.set_player_turn_state(returnState, world)
        world.ui.previousPlayerTurnState = nil -- Clean up the stored state.
    elseif key == "w" or key == "s" or key == "a" or key == "d" then
        move_unit_info_selection(key, world)
    elseif key == "j" then
        local map = build_menu_map(menu, world)
        if #map == 0 then return end

        -- Find the selected item from our map
        local selectedItem = nil
        for _, item in ipairs(map) do
            if item.index == menu.selectedIndex then
                selectedItem = item
                break
            end
        end

        if not selectedItem then return end -- Failsafe

        -- Handle actions based on the item's key
        if selectedItem.key == "name" then
            InputHelpers.play_menu_select_sound()
            local anim = world.ui.menus.unitInfo.detailsAnimation
            -- Toggle the animation's active state and reset its timer.
            anim.active = not anim.active
            anim.timer = 0
        elseif string.sub(selectedItem.key, 1, 6) == "weapon" then
            InputHelpers.play_menu_select_sound()
            local slotIndex = tonumber(string.sub(selectedItem.key, 7)) -- "weapon1" -> 1
            if not slotIndex then return end

            local weaponMenu = world.ui.menus.weaponSelect
            weaponMenu.unit = menu.unit
            weaponMenu.slot = slotIndex
            weaponMenu.options = {}
            weaponMenu.selectedIndex = 1

            local allowedWeaponTypes = {}
            if menu.unit.class and ClassBlueprints[menu.unit.class] then
                allowedWeaponTypes = ClassBlueprints[menu.unit.class].weaponTypes
            end

            local function table_contains(tbl, val)
                for _, value in ipairs(tbl) do if value == val then return true end end
                return false
            end

            for weaponKey, quantity in pairs(world.playerInventory.weapons) do
                if quantity > 0 then
                    local weaponData = WeaponBlueprints[weaponKey]
                    if weaponData and table_contains(allowedWeaponTypes, weaponData.type) then table.insert(weaponMenu.options, weaponKey) end
                end
            end

            if weaponMenu.unit.equippedWeapons[slotIndex] then
                table.insert(weaponMenu.options, "unequip")
            end

            if #weaponMenu.options > 0 then
                weaponMenu.active = true
                local currentWeapon = weaponMenu.unit.equippedWeapons[slotIndex]
                for i, optionKey in ipairs(weaponMenu.options) do
                    if optionKey == currentWeapon then
                        weaponMenu.selectedIndex = i
                        break
                    end
                end
                InputHelpers.set_player_turn_state("weapon_select", world)
            else
                -- TODO: Play a "cannot select" sound effect
            end
        end
    end
end

-- This handler also needs to process continuous input for smooth menu scrolling.
function UnitInfoLockedHandler.handle_continuous_input(key, world)
    move_unit_info_selection(key, world)
end

return UnitInfoLockedHandler