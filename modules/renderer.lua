-- renderer.lua
-- Contains all drawing logic for the game.

local Grid = require("modules.grid")
local Camera = require("modules.camera")
local Assets = require("modules.assets")
local CharacterBlueprints = require("data.character_blueprints")
local AttackBlueprints = require("data.attack_blueprints")
local WeaponBlueprints = require("data.weapon_blueprints")
local AttackPatterns = require("modules.attack_patterns")
local WorldQueries = require("modules.world_queries")
local BattleInfoMenu = require("modules.battle_info_menu")
local UnitInfoMenu = require("modules.unit_info_menu")
local ExpBarRendererSystem = require("systems.exp_bar_renderer_system")
local PromotionMenu = require("modules.promotion_menu")

local Renderer = {}

-- State for animated UI elements
local current_cursor_line_width = 2

-- Helper function for wrapping long strings of text, used by the action menu.
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

local function drawHealthBar(square, world)
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

local function drawWispBar(square, world)
    -- Only draw if the unit actually uses Wisp.
    if not square.wisp or not square.maxWisp then return end

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
    local currentNotches = math.min(square.maxWisp, maxNotches)
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

local function drawAllBars(entity, world)
   drawHealthBar(entity, world)
   -- Only draw the wisp and exp bars if the unit is not in combat, to reduce clutter.
   if not WorldQueries.isUnitInCombat(entity, world) then
       drawWispBar(entity, world)
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
local function draw_state_overlays(entity, is_active_player, currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation, onWater)
    -- Dying units should not have state overlays.
    if entity.components.fade_out then return end

    -- If the unit is swimming, set up the scissor clipping for all state overlays.
    -- This ensures that effects like the greyscale overlay are also clipped correctly.
    local oldScissor = {love.graphics.getScissor()}
    if onWater then
        -- The sprite is drawn anchored at bottom-center. Its top-left corner in world space is at
        -- (drawX - w / 2, finalDrawY - h).
        -- We want to set a scissor for the top half of the sprite's area.
        local scissorWorldX = drawX - w / 2
        local scissorWorldY = finalDrawY - h
        local scissorWorldW = w
        local scissorWorldH = h * 0.7 -- Show the top 70% of the sprite, hiding the bottom 30%.
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

local function draw_entity(entity, world, is_active_player)
    love.graphics.push()
    -- Check for the 'shake' component
    if entity.components.shake then
        local offsetX = math.random(-entity.components.shake.intensity, entity.components.shake.intensity)
        local offsetY = math.random(-entity.components.shake.intensity, entity.components.shake.intensity)
        love.graphics.translate(offsetX, offsetY)
    end

    if entity.components.animation then
        -- 1. Get animation data
        local animComponent = entity.components.animation
        local currentAnim = animComponent.animations[animComponent.current]
        local spriteSheet = animComponent.spriteSheet
        local w, h = currentAnim:getDimensions()

        -- 2. Calculate drawing position and offsets
        -- Base position is bottom-center of the entity's logical tile.
        local drawX = entity.x + entity.size / 2
        local baseDrawY = entity.y + entity.size

        -- Apply lunge effect offset if present.
        local lungeOffsetX, lungeOffsetY = 0, 0
        if entity.components.lunge then
            local lunge = entity.components.lunge
            local max_lunge_amount = 10 -- The peak distance of the lunge.

            -- Calculate the progress of the lunge animation (from 0 to 1).
            local progress = 1 - (lunge.timer / lunge.initialTimer)
            -- Use a sine wave to create a smooth out-and-back motion.
            -- math.sin(progress * math.pi) goes from 0 -> 1 -> 0 as progress goes from 0 -> 1.
            local current_lunge_amount = max_lunge_amount * math.sin(progress * math.pi)

            if lunge.direction == "up" then lungeOffsetY = -current_lunge_amount end
            if lunge.direction == "down" then lungeOffsetY = current_lunge_amount end
            if lunge.direction == "left" then lungeOffsetX = -current_lunge_amount end
            if lunge.direction == "right" then lungeOffsetX = current_lunge_amount end
        end
        drawX = drawX + lungeOffsetX
        baseDrawY = baseDrawY + lungeOffsetY

        local finalDrawY, rotation = calculate_visual_offsets(entity, currentAnim, drawX, baseDrawY)

        -- Calculate the base alpha for the entity. This will be 1 unless the unit is fading out.
        local baseAlpha = 1
        if entity.components.sinking then
            local sinking = entity.components.sinking
            local progress = 1 - (sinking.timer / sinking.initialTimer) -- 0 to 1
            finalDrawY = finalDrawY + progress * entity.size -- Move down
            baseAlpha = 1 - progress -- Fade out
        elseif entity.components.fade_out then
            baseAlpha = entity.components.fade_out.timer / entity.components.fade_out.initialTimer
        end

        -- Check if the unit is swimming to apply the submerged effect.
        local onWater = entity.canSwim and WorldQueries.isTileWater(entity.tileX, entity.tileY, world)

        -- 3. Draw the base sprite at the final calculated position.
        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, baseAlpha)

        if onWater and not entity.components.sinking then
            -- Unit is swimming, draw only the top portion of the sprite using a scissor.
            local oldScissor = {love.graphics.getScissor()}
            -- The sprite is drawn anchored at bottom-center. Its top-left corner in world space is at
            -- (drawX - w / 2, finalDrawY - h).
            -- We want to set a scissor for the top half of the sprite's area.
            local scissorWorldX = drawX - w / 2
            local scissorWorldY = finalDrawY - h
            local scissorWorldW = w
            local scissorWorldH = h * 0.7 -- Show the top 70% of the sprite, hiding the bottom 30%.
            -- Convert world coordinates to screen coordinates for the scissor.
            love.graphics.setScissor(scissorWorldX - Camera.x, scissorWorldY - Camera.y, scissorWorldW, scissorWorldH)
            currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
            love.graphics.setScissor(unpack(oldScissor))
        else
            currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
        end

        -- Draw selection flash effect if present
        if entity.components.selection_flash then
            local flash = entity.components.selection_flash
            local progress = flash.timer / flash.duration

            -- The width of the flash expands from a thin line to the full sprite width.
            -- Using progress^0.5 (sqrt) will make it expand fast at the start and slow down.
            local flashWidth = w * math.sqrt(progress)
            local flashX = drawX - flashWidth / 2
            local flashY = finalDrawY - h -- The sprite is drawn anchored bottom-center

            -- Use the solid color shader to only color the sprite's pixels
            if Assets.shaders.solid_color then
                -- Store the current scissor to restore it later
                local oldScissor = {love.graphics.getScissor()}

                -- Set the scissor to the expanding rectangle
                -- The scissor coordinates need to be in screen space, not world space.
                love.graphics.setScissor(flashX - Camera.x, flashY - Camera.y, flashWidth, h)

                -- Set the shader to tint the sprite white
                love.graphics.setShader(Assets.shaders.solid_color)
                local flashAlpha = 1.0 * (1 - progress)
                Assets.shaders.solid_color:send("solid_color", {1, 1, 1, flashAlpha * baseAlpha})

                -- Draw the sprite again, tinted white, clipped by the scissor
                currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)

                -- Reset shader and scissor
                love.graphics.setShader()
                -- Use global unpack for compatibility with older Lua versions used by LÖVE.
                love.graphics.setScissor(unpack(oldScissor))
            end
        end

        -- 4. Draw overlays for visual effects (damage tint, poison, etc.)
        draw_visual_effect_overlays(entity, currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation, baseAlpha)

        -- 5. Draw overlays for game state (acted, selected)
        draw_state_overlays(entity, is_active_player, currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation, onWater)

        -- 6. Reset shader state
        love.graphics.setShader()
    end

    -- 7. Draw the health bar on top of everything, but only if the unit is not fading out.
    -- If the unit is in combat, its health bar is drawn in a separate pass to ensure it's on top of all other units.
    if not entity.components.fade_out then
        if not WorldQueries.isUnitInCombat(entity, world) then
            drawAllBars(entity, world)
        end
    end

    -- 8. If the unit is carrying another unit, draw an icon on the map sprite.
    if entity.carriedUnit then
        local iconRadius = 5
        -- Position it in the bottom-right corner of the tile, just above the health bars.
        local iconX = entity.x + entity.size - iconRadius - 2
        local iconY = entity.y + entity.size - iconRadius - 2

        -- Draw a background for the icon to make it stand out.
        love.graphics.setColor(1, 0.8, 0.2, 1) -- Opaque Gold/yellow
        love.graphics.circle("fill", iconX, iconY, iconRadius)

        -- Draw a '+' symbol inside the circle.
        love.graphics.setColor(0, 0, 0, 1) -- Black for contrast
        love.graphics.setLineWidth(1.5)
        love.graphics.line(iconX - 2.5, iconY, iconX + 2.5, iconY) -- Horizontal line
        love.graphics.line(iconX, iconY - 2.5, iconX, iconY + 2.5) -- Vertical line
        love.graphics.setLineWidth(1) -- Reset line width
    end

    love.graphics.pop()
