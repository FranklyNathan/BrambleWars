-- modules/unit_info_menu.lua
-- Contains the drawing logic for the unit information menu.

local AttackBlueprints = require("data.attack_blueprints")

-- Define colors for origin types
local originTypeColors = {
    cavernborn = {0.8, 0.4, 0.1, 1}, -- Dark Orange
    marshborn = {0.1, 0.3, 0.8, 1}, -- Dark Blue
    forestborn = {0.1, 0.5, 0.2, 1}  -- Dark Green
}

-- Helper to format attack names into Title Case (e.g., "invigoration" -> "Invigoration").
local function formatAttackName(name)
    if not name then return "" end
    local s = name:gsub("_", " ")
    s = s:gsub("^%l", string.upper)
    s = s:gsub(" (%l)", function(c) return " " .. c:upper() end)
    return s
end

-- Helper function for wrapping long strings of text.
local function wrapText(text, limit, font)
    font = font or love.graphics.getFont()
    local lines = {}
    if not text then return lines end

    local currentLine = ""
    local currentWidth = 0

    for word in string.gmatch(text, "%S+") do
        local wordWidth = font:getWidth(word)
        if currentWidth > 0 and currentWidth + font:getWidth(" ") + wordWidth > limit then
            table.insert(lines, currentLine)
            currentLine = word
            currentWidth = wordWidth
        else
            if currentLine == "" then
                currentLine = word
            else
                currentLine = currentLine .. " " .. word
            end
            currentWidth = font:getWidth(currentLine)
        end
    end
    table.insert(lines, currentLine)
    return lines
end

-- Helper to capitalize the first letter of a string.
local function capitalize(str)
    if not str or str == "" then return "" end
    return str:sub(1,1):upper() .. str:sub(2)
end

local UnitInfoMenu = {}

