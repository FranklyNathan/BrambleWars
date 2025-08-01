-- modules/unit_info_menu.lua
-- Contains the drawing logic for the unit information menu.

local WorldQueries = require("modules.world_queries")
local Assets = require("modules.assets")
local WeaponBlueprints = require("data.weapon_blueprints")
local ClassBlueprints = require("data.class_blueprints")
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

local UnitInfoMenu = {}

function UnitInfoMenu.draw(world)
    local menu = world.ui.menus.unitInfo
    if menu.active and menu.unit then
        local unit = menu.unit
        local moveList = WorldQueries.getUnitMoveList(unit)
        local font = love.graphics.getFont()

        -- Menu dimensions
        local menuWidth = 180
        local menuX = Config.VIRTUAL_WIDTH - menuWidth - 10 -- Position from the right edge with a 10px gap
        local menuY = 10 -- Position from the top

        -- Check if this menu is being used for a level-up display.
        local levelUpAnim = world.ui.levelUpAnimation
        local isLevelUpDisplay = levelUpAnim and levelUpAnim.active and levelUpAnim.unit == unit
        local gainsMap = {}
        if isLevelUpDisplay then
            for stat, _ in pairs(levelUpAnim.statGains) do
                gainsMap[stat] = true
            end
        end

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

            -- Helper to draw the animated "+1" text for level ups.
            local function drawLevelUpBonus(key, x, y)
                if not isLevelUpDisplay or not key or not gainsMap[key] or not levelUpAnim.statsShown[key] then
                    return
                end

                local showPlusOne = (levelUpAnim.phase == 'revealing' or levelUpAnim.phase == 'holding' or levelUpAnim.phase == 'fading')
                if not showPlusOne then return end

                local alpha = 1.0
                local scale = 1.0
                local text = " +1"
                local textWidth = font:getWidth(text)
                local textHeight = font:getHeight()

                if levelUpAnim.phase == "fading" then
                    local fadeDuration = 0.4 -- from LevelUpDisplaySystem
                    local timeSinceFadeStart = love.timer.getTime() - (levelUpAnim.fadeStartTime or 0)
                    alpha = 1.0 - math.min(1, timeSinceFadeStart / fadeDuration)
                elseif levelUpAnim.phase == "revealing" then
                    local popInDuration = 0.15 -- from LevelUpDisplaySystem
                    local timeSinceReveal = love.timer.getTime() - levelUpAnim.statsShown[key].startTime
                    if timeSinceReveal < popInDuration then
                        local progress = timeSinceReveal / popInDuration
                        scale = 1.0 + (1.0 - progress) -- Start at 2.0 scale and shrink to 1.0
                        alpha = progress -- Fade in
                    end
                end

                love.graphics.setColor(0.5, 1, 0.5, alpha)
                love.graphics.print(text, x + textWidth / 2, y + textHeight / 2, 0, scale, scale, textWidth / 2, textHeight / 2)
            end

            -- Helper to draw a single full-width slice, now with icon and level-up awareness.
            local function drawFullSlice(text, value, key, isHeader, icon)
                currentSliceIndex = currentSliceIndex + 1
                local isSelected = menu.isLocked and not isLevelUpDisplay and menu.selectedIndex == currentSliceIndex

                local canAfford = true
                -- Check if the key corresponds to an attack and if the unit can afford it.
                if key and type(key) == "string" and AttackBlueprints[key] then
                    local attackData = AttackBlueprints[key]
                    if attackData.wispCost and unit.wisp < attackData.wispCost then
                        canAfford = false
                    end
                end

                -- Draw slice background with selection highlight
                if isSelected then
                    love.graphics.setColor(0.95, 0.95, 0.7, 0.9) -- Bright yellow/cream for selected
                elseif not canAfford then
                    love.graphics.setColor(0.2, 0.2, 0.2, 0.8) -- Dark grey for unaffordable
                else
                    love.graphics.setColor(0.2, 0.2, 0.1, 0.9) -- Dark brown/grey
                end
                love.graphics.rectangle("fill", menuX, yOffset, menuWidth, sliceHeight)

                local displayValue = value
                -- Only show "+1" during the reveal, hold, and fade phases.
                local showPlusOne = isLevelUpDisplay and key and gainsMap[key] and levelUpAnim.statsShown[key] and (levelUpAnim.phase == 'revealing' or levelUpAnim.phase == 'holding' or levelUpAnim.phase == 'fading')
                local isValueGreen = isLevelUpDisplay and key and gainsMap[key] and (levelUpAnim.phase == 'applying_stats' or levelUpAnim.phase == 'finished')

                local textY = yOffset + (sliceHeight - font:getHeight()) / 2
                if isHeader then
                    if isSelected then love.graphics.setColor(0, 0, 0, 1)
                    else love.graphics.setColor(1, 1, 1, 1)
                    end
                    love.graphics.printf(text, menuX, textY, menuWidth, "center")
                else
                    local textX = menuX + 10
                    -- Draw icon if it exists
                    -- Set the color for the icon and text first.
                    if showPlusOne then
                        local alpha = 1.0
                        if levelUpAnim.phase == "fading" then
                            local fadeDuration = 0.4
                            local timeSinceFadeStart = love.timer.getTime() - (levelUpAnim.fadeStartTime or 0)
                            alpha = 1.0 - math.min(1, timeSinceFadeStart / fadeDuration)
                        end
                        love.graphics.setColor(0.5, 1, 0.5, alpha) -- Green with fade
                    elseif isSelected then love.graphics.setColor(0, 0, 0, 1)
                    elseif not canAfford then love.graphics.setColor(0.5, 0.5, 0.5, 1) -- Grey text
                    else love.graphics.setColor(1, 1, 1, 1) end

                    -- Now draw the icon with the correct color.
                    if icon then
                        local iconY = yOffset + (sliceHeight - icon:getHeight()) / 2
                        love.graphics.draw(icon, textX, iconY, 0, 1, 1)
                        textX = textX + icon:getWidth() + 4
                    end

                    love.graphics.print(text, textX, textY)

                    -- Set color for the stat value (e.g., "25/25")
                    if displayValue then
                        local valueString = tostring(displayValue)
                        local valueWidth = font:getWidth(valueString)
                        local plusOneString = ""
                        if showPlusOne then
                            plusOneString = " +1"
                        end
                        local plusOneWidth = font:getWidth(plusOneString)
                        local totalWidth = valueWidth + plusOneWidth
                        local startX = menuX + menuWidth - totalWidth - 10

                        -- Draw the value string
                        if isValueGreen then
                            love.graphics.setColor(0.5, 1, 0.5, 1) -- Green
                        elseif isSelected then
                            love.graphics.setColor(0, 0, 0, 1)
                        elseif not canAfford then
                            love.graphics.setColor(0.5, 0.5, 0.5, 1) -- Grey text
                        else
                            love.graphics.setColor(1, 1, 1, 1)
                        end
                        love.graphics.print(valueString, startX, textY)

                        -- Draw the "+1" string if it exists
                        drawLevelUpBonus(key, startX + valueWidth, textY)
                    end
                end
                yOffset = yOffset + sliceHeight
            end

            local function drawStatSlicePair(text1, value1, key1, text2, value2, key2)
                local sliceWidth = menuWidth / 2
                local sliceX1 = menuX
                local sliceX2 = menuX + sliceWidth

                -- Draw left slice
                currentSliceIndex = currentSliceIndex + 1
                local isSelected1 = menu.isLocked and not isLevelUpDisplay and menu.selectedIndex == currentSliceIndex
                if isSelected1 then
                    love.graphics.setColor(0.95, 0.95, 0.7, 0.9)
                else
                    love.graphics.setColor(0.2, 0.2, 0.1, 0.9)
                end
                love.graphics.rectangle("fill", sliceX1, yOffset, sliceWidth, sliceHeight)

                local displayValue1 = value1
                -- The unit's stats are not yet updated during the animation, so we can just show the value.
                local showPlusOne1 = isLevelUpDisplay and key1 and gainsMap[key1] and levelUpAnim.statsShown[key1] and (levelUpAnim.phase == 'revealing' or levelUpAnim.phase == 'holding' or levelUpAnim.phase == 'fading')
                local isValueGreen1 = isLevelUpDisplay and key1 and gainsMap[key1] and (levelUpAnim.phase == 'applying_stats' or levelUpAnim.phase == 'finished')

                local textY = yOffset + (sliceHeight - font:getHeight()) / 2

                -- Set color for the left stat name
                if showPlusOne1 then
                    local alpha = 1.0
                    if levelUpAnim.phase == "fading" then
                        local fadeDuration = 0.4
                        local timeSinceFadeStart = love.timer.getTime() - (levelUpAnim.fadeStartTime or 0)
                        alpha = 1.0 - math.min(1, timeSinceFadeStart / fadeDuration)
                    end
                    love.graphics.setColor(0.5, 1, 0.5, alpha) -- Green with fade
                elseif isSelected1 then love.graphics.setColor(0, 0, 0, 1)
                else love.graphics.setColor(1, 1, 1, 1) end
                love.graphics.print(text1, sliceX1 + 10, textY)

                -- Draw the value next to the label, not right-aligned
                if value1 then
                    local text1Width = font:getWidth(text1)
                    local valueX = sliceX1 + 10 + text1Width + font:getWidth(" ")

                    -- Draw the value string
                    if isValueGreen1 then love.graphics.setColor(0.5, 1, 0.5, 1) elseif isSelected1 then love.graphics.setColor(0, 0, 0, 1) else love.graphics.setColor(1, 1, 1, 1) end
                    local valueString = tostring(displayValue1)
                    love.graphics.print(valueString, valueX, textY)

                    -- Draw the "+1" string if applicable
                    drawLevelUpBonus(key1, valueX + font:getWidth(valueString), textY)
                end

                -- Draw right slice
                currentSliceIndex = currentSliceIndex + 1
                local isSelected2 = menu.isLocked and not isLevelUpDisplay and menu.selectedIndex == currentSliceIndex
                if isSelected2 then
                    love.graphics.setColor(0.95, 0.95, 0.7, 0.9)
                else
                    love.graphics.setColor(0.2, 0.2, 0.1, 0.9)
                end
                love.graphics.rectangle("fill", sliceX2, yOffset, sliceWidth, sliceHeight)

                local displayValue2 = value2
                local showPlusOne2 = isLevelUpDisplay and key2 and gainsMap[key2] and levelUpAnim.statsShown[key2] and (levelUpAnim.phase == 'revealing' or levelUpAnim.phase == 'holding' or levelUpAnim.phase == 'fading')
                local isValueGreen2 = isLevelUpDisplay and key2 and gainsMap[key2] and (levelUpAnim.phase == 'applying_stats' or levelUpAnim.phase == 'finished')

                -- Set color for the right stat name
                if showPlusOne2 then
                    local alpha = 1.0
                    if levelUpAnim.phase == "fading" then
                        local fadeDuration = 0.4
                        local timeSinceFadeStart = love.timer.getTime() - (levelUpAnim.fadeStartTime or 0)
                        alpha = 1.0 - math.min(1, timeSinceFadeStart / fadeDuration)
                    end
                    love.graphics.setColor(0.5, 1, 0.5, alpha) -- Green with fade
                elseif isSelected2 then love.graphics.setColor(0, 0, 0, 1)
                else love.graphics.setColor(1, 1, 1, 1) end

                love.graphics.print(text2, sliceX2 + 10, textY)

                if value2 then
                    local text2Width = font:getWidth(text2)
                    local valueX2 = sliceX2 + 10 + text2Width + font:getWidth(" ")

                    if isValueGreen2 then love.graphics.setColor(0.5, 1, 0.5, 1)
                    elseif isSelected2 then love.graphics.setColor(0, 0, 0, 1)
                    else love.graphics.setColor(1, 1, 1, 1) end

                    local valueString2 = tostring(displayValue2)
                    love.graphics.print(valueString2, valueX2, textY)
                    drawLevelUpBonus(key2, valueX2 + font:getWidth(valueString2), textY)
                end

                yOffset = yOffset + sliceHeight
            end

            -- 1. Draw Name Header
            do
                currentSliceIndex = currentSliceIndex + 1
                local isSelected = menu.isLocked and menu.selectedIndex == currentSliceIndex

                -- Draw slice background with selection highlight
               if isSelected then
                   love.graphics.setColor(0.95, 0.95, 0.7, 0.9)
                else
                    love.graphics.setColor(0.2, 0.2, 0.1, 0.9)
                end
                love.graphics.rectangle("fill", menuX, yOffset, menuWidth, sliceHeight)

                -- Draw text with selection highlight
                if isSelected then love.graphics.setColor(0, 0, 0, 1) else love.graphics.setColor(1, 1, 1, 1) end
                local textY = yOffset + (sliceHeight - font:getHeight()) / 2

                -- Draw Name on the left
                local unitName = unit.displayName or unit.enemyType or "Unit"
                love.graphics.print(unitName, menuX + 10, textY)

                -- Draw Level on the right
                local levelToDisplay = unit.level or 1
                local isLevelGreen = false

                if isLevelUpDisplay then
                    -- During the animation, show the *next* level in green.
                    if levelUpAnim.phase ~= "applying_stats" and levelUpAnim.phase ~= "finished" then
                        levelToDisplay = levelToDisplay + 1
                        isLevelGreen = true
                    end
                    -- After the animation, the unit's level is already updated, so we just draw it normally (white).
                end

                local levelText = "Lv " .. levelToDisplay
                local levelWidth = font:getWidth(levelText)

                if isLevelGreen then love.graphics.setColor(0.5, 1, 0.5, 1) -- Green
                else if isSelected then love.graphics.setColor(0, 0, 0, 1) else love.graphics.setColor(1, 1, 1, 1) end end

                love.graphics.print(levelText, menuX + menuWidth - levelWidth - 10, textY)
                yOffset = yOffset + sliceHeight
            end

            -- 2. Draw Class
            do
                local speciesText = unit.species or ""
                local classText = "Unknown"
                if unit.class and ClassBlueprints[unit.class] then
                    classText = ClassBlueprints[unit.class].name
                end
                local displayText = (speciesText ~= "" and (speciesText .. " ") or "") .. classText
                -- The key "class" is added for selection logic in the input handler later.
                -- Set the last parameter to `false` to left-align the text like the name.
                drawFullSlice(displayText, nil, "class", false)

                -- Draw the origin icon on the right side of the slice.
                local originIcon = Assets.getOriginIcon(unit.originType)
                if originIcon then
                    local iconY = (yOffset - sliceHeight) + (sliceHeight - originIcon:getHeight()) / 2
                    local iconX = menuX + menuWidth - originIcon:getWidth() - 10
                    love.graphics.setColor(1, 1, 1, 1) -- Ensure color is white
                    love.graphics.draw(originIcon, iconX, iconY)
                end
            end

            -- 3. Draw Equipped Weapon
            do
                local weaponName = "Unarmed"
                local weaponIcon = nil
                if unit.equippedWeapon and WeaponBlueprints[unit.equippedWeapon] then
                    local weaponData = WeaponBlueprints[unit.equippedWeapon]
                    weaponName = weaponData.name
                    weaponIcon = Assets.getWeaponIcon(weaponData.type)
                else
                    print("[DEBUG] Unit Info Menu: No weapon equipped or blueprint not found.")
                end
                drawFullSlice(weaponName, nil, "weapon", false, weaponIcon)
            end

            -- 4. Draw HP and Wisp on the same slice
            drawStatSlicePair("HP:", math.floor(unit.hp) .. "/" .. unit.finalMaxHp, "maxHp", "Wisp:", math.floor(unit.wisp) .. "/" .. unit.finalMaxWisp, "maxWisp")

            -- 5. Draw Stats Grid
            drawStatSlicePair("Atk:", unit.finalAttackStat, "attackStat", "Def:", unit.finalDefenseStat, "defenseStat")
            drawStatSlicePair("Mag:", unit.finalMagicStat, "magicStat", "Res:", unit.finalResistanceStat, "resistanceStat")
            drawStatSlicePair("Wit:", unit.finalWitStat, "witStat", "Wgt:", unit.finalWeight, "weight")

            -- 6. Draw Moves Header and List
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", menuX, yOffset, menuWidth, 2)
            for _, attackName in ipairs(moveList) do
                local attackData = AttackBlueprints[attackName]
                if attackData then
                    local formattedName = formatAttackName(attackName)
                    local wispString = (attackData.wispCost and attackData.wispCost > 0) and string.rep("♦", attackData.wispCost) or ""
                    drawFullSlice(formattedName, wispString, attackName)
                end
            end

            -- 7. Draw carried unit info if it exists
            if unit.carriedUnit then
                local carried = unit.carriedUnit
                drawFullSlice("Carrying: " .. (carried.displayName or carried.enemyType), nil, "carried", true)
            end

            -- Draw the appended Power and Description slices if a move is selected
            -- 1(Name)+1(Class)+1(Weapon)+2(HP/Wisp)+6(Stats) = 11 slices before moves. So moves start at index 12.
            local movesStartIndex = 12
            local selectedAttackIndex = menu.selectedIndex - (movesStartIndex - 1)
            if menu.isLocked and selectedAttackIndex > 0 and selectedAttackIndex <= #moveList then
                local attackName = moveList[selectedAttackIndex]
                local attackData = AttackBlueprints[attackName]

                if attackData then
                    -- Draw the static "Power" slice, mimicking the action menu.
                    local powerSliceHeight = sliceHeight
                    local powerValueText = "--"
                    if attackData.displayPower then
                        powerValueText = attackData.displayPower
                    elseif attackData.power and attackData.power > 0 then
                        powerValueText = tostring(attackData.power)
                    end

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