end

local function draw_all_entities_and_effects(world)
    -- Draw afterimage effects
    for _, a in ipairs(world.afterimageEffects) do
        -- If the afterimage has sprite data, draw it as a solid-color sprite.
        if a.frame and a.spriteSheet and Assets.shaders.solid_color then
            love.graphics.setShader(Assets.shaders.solid_color)

            local alpha = (a.lifetime / a.initialLifetime) * 0.5 -- Max 50% transparent
            -- Send the dominant color and alpha to the shader
            Assets.shaders.solid_color:send("solid_color", {a.color[1], a.color[2], a.color[3], alpha})

            -- Anchor the afterimage to the same position as the original sprite
            local drawX = a.x + a.size / 2
            local drawY = a.y + a.size
            local w, h = a.width, a.height

            -- Draw the specific frame that was captured
            love.graphics.draw(a.spriteSheet, a.frame, drawX, drawY, 0, 1, 1, w / 2, h)

            love.graphics.setShader() -- Reset to default shader
        else
            -- Fallback for non-sprite entities or if shaders are unsupported.
            local alpha = (a.lifetime / a.initialLifetime) * 0.5
            love.graphics.setColor(a.color[1], a.color[2], a.color[3], alpha)
            love.graphics.rectangle("fill", a.x, a.y, a.size, a.size)
        end
    end

    -- Draw ascension shadows on the ground.
    for _, shadowData in ipairs(world.ascension_shadows) do
        local pixelX, pixelY = Grid.toPixels(shadowData.tileX, shadowData.tileY)
        local centerX = pixelX + Config.SQUARE_SIZE / 2
        local centerY = pixelY + Config.SQUARE_SIZE / 2
        -- Pulsating shadow effect
        local alpha = 0.3 + (math.sin(love.timer.getTime() * 4) + 1) / 2 * 0.2 -- Pulsates between 0.3 and 0.5 alpha
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.ellipse("fill", centerX, centerY, 14, 7)
    end

    -- Create a single list of all units and obstacles to be drawn.
    local drawOrder = {}
    for _, p in ipairs(world.players) do
        table.insert(drawOrder, p)
    end
    for _, e in ipairs(world.enemies) do
        table.insert(drawOrder, e)
    end
    for _, o in ipairs(world.obstacles) do
        table.insert(drawOrder, o)
    end

    -- Sort the list by Y-coordinate. Entities lower on the screen (higher y) are drawn later (on top).
    table.sort(drawOrder, function(a, b)
        return a.y < b.y
    end)

    -- Draw all units and obstacles in the correct Z-order.
    for _, entity in ipairs(drawOrder) do
        if entity.isObstacle then
            -- Only draw obstacles that have a sprite. This handles dynamically created
            -- obstacles (like from Grovecall), while map-based obstacles (without sprites)
            -- are still drawn by the map renderer to prevent double-drawing.
            if entity.sprite then
                -- Calculate alpha for fade-out effect.
                local baseAlpha = 1
                if entity.components.fade_out then
                    baseAlpha = entity.components.fade_out.timer / entity.components.fade_out.initialTimer
                end
                love.graphics.setColor(1, 1, 1, baseAlpha)
                local w, h = entity.sprite:getDimensions()
                -- Anchor to bottom-center of its tile for consistency with characters
                local drawX = entity.x + entity.size / 2
                local drawY = entity.y + entity.size
                love.graphics.draw(entity.sprite, drawX, drawY, 0, 1, 1, w / 2, h)
            end
        else -- It's a character
            -- Do not draw ascended units, unless they are currently animating their ascent.
            if not (entity.components and entity.components.ascended) or (entity.components and entity.components.ascending_animation) then
                local is_active = (entity.type == "player" and entity == world.ui.selectedUnit)
                draw_entity(entity, world, is_active) -- Pass world to draw_entity
            end
        end
    end

    -- Draw health bars for combatting units on top of everything else.
    for _, entity in ipairs(drawOrder) do
        if WorldQueries.isUnitInCombat(entity, world) then
            drawAllBars(entity, world)
        end
    end

    -- Draw active attack effects (flashing tiles)
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

    -- Draw projectiles
    for _, projectile in ipairs(world.projectiles) do
        love.graphics.setColor(1, 0.5, 0, 1) -- Orange/red color for projectiles
        love.graphics.rectangle("fill", projectile.x, projectile.y, projectile.size, projectile.size)
    end

    -- Draw particle effects
    for _, p in ipairs(world.particleEffects) do
        -- Fade out the particle as its lifetime decreases
        local alpha = (p.lifetime / p.initialLifetime)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
    end

    -- Draw damage popups
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
    for _, p in ipairs(world.damagePopups) do
        local alpha = (p.lifetime / p.initialLifetime)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.print(p.text, p.x, p.y)
    end

    -- Draw new grappling hooks and their lines
    for _, entity in ipairs(world.all_entities) do
        if entity.type == "grapple_hook" and entity.components.grapple_hook then
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

