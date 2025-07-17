-- effect_factory.lua
-- A factory module responsible for creating all temporary game effects,
-- like damage popups, attack visuals, and particle effects.

local AttackPatterns = require("modules.attack_patterns")
local world_ref -- A reference to the main world object

local EffectFactory = {}

function EffectFactory.init(world)
    world_ref = world
end

function EffectFactory.addAttackEffect(effectX, effectY, effectWidth, effectHeight, effectColor, delay, attacker, power, isHeal, targetType, critChanceOverride, statusEffect, specialProperties)
    table.insert(world_ref.attackEffects, {
        x = effectX, y = effectY, width = effectWidth, height = effectHeight,
        color = effectColor,
        initialDelay = delay,
        currentFlashTimer = Config.FLASH_DURATION,
        flashDuration = Config.FLASH_DURATION,
        attacker = attacker,
        power = power,
        amount = isHeal and power or nil, -- Keep amount for healing logic for now
        critChanceOverride = critChanceOverride,
        isHeal = isHeal,
        effectApplied = false,
        targetType = targetType,
        statusEffect = statusEffect, -- e.g., {type="stunned", duration=1}
        specialProperties = specialProperties
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

function EffectFactory.createRippleEffect(attacker, centerX, centerY, power, rippleCenterSize, targetType, statusEffect)
    -- Use the centralized ripple pattern generator
    local ripplePattern = AttackPatterns.ripple(centerX, centerY, rippleCenterSize)

    for _, effectData in ipairs(ripplePattern) do
        local s = effectData.shape
        EffectFactory.addAttackEffect(s.x, s.y, s.w, s.h, {1, 0, 0, 1}, effectData.delay, attacker, power, false, targetType, nil, statusEffect)
    end
end

return EffectFactory