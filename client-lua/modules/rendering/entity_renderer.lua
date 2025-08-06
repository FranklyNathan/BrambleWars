-- modules/rendering/entity_renderer.lua
-- Handles drawing a single entity and its various parts

local Assets = require("modules.assets")
local Camera = require("modules.camera")
local Grid = require("modules.grid")
local WorldQueries = require("modules.world_queries")

local EntityRenderer = {}

function EntityRenderer.drawHealthBar(square, world)
    local inCombat = WorldQueries.isUnitInCombat(square, world)
    local barWidth = square.size
    local barHeight
    if square.components.shrinking_health_bar then
        local shrink = square.components.shrinking_health_bar
        local progress = shrink.timer / shrink.initialTimer
        barHeight = math.floor(6 + (6 * progress)) -- Lerp from 12 down to 6
    else
        barHeight = inCombat and 12 or 6 -- Slightly shorter than before, but still taller than original
    end
    local barYOffset = square.size - 2 -- Positioned slightly overlapping the unit's bottom edge
    -- Floor the coordinates to ensure crisp, pixel-perfect rendering and prevent anti-aliasing.
    local x, y = math.floor(square.x), math.floor(square.y + barYOffset)

    -- 1. Draw the outer black frame first. This guarantees a crisp, 1px border.
    love.graphics.setColor(0, 0, 0, 1) -- Black
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)

    -- 2. Define the inner area for the health content.
    local innerX, innerY = x + 1, y + 1
    local innerWidth, innerHeight = barWidth - 2, barHeight - 2

    -- 3. Draw the inner background (the empty part of the bar).
    love.graphics.setColor(0.1, 0.1, 0.1, 1) -- Dark background for the empty part
    love.graphics.rectangle("fill", innerX, innerY, innerWidth, innerHeight)

    -- 4. Draw pending damage and current health bars on top of the inner background.
    -- We draw the segments separately to avoid overdraw and ensure shaders apply correctly.
    local healthColor
    if square.isObstacle then
        healthColor = {1, 0.6, 0, 1} -- Orange for obstacles
    elseif square.type == "enemy" then
        healthColor = {1, 0.2, 0.2, 1} -- Red for enemies
    elseif square.type == "neutral" then
        healthColor = {0.2, 0.8, 1, 1} -- Light blue for neutrals
    else -- player
        healthColor = {0.2, 1, 0.2, 1} -- Green for players
    end

    -- First, draw the current health portion with the shader.
    local currentHealthWidth = math.floor((square.hp / square.maxHp) * innerWidth)
    if currentHealthWidth > 0 then
        love.graphics.setColor(healthColor)
        love.graphics.rectangle("fill", innerX, innerY, currentHealthWidth, innerHeight)
    end

    -- Next, draw the pending damage portion right next to the current health.
    if square.components.pending_damage and square.components.pending_damage.displayAmount then
        local pending = square.components.pending_damage
        local totalHealth = math.min(square.maxHp, square.hp + pending.displayAmount)
        local totalHealthWidth = math.floor((totalHealth / square.maxHp) * innerWidth)
        local pendingDamageWidth = totalHealthWidth - currentHealthWidth
        if pendingDamageWidth > 0 then
            local pendingColor = pending.isCrit and {1, 1, 0.2, 1} or {1, 1, 1, 1} -- Yellow for crit, white for normal
            love.graphics.setColor(pendingColor)
            love.graphics.rectangle("fill", innerX + currentHealthWidth, innerY, pendingDamageWidth, innerHeight)
        end
    end
    -- 5. If shielded, draw an outline around the health bar.
    if square.components.shielded then
        love.graphics.setColor(0.7, 0.7, 1, 0.8) -- Light blue
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x - 1, y - 1, barWidth + 2, barHeight + 2)
        love.graphics.setLineWidth(1) -- Reset
    end
end