-- Helper to draw a set of tiles with a specific color and transparency.
local function draw_tile_set(tileSet, r, g, b, a, world)
    if not tileSet then return end
    local BORDER_WIDTH = 1
    local INSET_SIZE = Config.SQUARE_SIZE - (BORDER_WIDTH * 2)

    -- Determine the center of the ripple effect based on the current game state.
    -- The ripple should be centered on the unit whose range is being displayed.
    -- The unit_info_system is the single source of truth for which unit is the ripple's source.
    local ripple_center_unit = world.ui.menus.unitInfo.rippleSourceUnit

    for posKey, _ in pairs(tileSet) do
        local tileX = tonumber(string.match(posKey, "(-?%d+)"))
        local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
        if tileX and tileY then
            local finalAlpha = a -- Start with the base alpha for the tile set.

            -- If a ripple source is active, calculate and apply the ripple brightness.
            if ripple_center_unit then
                -- Calculate elapsed time since the ripple started for this unit.
                local elapsedTime = love.timer.getTime() - (world.ui.menus.unitInfo.rippleStartTime or love.timer.getTime())
                local rippleRadius = (elapsedTime * 10) % (15 + 3) -- (speed) % (maxRadius + width)
                local baseDist = math.abs(tileX - ripple_center_unit.tileX) + math.abs(tileY - ripple_center_unit.tileY)
                local deltaDist = math.abs(baseDist - rippleRadius)
                if deltaDist < 3 then -- width
                    local brightness = (1 - (deltaDist / 3)) * 0.2 -- maxBrightness
                    finalAlpha = finalAlpha + brightness
                end
            end

            love.graphics.setColor(r, g, b, math.min(1, finalAlpha))
            local pixelX, pixelY = Grid.toPixels(tileX, tileY)
            love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
        end
    end
end

