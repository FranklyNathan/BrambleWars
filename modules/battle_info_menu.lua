-- modules/battle_info_menu.lua
-- Contains the drawing logic for the battle forecast UI.

local Camera = require("modules.camera")
local BattleInfoMenu = {}

function BattleInfoMenu.draw(world)
    if not world.battleInfoMenu or not world.battleInfoMenu.active then
        return
    end

    local menu = world.battleInfoMenu
    local font = love.graphics.getFont()
    local lineHeight = 18

    -- Menu dimensions and position (bottom center)
    local menuWidth = 220
    -- Dynamically calculate menu height
    local numDataRows = 5
    local headerHeight = 25 -- Space for title and headers
    local menuHeight = headerHeight + (numDataRows * lineHeight) + 10 -- Add 10px for padding

    -- Position the menu next to the target unit.
    local target = menu.target
    local screenTargetX = target.x - Camera.x
    local screenTargetY = target.y - Camera.y

    local menuX = screenTargetX + target.size + 5 -- Position it to the right of the unit
    local menuY = screenTargetY

    -- Clamp menu position to stay on screen
    if menuX + menuWidth > Config.VIRTUAL_WIDTH then menuX = screenTargetX - menuWidth - 5 end
    if menuY + menuHeight > Config.VIRTUAL_HEIGHT then menuY = Config.VIRTUAL_HEIGHT - menuHeight end
    menuX = math.max(0, menuX)
    menuY = math.max(0, menuY)
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.85)
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
    love.graphics.setColor(0.8, 0.8, 0.9, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
    love.graphics.setLineWidth(1)

    -- Set text color
    love.graphics.setColor(1, 1, 1, 1)

    -- Title
    local title = "Battle Forecast"
    love.graphics.printf(title, menuX, menuY + 5, menuWidth, "center")

    -- Column Headers
    local yOffset = menuY + 25
    local playerColX = menuX + 90
    local enemyColX = menuX + 160
    love.graphics.setColor(0.6, 0.6, 1, 1) -- Player color (Blue)
    love.graphics.print("Player", playerColX, yOffset)
    love.graphics.setColor(1, 0.6, 0.6, 1) -- Enemy color (Red)
    love.graphics.print("Enemy", enemyColX, yOffset)

    -- Row Data
    love.graphics.setColor(1, 1, 1, 1) -- Reset to white for labels
    yOffset = yOffset + lineHeight
    love.graphics.print("Health:", menuX + 10, yOffset)
    love.graphics.setColor(0.6, 0.6, 1, 1)
    love.graphics.print(menu.playerHP, playerColX, yOffset)
    love.graphics.setColor(1, 0.6, 0.6, 1)
    love.graphics.print(tostring(menu.enemyHP), enemyColX, yOffset)

    love.graphics.setColor(1, 1, 1, 1)
    yOffset = yOffset + lineHeight
    love.graphics.print(menu.playerActionLabel or "Damage:", menuX + 10, yOffset)
    love.graphics.setColor(0.6, 0.6, 1, 1)
    love.graphics.print(menu.playerDamage, playerColX, yOffset)
    love.graphics.setColor(1, 0.6, 0.6, 1)
    love.graphics.print(tostring(menu.enemyDamage), enemyColX, yOffset)

    love.graphics.setColor(1, 1, 1, 1)
    yOffset = yOffset + lineHeight
    love.graphics.print("Hit %:", menuX + 10, yOffset)
    love.graphics.setColor(0.6, 0.6, 1, 1)
    love.graphics.print(menu.playerHitChance, playerColX, yOffset)
    love.graphics.setColor(1, 0.6, 0.6, 1)
    love.graphics.print(tostring(menu.enemyHitChance), enemyColX, yOffset)

    love.graphics.setColor(1, 1, 1, 1)
    yOffset = yOffset + lineHeight
    love.graphics.print("Crit %:", menuX + 10, yOffset)
    love.graphics.setColor(0.6, 0.6, 1, 1)
    love.graphics.print(menu.playerCritChance, playerColX, yOffset)
    love.graphics.setColor(1, 0.6, 0.6, 1)
    love.graphics.print(tostring(menu.enemyCritChance), enemyColX, yOffset)
end

return BattleInfoMenu