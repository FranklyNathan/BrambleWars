-- modules/live_combat_display.lua
-- Contains the drawing logic for the live combat UI that appears during attacks.

local Camera = require("modules.camera")
local LiveCombatDisplay = {}

-- A specialized health bar for the UI.
local function draw_ui_health_bar(unit, x, y, width, height, globalAlpha)
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 1 * globalAlpha)
    love.graphics.rectangle("fill", x, y, width, height)

    local healthColor = (unit.type == "enemy") and {1, 0, 0, 1} or {0, 1, 0, 1}

    -- Pending damage (white bar)
    if unit.components.pending_damage and unit.components.pending_damage.displayAmount then
        local pending = unit.components.pending_damage
        -- Ensure we don't draw a bar wider than the max width if there's overkill pending damage.
        local totalHealth = math.min(unit.maxHp, unit.hp + pending.displayAmount)
        local totalHealthBeforeDrainWidth = (totalHealth / unit.maxHp) * width
        love.graphics.setColor(1, 1, 1, 1 * globalAlpha)
        love.graphics.rectangle("fill", x, y, totalHealthBeforeDrainWidth, height)
    end

    -- Current health
    local currentHealthWidth = (unit.hp / unit.maxHp) * width
    love.graphics.setColor(healthColor[1], healthColor[2], healthColor[3], 1 * globalAlpha)
    love.graphics.rectangle("fill", x, y, currentHealthWidth, height)

    -- HP Text
    local hpText = math.floor(unit.hp) .. " / " .. unit.maxHp
    love.graphics.setColor(1, 1, 1, 1 * globalAlpha)
    love.graphics.printf(hpText, x, y + 1, width, "center")
end

-- Draws a single combat display panel.
local function draw_single_display(display, startX, startY, world)
    local player, enemy
    if display.attacker.type == 'player' then
        player = display.attacker
        enemy = display.defender
    else
        player = display.defender
        enemy = display.attacker
    end

    if not player or not enemy then return end

    -- Dimensions and panel width
    local displayWidth = 360
    local displayHeight = 50
    local panelWidth = displayWidth / 2

    -- Apply shake effect for critical hits
    if display.shake then
        local intensity = display.shake.intensity or 4
        startX = startX + math.random(-intensity, intensity)
        startY = startY + math.random(-intensity, intensity)
    end

    -- Fade out effect
    local alpha = 1.0
    if display.timer < 0.25 then
        alpha = display.timer / 0.25
    end

    -- Draw Panels
    love.graphics.setColor(0.7, 0.1, 0.1, 0.6 * alpha) -- Left (Enemy) Panel - Red
    love.graphics.rectangle("fill", startX, startY, panelWidth, displayHeight)
    love.graphics.setColor(0.1, 0.1, 0.7, 0.6 * alpha) -- Right (Player) Panel - Blue
    love.graphics.rectangle("fill", startX + panelWidth, startY, panelWidth, displayHeight)
    love.graphics.setColor(0.9, 0.9, 0.9, 0.7 * alpha) -- Border
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", startX, startY, displayWidth, displayHeight)

    -- Draw Names
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf(enemy.displayName, startX, startY + 4, panelWidth, "center")
    love.graphics.printf(player.displayName, startX + panelWidth, startY + 4, panelWidth, "center")

    -- Draw Health Bars and HP Text
    local barWidth = panelWidth - 20
    local barHeight = 15
    local barY = startY + displayHeight - barHeight - 8
    draw_ui_health_bar(enemy, startX + 10, barY, barWidth, barHeight, alpha)
    draw_ui_health_bar(player, startX + panelWidth + 10, barY, barWidth, barHeight, alpha)
end

function LiveCombatDisplay.draw(world)
    if not world.liveCombatDisplays or #world.liveCombatDisplays == 0 then return end

    -- 1. Collect all units involved to determine the overall position.
    local allUnits = {}
    local unitIds = {}
    for _, display in ipairs(world.liveCombatDisplays) do
        if not unitIds[display.attacker] then
            table.insert(allUnits, display.attacker)
            unitIds[display.attacker] = true
        end
        if not unitIds[display.defender] then
            table.insert(allUnits, display.defender)
            unitIds[display.defender] = true
        end
    end

    -- 2. Find the bounding box of all involved units.
    local topUnitY = math.huge
    local bottomUnitY = -math.huge
    local bottomUnitSize = 0
    local totalX = 0
    for _, unit in ipairs(allUnits) do
        topUnitY = math.min(topUnitY, unit.y)
        if unit.y >= bottomUnitY then
            bottomUnitY = unit.y
            bottomUnitSize = unit.size
        end
        totalX = totalX + unit.x
    end

    -- 3. Determine vertical positioning for the *entire stack*.
    local displayWidth = 360
    local displayHeight = 50
    local verticalOffset = 10 -- Space between unit and display
    local stackSpacing = 5 -- Space between stacked displays
    local totalStackHeight = #world.liveCombatDisplays * displayHeight + (#world.liveCombatDisplays - 1) * stackSpacing

    -- Potential Y positions for the TOP of the stack
    local belowY = bottomUnitY + bottomUnitSize + verticalOffset
    local aboveY = topUnitY - totalStackHeight - verticalOffset

    -- Check if these positions are visible within the camera's current view.
    local belowIsVisible = (belowY + totalStackHeight) < (Camera.y + Config.VIRTUAL_HEIGHT)
    local aboveIsVisible = aboveY > Camera.y

    local baseStartY
    if belowIsVisible then
        baseStartY = belowY
    elseif aboveIsVisible then
        baseStartY = aboveY
    else
        baseStartY = belowY -- Default to below
    end

    -- 4. Determine horizontal positioning: Center on the average position
    local avgX = totalX / #allUnits
    local startX = avgX + (Config.SQUARE_SIZE / 2) - (displayWidth / 2)

    -- 5. Draw each display in the stack.
    for i, display in ipairs(world.liveCombatDisplays) do
        -- Calculate the Y position for this specific display in the stack.
        local currentY = baseStartY + (i - 1) * (displayHeight + stackSpacing)
        draw_single_display(display, startX, currentY, world)
    end
end

return LiveCombatDisplay