-- modules/unit_info_menu.lua
-- Contains the drawing logic for the unit information menu.

local AttackBlueprints = require("data.attack_blueprints")

-- Define colors for origin types
local originTypeColors = {
    cavernborn = {0.8, 0.4, 0.1, 1}, -- Dark Orange
    marshborn = {0.1, 0.3, 0.8, 1}, -- Dark Blue
    forestborn = {0.1, 0.5, 0.2, 1}  -- Dark Green
}

-- Helper to format attack names into Title Case (e.g., "invigorating_aura" -> "Invigorating Aura").
local function formatAttackName(name)
    if not name then return "" end
    local s = name:gsub("_", " ")
    s = s:gsub("^%l", string.upper)
    s = s:gsub(" (%l)", function(c) return " " .. c:upper() end)
    return s
end

-- Helper to capitalize the first letter of a string.
local function capitalize(str)
    if not str or str == "" then return "" end
    return str:sub(1,1):upper() .. str:sub(2)
end

local UnitInfoMenu = {}

function UnitInfoMenu.draw(world)
    if world.unitInfoMenu.active and world.unitInfoMenu.unit then
        local unit = world.unitInfoMenu.unit
        local font = love.graphics.getFont()

        -- Menu dimensions
        local menuX = Config.VIRTUAL_WIDTH - 190 -- Position from the right edge
        local menuY = 10 -- Position from the top
        local menuWidth = 180

        -- Dynamically calculate menu height based on content.
        local lineHeight = 18
        -- Header (2) + Blank (1) + Stats (8) + Blank (1) + "Moves:" (1) + num_attacks
        local numContentLines = 2 + 1 + 8 + 1 + 1 + #unit.attacks
        local menuHeight = 20 + numContentLines * lineHeight -- 10px padding top/bottom

        -- Draw background
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
        love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
        -- Set border color based on unit type
        if unit.type == "player" then
            love.graphics.setColor(0.6, 0.6, 1, 1) -- Player Blue
        else -- enemy
            love.graphics.setColor(1, 0.6, 0.6, 1) -- Enemy Red
        end
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
        love.graphics.setLineWidth(1)

        -- Draw unit name and type at the top
        local unitName = unit.displayName
        if not unitName then
            if unit.enemyType then
                unitName = unit.enemyType -- For enemies
            else
                unitName = "Unit" -- Default label
            end
        end

        local xPos = menuX + 10
        local yPos = menuY + 10

        -- Draw unit name with team color
        if unit.type == "player" then
            love.graphics.setColor(0.6, 0.6, 1, 1) -- Player Blue
        else -- enemy
            love.graphics.setColor(1, 0.6, 0.6, 1) -- Enemy Red
        end
        love.graphics.print(unitName, xPos, yPos)

        -- Draw origin type with its color on a new line
        yPos = yPos + lineHeight
        local originColor = originTypeColors[unit.originType] or {1, 1, 1, 1}
        love.graphics.setColor(originColor)
        love.graphics.print(capitalize(unit.originType), xPos, yPos)

        -- Reset color and draw the rest of the stats
        love.graphics.setColor(1, 1, 1, 1)
        local yOffset = yPos + lineHeight * 2 -- Add a blank line after the header
        local labelX = menuX + 5
        local valueX = menuX + 75

        love.graphics.print("HP:", labelX, yOffset); love.graphics.print(math.floor(unit.hp) .. "/" .. unit.maxHp, valueX, yOffset); yOffset = yOffset + lineHeight
        love.graphics.print("Wisp:", labelX, yOffset); love.graphics.print(math.floor(unit.wisp) .. "/" .. unit.maxWisp, valueX, yOffset); yOffset = yOffset + lineHeight
        love.graphics.print("Atk:", labelX, yOffset); love.graphics.print(unit.attackStat, valueX, yOffset); yOffset = yOffset + lineHeight
        love.graphics.print("Def:", labelX, yOffset); love.graphics.print(unit.defenseStat, valueX, yOffset); yOffset = yOffset + lineHeight
        love.graphics.print("Mag:", labelX, yOffset); love.graphics.print(unit.magicStat, valueX, yOffset); yOffset = yOffset + lineHeight
        love.graphics.print("Res:", labelX, yOffset); love.graphics.print(unit.resistanceStat, valueX, yOffset); yOffset = yOffset + lineHeight
        love.graphics.print("Wit:", labelX, yOffset); love.graphics.print(unit.witStat, valueX, yOffset); yOffset = yOffset + lineHeight
        love.graphics.print("Wgt:", labelX, yOffset); love.graphics.print(unit.weight, valueX, yOffset); yOffset = yOffset + lineHeight

        yOffset = yOffset + lineHeight -- Blank line before moves
        love.graphics.print("Moves:", labelX, yOffset); yOffset = yOffset + lineHeight

        -- List known moves below stats
        local movesX = menuX + 10 -- No indent
        for i = 1, #unit.attacks do
            local attackName = unit.attacks[i]
            local attackData = AttackBlueprints[attackName]
            if attackData then -- Ensure attack data exists
                local formattedName = formatAttackName(attackName)
                -- Set color for the move name based on its origin type
                local moveColor = originTypeColors[attackData.originType] or {1, 1, 1, 1}
                love.graphics.setColor(moveColor)
                love.graphics.print(formattedName, movesX, yOffset)

                -- Generate and print wisp cost string
                if attackData.wispCost and attackData.wispCost > 0 then
                    local wispString = string.rep("♦", attackData.wispCost)
                    love.graphics.setColor(1, 1, 1, 1) -- White for wisp cost
                    local moveNameWidth = font:getWidth(formattedName .. " ")
                    love.graphics.print(wispString, movesX + moveNameWidth, yOffset)
                end

                yOffset = yOffset + lineHeight
            else
                -- Log missing attack data and skip printing.
                print("Warning: Attack data not found for: " .. attackName)
            end
        end
        love.graphics.setColor(1, 1, 1, 1) -- Reset color after drawing moves
    end
end

return UnitInfoMenu