-- Draws the EXP bar for a unit, but only if an EXP gain animation is active for it.
local function drawExpBar(unit, world)
    local anim = world.ui.expGainAnimation
    -- Only draw if the animation is active for this specific unit.
    if not anim or not anim.active or anim.unit ~= unit then
        return
    end

    -- Bar positioning
    local hpBarHeight = WorldQueries.getUnitHealthBarHeight(unit, world)
    local hpBarTopY = math.floor(unit.y + unit.size - 2)
    local barY = hpBarTopY + hpBarHeight -- Position directly below the health bar

    -- Bar dimensions
    local barWidth, barHeight = unit.size, 6
    local x = math.floor(unit.x)

    -- 1. Draw outer black frame
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", x, barY, barWidth, barHeight)

    -- 2. Define inner area and draw its background
    local innerX, innerY = x + 1, barY + 1
    local innerWidth, innerHeight = barWidth - 2, barHeight - 2
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", innerX, innerY, innerWidth, innerHeight)

    -- 4. Draw EXP fill
    local expRatio = anim.expCurrentDisplay / (unit.maxExp or 100)
    local fillWidth = math.min(innerWidth, math.floor(expRatio * innerWidth))
    if fillWidth > 0 then
        love.graphics.setColor(0.6, 0.2, 0.8, 1) -- Purple color for EXP
        love.graphics.rectangle("fill", innerX, innerY, fillWidth, innerHeight)
    end
end

function EntityRenderer.drawAllBars(entity, world)
   EntityRenderer.drawHealthBar(entity, world)
   -- Only draw the wisp and exp bars if the unit is not in combat, to reduce clutter.
   if not WorldQueries.isUnitInCombat(entity, world) then
       drawExpBar(entity, world)
       EntityRenderer.drawWispBar(entity, world)
   end
end

-- Calculates the final Y position and rotation for an entity, accounting for airborne and bobbing effects.
-- Also draws the shadow for airborne units.
local function calculate_visual_offsets(entity, currentAnim, drawX, baseDrawY)
    local visualYOffset = 0
    local rotation = 0

    if entity.statusEffects.airborne then
        local effect = entity.statusEffects.airborne
        local totalDuration = effect.totalDuration or 2 -- The initial duration of the airborne effect, default to 2.
        local timeElapsed = totalDuration - effect.duration
        local progress = math.min(1, timeElapsed / totalDuration)

        -- Draw shadow on the ground. It fades as the entity goes up.
        local shadowAlpha = 0.4 * (1 - math.sin(progress * math.pi))
        love.graphics.setColor(0, 0, 0, shadowAlpha)
        love.graphics.ellipse("fill", drawX, baseDrawY, 12, 6)

        -- Calculate visual offset for the "pop up" and rotation
        visualYOffset = -math.sin(progress * math.pi) * 40 -- Max height of 40px
        rotation = progress * (2 * math.pi) -- Full 360-degree rotation over the duration
    end

    -- Add a bobbing effect when idle and not airborne.
    local bobbingOffset = 0
    if currentAnim.status == "paused" and not entity.statusEffects.airborne and not entity.hasActed then
        bobbingOffset = math.sin(love.timer.getTime() * 8) -- Bob up and down 1 pixel
    end

    local finalDrawY = baseDrawY + visualYOffset + bobbingOffset
    return finalDrawY, rotation
end

