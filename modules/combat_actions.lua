-- combat_actions.lua
-- Contains functions that directly apply combat results like damage and healing to entities.

local StatusEffectManager = require("modules.status_effect_manager")
local EventBus = require("modules.event_bus")
local EffectFactory = require("modules.effect_factory")
local Grid = require("modules.grid")
local Assets = require("modules.assets")

local CombatActions = {}

function CombatActions.applyDirectHeal(target, healAmount)
    if target and target.hp and target.hp > 0 then
        target.hp = math.floor(target.hp + healAmount)
        if target.hp > target.finalMaxHp then target.hp = target.finalMaxHp end
        return true
    end
    return false
end
-- The attacker is passed in to correctly attribute kills for passives like Bloodrush.
function CombatActions.applyDirectDamage(world, target, damageAmount, isCrit, attacker, options)
    if not target or not target.hp or target.hp <= 0 then return end
    options = options or {} -- Ensure options table exists to prevent errors.

    -- Check for Tangrowth Square's shield first.
    if target.components.shielded then
        target.components.shielded = nil -- Consume the shield
        -- Create a "Blocked!" popup instead of a damage number.
        EffectFactory.createDamagePopup(world, target, "Blocked!", false, {0.7, 0.7, 1, 1}) -- Light blue text
        return -- Stop further processing, no damage is taken.
    end 

    local roundedDamage = math.floor(damageAmount)
    if roundedDamage > 0 then
        local wasAlive = target.hp > 0
        local hp_before_damage = target.hp
        target.hp = math.max(0, target.hp - roundedDamage)
        -- Only create the default popup if not explicitly told otherwise.
        if options.createPopup ~= false then
            EffectFactory.createDamagePopup(world, target, roundedDamage, isCrit)
        end
        target.components.shake = { timer = 0.2, intensity = 2 }
        target.components.damage_tint = { timer = 0.3, initialTimer = 0.3 } -- Add red tint effect

        -- Add the pending_damage component for the health bar animation.
        local actualDamageDealt = hp_before_damage - target.hp
        target.components.pending_damage = {
            amount = actualDamageDealt,
            delay = 0.2, -- A brief pause before the bar starts draining.
            timer = 0.6, -- The duration of the drain animation itself.
            initialTimer = 0.6,
            isCrit = isCrit,
            attacker = attacker
        }

        -- Check for Thunderguard passive on the target. This is the original implementation.
        -- It triggers here so it has access to the world state after damage is applied but before death is resolved.
        if wasAlive and target.type and world.teamPassives[target.type] and world.teamPassives[target.type].Thunderguard then
            local targetHasThunderguard = false
            for _, provider in ipairs(world.teamPassives[target.type].Thunderguard) do
                if provider == target then
                    targetHasThunderguard = true
                    break
                end
            end

            if targetHasThunderguard then
                local range = 2
                -- Apply paralysis to all enemy units in range.
                for _, unit in ipairs(world.all_entities) do
                    if unit ~= target and unit.hp and unit.hp > 0 and unit.type and unit.type ~= target.type then
                        local distance = math.abs(unit.tileX - target.tileX) + math.abs(unit.tileY - target.tileY)
                        if distance <= range then
                            StatusEffectManager.applyStatusEffect(unit, {type = "paralyzed", duration = 1}, world)
                        end
                    end
                end

                -- Create a visual effect for the tiles in range.
                for dx = -range, range do
                    for dy = -range, range do
                        if math.abs(dx) + math.abs(dy) <= range then
                            local tileX, tileY = target.tileX + dx, target.tileY + dy
                            if tileX >= 0 and tileX < world.map.width and tileY >= 0 and tileY < world.map.height then
                                local pixelX, pixelY = Grid.toPixels(tileX, tileY)
                                EffectFactory.addAttackEffect(world, { attacker = target, attackName = "thunderguard_retaliation", x = pixelX, y = pixelY, width = Config.SQUARE_SIZE, height = Config.SQUARE_SIZE, color = {1, 1, 0.2, 0.7}, targetType = "none" })
                            end
                        end
                    end
                end
            end
        end

        -- If the unit was alive and is now at 0 HP, it just died.
        if wasAlive and target.hp <= 0 then
            if target.isObstacle then
                -- The obstacle was destroyed.
                -- Don't delete immediately. Start a fade-out so the HP bar animation can play.
                -- The effect_timer_system will mark it for deletion when the timer is up.
                target.components.fade_out = { timer = 0.8, initialTimer = 0.8 }
                -- Create a shatter effect for visual feedback.
                local shatterColor = {0.4, 0.3, 0.2, 1} -- Brownish wood color
                EffectFactory.createShatterEffect(world, target.x, target.y, target.size, shatterColor)
                -- Play a sound effect.
                if Assets.sounds.tree_break then
                    Assets.sounds.tree_break:play()
                end
            else
                -- A unit died. Announce the death to any interested systems (quests, passives, etc.)
                EventBus:dispatch("unit_died", { victim = target, killer = attacker, world = world, reason = {type = "combat"} })
            end
        end
    end
end

function CombatActions.grantExp(unit, amount, world)
    -- Only players can gain EXP.
    if unit.type ~= "player" or unit.exp == nil then
        return
    end
    -- Don't grant exp if at max level (50).
    if unit.level >= 50 then
        unit.exp = 0 -- Keep exp at 0 if max level
        return
    end

    -- Set up the animation data BEFORE changing the unit's actual EXP.
    local anim = world.ui.expGainAnimation
    if not anim.active then
        anim.active = true
        anim.state = "filling"
        anim.unit = unit
        anim.expStart = unit.exp
        anim.expGained = amount
        anim.expCurrentDisplay = unit.exp
        anim.animationTimer = 0
        -- A base duration, plus a little extra for larger gains.
        anim.animationDuration = 0.5 + (amount / 100) * 0.5
        anim.lingerTimer = 0 -- Reset linger timer
    elseif anim.unit == unit then
        -- If an animation is already active for the same unit, just add to the gain.
        anim.expGained = anim.expGained + amount
        -- If it was lingering, restart the fill animation from its current point.
        if anim.state == "lingering" then
            anim.state = "filling"
            anim.animationTimer = 0
            anim.expStart = anim.expCurrentDisplay
            anim.animationDuration = 0.5 + (amount / 100) * 0.5 -- Recalculate duration for the new amount
        end
    end

    unit.exp = unit.exp + amount
    -- If the unit now has enough EXP to level up, flag them for the check.
    -- A generic system will pick this up after all combat animations are resolved.
    if unit.exp >= unit.maxExp then
        unit.components.pending_level_up = true
    end
    -- The level up check and UI update will be handled by another system after combat resolves.
end

return CombatActions