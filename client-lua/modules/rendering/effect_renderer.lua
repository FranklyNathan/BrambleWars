-- modules/rendering/effect_renderer.lua
-- Contains all drawing logic for visual effects.

local Assets = require("modules.assets")
local Grid = require("modules.grid")
local AttackBlueprints = require("data.attack_blueprints")
local WorldQueries = require("modules.world_queries")

local EffectRenderer = {}

local function drawAfterimages(world)
    for _, a in ipairs(world.afterimageEffects) do
        if a.frame and a.spriteSheet and Assets.shaders.solid_color then
            love.graphics.setShader(Assets.shaders.solid_color)
            local alpha = (a.lifetime / a.initialLifetime) * 0.5 -- Max 50% transparent
            Assets.shaders.solid_color:send("solid_color", {a.color[1], a.color[2], a.color[3], alpha})
            local drawX = a.x + a.size / 2
            local drawY = a.y + a.size
            local w, h = a.width, a.height
            love.graphics.draw(a.spriteSheet, a.frame, drawX, drawY, 0, 1, 1, w / 2, h)
            love.graphics.setShader() -- Reset to default shader
        else
            local alpha = (a.lifetime / a.initialLifetime) * 0.5
            love.graphics.setColor(a.color[1], a.color[2], a.color[3], alpha)
            love.graphics.rectangle("fill", a.x, a.y, a.size, a.size)
        end
    end
end

local function drawAscensionShadows(world)
    for _, shadowData in ipairs(world.ascension_shadows) do
        local pixelX, pixelY = Grid.toPixels(shadowData.tileX, shadowData.tileY)
        local centerX = pixelX + Config.SQUARE_SIZE / 2
        local centerY = pixelY + Config.SQUARE_SIZE / 2
        local alpha = 0.3 + (math.sin(love.timer.getTime() * 4) + 1) / 2 * 0.2 -- Pulsates between 0.3 and 0.5 alpha
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.ellipse("fill", centerX, centerY, 14, 7)
    end
end

local function drawAttackEffects(world)
    for _, effect in ipairs(world.attackEffects) do
        -- Only draw if the initial delay has passed
        if effect.initialDelay <= 0 then
            -- Check the attack's blueprint to see if it should draw a tile.
            local attackData = effect.attackName and AttackBlueprints[effect.attackName]
            if attackData and attackData.drawsTile then
                -- Calculate alpha for flashing effect (e.g., fade out)
                local alpha = effect.currentFlashTimer / effect.flashDuration
                love.graphics.setColor(effect.color[1], effect.color[2], effect.color[3], alpha) -- Use effect's color
                love.graphics.rectangle("fill", effect.x, effect.y, effect.width, effect.height)
            end
        end
    end
end

local function drawProjectiles(world)
    for _, projectile in ipairs(world.projectiles) do
        love.graphics.setColor(1, 0.5, 0, 1) -- Orange/red color for projectiles
        love.graphics.rectangle("fill", projectile.x, projectile.y, projectile.size, projectile.size)
    end
end

local function drawParticles(world)
    for _, p in ipairs(world.particleEffects) do
        -- Fade out the particle as its lifetime decreases
        local alpha = (p.lifetime / p.initialLifetime)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
    end
end

local function drawDamagePopups(world)
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
    for _, p in ipairs(world.damagePopups) do
        local alpha = (p.lifetime / p.initialLifetime)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.print(p.text, p.x, p.y)
    end
end

local function drawGrappleHooks(world)
    -- Iterate only over the grapple hooks, not all entities, for better performance.
    for _, entity in ipairs(world.grapple_hooks) do
        if entity.components.grapple_hook then
            local hookComp = entity.components.grapple_hook
            local attacker = hookComp.attacker

            -- Draw the hook itself
            love.graphics.setColor(entity.color)
            love.graphics.rectangle("fill", entity.x, entity.y, entity.size, entity.size)

            -- Draw the line from the attacker to the hook
            if attacker then
                love.graphics.setColor(1, 0.4, 0.7, 1) -- Pink color for the grapple line
                love.graphics.setLineWidth(2)
                local x1, y1 = attacker.x + attacker.size / 2, attacker.y + attacker.size / 2
                local x2, y2 = entity.x + entity.size / 2, entity.y + entity.size / 2
                love.graphics.line(x1, y1, x2, y2)
                love.graphics.setLineWidth(1) -- Reset
            end
        end
    end
end

function EffectRenderer.drawBackground(world)
    drawAfterimages(world)
    drawAscensionShadows(world)
end

function EffectRenderer.drawForeground(world)
    drawAttackEffects(world)
    drawProjectiles(world)
    drawParticles(world)
    drawDamagePopups(world)
    drawGrappleHooks(world)
end

return EffectRenderer