function UnitInfoMenu.draw(world)
    local menu = world.unitInfoMenu
    if menu.active and menu.unit then
        local unit = menu.unit
        local font = love.graphics.getFont()

        -- Menu dimensions
        local menuX = Config.VIRTUAL_WIDTH - 160 -- Position from the right edge
        local menuY = 10 -- Position from the top
        local menuWidth = 150
        local menuHeight

        if unit.isObstacle then
            -- Draw a simplified info box for obstacles.
            local lineHeight = 18
            local numContentLines = 3 -- Name, Blank, Weight
            menuHeight = 20 + numContentLines * lineHeight

            -- Draw background
            love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
            love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
            love.graphics.setColor(0.7, 0.7, 0.7, 1) -- Neutral grey border
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
            love.graphics.setLineWidth(1)

            local xPos = menuX + 10
            local yPos = menuY + 10

            -- Draw obstacle name
            love.graphics.setColor(0.9, 0.9, 0.9, 1) -- Light grey
            love.graphics.print("Obstacle", xPos, yPos)

            -- Draw weight
            yPos = yPos + lineHeight * 2 -- Add a blank line
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print("Wgt:", menuX + 5, yPos)
            love.graphics.print(unit.weight, menuX + 60, yPos)
        else
            -- Slice-based drawing logic
            local sliceHeight = 22
            local yOffset = menuY
            local currentSliceIndex = 0

            -- Helper to draw a single full-width slice
            local function drawFullSlice(text, value, isHeader)
                currentSliceIndex = currentSliceIndex + 1
                local isSelected = menu.isLocked and menu.selectedIndex == currentSliceIndex

                -- Draw slice background with selection highlight
                if isSelected then
                    love.graphics.setColor(0.95, 0.95, 0.7, 0.9) -- Bright yellow/cream for selected
                else
                    love.graphics.setColor(0.2, 0.2, 0.1, 0.9) -- Dark brown/grey
                end
                love.graphics.rectangle("fill", menuX, yOffset, menuWidth, sliceHeight)

                -- Draw text with selection highlight
                if isSelected then
                    love.graphics.setColor(0, 0, 0, 1) -- Black text for selected
                else
                    love.graphics.setColor(1, 1, 1, 1) -- White text
                end
                local textY = yOffset + (sliceHeight - font:getHeight()) / 2
                if isHeader then
                    love.graphics.printf(text, menuX, textY, menuWidth, "center")
                else
                    love.graphics.print(text, menuX + 10, textY)
                    if value then
                        local valueWidth = font:getWidth(tostring(value))
                        love.graphics.print(value, menuX + menuWidth - valueWidth - 10, textY)
                    end
                end
                yOffset = yOffset + sliceHeight
            end

            -- Helper to draw a pair of stat slices side-by-side
            local function drawStatSlicePair(text1, value1, text2, value2)
                local sliceWidth = menuWidth / 2
                local sliceX1 = menuX
                local sliceX2 = menuX + sliceWidth

                -- Draw left slice
                currentSliceIndex = currentSliceIndex + 1
                local isSelected1 = menu.isLocked and menu.selectedIndex == currentSliceIndex
                if isSelected1 then
                    love.graphics.setColor(0.95, 0.95, 0.7, 0.9)
                else
                    love.graphics.setColor(0.2, 0.2, 0.1, 0.9)
                end
                love.graphics.rectangle("fill", sliceX1, yOffset, sliceWidth, sliceHeight)

                if isSelected1 then
                    love.graphics.setColor(0, 0, 0, 1)
                else
                    love.graphics.setColor(1, 1, 1, 1)
                end
                local textY = yOffset + (sliceHeight - font:getHeight()) / 2
                love.graphics.print(text1, sliceX1 + 10, textY)
                if value1 then
                    love.graphics.print(tostring(value1), sliceX1 + 45, textY)
                end

                -- Draw right slice
                currentSliceIndex = currentSliceIndex + 1
                local isSelected2 = menu.isLocked and menu.selectedIndex == currentSliceIndex
                if isSelected2 then
                    love.graphics.setColor(0.95, 0.95, 0.7, 0.9)
                else
                    love.graphics.setColor(0.2, 0.2, 0.1, 0.9)
                end
                love.graphics.rectangle("fill", sliceX2, yOffset, sliceWidth, sliceHeight)

                if isSelected2 then
                    love.graphics.setColor(0, 0, 0, 1)
                else
                    love.graphics.setColor(1, 1, 1, 1)
                end
                love.graphics.print(text2, sliceX2 + 10, textY)
                if value2 then
                    love.graphics.print(tostring(value2), sliceX2 + 45, textY)
                end

                yOffset = yOffset + sliceHeight
            end

            -- 1. Draw Name Header
            local unitName = unit.displayName or unit.enemyType or "Unit"
            drawFullSlice(unitName, nil, true)

            -- 2. Draw HP and Wisp
            drawFullSlice("HP", math.floor(unit.hp) .. "/" .. unit.maxHp)
            drawFullSlice("Wisp", math.floor(unit.wisp) .. "/" .. unit.maxWisp)

            -- 3. Draw Stats Grid
            drawStatSlicePair("Atk:", unit.attackStat, "Def:", unit.defenseStat)
            drawStatSlicePair("Mag:", unit.magicStat, "Res:", unit.resistanceStat)
            drawStatSlicePair("Wit:", unit.witStat, "Wgt:", unit.weight)

            -- 4. Draw Moves Header and List
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", menuX, yOffset, menuWidth, 2)
            for _, attackName in ipairs(unit.attacks) do
                local attackData = AttackBlueprints[attackName]
                if attackData then
                    local formattedName = formatAttackName(attackName)
                    local wispString = (attackData.wispCost and attackData.wispCost > 0) and string.rep("♦", attackData.wispCost) or ""
                    drawFullSlice(formattedName, wispString)
                end
            end

            -- 5. Draw carried unit info if it exists
            if unit.carriedUnit then
                local carried = unit.carriedUnit
                drawFullSlice("Carrying: " .. (carried.displayName or carried.enemyType), nil, true)
            end

            -- Draw the appended Power and Description slices if a move is selected
            local movesStartIndex = 9 -- 1(Name)+2(HP/Wisp)+6(Stats) = 9. So moves start at index 10.
            local selectedAttackIndex = menu.selectedIndex - movesStartIndex
            if menu.isLocked and selectedAttackIndex > 0 and selectedAttackIndex <= #unit.attacks then
                local attackName = unit.attacks[selectedAttackIndex]
                local attackData = AttackBlueprints[attackName]

                if attackData then
                    -- Draw the static "Power" slice, mimicking the action menu.
                    local powerSliceHeight = sliceHeight
                    local powerValueText = (attackData.power and attackData.power > 0) and tostring(attackData.power) or "--"

                    -- Draw the slice background (always unselected style)
                    love.graphics.setColor(0.2, 0.2, 0.1, 0.9)
                    love.graphics.rectangle("fill", menuX, yOffset, menuWidth, powerSliceHeight)

                    -- Draw separator line at the top of the slice
                    love.graphics.setColor(0, 0, 0, 0.3)
                    love.graphics.rectangle("fill", menuX, yOffset, menuWidth, 2)

                    -- Draw the text
                    love.graphics.setColor(1, 1, 1, 1) -- White text
                    local textY = yOffset + (powerSliceHeight - font:getHeight()) / 2
                    love.graphics.print("Power", menuX + 10, textY)

                    -- Draw the right-aligned power value
                    local valueWidth = font:getWidth(powerValueText)
                    love.graphics.print(powerValueText, menuX + menuWidth - valueWidth - 10, textY)
                    yOffset = yOffset + powerSliceHeight

                    -- Draw the static "Description" slice.
                    local descText = attackData.description or ""
                    local wrappedLines = wrapText(descText, menuWidth - 20, font)
                    local descLineHeight = font:getHeight() * 1.2
                    -- Use a fixed height for consistency, e.g., for 3 lines of text.
                    local descriptionSliceHeight = 10 + 5 * descLineHeight

                    -- Draw panel background
                    love.graphics.setColor(0.2, 0.2, 0.1, 0.9)
                    love.graphics.rectangle("fill", menuX, yOffset, menuWidth, descriptionSliceHeight)
                    love.graphics.setColor(0, 0, 0, 0.3)
                    love.graphics.rectangle("fill", menuX, yOffset, menuWidth, 2)
                    love.graphics.setColor(1, 1, 1, 1)
                    for i, line in ipairs(wrappedLines) do
                        if i > 5 then break end -- Only draw up to 5 lines
                        local lineY = yOffset + 5 + (i - 1) * descLineHeight
                        love.graphics.print(line, menuX + 10, lineY)
                    end
                end
            end
        end
    end
end

return UnitInfoMenu