-- Draws shader-based overlays for visual effects like damage tint and status effects.
local function draw_visual_effect_overlays(entity, currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation, baseAlpha)
    if not Assets.shaders.solid_color then return end

    -- If poisoned, draw a semi-transparent pulsating overlay on top.
    if entity.statusEffects.poison then
        love.graphics.setShader(Assets.shaders.solid_color)
        local pulse = (math.sin(love.timer.getTime() * 8) + 1) / 2
        local effectAlpha = 0.2 + pulse * 0.3
        Assets.shaders.solid_color:send("solid_color", {0.6, 0.2, 0.8, effectAlpha * baseAlpha})
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
    end

    -- If paralyzed, draw a semi-transparent pulsating overlay on top.
    if entity.statusEffects.paralyzed then
        love.graphics.setShader(Assets.shaders.solid_color)
        local pulse = (math.sin(love.timer.getTime() * 6) + 1) / 2
        local effectAlpha = 0.1 + pulse * 0.3
        Assets.shaders.solid_color:send("solid_color", {1.0, 1.0, 0.2, effectAlpha * baseAlpha})
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
    end

    -- If taunted, draw a semi-transparent pulsating red overlay.
    if entity.statusEffects.taunted then
        love.graphics.setShader(Assets.shaders.solid_color)
        local pulse = (math.sin(love.timer.getTime() * 8) + 1) / 2 -- 0 to 1
        local effectAlpha = 0.2 + pulse * 0.3 -- 0.2 to 0.5
        Assets.shaders.solid_color:send("solid_color", {1.0, 0.2, 0.2, effectAlpha * baseAlpha})
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
    end

    -- If invincible, draw a semi-transparent pulsating gold overlay.
    if entity.statusEffects.invincible then
        love.graphics.setShader(Assets.shaders.solid_color)
        local pulse = (math.sin(love.timer.getTime() * 6) + 1) / 2 -- 0 to 1
        local effectAlpha = 0.3 + pulse * 0.3 -- 0.3 to 0.6
        Assets.shaders.solid_color:send("solid_color", {1.0, 0.85, 0.2, effectAlpha * baseAlpha}) -- Gold color
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
    end

    -- If stunned, draw a static purple overlay.
    if entity.statusEffects.stunned then
        love.graphics.setShader(Assets.shaders.solid_color)
        Assets.shaders.solid_color:send("solid_color", {0.5, 0, 0.5, 0.5 * baseAlpha})
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
    end

    -- If the unit just took damage, draw a brief white flash that fades out.
    -- This is drawn last so it appears on top of other status overlays.
    if entity.components.damage_tint then
        love.graphics.setShader(Assets.shaders.solid_color)
        -- The flash fades out as the timer runs down.
        local effectAlpha = (entity.components.damage_tint.timer / entity.components.damage_tint.initialTimer)
        Assets.shaders.solid_color:send("solid_color", {1, 1, 1, effectAlpha * baseAlpha}) -- White flash
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
    end
end

-- Draws shader-based overlays for game states, like "has acted" or "is selected".
local function draw_state_overlays(entity, is_active_player, currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation, clipRatio)
    -- Dying units should not have state overlays.
    if entity.components.fade_out then return end

    -- If the unit is submerged, set up the scissor clipping for all state overlays.
    -- This ensures that effects like the greyscale overlay are also clipped correctly.
    local oldScissor = {love.graphics.getScissor()}
    if clipRatio then
        -- The sprite is drawn anchored at bottom-center. Its top-left corner in world space is at
        -- (drawX - w / 2, finalDrawY - h).
        -- We want to set a scissor for the top portion of the sprite's area.
        local scissorWorldX = drawX - w / 2
        local scissorWorldY = finalDrawY - h
        local scissorWorldW = w
        local scissorWorldH = h * clipRatio
        -- Convert world coordinates to screen coordinates for the scissor.
        love.graphics.setScissor(scissorWorldX - Camera.x, scissorWorldY - Camera.y, scissorWorldW, scissorWorldH)
    end

    -- If the unit has acted, draw a greyscale version on top of everything else.
    if entity.hasActed and Assets.shaders.greyscale then
        love.graphics.setShader(Assets.shaders.greyscale)
        Assets.shaders.greyscale:send("strength", 1.0)
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
    end
 
    -- If this is the active player, draw the outline on top as an overlay.
    if is_active_player and Assets.shaders.outline then
        love.graphics.setShader(Assets.shaders.outline)
        Assets.shaders.outline:send("outline_color", {1.0, 1.0, 1.0, 1.0})
        Assets.shaders.outline:send("texture_size", {spriteSheet:getWidth(), spriteSheet:getHeight()})
        Assets.shaders.outline:send("outline_only", true)
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
    end

    -- Reset the scissor regardless of whether it was set. This restores the clipping
    -- rectangle to its previous state (usually the full screen).
    love.graphics.setScissor(unpack(oldScissor))
end

local function apply_shake_transform(entity)
    if entity.components.shake then
        local shake = entity.components.shake
        local offsetX, offsetY = 0, 0
        if shake.direction == "horizontal" then
            offsetX = math.random(-shake.intensity, shake.intensity)
        elseif shake.direction == "vertical" then
            offsetY = math.random(-shake.intensity, shake.intensity)
        else
            offsetX = math.random(-shake.intensity, shake.intensity)
            offsetY = math.random(-shake.intensity, shake.intensity)
        end
        love.graphics.translate(offsetX, offsetY)
    end
