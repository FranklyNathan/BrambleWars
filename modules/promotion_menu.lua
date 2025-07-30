-- modules/promotion_menu.lua
-- Contains the drawing logic for the class promotion menu.

local PromotionMenu = {}

function PromotionMenu.draw(world)
    local menu = world.ui.menus.promotion
    if not menu.active or not menu.unit then return end

    local font = love.graphics.getFont()
    local unit = menu.unit

    -- Menu dimensions and positioning
    local menuWidth = 250
    local menuHeight = 320
    local menuX = (Config.VIRTUAL_WIDTH - menuWidth) / 2
    local menuY = (Config.VIRTUAL_HEIGHT - menuHeight) / 2

    -- Draw a semi-transparent background overlay to dim the game world
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT)

    -- Draw menu background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.95) -- Dark blueish background
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
    love.graphics.setColor(0.8, 0.8, 0.9, 1) -- Light border
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
    love.graphics.setLineWidth(1)

    -- Draw header
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Choose a Promotion for " .. unit.displayName, menuX, menuY + 10, menuWidth, "center")

    -- Draw promotion options
    local yOffset = menuY + 40
    local sliceHeight = 25

    for i, option in ipairs(menu.options) do
        local isSelected = (i == menu.selectedIndex)

        -- Draw slice background
        if isSelected then
            love.graphics.setColor(0.95, 0.95, 0.7, 0.9) -- Cream/yellow for selected
        else
            love.graphics.setColor(0.2, 0.2, 0.1, 0.9) -- Dark brown/grey
        end
        love.graphics.rectangle("fill", menuX + 5, yOffset, menuWidth - 10, sliceHeight)

        -- Draw class name
        if isSelected then
            love.graphics.setColor(0, 0, 0, 1) -- Black for selected text
        else
            love.graphics.setColor(1, 1, 1, 1) -- White for normal
        end
        local textY = yOffset + (sliceHeight - font:getHeight()) / 2
        love.graphics.print(option.name, menuX + 15, textY)

        yOffset = yOffset + sliceHeight + 5 -- Add a little space between options
    end

    -- Draw stat bonuses for the selected promotion
    local selectedOption = menu.options[menu.selectedIndex]
    if selectedOption and selectedOption.stat_bonuses then
        local bonusY = yOffset + 20
        local lineHeight = 18

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Stat Bonuses:", menuX + 15, bonusY)
        bonusY = bonusY + lineHeight

        local statMap = {
            maxHp = "HP", attackStat = "Atk", defenseStat = "Def",
            magicStat = "Mag", resistanceStat = "Res", witStat = "Wit",
            movement = "Mov", wispStat = "Wisp", weight = "Wgt"
        }

        local col1X = menuX + 15
        local col2X = menuX + (menuWidth / 2) - 10
        local currentX = col1X
        local currentY = bonusY

        -- Iterate through bonuses and draw them in two columns
        for stat, bonus in pairs(selectedOption.stat_bonuses) do
            if bonus ~= 0 then
                local statDisplayName = statMap[stat] or stat
                local bonusText = string.format("%+d", bonus)
                love.graphics.setColor(0.5, 1, 0.5, 1) -- Green for positive bonus
                love.graphics.printf(statDisplayName .. ": " .. bonusText, currentX, currentY, (menuWidth / 2) - 20, "left")
                
                if currentX == col1X then
                    currentX = col2X
                else
                    currentX = col1X
                    currentY = currentY + lineHeight
                end
            end
        end
    end

    -- Draw confirmation prompt
    love.graphics.setColor(1, 1, 1, 0.6 + (math.sin(love.timer.getTime() * 2) + 1) / 2 * 0.4) -- Pulsing alpha
    love.graphics.printf("Press [J] to Confirm", menuX, menuHeight + menuY - 25, menuWidth, "center")
end

return PromotionMenu