local function draw_world_space_ui(world)
    -- Draw Turn-Based UI Elements (Ranges, Path, Cursor)
    local BORDER_WIDTH = 1
    local INSET_SIZE = Config.SQUARE_SIZE - (BORDER_WIDTH * 2)

    -- New: Draw pulsating WinTiles. This is drawn first so other UI elements appear on top.
    -- This should be visible during both player and enemy turns.
    if world.winTiles and #world.winTiles > 0 then
        local alpha = 0.3 + (math.sin(love.timer.getTime() * 3) + 1) / 2 * 0.3 -- Pulsates between 0.3 and 0.6 alpha
        love.graphics.setColor(0.2, 1.0, 0.2, alpha) -- Pulsating green
        for _, tile in ipairs(world.winTiles) do
            local pixelX, pixelY = Grid.toPixels(tile.x, tile.y)
            love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
        end
        love.graphics.setColor(1, 1, 1, 1) -- Reset color
    end

    -- Helper to draw the cursor's corner shapes.
    local function draw_cursor_corners(x, y, size, cornerLength, offset)
        -- Top-left
        love.graphics.line(x + offset + cornerLength, y + offset, x + offset, y + offset, x + offset, y + offset + cornerLength)
        -- Top-right
        love.graphics.line(x + size - offset - cornerLength, y + offset, x + size - offset, y + offset, x + size - offset, y + offset + cornerLength)
        -- Bottom-left
        love.graphics.line(x + offset + cornerLength, y + size - offset, x + offset, y + size - offset, x + offset, y + size - offset - cornerLength)
        -- Bottom-right
        love.graphics.line(x + size - offset - cornerLength, y + size - offset, x + size - offset, y + size - offset, x + size - offset, y + size - offset - cornerLength)
    end

    if world.gameState == "gameplay" and world.turn == "player" then
        -- Draw the action menu's attack preview
        if world.ui.menus.action.active and world.ui.menus.action.previewAttackableTiles then
            draw_tile_set(world.ui.menus.action.previewAttackableTiles, 1, 0.2, 0.2, 0.5, world) -- Brighter red
        end

        -- Draw the action menu's AoE preview for ground-targeted attacks
        if world.ui.menus.action.active and world.ui.menus.action.previewAoeShapes then
            love.graphics.setColor(1, 0.2, 0.2, 0.6) -- Semi-transparent red, same as ground_aiming preview
            for _, effectData in ipairs(world.ui.menus.action.previewAoeShapes) do
                local s = effectData.shape
                if s.type == "rect" then
                    love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)
                end
            end
            love.graphics.setColor(1, 1, 1, 1) -- Reset color
        end

                -- New: Draw the fading range indicators after a move is confirmed.
        if world.ui.pathing.rangeFadeEffect and world.ui.pathing.rangeFadeEffect.active then
            local effect = world.ui.pathing.rangeFadeEffect
            local progress = effect.timer / effect.initialTimer -- Fades from 1 down to 0

            -- Draw fading attackable tiles (danger zone)
            if effect.attackableTiles then
                draw_tile_set(effect.attackableTiles, 1, 0.2, 0.2, 0.3 * progress, world)
            end

            -- Draw fading reachable tiles (movement range)
            if effect.reachableTiles then
                draw_tile_set(effect.reachableTiles, 0.2, 0.4, 1, 0.6 * progress, world)
            end
        end

        -- 1. Draw the full attack range for the selected unit (the "danger zone").
        local showDangerZone = world.ui.playerTurnState == "unit_selected" or world.ui.playerTurnState == "ground_aiming" or world.ui.playerTurnState == "cycle_targeting"
        if showDangerZone and world.ui.pathing.attackableTiles then
            draw_tile_set(world.ui.pathing.attackableTiles, 1, 0.2, 0.2, 0.3, world)
        end

        -- Draw hovered unit's danger zone (fainter)
        if world.ui.menus.unitInfo.active and world.ui.pathing.hoverAttackableTiles then
            draw_tile_set(world.ui.pathing.hoverAttackableTiles, 1, 0.2, 0.2, 0.2, world)
        end

        -- Draw hovered unit's movement range
        if world.ui.menus.unitInfo.active and world.ui.pathing.hoverReachableTiles then
            draw_tile_set(world.ui.pathing.hoverReachableTiles, 0.2, 0.4, 1, 0.2, world)
        end

        -- 2. Draw the movement range for the selected unit. This is drawn on top of the attack range.
        if world.ui.playerTurnState == "unit_selected" and world.ui.pathing.reachableTiles then 
            draw_tile_set(world.ui.pathing.reachableTiles, 0.2, 0.4, 1, 0.6, world)
        end

        -- Draw enemy range display if active
        if world.ui.menus.enemyRangeDisplay.active then
            draw_tile_set(world.ui.menus.enemyRangeDisplay.attackableTiles, 1, 0.2, 0.2, 0.4, world) -- Red for attack
            draw_tile_set(world.ui.menus.enemyRangeDisplay.reachableTiles, 0.2, 0.4, 1, 0.4, world) -- Blue for movement
        end

        -- 3. Draw the movement path.
        if world.ui.playerTurnState == "unit_selected" and world.ui.pathing.movementPath and #world.ui.pathing.movementPath > 0 then
            local pathTiles = {}
            for _, node in ipairs(world.ui.pathing.movementPath) do
                local tileX, tileY = Grid.toTile(node.x, node.y)
                pathTiles[tileX .. "," .. tileY] = true
            end
            draw_tile_set(pathTiles, 1, 1, 0.5, 0.8, world) -- Gold color
        end

        -- Draw the move destination effect (descending cursor and glowing tile)
        if world.ui.pathing.moveDestinationEffect then
            local effect = world.ui.pathing.moveDestinationEffect
            local pixelX, pixelY = Grid.toPixels(effect.tileX, effect.tileY)
            local size = Config.SQUARE_SIZE

            if effect.state == "descending" then
                -- Animate the cursor morphing into a filled square.
                local progress = 1 - (effect.timer / effect.initialTimer) -- Goes from 0 to 1
                local cornerLength = 8

                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setLineWidth(6) -- Use the thick "locked in" line width

                if progress < 0.5 then
                    -- Phase 1: Animate outline formation. The L-shapes grow and the whole shape shrinks by 1px.
                    local outline_progress = progress / 0.5 -- This sub-progress goes from 0 to 1.

                    -- Interpolate the position and size to shrink the cursor by 1px on each side.
                    local anim_x = pixelX + 4 * outline_progress -- Shrink significantly to account for thick cursor line.
                    local anim_y = pixelY + 4 * outline_progress
                    local anim_size = size - 8 * outline_progress

                    local current_len = cornerLength + ((anim_size / 2) - cornerLength) * outline_progress

                    -- Draw the 8 elongating lines from the corners.
                    love.graphics.line(anim_x, anim_y, anim_x + current_len, anim_y) -- Top-left H
                    love.graphics.line(anim_x, anim_y, anim_x, anim_y + current_len) -- Top-left V
                    love.graphics.line(anim_x + anim_size, anim_y, anim_x + anim_size - current_len, anim_y) -- Top-right H
                    love.graphics.line(anim_x + anim_size, anim_y, anim_x + anim_size, anim_y + current_len) -- Top-right V
                    love.graphics.line(anim_x, anim_y + anim_size, anim_x + current_len, anim_y + anim_size) -- Bottom-left H
                    love.graphics.line(anim_x, anim_y + anim_size, anim_x, anim_y + anim_size - current_len) -- Bottom-left V
                    love.graphics.line(anim_x + anim_size, anim_y + anim_size, anim_x + anim_size - current_len, anim_y + anim_size) -- Bottom-right H
                    love.graphics.line(anim_x + anim_size, anim_y + anim_size, anim_x + anim_size, anim_y + anim_size - current_len) -- Bottom-right V
                else
                    -- Phase 2: The outline is now a full square. Animate the fill from the corners.
                    local fill_progress = (progress - 0.5) / 0.5 -- This sub-progress goes from 0 to 1.

                    -- The cursor is now fully shrunken to match the inset tile size.
                    local inset_x = pixelX + 4
                    local inset_y = pixelY + 4
                    local inset_size = size - 8

                    -- First, draw the complete square outline that was formed in Phase 1.
                    love.graphics.rectangle("line", inset_x, inset_y, inset_size, inset_size)

                    -- Calculate the distance the fill should travel from each edge.
                    local fill_distance = (inset_size / 2) * fill_progress

                    -- Draw four rectangles, one growing from each perimeter edge, to fill the square.
                    love.graphics.rectangle("fill", inset_x, inset_y, inset_size, fill_distance) -- Top
                    love.graphics.rectangle("fill", inset_x, inset_y + inset_size - fill_distance, inset_size, fill_distance) -- Bottom
                    love.graphics.rectangle("fill", inset_x, inset_y, fill_distance, inset_size) -- Left
                    love.graphics.rectangle("fill", inset_x + inset_size - fill_distance, inset_y, fill_distance, inset_size) -- Right
                end
                love.graphics.setLineWidth(1)
            elseif effect.state == "glowing" then
                -- Animate the tile glowing with a pulsating effect.
                local glowAlpha = 0.4 + (math.sin(love.timer.getTime() * 8) + 1) / 2 * 0.3 -- Pulsates between 0.4 and 0.7
                love.graphics.setColor(1, 1, 1, glowAlpha)
                -- Use the inset dimensions to match the final frame of the descending animation.
                local inset_x = pixelX + 1
                local inset_y = pixelY + 1
                local inset_size = size - 2
                love.graphics.rectangle("fill", inset_x, inset_y, inset_size, inset_size)
            end
        end

        -- 4. Draw the map cursor.
        if world.ui.playerTurnState == "free_roam" or world.ui.playerTurnState == "unit_selected" or
           world.ui.playerTurnState == "cycle_targeting" or world.ui.playerTurnState == "ground_aiming" or 
           world.ui.playerTurnState == "enemy_range_display" or
           world.ui.playerTurnState == "rescue_targeting" or world.ui.playerTurnState == "drop_targeting" or
           world.ui.playerTurnState == "shove_targeting" or world.ui.playerTurnState == "take_targeting"
           then
            -- Animate the cursor's line width for a "lock in" effect
            local target_cursor_line_width = 2 -- Normal thickness
            if world.ui.playerTurnState == "unit_selected" or world.ui.playerTurnState == "enemy_range_display" then
                target_cursor_line_width = 6 -- Thicker when a unit is selected
            end
            -- Lerp the current width towards the target width for a smooth animation
            current_cursor_line_width = current_cursor_line_width + (target_cursor_line_width - current_cursor_line_width) * 0.2

            love.graphics.setColor(1, 1, 1, 1) -- White cursor outline
            love.graphics.setLineWidth(current_cursor_line_width)
            local baseCursorPixelX, baseCursorPixelY
            if world.ui.playerTurnState == "cycle_targeting" and world.ui.targeting.cycle.active and #world.ui.targeting.cycle.targets > 0 then
                local target = world.ui.targeting.cycle.targets[world.ui.targeting.cycle.selectedIndex]
                if target then
                    -- In cycle mode, the cursor is on the target itself.
                    baseCursorPixelX, baseCursorPixelY = target.x, target.y
                else
                    baseCursorPixelX, baseCursorPixelY = Grid.toPixels(world.ui.mapCursorTile.x, world.ui.mapCursorTile.y)
                end
            else
                baseCursorPixelX, baseCursorPixelY = Grid.toPixels(world.ui.mapCursorTile.x, world.ui.mapCursorTile.y)
            end

            -- New: Hover and projected shadow logic
            local hover_offset = math.floor(-4 + math.sin(love.timer.getTime() * 4) * 2) -- Bob up and down in 1px increments
            local cursorPixelX = baseCursorPixelX
            local cursorPixelY = baseCursorPixelY + hover_offset
            local cornerLength = 8 -- A fixed length for the corner lines.
            local size = Config.SQUARE_SIZE
            local offset = 0 -- No more pulsing animation

            -- Draw the shadow on the ground tile by drawing the cursor shape in black.
            love.graphics.setColor(0, 0, 0, 0.25)
            draw_cursor_corners(baseCursorPixelX, baseCursorPixelY, size, cornerLength, offset)

            -- Draw the actual cursor itself (now hovering)
            love.graphics.setColor(1, 1, 1, 1) -- White cursor outline
            draw_cursor_corners(cursorPixelX, cursorPixelY, size, cornerLength, offset)
            love.graphics.setLineWidth(1) -- Reset line width
        end

        -- Draw the ground aiming grid (the valid area for ground-targeted attacks)
        if world.ui.playerTurnState == "ground_aiming" and world.ui.pathing.groundAimingGrid then
            draw_tile_set(world.ui.pathing.groundAimingGrid, 0.2, 0.8, 1, 0.4, world) -- A light, cyan-ish color
        end

        -- 5. Draw the Attack AoE preview
        if world.ui.playerTurnState == "ground_aiming" and world.ui.targeting.attackAoETiles then
            love.graphics.setColor(1, 0.2, 0.2, 0.6) -- Semi-transparent red
            for _, effectData in ipairs(world.ui.targeting.attackAoETiles) do
                local s = effectData.shape
                if s.type == "rect" then
                    love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)
                elseif s.type == "line_set" then
                    -- Could render lines here in the future if needed for previews
                end
            end
            love.graphics.setColor(1, 1, 1, 1) -- Reset color
        end

        -- 6. Draw Cycle Targeting UI (previews, etc.)
        if world.ui.playerTurnState == "cycle_targeting" and world.ui.targeting.cycle.active then
            local cycle = world.ui.targeting.cycle
            if #cycle.targets > 0 then
                local target = cycle.targets[cycle.selectedIndex]
                local attacker = world.ui.menus.action.unit
                local attackData = world.ui.targeting.selectedAttackName and AttackBlueprints[world.ui.targeting.selectedAttackName]

                if target and attacker and attackData then
                    if attackData.useType == "support" then
                        -- Draw a green overlay on the targeted ally.
                        love.graphics.setColor(0.2, 1, 0.2, 0.3) -- Semi-transparent green.
                        love.graphics.rectangle("fill", target.x + BORDER_WIDTH, target.y + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                    elseif world.ui.targeting.selectedAttackName== "phantom_step" then
                        -- Special preview for Phantom Step: show target and destination.
                        love.graphics.setColor(1, 0.2, 0.2, 0.3) -- Semi-transparent red
                        love.graphics.rectangle("fill", target.x + BORDER_WIDTH, target.y + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                        local dx, dy = 0, 0
                        if target.lastDirection == "up" then dy = 1
                        elseif target.lastDirection == "down" then dy = -1
                        elseif target.lastDirection == "left" then dx = 1
                        elseif target.lastDirection == "right" then dx = -1
                        end
                        local behindTileX, behindTileY = target.tileX + dx, target.tileY + dy
                        local behindPixelX, behindPixelY = Grid.toPixels(behindTileX, behindTileY)
                        love.graphics.setColor(0.2, 0.4, 1, 0.3) -- Semi-transparent blue
                        love.graphics.rectangle("fill", behindPixelX + BORDER_WIDTH, behindPixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                    elseif attackData.patternType and type(AttackPatterns[attackData.patternType]) == "function" then
                        -- New: Handle functional patterns like line_of_sight.
                        -- The attacker's direction is already set by the targeting system.
                        local patternFunc = AttackPatterns[attackData.patternType]
                        local attackShapes = patternFunc(attacker, world)
                        love.graphics.setColor(1, 0.2, 0.2, 0.3) -- Semi-transparent red
                        for _, effectData in ipairs(attackShapes) do
                            local s = effectData.shape
                            if s.type == "rect" then
                                love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)
                            end
                        end
                    elseif world.ui.targeting.selectedAttackName== "hookshot" then
                        -- Special preview for Hookshot: draw a line to the target.
                        love.graphics.setColor(1, 0.2, 0.2, 0.3) -- Semi-transparent red
                        local dist = math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY)

                        if attacker.tileX == target.tileX then -- Vertical line
                            local dirY = (target.tileY > attacker.tileY) and 1 or -1
                            for i = 1, dist do
                                local pixelX, pixelY = Grid.toPixels(attacker.tileX, attacker.tileY + i * dirY)
                                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                            end
                        elseif attacker.tileY == target.tileY then -- Horizontal line
                            local dirX = (target.tileX > attacker.tileX) and 1 or -1
                            for i = 1, dist do
                                local pixelX, pixelY = Grid.toPixels(attacker.tileX + i * dirX, attacker.tileY)
                                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                            end
                        end
                    elseif world.ui.targeting.selectedAttackName== "shockwave" then
                        -- Special preview for Shockwave: show the AoE around the attacker.
                        love.graphics.setColor(1, 0.2, 0.2, 0.6) -- Semi-transparent red
                        if attacker and attackData.range then
                            for dx = -attackData.range, attackData.range do
                                for dy = -attackData.range, attackData.range do
                                    if math.abs(dx) + math.abs(dy) <= attackData.range then
                                        local tileX, tileY = attacker.tileX + dx, attacker.tileY + dy
                                        local pixelX, pixelY = Grid.toPixels(tileX, tileY)
                                        love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                                    end
                                end
                            end
                        end
                    else
                        -- Default preview for all other attacks (standard melee, ranged, etc.):
                        -- Just highlight the selected target tile.
                        love.graphics.setColor(1, 0.2, 0.2, 0.3) -- Semi-transparent red
                        love.graphics.rectangle("fill", target.x + BORDER_WIDTH, target.y + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                    end
                end
            end
        end

        -- 7. Draw Rescue/Drop Targeting UI
        if world.ui.playerTurnState == "rescue_targeting" and world.ui.targeting.rescue.active then
            local rescue = world.ui.targeting.rescue
            -- Draw all potential targets with a base color
            love.graphics.setColor(0.2, 1, 0.2, 0.4) -- Semi-transparent green
            for _, target in ipairs(rescue.targets) do
                local pixelX, pixelY = Grid.toPixels(target.tileX, target.tileY)
                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
            end

            -- Draw the selected target with a brighter color
            if #rescue.targets > 0 then
                local selectedTarget = rescue.targets[rescue.selectedIndex]
                if selectedTarget then
                    love.graphics.setColor(0.2, 1, 0.2, 0.7) -- Brighter green
                    local pixelX, pixelY = Grid.toPixels(selectedTarget.tileX, selectedTarget.tileY)
                    love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                end
            end
        elseif world.ui.playerTurnState == "drop_targeting" and world.ui.targeting.drop.active then
            local drop = world.ui.targeting.drop
            -- Draw all potential drop tiles with a base color
            love.graphics.setColor(1, 0.8, 0.2, 0.4) -- Semi-transparent yellow/gold
            for _, tile in ipairs(drop.tiles) do
                local pixelX, pixelY = Grid.toPixels(tile.tileX, tile.tileY)
                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
            end

            -- Draw the selected tile with a brighter color
            if #drop.tiles > 0 then
                local selectedTile = drop.tiles[drop.selectedIndex]
                if selectedTile then
                    love.graphics.setColor(1, 0.8, 0.2, 0.7) -- Brighter yellow/gold
                    local pixelX, pixelY = Grid.toPixels(selectedTile.tileX, selectedTile.tileY)
                    love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                end
            end
        elseif world.ui.playerTurnState == "shove_targeting" and world.ui.targeting.shove.active then
            local shove = world.ui.targeting.shove
            -- Draw all potential targets with a base color
            love.graphics.setColor(0.2, 0.8, 1, 0.4) -- Semi-transparent cyan
            for _, target in ipairs(shove.targets) do
                local pixelX, pixelY = Grid.toPixels(target.tileX, target.tileY)
                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
            end

            -- Draw the selected target with a brighter color
            if #shove.targets > 0 then
                local selectedTarget = shove.targets[shove.selectedIndex]
                if selectedTarget then
                    -- Highlight the target itself with a bright cyan
                    love.graphics.setColor(0.2, 0.8, 1, 0.7)
                    local pixelX, pixelY = Grid.toPixels(selectedTarget.tileX, selectedTarget.tileY)
                    love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)

                    -- Also highlight the destination tile with the same color
                    local shover = world.ui.menus.action.unit
                    if shover then
                        local dx = selectedTarget.tileX - shover.tileX
                        local dy = selectedTarget.tileY - shover.tileY
                        local destTileX, destTileY = selectedTarget.tileX + dx, selectedTarget.tileY + dy
                        local destPixelX, destPixelY = Grid.toPixels(destTileX, destTileY)
                        love.graphics.rectangle("fill", destPixelX + BORDER_WIDTH, destPixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                    end
                end
            end
        elseif world.ui.playerTurnState == "take_targeting" and world.ui.targeting.take.active then
            local take = world.ui.targeting.take
            -- Draw all potential targets with a base color
            love.graphics.setColor(0.8, 0.2, 0.8, 0.4) -- Semi-transparent magenta
            for _, target in ipairs(take.targets) do
                local pixelX, pixelY = Grid.toPixels(target.tileX, target.tileY)
                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
            end

            -- Draw the selected target with a brighter color
            if #take.targets > 0 then
                local selectedTarget = take.targets[take.selectedIndex]
                if selectedTarget then
                    love.graphics.setColor(0.8, 0.2, 0.8, 0.7) -- Brighter magenta
                    local pixelX, pixelY = Grid.toPixels(selectedTarget.tileX, selectedTarget.tileY)
                    love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                end
            end
        end
    end
end

local function draw_game_over_screen(world)
    -- Draw a dark, semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT)

    -- Draw "GAME OVER" text
    love.graphics.setColor(1, 0.1, 0.1, 1) -- Red
    local currentFont = love.graphics.getFont()
    -- Temporarily use a larger font for dramatic effect
    -- We create it here but don't store it, as it's only for this screen.
    local largeFont = love.graphics.newFont("assets/Px437_DOS-V_TWN16.ttf", 64)
    love.graphics.setFont(largeFont)
    love.graphics.printf("GAME OVER", 0, Config.VIRTUAL_HEIGHT / 2 - 64, Config.VIRTUAL_WIDTH, "center")

    -- Draw prompt to exit
    love.graphics.setFont(currentFont) -- Revert to the normal font
    love.graphics.setColor(1, 1, 1, 0.6 + (math.sin(love.timer.getTime() * 2) + 1) / 2 * 0.4) -- Pulsing alpha
    love.graphics.printf("Press [Escape] to Exit", 0, Config.VIRTUAL_HEIGHT / 2 + 20, Config.VIRTUAL_WIDTH, "center")
end

local function draw_pause_screen(world)
    -- Draw a dark, semi-transparent overlay to dim the game world but keep it visible.
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT)

    -- Draw "PAUSED" text using a large font.
    love.graphics.setColor(1, 1, 1, 1) -- White
    local currentFont = love.graphics.getFont()
    -- Use the pre-loaded title font for consistency.
    local largeFont = Assets.fonts.title or love.graphics.newFont("assets/Px437_DOS-V_TWN16.ttf", 64)
    love.graphics.setFont(largeFont)
    love.graphics.printf("PAUSED", 0, Config.VIRTUAL_HEIGHT / 2 - 64, Config.VIRTUAL_WIDTH, "center")

    -- Draw a prompt to resume the game.
    love.graphics.setFont(currentFont) -- Revert to the normal font
    love.graphics.setColor(1, 1, 1, 0.6 + (math.sin(love.timer.getTime() * 2) + 1) / 2 * 0.4) -- Pulsing alpha
    love.graphics.printf("Press [Escape] to Resume", 0, Config.VIRTUAL_HEIGHT / 2 + 20, Config.VIRTUAL_WIDTH, "center")