end

local function calculate_draw_position(entity)
    -- Base position is bottom-center of the entity's logical tile.
    local drawX = entity.x + entity.size / 2
    local baseDrawY = entity.y + entity.size

    -- Apply lunge effect offset if present.
    if entity.components.lunge then
        local lunge = entity.components.lunge
        local max_lunge_amount = 10
        local progress = 1 - (lunge.timer / lunge.initialTimer)
        local current_lunge_amount = max_lunge_amount * math.sin(progress * math.pi)

        if lunge.direction == "up" then baseDrawY = baseDrawY - current_lunge_amount end
        if lunge.direction == "down" then baseDrawY = baseDrawY + current_lunge_amount end
        if lunge.direction == "left" then drawX = drawX - current_lunge_amount end
        if lunge.direction == "right" then drawX = drawX + current_lunge_amount end
    end

    -- Apply knockback effect offset if present.
    if entity.components.knockback_animation then
        local knockback = entity.components.knockback_animation
        local max_knockback_amount = knockback.distance or 8
        local progress = 1 - (knockback.timer / knockback.initialTimer)
        local current_knockback_amount = max_knockback_amount * math.sin(progress * math.pi)

        if knockback.direction == "up" then baseDrawY = baseDrawY - current_knockback_amount end
        if knockback.direction == "down" then baseDrawY = baseDrawY + current_knockback_amount end
        if knockback.direction == "left" then drawX = drawX - current_knockback_amount end
        if knockback.direction == "right" then drawX = drawX + current_knockback_amount end
    end

    return drawX, baseDrawY
end

local function calculate_alpha_and_vertical_offset(entity, finalDrawY)
    local baseAlpha = 1
    if entity.components.sinking then
        local sinking = entity.components.sinking
        local progress = 1 - (sinking.timer / sinking.initialTimer)
        finalDrawY = finalDrawY + progress * entity.size
        baseAlpha = 1 - progress
    elseif entity.components.reviving then
        local reviving = entity.components.reviving
        local progress = 1 - (reviving.timer / reviving.initialTimer)
        finalDrawY = finalDrawY + (1 - progress) * entity.size
        baseAlpha = progress
    elseif entity.components.fade_out then
        baseAlpha = entity.components.fade_out.timer / entity.components.fade_out.initialTimer
    end
    return baseAlpha, finalDrawY
end

local function get_clipping_ratio(entity, world)
    local onWater = entity.canSwim and WorldQueries.isTileWater(entity.tileX, entity.tileY, world)
    local inMud = (not entity.isFlying) and WorldQueries.isTileMud(entity.tileX, entity.tileY, world)
    if onWater then
        return 0.7 -- Show top 70% (hide 30%)
    elseif inMud then
        return 0.75 -- Show top 75% (hide 25%)
    end
    return nil
end

local function draw_base_sprite(currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation, baseAlpha, clipRatio, entity)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, baseAlpha)

    if clipRatio and not entity.components.sinking then
        local oldScissor = {love.graphics.getScissor()}
        local scissorWorldX = drawX - w / 2
        local scissorWorldY = finalDrawY - h
        local scissorWorldW = w
        local scissorWorldH = h * clipRatio
        love.graphics.setScissor(scissorWorldX - Camera.x, scissorWorldY - Camera.y, scissorWorldW, scissorWorldH)
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
        love.graphics.setScissor(unpack(oldScissor))
    else
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
    end
end

local function draw_selection_flash(entity, currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation, baseAlpha)
    if not entity.components.selection_flash then return end

    local flash = entity.components.selection_flash
    local progress = flash.timer / flash.duration
    local flashWidth = w * math.sqrt(progress)
    local flashX = drawX - flashWidth / 2
    local flashY = finalDrawY - h

    if Assets.shaders.solid_color then
        local oldScissor = {love.graphics.getScissor()}
        love.graphics.setScissor(flashX - Camera.x, flashY - Camera.y, flashWidth, h)
        love.graphics.setShader(Assets.shaders.solid_color)
        local flashAlpha = 1.0 * (1 - progress)
        Assets.shaders.solid_color:send("solid_color", {1, 1, 1, flashAlpha * baseAlpha})
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
        love.graphics.setShader()
        love.graphics.setScissor(unpack(oldScissor))
    end
