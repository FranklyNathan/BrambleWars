-- effect_timer_system.lua
-- This system is responsible for updating simple countdown timers on entities for visual effects.

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
                    s.components.pending_damage = nil
                else
                    -- This value will be read by the renderer to draw the white "draining" part of the bar.
                    pending.displayAmount = pending.amount * (pending.timer / pending.initialTimer)
                end
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

    -- Live Combat Displays
    for i = #world.liveCombatDisplays, 1, -1 do
        local display = world.liveCombatDisplays[i]
        display.timer = display.timer - dt

        -- Update shake timer for the display if it exists (for critical hits)
        if display.shake then
            display.shake.timer = display.shake.timer - dt
            if display.shake.timer <= 0 then
                display.shake = nil
            end
        end

        if display.timer <= 0 then
            table.remove(world.liveCombatDisplays, i)
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
end

return EffectTimerSystem