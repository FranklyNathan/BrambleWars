-- effect_factory.lua
-- A factory module responsible for creating all temporary game effects,
-- like damage popups, attack visuals, and particle effects.

local AttackPatterns = require("modules.attack_patterns")
local WorldQueries = require("modules.world_queries")

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
        currentFlashTimer = options.duration or Config.FLASH_DURATION,
        flashDuration = options.duration or Config.FLASH_DURATION,
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

function EffectFactory.createExpPopEffect(world, unit)
    if not unit then return end
    local anim = world.ui.expGainAnimation
    if not anim or not anim.active then return end

    -- Calculate the position of the EXP bar to center the effect.
    local barW = unit.size
    local hpBarHeight = WorldQueries.getUnitHealthBarHeight(unit, world)
    local hpBarTopY = math.floor(unit.y + unit.size - 2)
    local barY = hpBarTopY + hpBarHeight
    local barCenterX = unit.x + barW / 2
    local barCenterY = barY + 3 -- Center of the bar's height (6px)

    local numParticles = 40
    local colors = {
        {1, 0.9, 0.2, 1}, -- Golden Yellow
        {0, 1, 1, 1},     -- Cyan
        {1, 1, 1, 1}      -- White
    }

    for i = 1, numParticles do
        local angle = math.random() * 2 * math.pi
        local speed = math.random(50, 150)
        table.insert(world.particleEffects, {
            x = barCenterX, y = barCenterY,
            size = math.random(2, 4),
            vx = math.cos(angle) * speed, vy = math.sin(angle) * speed,
            lifetime = math.random() * 0.6 + 0.3, -- 0.3 to 0.9 seconds
            initialLifetime = 0.6,
            color = colors[math.random(1, #colors)]
        })
    end
end

function EffectFactory.createRippleEffect(world, attacker, attackName, centerX, centerY, rippleCenterSize, targetType, statusEffect, specialProperties)
    -- Look up the attack's data to find its pattern.
    local attackData = AttackBlueprints[attackName]
    local patternFunc = attackData and attackData.patternType and AttackPatterns[attackData.patternType]

    -- Ensure the pattern is a function before calling it.
    if type(patternFunc) ~= "function" then
        print("Warning: createRippleEffect called for attack '" .. tostring(attackName) .. "' which has no valid pattern function.")
        return
    end

    -- Generate the full ripple pattern using the dynamically found function.
    local fullPattern = patternFunc(centerX, centerY, rippleCenterSize)

    -- Add all effects from the pattern to the queue
    -- The rippleEffectQueue should be initialized in the world object itself.
    table.insert(world.rippleEffectQueue, { attacker = attacker, attackName = attackName, pattern = fullPattern, currentIndex = 1, targetType = targetType, statusEffect = statusEffect, specialProperties = specialProperties or {}})
end

return EffectFactory