-- systems/exp_bar_renderer_system.lua
-- This system is dedicated to drawing the EXP gain animation bar.
-- By separating the drawing, we can ensure it's rendered on top of other elements.

local WorldQueries = require("modules.world_queries")
local ExpBarRendererSystem = {}

function ExpBarRendererSystem.draw(world)
    local anim = world.ui.expGainAnimation
    -- Only draw if the animation is active and has a valid unit.
    if anim and anim.active and anim.unit then
        local unit = anim.unit
        
        -- Failsafe: Don't draw if the unit is marked for deletion.
        if unit.isMarkedForDeletion then return end

        -- Positioning the bar below the unit.
        -- We use the unit's current pixel position (x, y) for smooth following.
        local barW = unit.size
        local barH = 6 -- Matches the HP bar height

        -- Dynamically calculate the Y position to be directly below the HP bar.
        local hpBarHeight = WorldQueries.getUnitHealthBarHeight(unit, world)
        -- The HP bar's top Y position is calculated relative to the unit's bottom edge.
        local hpBarTopY = math.floor(unit.y + unit.size - 2)

        local barX = math.floor(unit.x)
        -- The EXP bar should start exactly where the HP bar ends, sharing a border.
        local barY = hpBarTopY + hpBarHeight

        -- 1. Draw the outer black frame first.
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", barX, barY, barW, barH)

        -- 2. Define the inner area for the content.
        local innerX, innerY = barX + 1, barY + 1
        local innerW, innerH = barW - 2, barH - 2

        -- 3. Draw the inner background (the empty part of the bar).
        love.graphics.setColor(0.1, 0.1, 0.1, 1)
        love.graphics.rectangle("fill", innerX, innerY, innerW, innerH)

        -- 4. Draw the EXP portions on top of the inner background.
        local startRatio = 0
        if unit.maxExp > 0 then
            startRatio = math.max(0, math.min(1, anim.expStart / unit.maxExp))
        end
        local startWidth = math.floor(innerW * startRatio)
        
        -- Draw the yellow portion for existing EXP.
        if startWidth > 0 then
            love.graphics.setColor(1, 0.9, 0.2, 1) -- A nice golden yellow
            love.graphics.rectangle("fill", innerX, innerY, startWidth, innerH)
        end

        local currentRatio = 0
        if unit.maxExp > 0 then
            currentRatio = math.max(0, math.min(1, anim.expCurrentDisplay / unit.maxExp))
        end
        local currentWidth = math.floor(innerW * currentRatio)

        local gainedWidth = currentWidth - startWidth
        if gainedWidth > 0 then
            love.graphics.setColor(0, 1, 1, 1) -- Cyan for the filling part
            love.graphics.rectangle("fill", innerX + startWidth, innerY, gainedWidth, innerH)
        end

        -- Reset color to white for other drawing operations.
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return ExpBarRendererSystem