end

local function draw_weapon_select_menu(world)
    local menu = world.ui.menus.weaponSelect
    if not menu.active then return end

    local font = love.graphics.getFont()

    -- Menu dimensions and positioning
    -- Position it to the left of the unit info menu.
    local menuWidth = 190 -- Increased width to prevent text overlap
    -- The unit info menu is 200px wide with a 10px gap from the right edge.
    local unitInfoMenuX = Config.VIRTUAL_WIDTH - 200 - 10
    local menuX = unitInfoMenuX - menuWidth - 10 -- Place it to the left with a 10px gap.

    -- Calculate height based on number of options.
    local sliceHeight = 22
    local headerHeight = 30
    local menuHeight = headerHeight + (#menu.options * sliceHeight)
    local menuY = 10 -- Align with the top of the unit info menu.

    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.9) -- Dark blueish background
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
    love.graphics.setColor(0.8, 0.8, 0.9, 1) -- Light border
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
    love.graphics.setLineWidth(1)

    -- Draw header
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Equip Weapon", menuX, menuY + 5, menuWidth, "center")

    -- Draw weapon options
    local yOffset = menuY + headerHeight
    for i, optionKey in ipairs(menu.options) do
        local isSelected = (i == menu.selectedIndex)
        local textY = yOffset + (sliceHeight - font:getHeight()) / 2
        local textX = menuX + 10

        if optionKey == "unequip" then
            -- Special drawing for the "Unequip" option
            if isSelected then
                love.graphics.setColor(0.95, 0.95, 0.7, 0.9) -- Cream/yellow for selected
                love.graphics.rectangle("fill", menuX + 1, yOffset, menuWidth - 2, sliceHeight)
                love.graphics.setColor(0, 0, 0, 1) -- Black text
            else
                love.graphics.setColor(1, 1, 1, 1) -- White text
            end
            love.graphics.print("Unequip", textX, textY)
        else
            -- Existing logic for drawing weapon names
            local weapon = WeaponBlueprints[optionKey]
            if weapon then
                if isSelected then
                    love.graphics.setColor(0.95, 0.95, 0.7, 0.9) -- Cream/yellow for selected
                    love.graphics.rectangle("fill", menuX + 1, yOffset, menuWidth - 2, sliceHeight)
                end

                if isSelected then love.graphics.setColor(0, 0, 0, 1) else love.graphics.setColor(1, 1, 1, 1) end

                -- Draw icon
                local weaponIcon = Assets.getWeaponIcon(weapon.type)
                if weaponIcon then
                    local iconY = yOffset + (sliceHeight - weaponIcon:getHeight()) / 2
                    love.graphics.draw(weaponIcon, textX, iconY, 0, 1, 1)
                    textX = textX + weaponIcon:getWidth() + 4
                end

                love.graphics.print(weapon.name, textX, textY)

                -- Draw the quantity of the weapon, right-aligned.
                local quantity = world.playerInventory.weapons[optionKey] or 0
                local quantityText = "x" .. quantity
                local quantityWidth = font:getWidth(quantityText)
                -- The color is already set correctly (white for normal, black for selected).
                love.graphics.print(quantityText, menuX + menuWidth - quantityWidth - 10, textY)
            end
        end
        yOffset = yOffset + sliceHeight
    end
