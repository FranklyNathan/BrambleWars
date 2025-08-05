-- combat_actions.lua
-- Contains functions that directly apply combat results like damage and healing to entities.

local StatusEffectManager = require("modules.status_effect_manager")
local EventBus = require("modules.event_bus")
local EffectFactory = require("modules.effect_factory")
local Grid = require("modules.grid")
local Assets = require("modules.assets")
local PassiveSystem = require("systems.passive_system")
local StatSystem = require("systems.stat_system")

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
        -- Add a shake effect. Make it more intense for critical hits.
        if isCrit then
            -- Determine shake direction based on unit's facing direction
            local shakeDirection = "horizontal" -- Default for up/down
            if target.lastDirection == "left" or target.lastDirection == "right" then
                shakeDirection = "vertical"
            end
            target.components.shake = { timer = 0.3, intensity = 2, direction = shakeDirection } -- Longer and more intense shake for crits.
        else
            target.components.shake = { timer = 0.2, intensity = 1 } -- Standard shake for normal hits.
        end
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
                -- Play the death sound effect for a lethal combat hit.
                if Assets.sounds.unit_death then
                    Assets.sounds.unit_death:play()
                end
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
        -- Dispatch an event so other systems (like the UI) can react immediately.
        EventBus:dispatch("exp_gain_started", { world = world, unit = unit })
    elseif anim.unit == unit then
        -- If an animation is already active for the same unit, just add to the gain.
        anim.expGained = anim.expGained + amount
        -- If it was shrinking, restart the fill animation from its current point.
        if anim.state == "shrinking" then
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

--- Changes a unit's team allegiance and handles all related state changes.
-- @param unitToConvert (table): The unit whose team is changing.
-- @param newTeamOwner (table): A unit on the team the target is converting to.
-- @param world (table): The game world.
-- @param options (table): An optional table for customization.
--   - popupText (string): Text for the visual popup (e.g., "Converted!").
--   - popupColor (table): The color for the popup text.
--   - onConvert (function): A callback function to run special logic *before* the final stat recalculation.
--     It receives (unitToConvert, newTeamOwner, world) as arguments.
--   - skipDefaultHeal (boolean): If true, the unit will not be fully healed after conversion.
function CombatActions.convertUnitAllegiance(unitToConvert, newTeamOwner, world, options)
    options = options or {}

    -- 1. Remove from old team's passive list.
    PassiveSystem.remove_unit_from_passives(unitToConvert, world)

    -- 2. Remove from old team's unit list.
    local oldTeamList
    if unitToConvert.type == "player" then oldTeamList = world.players
    elseif unitToConvert.type == "enemy" then oldTeamList = world.enemies
    elseif unitToConvert.type == "neutral" then oldTeamList = world.neutrals
    end

    if oldTeamList then
        for i = #oldTeamList, 1, -1 do
            if oldTeamList[i] == unitToConvert then table.remove(oldTeamList, i); break; end
        end
    end

    -- 3. Switch team type and add to new team list.
    unitToConvert.type = newTeamOwner.type
    local newTeamList = (unitToConvert.type == "player") and world.players or world.enemies
    table.insert(newTeamList, unitToConvert)

    -- 4. Update AI component and reset state for conversion.
    if unitToConvert.type == "enemy" then unitToConvert.components.ai = {} else unitToConvert.components.ai = nil end
    -- A converted unit gets a fresh start on its new team and can act this turn,
    -- even if it had already acted. This applies to both revival (Necromantia)
    -- and mid-combat conversion (Silver Tongue).
    unitToConvert.hasActed = false
    unitToConvert.lastDirection = "down" -- Face down.

    -- 5. Clear status effects.
    unitToConvert.statusEffects = {}

    -- 6. Run optional onConvert callback for special logic (like Necromantia's HP reduction).
    if options.onConvert then
        options.onConvert(unitToConvert, newTeamOwner, world)
    end

    -- 7. Add to new team's passive list and recalculate stats.
    PassiveSystem.add_unit_to_passives(unitToConvert, world)
    StatSystem.recalculate_for_unit(unitToConvert, world)

    -- 8. Fully heal the unit to its new max stats, unless skipped.
    if not options.skipDefaultHeal then
        unitToConvert.hp = unitToConvert.finalMaxHp
        unitToConvert.wisp = unitToConvert.finalMaxWisp
    end

    -- 9. Create a visual effect.
    if options.popupText then
        EffectFactory.createDamagePopup(world, unitToConvert, options.popupText, false, options.popupColor)
    end
end
    
return CombatActions