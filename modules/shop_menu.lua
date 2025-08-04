-- modules/shop_menu.lua
-- Contains the drawing logic for the shop menu UI.

local Assets = require("modules.assets")
local WorldQueries = require("modules.world_queries")
local WeaponBlueprints = require("data.weapon_blueprints")
local Config = require("config")

local ShopMenu = {}

-- Helper to draw a standard menu slice.
local function drawSlice(x, y, width, height, text, middleText, value, icon, isSelected, font, isEnabled)
    isEnabled = isEnabled == nil and true or isEnabled -- Default to true

    -- Set background color
    if isSelected then
        love.graphics.setColor(0.95, 0.95, 0.7, 0.9) -- Cream/yellow for selected
    else
        love.graphics.setColor(0.2, 0.2, 0.1, 0.9) -- Dark brown/grey
    end
    love.graphics.rectangle("fill", x, y, width, height)

    -- Set text color
    if not isEnabled then
        love.graphics.setColor(0.5, 0.5, 0.5, 1) -- Greyed out
    elseif isSelected then
        love.graphics.setColor(0, 0, 0, 1) -- Black
    else
        love.graphics.setColor(1, 1, 1, 1) -- White
    end

    local textY = y + (height - font:getHeight()) / 2
    local textX = x + 10

    -- Draw icon
    if icon then
        local iconY = y + (height - icon:getHeight()) / 2
        love.graphics.draw(icon, textX, iconY)
        textX = textX + icon:getWidth() + 4
    end

    -- Draw text
    love.graphics.print(text, textX, textY)

    -- Draw middle text (centered)
    if middleText then
        -- Position text at 65% of the slice width to avoid overlapping with the name.
        love.graphics.print(middleText, x + width * 0.65, textY)
    end

    -- Draw value (right-aligned)
    if value then
        local valueString = tostring(value)
        local valueWidth = font:getWidth(valueString)
        love.graphics.print(valueString, x + width - valueWidth - 10, textY)
    end
end

-- Draws the main shop interface.
function ShopMenu.draw(world)
    local menu = world.ui.menus.shop
    if not menu.active then return end

    local font = love.graphics.getFont()

    -- Dim the background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT)

    -- Main window layout
    local windowWidth = 500
    local windowHeight = 300
    local windowX = (Config.VIRTUAL_WIDTH - windowWidth) / 2
    local windowY = (Config.VIRTUAL_HEIGHT - windowHeight) / 2

    -- Draw main window background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.95)
    love.graphics.rectangle("fill", windowX, windowY, windowWidth, windowHeight)
    love.graphics.setColor(0.8, 0.8, 0.9, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", windowX, windowY, windowWidth, windowHeight)
    love.graphics.setLineWidth(1)

    -- Draw Shopkeep portrait
    local portrait = Assets.images.Default_Portrait -- Fallback
    if world.shopkeep and world.shopkeep.portrait and Assets.images[world.shopkeep.portrait] then
        portrait = Assets.images[world.shopkeep.portrait]
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(portrait, windowX + 10, windowY + 10)

    -- Draw Nutmegs count
    local nutmegsText = "Nutmegs: " .. world.playerInventory.nutmegs
    love.graphics.printf(nutmegsText, windowX, windowY + windowHeight - 30, windowWidth - 20, "right")

    -- Define the area for the main content (options list)
    local contentX = windowX + 180
    local contentY = windowY + 10
    local contentWidth = windowWidth - 190

    -- View-specific drawing
    if menu.view == "main" then
        local options = {"Buy", "Sell", "Exit"}
        for i, text in ipairs(options) do
            drawSlice(contentX, contentY + (i - 1) * 30, contentWidth, 25, text, nil, nil, nil, i == menu.selectedIndex, font)
        end
    elseif menu.view == "buy" or menu.view == "sell" then
        local options = (menu.view == "buy") and menu.buyOptions or menu.sellOptions
        local title = (menu.view == "buy") and "Buy" or "Sell"
        love.graphics.printf(title, contentX, contentY, contentWidth, "center")

        for i, weaponKey in ipairs(options) do
            local weapon = WeaponBlueprints[weaponKey]
            if weapon then
                local price
                if menu.view == "buy" then
                    local shoppingUnit = world.ui.menus.action.unit
                    price = WorldQueries.getPurchasePrice(shoppingUnit, weaponKey, world)
                else -- "sell"
                    price = math.floor(weapon.value / 2)
                end
                local priceText = price .. " N"
                local icon = Assets.getWeaponIcon(weapon.type)
                local itemCount = 0
                if menu.view == "buy" then
                    -- For "Buy" view, show the shopkeeper's stock.
                    itemCount = (world.shopkeep and world.shopkeep.shopInventory[weaponKey]) or 0
                elseif menu.view == "sell" then
                    -- For "Sell" view, show the player's inventory count.
                    itemCount = world.playerInventory.weapons[weaponKey] or 0
                end
                local countText = "(x" .. itemCount .. ")"
                local canAfford = (menu.view == "buy") and (world.playerInventory.nutmegs >= price) or true
                drawSlice(contentX, contentY + 30 + (i - 1) * 25, contentWidth, 22, weapon.name, countText, priceText, icon, i == menu.selectedIndex, font, canAfford)
            end
        end
    elseif menu.view == "confirm_buy" or menu.view == "confirm_sell" then
        -- Draw a confirmation box over the content area
        local confirmWidth = 250
        local confirmHeight = 100
        local confirmX = windowX + (windowWidth - confirmWidth) / 2
        local confirmY = windowY + (windowHeight - confirmHeight) / 2

        love.graphics.setColor(0.1, 0.1, 0.2, 1.0)
        love.graphics.rectangle("fill", confirmX, confirmY, confirmWidth, confirmHeight)
        love.graphics.setColor(0.8, 0.8, 0.9, 1)
        love.graphics.rectangle("line", confirmX, confirmY, confirmWidth, confirmHeight)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(menu.confirmMessage, confirmX, confirmY + 10, confirmWidth, "center")

        -- Draw Yes/No options
        local yesX = confirmX + 30
        local noX = confirmX + confirmWidth - 80
        local optionY = confirmY + 50

        if menu.selectedIndex == 1 then love.graphics.setColor(1, 1, 0, 1) else love.graphics.setColor(1, 1, 1, 1) end
        love.graphics.print("Yes", yesX, optionY)

        if menu.selectedIndex == 2 then love.graphics.setColor(1, 1, 0, 1) else love.graphics.setColor(1, 1, 1, 1) end
        love.graphics.print("No", noX, optionY)
    elseif menu.view == "insufficient_funds" then
        -- Draw a message box
        local msgWidth = 250
        local msgHeight = 100
        local msgX = windowX + (windowWidth - msgWidth) / 2
        local msgY = windowY + (windowHeight - msgHeight) / 2

        love.graphics.setColor(0.1, 0.1, 0.2, 1.0)
        love.graphics.rectangle("fill", msgX, msgY, msgWidth, msgHeight)
        love.graphics.setColor(0.8, 0.8, 0.9, 1)
        love.graphics.rectangle("line", msgX, msgY, msgWidth, msgHeight)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(menu.insufficientFundsMessage, msgX + 10, msgY + 20, msgWidth - 20, "center")

        -- Draw OK prompt
        love.graphics.setColor(1, 1, 0, 1) -- Always selected
        love.graphics.printf("[OK]", msgX, msgY + 70, msgWidth, "center")
    end
end

return ShopMenu