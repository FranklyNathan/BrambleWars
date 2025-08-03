-- effect_timer_system.lua
-- This system is responsible for updating simple countdown timers on entities for visual effects.

local EffectFactory = require("modules.effect_factory")
local CharacterBlueprints = require("data.character_blueprints")
local Assets = require("modules.assets")
local StatusEffectManager = require("modules.status_effect_manager")
local TileStatusBlueprints = require("data.tile_status_blueprints")

-- A simple linear interpolation function.
local function lerp(a, b, t)
    return a + (b - a) * t
end

local EffectTimerSystem = {}

function EffectTimerSystem.update(dt, world)
    -- 1. Update timers on entity components
    for _, s in ipairs(world.all_entities) do
        -- Update shake timer
        -- The check for s.components is no longer needed, as world.lua now guarantees it exists.
        if s.components.shake then
            s.components.shake.timer = s.components.shake.timer - dt
            if s.components.shake.timer <= 0 then
                s.components.shake = nil -- Remove the component to end the effect
            end
        end

        -- Update lunge timer
        if s.components.lunge then
            s.components.lunge.timer = s.components.lunge.timer - dt
            if s.components.lunge.timer <= 0 then
                s.components.lunge = nil
            end
        end

        -- Update knockback timer
        if s.components.knockback_animation then
            s.components.knockback_animation.timer = math.max(0, s.components.knockback_animation.timer - dt)
            if s.components.knockback_animation.timer <= 0 then
                s.components.knockback_animation = nil
            end
        end

        -- Update rescue animation timer
        if s.components.being_rescued then
            s.components.being_rescued.timer = s.components.being_rescued.timer - dt
            if s.components.being_rescued.timer <= 0 then
                s.isMarkedForDeletion = true
                s.components.being_rescued = nil
            end
        end

        -- Update damage tint timer
        if s.components.damage_tint then
            s.components.damage_tint.timer = s.components.damage_tint.timer - dt
            if s.components.damage_tint.timer <= 0 then
                s.components.damage_tint = nil
            end
        end

        -- Update fade_out timer
        if s.components.fade_out then
            s.components.fade_out.timer = s.components.fade_out.timer - dt
            if s.components.fade_out.timer <= 0 then
                s.isMarkedForDeletion = true -- Mark for deletion now that the fade is complete.
                s.components.fade_out = nil
            end
        end

        -- New: Handle reviving animation for Necromantia
        if s.components.reviving then
            local reviving = s.components.reviving
            reviving.timer = math.max(0, reviving.timer - dt)
            if reviving.timer == 0 then
                -- Animation is finished. Finalize the revival.
                s.hp = s.finalMaxHp
                s.wisp = s.finalMaxWisp
                s.hasActed = false -- Now the unit can act.
                s.components.reviving = nil
            end
        end

        -- Update selection_flash timer
        if s.components.selection_flash then
            s.components.selection_flash.timer = s.components.selection_flash.timer + dt
            if s.components.selection_flash.timer >= s.components.selection_flash.duration then
                s.components.selection_flash = nil -- Remove the component to end the effect
            end
        end

        -- Update ascending animation for Ascension ability
        if s.components.ascending_animation then
            local asc = s.components.ascending_animation
            asc.timer = asc.timer - dt

            -- Store old position for afterimage
            local oldX, oldY = s.x, s.y

            -- Move the unit's sprite rapidly upwards.
            s.y = s.y - (asc.speed * dt)

            -- Create afterimage for the ascent trail
            if not s.components.afterimage then
                s.components.afterimage = { timer = 0, interval = 0.03 } -- A smaller interval for a smoother trail
            end
            local afterimage = s.components.afterimage
            afterimage.timer = afterimage.timer + dt
            if afterimage.timer >= afterimage.interval then
                afterimage.timer = afterimage.timer - afterimage.interval

                -- Determine the color for the trail based on the unit's blueprint.
                local streakColor = {1, 1, 1} -- Default to white
                if s.type == "player" and CharacterBlueprints[s.playerType] then
                    streakColor = CharacterBlueprints[s.playerType].dominantColor or streakColor
                end

                -- Get the current sprite frame for the afterimage.
                local streakWidth, streakHeight = s.size, s.size
                local currentFrame, spriteSheet = nil, nil
                if s.components.animation then
                    local animComponent = s.components.animation
                    local currentAnim = animComponent.animations[animComponent.current]
                    if currentAnim then
                        streakWidth, streakHeight = currentAnim:getDimensions()
                        currentFrame = currentAnim.frames[currentAnim.position]
                        spriteSheet = animComponent.spriteSheet
                    end
                end

                table.insert(world.afterimageEffects, { x = oldX, y = oldY, size = s.size, width = streakWidth, height = streakHeight, frame = currentFrame, spriteSheet = spriteSheet, color = streakColor, lifetime = 0.3, initialLifetime = 0.3, direction = s.lastDirection })
            end

            -- When the timer is up, the animation is over. The unit is now fully ascended and will be hidden by the renderer.
            if asc.timer <= 0 then
                s.components.ascending_animation = nil
                s.components.afterimage = nil -- Clean up the afterimage component as well
                -- Snap the target Y to the current Y to prevent the movement system from pulling it back down.
                s.targetY = s.y
            end
        end

        -- Update pending_damage timer for health bar animation
        if s.components.pending_damage then
            local pending = s.components.pending_damage
            -- New logic with a delay before draining starts.
            if pending.delay and pending.delay > 0 then
                -- We are in the initial pause phase.
                pending.delay = pending.delay - dt
                -- During the delay, the display amount should show the full damage.
                pending.displayAmount = pending.amount
            else
                -- The pause is over, now we animate the drain.
                pending.timer = pending.timer - dt
                if pending.timer <= 0 then
                    -- Trigger shrink on both participants when the animation finishes.
                    if pending.attacker and pending.attacker.components then
                        pending.attacker.components.shrinking_health_bar = { timer = 0.3, initialTimer = 0.3 }
                    end
                    s.components.shrinking_health_bar = { timer = 0.3, initialTimer = 0.3 }

                    s.components.pending_damage = nil
                else
                    -- This value will be read by the renderer to draw the white "draining" part of the bar.
                    pending.displayAmount = pending.amount * (pending.timer / pending.initialTimer)
                end
            end
        end

        -- Update health bar shrink animation timer
        if s.components.shrinking_health_bar then
            local shrink = s.components.shrinking_health_bar
            shrink.timer = math.max(0, shrink.timer - dt)
            if shrink.timer == 0 then
                s.components.shrinking_health_bar = nil
            end
        end

        -- Update time-based status effects like 'airborne'. This ensures the visual
        -- effect (like rotation) progresses smoothly over time, not just at turn ends.
        if s.statusEffects and s.statusEffects.airborne then
            local effect = s.statusEffects.airborne
            -- Only tick down the duration if it's not being actively controlled by another system (like Aetherfall).
            if not effect.aetherfall_controlled then
                effect.duration = effect.duration - dt
                if effect.duration <= 0 then
                    s.statusEffects.airborne = nil
                end
            end
        end
    end

    -- Update any existing sinking animations.
    for _, entity in ipairs(world.all_entities) do
        if entity.components and entity.components.sinking then
            local sinking = entity.components.sinking
            sinking.timer = math.max(0, sinking.timer - dt)
            if sinking.timer == 0 then
                entity.isMarkedForDeletion = true
                entity.components.sinking = nil
            end
        end
    end

    -- 2. Update standalone visual effects
    -- Afterimages
    for i = #world.afterimageEffects, 1, -1 do
        local effect = world.afterimageEffects[i]
        effect.lifetime = effect.lifetime - dt
        if effect.lifetime <= 0 then
            table.remove(world.afterimageEffects, i)
        end
    end

    -- Damage Popups
    for i = #world.damagePopups, 1, -1 do
        local popup = world.damagePopups[i]
        popup.lifetime = popup.lifetime - dt
        if popup.lifetime <= 0 then
            table.remove(world.damagePopups, i)
        else
            popup.y = popup.y + popup.vy * dt -- Move it upwards
        end
    end

    -- Particle Effects
    for i = #world.particleEffects, 1, -1 do
        local p = world.particleEffects[i]
        p.lifetime = p.lifetime - dt
        if p.lifetime <= 0 then
            table.remove(world.particleEffects, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
    end

    -- Attack Effects (hit tiles)
    for i = #world.attackEffects, 1, -1 do
        local effect = world.attackEffects[i]
        if effect.initialDelay > 0 then
            effect.initialDelay = effect.initialDelay - dt
        else
            effect.currentFlashTimer = effect.currentFlashTimer - dt
            if effect.currentFlashTimer <= 0 then
                table.remove(world.attackEffects, i)
            end
        end
    end

    -- 3. Update range fade-out effect timer
    if world.ui.pathing.rangeFadeEffect and world.ui.pathing.rangeFadeEffect.active then
        local effect = world.ui.pathing.rangeFadeEffect
        effect.timer = math.max(0, effect.timer - dt)
        if effect.timer == 0 then
            -- The fade is complete, clear the effect.
            world.ui.pathing.rangeFadeEffect = nil
        end
    end

    -- 4. Handle queued ripple effects
    -- Process all ripples in the queue for this frame. This is more robust than processing one per frame.
    for i = #world.rippleEffectQueue, 1, -1 do
        local rippleData = world.rippleEffectQueue[i]

        -- Create all attack effects defined in the ripple's pattern at once.
        -- The individual 'delay' on each effect will handle the timing of its activation.
        for _, effectData in ipairs(rippleData.pattern) do
            local s = effectData.shape
            local color = {1, 0, 0, 1} -- Default color (adjust if needed)

            EffectFactory.addAttackEffect(world, {
                attacker = rippleData.attacker,
                attackName = rippleData.attackName,
                x = s.x, y = s.y,
                width = s.w, height = s.h,
                color = color,
                delay = effectData.delay,
                targetType = rippleData.targetType,
                statusEffect = rippleData.statusEffect,
                specialProperties = rippleData.specialProperties
            })
        end

        -- The ripple has been fully processed, so remove it from the queue.
        table.remove(world.rippleEffectQueue, i)
    end

    -- 5. Update EXP gain animation
    if world.ui.expGainAnimation and world.ui.expGainAnimation.active then
        local anim = world.ui.expGainAnimation
        local unit = anim.unit

        -- Failsafe in case the unit was somehow cleared but the animation is still active.
        if not unit then
            anim.active = false
        else
            if anim.state == "filling" then
                anim.animationTimer = math.min(anim.animationTimer + dt, anim.animationDuration)
                local progress = anim.animationTimer / anim.animationDuration

                -- The target EXP for the animation is the starting EXP plus the total gained.
                local targetExp = anim.expStart + anim.expGained
                anim.expCurrentDisplay = lerp(anim.expStart, targetExp, progress)

                -- Check if the bar has filled up to trigger a level-up "pop".
                if anim.expCurrentDisplay >= unit.maxExp then
                    -- Trigger the pop effect and sound.
                    EffectFactory.createExpPopEffect(world, unit)

                    -- Calculate remaining EXP to continue filling.
                    local totalExpFromStart = anim.expStart + anim.expGained
                    local remainingExp = totalExpFromStart - unit.maxExp

                    -- Reset the animation state to start filling from zero.
                    anim.expStart = 0
                    anim.expGained = remainingExp
                    anim.expCurrentDisplay = 0
                    anim.animationTimer = 0
                    -- Recalculate duration for the remaining amount.
                    anim.animationDuration = 0.5 + (remainingExp / 100) * 0.5

                    -- If there's no more EXP to gain after the pop, transition to lingering.
                    if remainingExp <= 0 then
                        anim.state = "shrinking"
                        anim.shrinkDuration = 0.3
                        anim.shrinkTimer = anim.shrinkDuration
                    end
                -- If no pop, check if the regular fill animation is finished.
                elseif progress >= 1 then
                    -- Snap to final value to avoid float inaccuracies.
                    anim.expCurrentDisplay = targetExp
                    -- Transition to shrinking state.
                    anim.state = "shrinking"
                    anim.shrinkDuration = 0.3 -- The duration of the shrink animation.
                    anim.shrinkTimer = anim.shrinkDuration
                end
            elseif anim.state == "shrinking" then
                anim.shrinkTimer = math.max(0, anim.shrinkTimer - dt)
                if anim.shrinkTimer == 0 then
                    -- The shrink is over. Reset the state.
                    anim.active = false
                    anim.unit = nil
                    anim.state = "idle"
                end
            end
        end
    end

    -- 6. Handle sequential fire spreading for tile statuses.
    if world.tileStatuses then
        local spreads_to_process = {}

        for posKey, status in pairs(world.tileStatuses) do
            if status.is_spreading then
                status.spread_timer = status.spread_timer - dt
                if status.spread_timer <= 0 then
                    table.insert(spreads_to_process, posKey)
                    -- Mark it so we don't process it again this frame.
                    status.is_spreading = false 
                end
            end
        end

        for _, posKey in ipairs(spreads_to_process) do
            local tileX = tonumber(string.match(posKey, "(-?%d+)"))
            local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
            
            -- Check neighbors and ignite them.
            local neighbors = {{dx=0,dy=-1},{dx=0,dy=1},{dx=-1,dy=0},{dx=1,dy=0}}
            for _, move in ipairs(neighbors) do
                local nextX, nextY = tileX + move.dx, tileY + move.dy
                local nextPosKey = nextX .. "," .. nextY
                local nextStatus = world.tileStatuses[nextPosKey]
                local nextBlueprint = nextStatus and TileStatusBlueprints[nextStatus.type]

                if nextBlueprint and nextBlueprint.spreads_fire then
                    local duration = (world.tileStatuses[posKey] and world.tileStatuses[posKey].duration) or 2
                    StatusEffectManager.igniteTileAndSpread(nextX, nextY, world, duration)
                end
            end
        end
    end
end

return EffectTimerSystem