end

local function draw_screen_space_ui(world)
    -- Draw Action Menu
    -- Only draw the menu if it's active AND the range fade effect is finished (or not active).
    if world.ui.menus.action.active and not (world.ui.pathing.rangeFadeEffect and world.ui.pathing.rangeFadeEffect.active) then
        local menu = world.ui.menus.action
        local unit = menu.unit
        if not unit then return end -- Can't draw without a unit

        -- Convert world coordinates to screen coordinates for UI positioning
        local screenUnitX = unit.x - Camera.x
        local screenUnitY = unit.y - Camera.y
        local font = love.graphics.getFont()

        -- Check if the currently selected move has power to determine if we need an extra slice.
        local selectedOption = menu.options[menu.selectedIndex]
        local selectedAttackData = selectedOption and AttackBlueprints[selectedOption.key]

        -- New: Fixed width for the menu.
        local menuWidth = 180
        local sliceHeight = 25 -- A bit taller for a nicer look
        local mainOptionsHeight = #menu.options * sliceHeight

        -- New: Calculate height for power and description slices.
        local powerSliceHeight = sliceHeight
        local descText = (selectedAttackData and selectedAttackData.description) or ""
        local wrappedLines = wrapText(descText, menuWidth - 20, font) -- 10px padding on each side
        local descLineHeight = font:getHeight() * 1.2
        local descriptionSliceHeight = 10 + 4 * descLineHeight -- Fixed height for 4 lines of text.

        local menuHeight = mainOptionsHeight + powerSliceHeight + descriptionSliceHeight
        local menuX = screenUnitX + unit.size + 5 -- Position it to the right of the unit
        local menuY = screenUnitY + (unit.size / 2) - mainOptionsHeight -- Anchor the top of the menu relative to the main options, not the total height.

        -- Clamp menu position to stay on screen
        if menuX + menuWidth > Config.VIRTUAL_WIDTH then menuX = screenUnitX - menuWidth - 5 end
        if menuY + menuHeight > Config.VIRTUAL_HEIGHT then menuY = Config.VIRTUAL_HEIGHT - menuHeight end
        menuX = math.max(0, menuX)
        menuY = math.max(0, menuY)

        -- Draw menu options as a stack of slices
        local horizontalShift = 10 -- How much the selected slice shifts left

        for i, option in ipairs(menu.options) do
            local sliceX = menuX
            local sliceY = menuY + (i - 1) * sliceHeight
            local sliceColor, textColor
 
            -- Determine if the option is usable (has targets and enough wisp)
            local is_usable = true
            local attackData = AttackBlueprints[option.key]
            if attackData then
                -- Check for wisp cost
                if attackData.wispCost and menu.unit.wisp < attackData.wispCost then
                    is_usable = false
                end
                -- Check for valid targets if wisp is sufficient
                if is_usable and attackData.targeting_style == "cycle_target" then
                    local validTargets = WorldQueries.findValidTargetsForAttack(menu.unit, option.key, world)
                    if #validTargets == 0 then
                        is_usable = false
                    end
                end
            end

            if i == menu.selectedIndex then
                -- Selected slice: shift left, bright color
                sliceX = sliceX - horizontalShift
                sliceColor = {0.95, 0.95, 0.7, 0.9}
                textColor = {0, 0, 0, 1} -- Black
            else
                -- Unselected slice: normal position, darker color
                sliceColor = {0.2, 0.2, 0.1, 0.9}
                textColor = {1, 1, 1, 1} -- White
            end

            -- If the option is not usable, grey it out
            if not is_usable then
                sliceColor = {0.2, 0.2, 0.2, 0.8} -- Dark grey
                textColor = {0.5, 0.5, 0.5, 1} -- Grey
            end

            -- Draw the slice background
            love.graphics.setColor(sliceColor)
            love.graphics.rectangle("fill", sliceX, sliceY, menuWidth, sliceHeight)

            -- Draw the text
            love.graphics.setColor(textColor)
            local textY = sliceY + (sliceHeight - font:getHeight()) / 2
            love.graphics.print(option.text, sliceX + 10, textY)

            -- Draw wisp cost diamonds
            if attackData and attackData.wispCost and attackData.wispCost > 0 then
                local wispString = string.rep("♦", attackData.wispCost) -- The diamonds themselves
                local wispWidth = font:getWidth(wispString)
                -- Use the same text color for the wisp cost
                love.graphics.setColor(textColor)
                love.graphics.print(wispString, sliceX + menuWidth - wispWidth - 10, textY) -- Right-align the wisp cost
            end
        end

        -- Draw the static "Power" slice.
        local powerSliceY = menuY + mainOptionsHeight
        local powerValueText = "--"
        if selectedAttackData then
            if selectedAttackData.displayPower then
                powerValueText = selectedAttackData.displayPower
            elseif selectedAttackData.power and selectedAttackData.power > 0 then
                powerValueText = tostring(selectedAttackData.power)
            end
        end

        -- Draw the slice background (always unselected style)
        love.graphics.setColor(0.2, 0.2, 0.1, 0.9)
        love.graphics.rectangle("fill", menuX, powerSliceY, menuWidth, powerSliceHeight)

        -- Draw separator line at the top of the slice
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", menuX, powerSliceY, menuWidth, 2)

        -- Draw the text
        love.graphics.setColor(1, 1, 1, 1) -- White text
        local textY = powerSliceY + (powerSliceHeight - font:getHeight()) / 2
        love.graphics.print("Power", menuX + 10, textY)

        -- Draw the right-aligned power value
        local valueWidth = font:getWidth(powerValueText)
        love.graphics.print(powerValueText, menuX + menuWidth - valueWidth - 10, textY)

        -- Draw the static "Description" slice.
        local descriptionSliceY = powerSliceY + powerSliceHeight

        -- Draw the slice background
        love.graphics.setColor(0.2, 0.2, 0.1, 0.9)
        love.graphics.rectangle("fill", menuX, descriptionSliceY, menuWidth, descriptionSliceHeight)

        -- Draw separator line at the top of the slice
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", menuX, descriptionSliceY, menuWidth, 2)

        -- Draw the wrapped description text
        love.graphics.setColor(1, 1, 1, 1)
        for i, line in ipairs(wrappedLines) do
            local lineY = descriptionSliceY + 5 + (i - 1) * descLineHeight
            love.graphics.print(line, menuX + 10, lineY)
        end
    end

    -- Draw Map Menu
    if world.ui.menus.map.active then
        local menu = world.ui.menus.map
        local cursorTile = world.ui.mapCursorTile
        local worldCursorX, worldCursorY = Grid.toPixels(cursorTile.x, cursorTile.y)
        local font = love.graphics.getFont()

        -- Convert world coordinates to screen coordinates for UI positioning
        local screenCursorX = worldCursorX - Camera.x
        local screenCursorY = worldCursorY - Camera.y

        -- Dynamically calculate menu width based on the longest option text
        local maxTextWidth = 0
        for _, option in ipairs(menu.options) do
            maxTextWidth = math.max(maxTextWidth, font:getWidth(option.text))
        end
        local menuWidth = maxTextWidth + 20 -- 10px padding on each side
        local menuHeight = #menu.options * 20 + 10
        local menuX = screenCursorX + Config.SQUARE_SIZE + 5 -- Position it to the right of the cursor
        local menuY = screenCursorY

        -- Clamp menu position to stay on screen
        if menuX + menuWidth > Config.VIRTUAL_WIDTH then menuX = screenCursorX - menuWidth - 5 end
        if menuY + menuHeight > Config.VIRTUAL_HEIGHT then menuY = Config.VIRTUAL_HEIGHT - menuHeight end
        menuX = math.max(0, menuX)
        menuY = math.max(0, menuY)

        -- Draw menu background
        love.graphics.setColor(0.1, 0.1, 0.2, 0.8)
        love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
        love.graphics.setColor(0.8, 0.8, 0.9, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
        love.graphics.setLineWidth(1)

        -- Draw menu options
        for i, option in ipairs(menu.options) do
            local yPos = menuY + 5 + (i - 1) * 20
            if i == menu.selectedIndex then
                love.graphics.setColor(1, 1, 0, 1) -- Yellow for selected
            else
                love.graphics.setColor(1, 1, 1, 1) -- White for others
            end
            love.graphics.print(option.text, menuX + 10, yPos)
        end
    end

    -- Draw Battle Info Menu
    BattleInfoMenu.draw(world)

    -- Draw Unit Info Menu
    UnitInfoMenu.draw(world)

    -- Draw Weapon Select Menu
    draw_weapon_select_menu(world)

    -- Draw Promotion Menu
    PromotionMenu.draw(world)

    -- Draw Game Over Screen (this is a screen-space UI)
    if world.gameState == "game_over" then
        draw_game_over_screen(world)
    end
end

--------------------------------------------------------------------------------
-- MAIN DRAW FUNCTION
--------------------------------------------------------------------------------

function Renderer.draw(world)
    -- 1. Clear the screen with a background color
    love.graphics.clear(0.1, 0.1, 0.1, 1)

    -- 2. Draw the Tiled map.
    -- The 'sti' library handles its own drawing to an internal canvas and resets the graphics state.
    -- Because of this, we can't use Camera.apply() for the map itself. Instead, we must pass
    -- the camera's translation directly to the map's draw function.
    if world.map then
        world.map:draw(-math.floor(Camera.x), -math.floor(Camera.y))
    end

    -- 3. Now, apply the camera's transformation to draw all other world-space objects
    -- (entities, UI elements like range indicators, etc.) so they are positioned correctly
    -- relative to the map.
    Camera.apply()
    draw_world_space_ui(world)
    draw_all_entities_and_effects(world)

    -- Draw the EXP bar here, so it's in world-space and on top of entities.
    ExpBarRendererSystem.draw(world)

    Camera.revert()

    -- 4. Draw screen-space UI based on the current game state
    if world.gameState == "gameplay" then
        draw_screen_space_ui(world)
    elseif world.gameState == "paused" then
        -- Draw the pause screen on top of the frozen game state.
        draw_pause_screen(world)
    elseif world.gameState == "game_over" then
        -- The game over screen is drawn on top of the final game state.
        draw_screen_space_ui(world)
    end

    -- 5. Reset graphics state to be safe
    love.graphics.setColor(1, 1, 1, 1)
end

return Renderer