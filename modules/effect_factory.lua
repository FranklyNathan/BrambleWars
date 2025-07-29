-- effect_factory.lua
-- A factory module responsible for creating all temporary game effects,
-- like damage popups, attack visuals, and particle effects.

local AttackPatterns = require("modules.attack_patterns")

local EffectFactory = {}

--[[
Refactored to accept an `options` table to improve readability and maintainability
by avoiding a long list of parameters. The `world` object is now passed directly
to each function, removing the need for a stateful `init` function and a global-like `world_ref`.
This makes the factory more modular and easier to test.
--]]
function EffectFactory.addAttackEffect(world, options)
    -- Ensure required fields are present
    assert(options.attacker, "addAttackEffect requires an attacker")
    assert(options.attackName, "addAttackEffect requires an attackName")

    table.insert(world.attackEffects, {
        x = options.x or 0,
        y = options.y or 0,
        width = options.width or 0,
        height = options.height or 0,
        color = options.color or {1, 1, 1, 1},
        initialDelay = options.delay or 0,
        currentFlashTimer = Config.FLASH_DURATION,
        flashDuration = Config.FLASH_DURATION,
        attacker = options.attacker,
        attackName = options.attackName,
        critOverride = options.critOverride,
        amount = options.amount,
        isHeal = options.isHeal or false,
        effectApplied = false,
        targetType = options.targetType,
        statusEffect = options.statusEffect,
        specialProperties = options.specialProperties or {} -- Ensure this is never nil
    })
end

function EffectFactory.createDamagePopup(world, target, damage, isCrit, colorOverride)
    local popup = {
        text = tostring(damage),
        x = target.x + target.size, -- To the right of the square
        y = target.y,
        vy = -50, -- Moves upwards
        lifetime = Config.POPUP_LIFETIME or 0.7,
        initialLifetime = Config.POPUP_LIFETIME or 0.7,
        color = colorOverride or {1, 0.2, 0.2, 1}, -- Default to bright red
        scale = 1
    }
    if isCrit then
        popup.text = popup.text .. "!"
        popup.color = {1, 1, 0.2, 1} -- Bright yellow
        popup.scale = 1.2 -- Slightly bigger
    end
    table.insert(world.damagePopups, popup)
end

function EffectFactory.createShatterEffect(world, x, y, size, color)
    local numParticles = 30
    for i = 1, numParticles do
        table.insert(world.particleEffects, {
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

function EffectFactory.createRippleEffect(world, attacker, attackName, centerX, centerY, rippleCenterSize, targetType, statusEffect, specialProperties)
    -- Generate the full ripple pattern
    local fullPattern = AttackPatterns.eruption_aoe(centerX, centerY, rippleCenterSize)

    -- Add all effects from the pattern to the queue
    -- The rippleEffectQueue should be initialized in the world object itself.
    table.insert(world.rippleEffectQueue, { attacker = attacker, attackName = attackName, pattern = fullPattern, currentIndex = 1, targetType = targetType, statusEffect = statusEffect, specialProperties = specialProperties or {}})
end

return EffectFactory