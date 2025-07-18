-- modules/unit_info_menu.lua
-- Contains the drawing logic for the unit information menu.

local AttackBlueprints = require("data.attack_blueprints")

local UnitInfoMenu = {}

function UnitInfoMenu.draw(world)
    if world.unitInfoMenu.active and world.unitInfoMenu.unit then
        local unit = world.unitInfoMenu.unit
        local font = love.graphics.getFont()

        -- Menu dimensions
        local menuX = Config.VIRTUAL_WIDTH - 200 -- Position from the right edge
        local menuY = 10 -- Position from the top
        local menuWidth = 190
        local menuHeight = 200 -- Starting height, will expand

        -- Dynamically calculate menu height based on content.
        -- 8 stats + "Moves:" label + 1 line for bottom padding = 10 lines.
        local numStats = 10
        local lineHeight = 18
        local contentHeight = 20 + numStats * lineHeight + (#unit.attacks) * lineHeight --Title + stats height
        menuHeight = math.max(menuHeight, contentHeight)

        -- Draw background
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
        love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
        love.graphics.setColor(0.8, 0.8, 0.9, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
        love.graphics.setLineWidth(1)

        -- Set text color
        love.graphics.setColor(1, 1, 1, 1)
        -- Draw unit name and type at the top
        local unitName = unit.displayName
        if not unitName then
           if unit.enemyType then
               unitName = unit.enemyType -- For enemies
           else
               unitName = "Unit" -- Default label
           end
        end
        love.graphics.print(unitName .. " (" .. unit.originType .. ")", menuX + 10, menuY + 10)
        local yOffset = menuY + 30
        love.graphics.print("HP: " .. math.floor(unit.hp) .. " / " .. unit.maxHp, menuX + 10, yOffset) yOffset = yOffset + lineHeight
        love.graphics.print("Wisp: " .. math.floor(unit.wisp) .. " / " .. unit.maxWisp, menuX + 10, yOffset) yOffset = yOffset + lineHeight
        love.graphics.print("Attack: " .. unit.attackStat, menuX + 10, yOffset) yOffset = yOffset + lineHeight
        love.graphics.print("Defense: " .. unit.defenseStat, menuX + 10, yOffset) yOffset = yOffset + lineHeight
        love.graphics.print("Magic: " .. unit.magicStat, menuX + 10, yOffset) yOffset = yOffset + lineHeight
        love.graphics.print("Resistance: " .. unit.resistanceStat, menuX + 10, yOffset) yOffset = yOffset + lineHeight
        love.graphics.print("Wit: " .. unit.witStat, menuX + 10, yOffset) yOffset = yOffset + lineHeight
        love.graphics.print("Weight: " .. unit.weight, menuX + 10, yOffset) yOffset = yOffset + lineHeight
        love.graphics.print("Moves: ", menuX + 10, yOffset) yOffset = yOffset + lineHeight
        -- List known moves below stats
        for i = 1, #unit.attacks do
            local attackName = unit.attacks[i]
            local attackData = AttackBlueprints[attackName]
            if attackData then -- Ensure attack data exists
                love.graphics.print("- " .. attackName, menuX + 10, yOffset)
                yOffset = yOffset + lineHeight
            else
                -- Log missing attack data and skip printing.
                print("Warning: Attack data not found for: " .. attackName)
            end
        end
    end
end

return UnitInfoMenu