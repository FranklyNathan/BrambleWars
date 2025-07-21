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
        -- Set color based on whether the damage was a critical hit.
        if pending.isCrit then
            love.graphics.setColor(1, 1, 0.2, 1 * globalAlpha) -- Yellow for crit pending damage
        else
            love.graphics.setColor(1, 1, 1, 1 * globalAlpha) -- White for normal pending damage
        end
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
    love.graphics.setColor(0.7, 0.1, 0.1, 0.8 * alpha) -- Left (Enemy) Panel - Red
    love.graphics.rectangle("fill", startX, startY, panelWidth, displayHeight)
    love.graphics.setColor(0.1, 0.1, 0.7, 0.8 * alpha) -- Right (Player) Panel - Blue
    love.graphics.rectangle("fill", startX + panelWidth, startY, panelWidth, displayHeight)
    love.graphics.setColor(0.9, 0.9, 0.9, 0.85 * alpha) -- Border
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

    -- 1. Group displays by their attackInstanceId. This allows for multiple, separate combat stacks.
    local displayGroups = {}
    local nextGroupId = 1 -- A counter for displays that don't have an ID.
    for _, display in ipairs(world.liveCombatDisplays) do
        local groupId = display.attackInstanceId
        if not groupId then
            -- If a display has no ID, give it a unique group so it's drawn by itself.
            groupId = "no_id_" .. nextGroupId
            nextGroupId = nextGroupId + 1
        end

        if not displayGroups[groupId] then
            displayGroups[groupId] = {}
        end
        table.insert(displayGroups[groupId], display)
    end

    -- 2. Iterate over each group and draw it as a self-contained stack.
    for _, group in pairs(displayGroups) do
        -- 2a. Collect all units involved in this specific group.
        local allUnits = {}
        local unitIds = {}
        for _, display in ipairs(group) do
            if not unitIds[display.attacker] then table.insert(allUnits, display.attacker); unitIds[display.attacker] = true; end
            if not unitIds[display.defender] then table.insert(allUnits, display.defender); unitIds[display.defender] = true; end
        end

        if #allUnits > 0 then
            -- 2b. Find the bounding box of all involved units in this group.
            local topUnitY, bottomUnitY, bottomUnitSize, totalX = math.huge, -math.huge, 0, 0
            for _, unit in ipairs(allUnits) do
                topUnitY = math.min(topUnitY, unit.y)
                if unit.y >= bottomUnitY then bottomUnitY, bottomUnitSize = unit.y, unit.size end
                totalX = totalX + unit.x
            end

            -- 2c. Determine vertical positioning for this stack.
            local displayWidth, displayHeight, verticalOffset, stackSpacing = 360, 50, 10, 5
            local totalStackHeight = #group * displayHeight + (#group - 1) * stackSpacing
            local belowY = bottomUnitY + bottomUnitSize + verticalOffset
            local aboveY = topUnitY - totalStackHeight - verticalOffset
            local belowIsVisible = (belowY + totalStackHeight) < (Camera.y + Config.VIRTUAL_HEIGHT)
            local aboveIsVisible = aboveY > Camera.y

            local baseStartY, stackGrowsUp = belowY, false
            if belowIsVisible then
                baseStartY = belowY
            elseif aboveIsVisible then
                baseStartY = aboveY
            else
                -- Neither position is fully visible. Default to the bottom of the screen,
                -- and make the stack grow upwards from there to ensure visibility.
                baseStartY = Camera.y + Config.VIRTUAL_HEIGHT - 5 -- Anchor at the bottom of the screen (with padding)
                stackGrowsUp = true
            end

            -- 2d. Determine horizontal positioning for this stack.
            local avgX = totalX / #allUnits
            local startX = avgX + (Config.SQUARE_SIZE / 2) - (displayWidth / 2)

            -- 2e. Draw each display in this group's stack.
            if stackGrowsUp then
                -- Draw from bottom to top. The baseStartY is the bottom edge of the stack.
                for i = 1, #group do
                    local stackIndex = #group - i
                    local currentY = baseStartY - displayHeight - (stackIndex * (displayHeight + stackSpacing))
                    draw_single_display(group[i], startX, currentY, world)
                end
            else
                -- Draw from top to bottom (original logic). The baseStartY is the top edge of the stack.
                for i, display in ipairs(group) do
                    local currentY = baseStartY + (i - 1) * (displayHeight + stackSpacing)
                    draw_single_display(display, startX, currentY, world)
                end
            end
        end
    end
end

return LiveCombatDisplay