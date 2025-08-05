-- modules/input_handlers/shop_menu_handler.lua
-- Handles input when the shop menu is open.

local InputHelpers = require("modules.input_helpers")
local WorldQueries = require("modules.world_queries")
local WeaponBlueprints = require("data.weapon_blueprints")
local Assets = require("modules.assets")

local ShopMenuHandler = {}

-- Helper function to populate the buy options list for the shop.
function ShopMenuHandler.repopulate_buy_options(world)
    local menu = world.ui.menus.shop
    local shopkeep = world.shopkeep
    menu.buyOptions = {}

    if shopkeep and shopkeep.shopInventory then
        for weaponKey, quantity in pairs(shopkeep.shopInventory) do
            if quantity > 0 then
                table.insert(menu.buyOptions, weaponKey)
            end
        end
        -- Sort the options alphabetically by display name for consistency.
        table.sort(menu.buyOptions, function(a, b)
            local nameA = (WeaponBlueprints[a] and WeaponBlueprints[a].name) or a
            local nameB = (WeaponBlueprints[b] and WeaponBlueprints[b].name) or b
            return nameA < nameB
        end)
        -- If the player is currently in the buy view, update the live options list.
        if menu.view == "buy" then
            menu.options = menu.buyOptions
        end
    end
end

-- Helper function to populate the sell options list for the shop.
function ShopMenuHandler.repopulate_sell_options(world)
    local shopMenu = world.ui.menus.shop
    shopMenu.sellOptions = {}
    local allEquipped = {}
    -- Count all weapons currently equipped by the player's party.
    for _, p in ipairs(world.players) do
        if p.equippedWeapons then
            for _, wKey in pairs(p.equippedWeapons) do
                allEquipped[wKey] = (allEquipped[wKey] or 0) + 1
            end
        end
    end

    -- Compare inventory against equipped counts to find sellable items.
    for weaponKey, totalQuantity in pairs(world.playerInventory.weapons) do
        local equippedCount = allEquipped[weaponKey] or 0
        if totalQuantity > equippedCount then
            table.insert(shopMenu.sellOptions, weaponKey)
        end
    end
    -- Sort the options alphabetically by display name for consistency.
    table.sort(shopMenu.sellOptions, function(a, b)
        local nameA = (WeaponBlueprints[a] and WeaponBlueprints[a].name) or a
        local nameB = (WeaponBlueprints[b] and WeaponBlueprints[b].name) or b
        return nameA < nameB
    end)
    -- If the player is currently in the sell view, update the live options list.
    if shopMenu.view == "sell" then
        shopMenu.options = shopMenu.sellOptions
    end
end