end

local function draw_carried_unit_icon(entity)
    if not entity.carriedUnit then return end

    local iconRadius = 5
    local iconX = entity.x + entity.size - iconRadius - 2
    local iconY = entity.y + entity.size - iconRadius - 2

    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.circle("fill", iconX, iconY, iconRadius)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(iconX - 2.5, iconY, iconX + 2.5, iconY)
    love.graphics.line(iconX, iconY - 2.5, iconX, iconY + 2.5)
    love.graphics.setLineWidth(1)
end

function EntityRenderer.drawEntity(entity, world, is_active_player)
    love.graphics.push()
    apply_shake_transform(entity)

    if entity.components.animation then
        -- 1. Get animation data
        local animComponent = entity.components.animation
        local currentAnim = animComponent.animations[animComponent.current]
        local spriteSheet = animComponent.spriteSheet
        local w, h = currentAnim:getDimensions()

        -- 2. Calculate drawing position and visual state
        local drawX, baseDrawY = calculate_draw_position(entity)
        local finalDrawY, rotation = calculate_visual_offsets(entity, currentAnim, drawX, baseDrawY)
        local baseAlpha, finalDrawY = calculate_alpha_and_vertical_offset(entity, finalDrawY)
        local clipRatio = get_clipping_ratio(entity, world)

        -- 3. Draw the base sprite and selection flash
        draw_base_sprite(currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation, baseAlpha, clipRatio, entity)
        draw_selection_flash(entity, currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation, baseAlpha)

        -- 4. Draw overlays for visual effects and game state
        draw_visual_effect_overlays(entity, currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation, baseAlpha)
        draw_state_overlays(entity, is_active_player, currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation, clipRatio)
        love.graphics.setShader()
    end

    -- 5. Draw status bars and icons
    if not entity.components.fade_out then
        if not WorldQueries.isUnitInCombat(entity, world) then
            EntityRenderer.drawAllBars(entity, world)
        end
    end
    draw_carried_unit_icon(entity)

    love.graphics.pop()
end

function EntityRenderer.drawWispBar(square, world)
    -- Only draw if the unit actually uses Wisp.
    if square.wisp == nil then return end

    -- Determine vertical position, accounting for the HP and EXP bars.
    local hpBarHeight = WorldQueries.getUnitHealthBarHeight(square, world)
    local hpBarTopY = math.floor(square.y + square.size - 2)
    local barYOffset = hpBarTopY + hpBarHeight -- Start at the bottom of the HP bar.

    -- If an EXP bar animation is active for this unit, shift the Wisp bar down to make room.
    local expAnim = world.ui.expGainAnimation
    if expAnim and expAnim.active and expAnim.unit == square then
        local expBarHeight = 6 -- The height of the EXP bar.
        barYOffset = barYOffset + expBarHeight
    end

    -- Wisp bar properties
    local barMaxWidth, barHeight = square.size, 4 -- A bit taller for clarity
    local baseX, baseY = math.floor(square.x), barYOffset

    local maxNotches = 8 -- Character with max 8 wisp will have a bar as long as the health bar
    local currentNotches = math.min(square.finalMaxWisp, maxNotches)
    if currentNotches == 0 then return end -- Don't draw if there are no notches to show.

    local barWidth = (currentNotches / maxNotches) * barMaxWidth
    local notchWidth = math.floor(barWidth / currentNotches)
    local filledNotches = math.floor(square.wisp) -- 1 wisp = 1 filled notch

    for i = 1, currentNotches do
        local notchX = baseX + (i - 1) * notchWidth

        -- 1. Draw the outer black frame for the notch.
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", notchX, baseY, notchWidth, barHeight)

        -- 2. Define the inner area for the fill.
        local innerX, innerY = notchX + 1, baseY + 1
        local innerW, innerH = notchWidth - 2, barHeight - 2

        -- 3. Determine the fill color and draw it.
        love.graphics.setColor((i <= filledNotches) and {1, 1, 1, 1} or {0.1, 0.1, 0.1, 1}) -- White when full, dark grey when empty
        love.graphics.rectangle("fill", innerX, innerY, innerW, innerH)
    end
end

return EntityRenderer