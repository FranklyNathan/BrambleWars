-- effect_factory.lua
-- A factory module responsible for creating all temporary game effects,
-- like damage popups, attack visuals, and particle effects.

local AttackPatterns = require("modules.attack_patterns")
local world_ref -- A reference to the main world object

local EffectFactory = {}

function EffectFactory.init(world)
    world_ref = world
end

function EffectFactory.addAttackEffect(attacker, attackName, effectX, effectY, effectWidth, effectHeight, effectColor, delay, isHeal, targetType, critOverride, statusEffect, specialProperties)
    table.insert(world_ref.attackEffects, {
        x = effectX, y = effectY, width = effectWidth, height = effectHeight,
        color = effectColor,
        initialDelay = delay,
        currentFlashTimer = Config.FLASH_DURATION,
        flashDuration = Config.FLASH_DURATION,
        attacker = attacker,
        -- New centralized attack effect attributes
        attackName = attackName, -- Attack name is required now
        critOverride = critOverride, -- Instead of critChanceOverride
        amount = isHeal and 5 or nil, -- Keep amount for healing logic for now - hardcoded for now
        isHeal = isHeal,
        effectApplied = false,
        targetType = targetType,
        statusEffect = statusEffect,
        specialProperties = specialProperties or {} -- Ensure this is never nil
    })
end

function EffectFactory.createDamagePopup(target, damage, isCrit, colorOverride)
    local popup = {
        text = tostring(damage),
        x = target.x + target.size, -- To the right of the square
        y = target.y,
        vy = -50, -- Moves upwards
        lifetime = 0.7,
        initialLifetime = 0.7,
        color = colorOverride or {1, 0.2, 0.2, 1}, -- Default to bright red
        scale = 1
    }
    if isCrit then
        popup.text = popup.text .. "!"
        popup.color = {1, 1, 0.2, 1} -- Bright yellow
        popup.scale = 1.2 -- Slightly bigger
    end
    table.insert(world_ref.damagePopups, popup)
end

function EffectFactory.createShatterEffect(x, y, size, color)
    local numParticles = 30
    for i = 1, numParticles do
        table.insert(world_ref.particleEffects, {
            x = x + size / 2,
            y = y + size / 2,
            size = math.random(1, 3),
            -- Random velocity in any direction
            vx = math.random(-100, 100),
            vy = math.random(-100, 100),
            lifetime = math.random() * 0.5 + 0.2, -- 0.2 to 0.7 seconds
            initialLifetime = 0.5,
            color = color or {0.7, 0.7, 0.7, 1} -- Default to grey
        })
    end
end

function EffectFactory.createRippleEffect(attacker, attackName, centerX, centerY, rippleCenterSize, targetType, statusEffect, specialProperties)
    -- Use the centralized ripple pattern generator
    local ripplePattern = AttackPatterns.eruption_aoe(centerX, centerY, rippleCenterSize)
    local color = {1, 0, 0, 1} -- Default ripple color

    for _, effectData in ipairs(ripplePattern) do
        local s = effectData.shape
        -- Correctly call addAttackEffect with the right arguments.
        EffectFactory.addAttackEffect(attacker, attackName, s.x, s.y, s.w, s.h, color, effectData.delay, false, targetType, nil, statusEffect, specialProperties)
    end
end

return EffectFactory