function ShopMenuHandler.handle_key_press(key, world)
    local menu = world.ui.menus.shop
    if not menu.active then return end

    if menu.view == "main" then
        if key == "w" or key == "s" then
            InputHelpers.navigate_vertical_menu(key, menu, nil, world)
        elseif key == "j" then
            InputHelpers.play_menu_select_sound()
            if menu.selectedIndex == 1 then -- Buy
                menu.view = "buy"; menu.selectedIndex = 1; menu.options = menu.buyOptions
            elseif menu.selectedIndex == 2 then -- Sell
                menu.view = "sell"; menu.selectedIndex = 1; menu.options = menu.sellOptions
            elseif menu.selectedIndex == 3 then -- Exit
                if Assets.sounds.back_out then Assets.sounds.back_out:stop(); Assets.sounds.back_out:play() end
                menu.active = false; InputHelpers.set_player_turn_state("action_menu", world); world.ui.menus.action.active = true
            end
        elseif key == "k" then
            if Assets.sounds.back_out then Assets.sounds.back_out:stop(); Assets.sounds.back_out:play() end
            menu.active = false; InputHelpers.set_player_turn_state("action_menu", world); world.ui.menus.action.active = true
        end
    elseif menu.view == "buy" then
        if #menu.buyOptions > 0 then
            if key == "w" or key == "s" then
                InputHelpers.navigate_vertical_menu(key, menu, nil, world)
            elseif key == "j" then
                local weaponKey = menu.buyOptions[menu.selectedIndex]
                local weapon = WeaponBlueprints[weaponKey]
                local shoppingUnit = world.ui.menus.action.unit
                local price = WorldQueries.getPurchasePrice(shoppingUnit, weaponKey, world)
                if world.playerInventory.nutmegs >= price then
                    InputHelpers.play_menu_select_sound()
                    menu.view = "confirm_buy"; menu.itemToConfirm = weaponKey
                    menu.confirmMessage = "Buy " .. weapon.name .. " for " .. price .. " Nutmegs?"
                    menu.selectedIndex = 1 -- Default to "Yes"
                else
                    if Assets.sounds.back_out then Assets.sounds.back_out:stop(); Assets.sounds.back_out:play() end
                    menu.view = "insufficient_funds"; menu.insufficientFundsMessage = "Not enough Nutmegs!"
                end
            end
        end
        if key == "k" then
            if Assets.sounds.back_out then Assets.sounds.back_out:stop(); Assets.sounds.back_out:play() end
            menu.view = "main"; menu.selectedIndex = 1; menu.options = {"Buy", "Sell", "Exit"}
        end
    elseif menu.view == "sell" then
        if #menu.sellOptions > 0 then
            if key == "w" or key == "s" then
                InputHelpers.navigate_vertical_menu(key, menu, nil, world)
            elseif key == "j" then
                local weaponKey = menu.sellOptions[menu.selectedIndex]
                local weapon = WeaponBlueprints[weaponKey]
                local sellPrice = math.floor(weapon.value / 2)
                InputHelpers.play_menu_select_sound()
                menu.view = "confirm_sell"; menu.itemToConfirm = weaponKey
                menu.confirmMessage = "Sell " .. weapon.name .. " for " .. sellPrice .. " Nutmegs?"
                menu.selectedIndex = 1 -- Default to "Yes"
            end
        end
        if key == "k" then
            if Assets.sounds.back_out then Assets.sounds.back_out:stop(); Assets.sounds.back_out:play() end
            menu.view = "main"; menu.selectedIndex = 2; menu.options = {"Buy", "Sell", "Exit"}
        end
    elseif menu.view == "confirm_buy" then
        if key == "a" or key == "d" then
            menu.selectedIndex = (menu.selectedIndex == 1) and 2 or 1
            if Assets.sounds.cursor_move then Assets.sounds.cursor_move:stop(); Assets.sounds.cursor_move:play() end
        elseif key == "j" then
            if menu.selectedIndex == 1 then -- Yes
                local weaponKey = menu.itemToConfirm
                local shoppingUnit = world.ui.menus.action.unit
                local price = WorldQueries.getPurchasePrice(shoppingUnit, weaponKey, world)
                InputHelpers.play_menu_select_sound()

                -- 1. Update player inventory and nutmegs.
                world.playerInventory.nutmegs = world.playerInventory.nutmegs - price
                world.playerInventory.weapons[weaponKey] = (world.playerInventory.weapons[weaponKey] or 0) + 1

                -- 2. Update shopkeeper's inventory.
                if world.shopkeep and world.shopkeep.shopInventory then
                    world.shopkeep.shopInventory[weaponKey] = (world.shopkeep.shopInventory[weaponKey] or 0) - 1
                end

                -- 3. Commit the move and refresh UI lists.
                local unit = world.ui.menus.action.unit
                if unit then unit.components.move_is_committed = true end
                ShopMenuHandler.repopulate_buy_options(world) -- Repopulate buy list after buying
                ShopMenuHandler.repopulate_sell_options(world) -- Repopulate sell list after buying
                menu.view = "buy"; menu.selectedIndex = 1; menu.options = menu.buyOptions
            else -- No
                if Assets.sounds.back_out then Assets.sounds.back_out:stop(); Assets.sounds.back_out:play() end
                menu.view = "buy"; menu.selectedIndex = 1; menu.options = menu.buyOptions
            end
        elseif key == "k" then
            if Assets.sounds.back_out then Assets.sounds.back_out:stop(); Assets.sounds.back_out:play() end
            menu.view = "buy"; menu.selectedIndex = 1; menu.options = menu.buyOptions
        end
    elseif menu.view == "confirm_sell" then
        if key == "a" or key == "d" then
            menu.selectedIndex = (menu.selectedIndex == 1) and 2 or 1
            if Assets.sounds.cursor_move then Assets.sounds.cursor_move:stop(); Assets.sounds.cursor_move:play() end
        elseif key == "j" then
            if menu.selectedIndex == 1 then -- Yes
                InputHelpers.play_menu_select_sound()
                local weaponKey = menu.itemToConfirm
                local weapon = WeaponBlueprints[weaponKey]
                -- 1. Update player inventory and nutmegs.
                local sellPrice = math.floor(weapon.value / 2)
                world.playerInventory.nutmegs = world.playerInventory.nutmegs + sellPrice
                world.playerInventory.weapons[weaponKey] = world.playerInventory.weapons[weaponKey] - 1
                if world.playerInventory.weapons[weaponKey] <= 0 then world.playerInventory.weapons[weaponKey] = nil end

                -- 2. Update shopkeeper's inventory.
                if world.shopkeep and world.shopkeep.shopInventory then
                    world.shopkeep.shopInventory[weaponKey] = (world.shopkeep.shopInventory[weaponKey] or 0) + 1
                end

                -- 3. Commit the move and refresh UI lists.
                local unit = world.ui.menus.action.unit
                if unit then unit.components.move_is_committed = true end
                ShopMenuHandler.repopulate_buy_options(world) -- Repopulate buy list after selling
                ShopMenuHandler.repopulate_sell_options(world)
                menu.view = "sell"; menu.options = menu.sellOptions
                menu.selectedIndex = math.min(menu.selectedIndex, #menu.sellOptions)
                if #menu.sellOptions == 0 then menu.selectedIndex = 1 end
            else -- No
                if Assets.sounds.back_out then Assets.sounds.back_out:stop(); Assets.sounds.back_out:play() end
                menu.view = "sell"; menu.selectedIndex = 1; menu.options = menu.sellOptions
            end
        elseif key == "k" then
            if Assets.sounds.back_out then Assets.sounds.back_out:stop(); Assets.sounds.back_out:play() end
            menu.view = "sell"; menu.selectedIndex = 1; menu.options = menu.sellOptions
        end
    elseif menu.view == "insufficient_funds" then
        if key == "j" or key == "k" then
            InputHelpers.play_menu_select_sound()
            menu.view = "buy"; menu.selectedIndex = 1; menu.options = menu.buyOptions
        end
    end
end

return ShopMenuHandler