-- modules/unit_info_menu.lua
-- Contains the drawing logic for the unit information menu.

local WorldQueries = require("modules.world_queries")
local Assets = require("modules.assets")
local WeaponBlueprints = require("data.weapon_blueprints")
local PassiveBlueprints = require("data/passive_blueprints")
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
        local passiveList = WorldQueries.getUnitPassiveList(unit)
        local font = love.graphics.getFont()

        -- Determine the number of weapon slots to display. This affects the menu layout and indexing.
        local hasDualWielder = false
        if not unit.isObstacle then
            for _, p in ipairs(passiveList) do
                if p == "DualWielder" then
                    hasDualWielder = true
                    break
                end
            end
        end
        local numWeaponSlots = hasDualWielder and 2 or 1

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
            local function drawFullSlice(text, value, key, isHeader, icon, absoluteIndex, scrollIndicatorDirection)
                currentSliceIndex = currentSliceIndex + 1
                local isSelected = menu.isLocked and not isLevelUpDisplay and menu.selectedIndex == (absoluteIndex or currentSliceIndex)

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

                    if scrollIndicatorDirection then
                        local textWidth = font:getWidth(text)
                        local arrowCenterX = textX + textWidth + 8 -- Position it 8px after the text
                        local arrowCenterY = yOffset + sliceHeight / 2
                        local triSize = 4
                        local p1x, p1y, p2x, p2y, p3x, p3y

                        -- Set color for the arrow
                        if isSelected then love.graphics.setColor(0, 0, 0, 1)
                        elseif not canAfford then love.graphics.setColor(0.5, 0.5, 0.5, 1)
                        else love.graphics.setColor(1, 1, 1, 1) end

                        if scrollIndicatorDirection == "down" then
                            p1x, p1y = arrowCenterX - triSize, arrowCenterY - triSize / 2
                            p2x, p2y = arrowCenterX + triSize, arrowCenterY - triSize / 2
                            p3x, p3y = arrowCenterX, arrowCenterY + triSize / 2
                        elseif scrollIndicatorDirection == "up" then
                            p1x, p1y = arrowCenterX - triSize, arrowCenterY + triSize / 2
                            p2x, p2y = arrowCenterX + triSize, arrowCenterY + triSize / 2
                            p3x, p3y = arrowCenterX, arrowCenterY - triSize / 2
                        end
                        love.graphics.polygon("fill", p1x, p1y, p2x, p2y, p3x, p3y)
                    end

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

            -- Helper to draw a single half-width stat slice.
            local function drawSingleStatSlice(sliceX, text, value, key, isSelected)
                -- Draw background
                if isSelected then love.graphics.setColor(0.95, 0.95, 0.7, 0.9)
                else love.graphics.setColor(0.2, 0.2, 0.1, 0.9) end
                love.graphics.rectangle("fill", sliceX, yOffset, menuWidth / 2, sliceHeight)

                -- Determine text/value colors based on level up state
                local showPlusOne = isLevelUpDisplay and key and gainsMap[key] and levelUpAnim.statsShown[key] and (levelUpAnim.phase == 'revealing' or levelUpAnim.phase == 'holding' or levelUpAnim.phase == 'fading')
                local isValueGreen = isLevelUpDisplay and key and gainsMap[key] and (levelUpAnim.phase == 'applying_stats' or levelUpAnim.phase == 'finished')
                local textY = yOffset + (sliceHeight - font:getHeight()) / 2

                -- Set color for the stat name
                if showPlusOne then
                    local alpha = 1.0
                    if levelUpAnim.phase == "fading" then
                        local fadeDuration = 0.4
                        local timeSinceFadeStart = love.timer.getTime() - (levelUpAnim.fadeStartTime or 0)
                        alpha = 1.0 - math.min(1, timeSinceFadeStart / fadeDuration)
                    end
                    love.graphics.setColor(0.5, 1, 0.5, alpha) -- Green with fade
                elseif isSelected then love.graphics.setColor(0, 0, 0, 1)
                else love.graphics.setColor(1, 1, 1, 1) end
                love.graphics.print(text, sliceX + 10, textY)

                -- Draw the value
                if value then
                    local textWidth = font:getWidth(text)
                    local valueX = sliceX + 10 + textWidth + font:getWidth(" ")

                    if isValueGreen then love.graphics.setColor(0.5, 1, 0.5, 1)
                    elseif isSelected then love.graphics.setColor(0, 0, 0, 1)
                    else love.graphics.setColor(1, 1, 1, 1) end

                    local valueString = tostring(value)
                    love.graphics.print(valueString, valueX, textY)
                    drawLevelUpBonus(key, valueX + font:getWidth(valueString), textY)
                end
            end

            local function drawStatSlicePair(text1, value1, key1, text2, value2, key2)
                local sliceWidth = menuWidth / 2
                local sliceX1 = menuX
                local sliceX2 = menuX + sliceWidth

                -- Draw left slice
                currentSliceIndex = currentSliceIndex + 1
                local isSelected1 = menu.isLocked and not isLevelUpDisplay and menu.selectedIndex == currentSliceIndex
                drawSingleStatSlice(sliceX1, text1, value1, key1, isSelected1)

                -- Draw right slice
                currentSliceIndex = currentSliceIndex + 1
                local isSelected2 = menu.isLocked and not isLevelUpDisplay and menu.selectedIndex == currentSliceIndex
                drawSingleStatSlice(sliceX2, text2, value2, key2, isSelected2)

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

 -- NEW: Handle EXP Slice animation and drawing
            local expAnim = menu.expSliceAnimation
            if expAnim and expAnim.currentHeight > 0 then
                -- The slice grows from the bottom of the name slice.
                -- The background for the slice.
                love.graphics.setColor(0.2, 0.2, 0.1, 0.9)
                -- Use a scissor to clip the drawing as it grows.
                love.graphics.setScissor(menuX, yOffset, menuWidth, expAnim.currentHeight)
                love.graphics.rectangle("fill", menuX, yOffset, menuWidth, sliceHeight)

                -- Draw the EXP bar inside the slice.
                local barWidth = menuWidth - 74 -- Give some padding
                local barHeight = 8
                local barX = menuX + 10
                local barY = yOffset + (sliceHeight - barHeight) / 2

                -- Black background for the bar
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)

                -- White fill for the EXP progress
                local expRatio = (unit.exp or 0) / (unit.maxExp or 100)
                local fillWidth = barWidth * expRatio
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle("fill", barX, barY, fillWidth, barHeight)

                -- Draw black ticks every 20 EXP
                love.graphics.setColor(0, 0, 0, 1)
                local maxExp = unit.maxExp or 100
                for tickExp = 20, maxExp - 1, 20 do
                    local tickRatio = tickExp / maxExp
                    local tickX = barX + math.floor(barWidth * tickRatio)
                    love.graphics.line(tickX, barY, tickX, barY + barHeight)
                end

                -- Draw the EXP text
                love.graphics.setColor(1, 1, 1, 1) -- Reset color to white for the text
                local expText = (unit.exp or 0) .. " Exp"
                local textX = barX + barWidth + 8
                local textY = yOffset + (sliceHeight - font:getHeight()) / 2
                love.graphics.print(expText, textX, textY)

                -- Reset scissor
                love.graphics.setScissor()

                -- Push down all subsequent slices
                yOffset = yOffset + expAnim.currentHeight
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

            -- 3. Draw Equipped Weapon(s)
            do
                for i = 1, numWeaponSlots do
                    local weaponKey = unit.equippedWeapons and unit.equippedWeapons[i]
                    local weaponName = "Unarmed"
                    local weaponIcon = nil
                    local sliceKey = "weapon" .. i -- e.g., "weapon1", "weapon2"

                    if weaponKey and WeaponBlueprints[weaponKey] then
                        local weaponData = WeaponBlueprints[weaponKey]
                        weaponName = weaponData.name
                        weaponIcon = Assets.getWeaponIcon(weaponData.type)
                    end
                    drawFullSlice(weaponName, nil, sliceKey, false, weaponIcon)
                end
            end

            -- 4. Draw HP and Wisp on the same slice
            drawStatSlicePair("HP:", math.floor(unit.hp) .. "/" .. unit.finalMaxHp, "maxHp", "Wisp:", math.floor(unit.wisp) .. "/" .. unit.finalMaxWisp, "maxWisp")

            -- 5. Draw Stats Grid
            drawStatSlicePair("Atk:", unit.finalAttackStat, "attackStat", "Def:", unit.finalDefenseStat, "defenseStat")
            drawStatSlicePair("Mag:", unit.finalMagicStat, "magicStat", "Res:", unit.finalResistanceStat, "resistanceStat")
            drawStatSlicePair("Wit:", unit.finalWitStat, "witStat", "Wgt:", unit.finalWeight, "weight")

            -- 6. Draw Passives List
            if #passiveList > 0 then
                love.graphics.setColor(0, 0, 0, 0.3)
                love.graphics.rectangle("fill", menuX, yOffset, menuWidth, 2)
                yOffset = yOffset + 2

                for _, passiveName in ipairs(passiveList) do
                    currentSliceIndex = currentSliceIndex + 1
                    local isSelected = menu.isLocked and not isLevelUpDisplay and menu.selectedIndex == currentSliceIndex
                    local passiveData = PassiveBlueprints[passiveName]

                    if passiveData then
                        -- Draw slice background
                        if isSelected then love.graphics.setColor(0.95, 0.95, 0.7, 0.9)
                        else love.graphics.setColor(0.2, 0.2, 0.1, 0.9) end
                        love.graphics.rectangle("fill", menuX, yOffset, menuWidth, sliceHeight)

                        -- Draw text
                        if isSelected then love.graphics.setColor(0, 0, 0, 1)
                        else love.graphics.setColor(1, 1, 1, 1) end
                        
                        local textY = yOffset + (sliceHeight - font:getHeight()) / 2
                        local text = passiveData.name
                        local textWidth = font:getWidth(text)
                        -- Right-align the text
                        love.graphics.print(text, menuX + menuWidth - textWidth - 10, textY)
                        
                        yOffset = yOffset + sliceHeight
                    end
                end
            end

            -- 7. Draw Moves List
            love.graphics.setColor(0, 0, 0, 0.3)
            love.graphics.rectangle("fill", menuX, yOffset, menuWidth, 2)
            yOffset = yOffset + 2

            local MAX_VISIBLE_MOVES = 5
            local moveListScrollOffset = menu.moveListScrollOffset or 0

            local numVisibleMoves = math.min(MAX_VISIBLE_MOVES, #moveList - moveListScrollOffset)

            -- We need to know the absolute start index of the moves list to calculate selection correctly.
            -- This is based on the number of slices that came before it.
            local moves_start_index = 2 + numWeaponSlots + 8 + #passiveList + 1

            for i = 1, numVisibleMoves do
                local isFirstVisibleMove = (i == 1)
                local isLastVisibleMove = (i == numVisibleMoves)
                local canScrollUp = (moveListScrollOffset > 0)
                local canScrollDown = (#moveList > MAX_VISIBLE_MOVES) and ((moveListScrollOffset + MAX_VISIBLE_MOVES) < #moveList)

                local scrollIndicator = nil
                if isFirstVisibleMove and canScrollUp then scrollIndicator = "up"
                elseif isLastVisibleMove and canScrollDown then scrollIndicator = "down" end

                local moveIndexInFullList = i + moveListScrollOffset
                local attackName = moveList[moveIndexInFullList]
                local attackData = AttackBlueprints[attackName]
                if attackData then
                    local formattedName = formatAttackName(attackName)
                    local wispString = (attackData.wispCost and attackData.wispCost > 0) and string.rep("♦", attackData.wispCost) or ""
                    local absoluteIndex = moves_start_index + moveIndexInFullList - 1
                    drawFullSlice(formattedName, wispString, attackName, false, nil, absoluteIndex, scrollIndicator)
                end
            end

            -- After drawing the visible moves, we must manually update the slice index counter
            -- to what it would be if all moves were drawn, so that subsequent slices (like "Carrying")
            -- have the correct index for selection.
            currentSliceIndex = moves_start_index + #moveList - 1

            -- 8. Draw carried unit info if it exists
            if unit.carriedUnit then
                local carried = unit.carriedUnit
                drawFullSlice("Carrying: " .. (carried.displayName or carried.enemyType), nil, "carried", true)
            end

            -- 9. Draw Description Box for selected passive or move
            if menu.isLocked and not isLevelUpDisplay then
                local numPassives = #passiveList
                local numMoves = #moveList

                -- Dynamically calculate the start/end indices of each section
                local NAME_CLASS_END = 2
                local WEAPONS_END = NAME_CLASS_END + numWeaponSlots
                -- HP/Wisp is 1 slice pair (2 items), then 3 stat rows (6 items).
                local STATS_END = WEAPONS_END + 8
                local PASSIVES_START = STATS_END + 1
                local PASSIVES_END = PASSIVES_START + numPassives - 1
                local MOVES_START = PASSIVES_END + 1

                local selectedKey, selectedData, hasPowerSlice = nil, nil, false

                if menu.selectedIndex >= PASSIVES_START and menu.selectedIndex <= PASSIVES_END then
                    local passiveIndex = menu.selectedIndex - (PASSIVES_START - 1)
                    selectedKey = passiveList[passiveIndex]
                    selectedData = selectedKey and PassiveBlueprints[selectedKey]
                    hasPowerSlice = false
                elseif menu.selectedIndex >= MOVES_START then
                    local moveIndex = menu.selectedIndex - (MOVES_START - 1)
                    selectedKey = moveList[moveIndex]
                    selectedData = selectedKey and AttackBlueprints[selectedKey]
                    hasPowerSlice = true
                end

                if selectedData then
                    local descriptionSliceY = yOffset

                    if hasPowerSlice then
                        -- Draw the static "Power" slice for moves.
                        local powerSliceHeight = sliceHeight
                        local powerValueText = "--"
                        if selectedData.displayPower then
                            powerValueText = selectedData.displayPower
                        elseif selectedData.power and selectedData.power > 0 then
                            powerValueText = tostring(selectedData.power)
                        end

                        love.graphics.setColor(0.2, 0.2, 0.1, 0.9)
                        love.graphics.rectangle("fill", menuX, yOffset, menuWidth, powerSliceHeight)
                        love.graphics.setColor(0, 0, 0, 0.3)
                        love.graphics.rectangle("fill", menuX, yOffset, menuWidth, 2)
                        love.graphics.setColor(1, 1, 1, 1)
                        local textY = yOffset + (powerSliceHeight - font:getHeight()) / 2
                        love.graphics.print("Power", menuX + 10, textY)
                        local valueWidth = font:getWidth(powerValueText)
                        love.graphics.print(powerValueText, menuX + menuWidth - valueWidth - 10, textY)
                        descriptionSliceY = yOffset + powerSliceHeight
                    end

                    -- Draw the description panel.
                    local descText = selectedData.description or ""
                    local wrappedLines = wrapText(descText, menuWidth - 20, font)
                    local descLineHeight = font:getHeight() * 1.2
                    local descriptionSliceHeight = 10 + 5 * descLineHeight

                    love.graphics.setColor(0.2, 0.2, 0.1, 0.9)
                    love.graphics.rectangle("fill", menuX, descriptionSliceY, menuWidth, descriptionSliceHeight)
                    love.graphics.setColor(0, 0, 0, 0.3)
                    love.graphics.rectangle("fill", menuX, descriptionSliceY, menuWidth, 2)
                    love.graphics.setColor(1, 1, 1, 1)
                    for i, line in ipairs(wrappedLines) do
                        if i > 5 then break end -- Only draw up to 5 lines
                        local lineY = descriptionSliceY + 5 + (i - 1) * descLineHeight
                        love.graphics.print(line, menuX + 10, lineY)
                    end
                end
            end
        end
    end
end

return UnitInfoMenu