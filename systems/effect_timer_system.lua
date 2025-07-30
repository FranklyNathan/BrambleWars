-- effect_timer_system.lua
-- This system is responsible for updating simple countdown timers on entities for visual effects.

local EffectFactory = require("modules.effect_factory")
local Assets = require("modules.assets")

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

        -- Update selection_flash timer
        if s.components.selection_flash then
            s.components.selection_flash.timer = s.components.selection_flash.timer + dt
            if s.components.selection_flash.timer >= s.components.selection_flash.duration then
                s.components.selection_flash = nil -- Remove the component to end the effect
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
    if world.rippleEffectQueue and #world.rippleEffectQueue > 0 then
        local rippleData = world.rippleEffectQueue[1] -- Process the first ripple in the queue

        -- Check if we're still adding effects from this ripple
        if rippleData.currentIndex <= #rippleData.pattern then
            local effectData = rippleData.pattern[rippleData.currentIndex]
            local s = effectData.shape
            local color = {1, 0, 0, 1} -- Default color (adjust if needed)

            -- Create a single attack effect with its delay
            EffectFactory.addAttackEffect(world, {
                attacker = rippleData.attacker,
                attackName = rippleData.attackName,
                x = s.x,
                y = s.y,
                width = s.w,
                height = s.h,
                color = color,
                delay = effectData.delay,
                targetType = rippleData.targetType,
                statusEffect = rippleData.statusEffect,
                specialProperties = rippleData.specialProperties
            })
            
            -- Move to the next effect in the ripple
            rippleData.currentIndex = rippleData.currentIndex + 1
        else
            -- All effects from this ripple have been added. Remove from the queue
            table.remove(world.rippleEffectQueue, 1)
        end
    end
    -- Check for delays and add subsequent ripple effect when appropriate.
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
                        anim.state = "lingering"
                        anim.lingerTimer = 1.0
                    end
                -- If no pop, check if the regular fill animation is finished.
                elseif progress >= 1 then
                    -- Snap to final value to avoid float inaccuracies.
                    anim.expCurrentDisplay = targetExp
                    -- Transition to lingering state.
                    anim.state = "lingering"
                    anim.lingerTimer = 1.0 -- Linger for 1 second.
                end
            elseif anim.state == "lingering" then
                anim.lingerTimer = math.max(0, anim.lingerTimer - dt)
                if anim.lingerTimer == 0 then
                    -- The linger is over. Reset the state.
                    anim.active = false
                    anim.unit = nil
                    anim.state = "idle"
                end
            end
        end
    end

        -- Handle the next effect in queue, if any and it is time.
       
        
        
    
end

return EffectTimerSystem