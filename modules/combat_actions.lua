-- combat_actions.lua
-- Contains functions that directly apply combat results like damage and healing to entities.

local StatusEffectManager = require("modules.status_effect_manager")
local EventBus = require("modules.event_bus")
local EffectFactory = require("modules.effect_factory")

local CombatActions = {}

function CombatActions.applyDirectHeal(target, healAmount)
    if target and target.hp and target.hp > 0 then
        target.hp = math.floor(target.hp + healAmount)
        if target.hp > target.maxHp then target.hp = target.maxHp end
        return true
    end
    return false
end
-- The attacker is passed in to correctly attribute kills for passives like Bloodrush.
function CombatActions.applyDirectDamage(target, damageAmount, isCrit, attacker, options)
    if not target or not target.hp or target.hp <= 0 then return end
    options = options or {} -- Ensure options table exists to prevent errors.

    -- Check for Tangrowth Square's shield first.
    if target.components.shielded then
        target.components.shielded = nil -- Consume the shield
        -- Create a "Blocked!" popup instead of a damage number.
        EffectFactory.createDamagePopup(target, "Blocked!", false, {0.7, 0.7, 1, 1}) -- Light blue text
        return -- Stop further processing, no damage is taken.
    end 

    local roundedDamage = math.floor(damageAmount)
    if roundedDamage > 0 then
        local wasAlive = target.hp > 0
        target.hp = target.hp - roundedDamage
        -- Only create the default popup if not explicitly told otherwise.
        if options.createPopup ~= false then
            EffectFactory.createDamagePopup(target, roundedDamage, isCrit)
        end
        target.components.shake = { timer = 0.2, intensity = 2 }
        if target.hp < 0 then target.hp = 0 end

        -- If the unit was alive and is now at 0 HP, it just died.
        if wasAlive and target.hp <= 0 then
            -- Announce the death to any interested systems (quests, passives, etc.)
            -- This is the primary source for kill-related events.
            EventBus:dispatch("unit_died", { victim = target, killer = attacker, world = world })
        end
    end
end

function CombatActions.executeShockwave(attacker, attackData, world)
    if not attacker or not attackData or not world then return false end
    for _, entity in ipairs(world.all_entities) do
        if entity.hp ~= nil and entity.hp > 0 and entity.type ~= attacker.type then
            -- Shockwave hits all enemies within range of the *attacker*, not the target.
            local distance = math.abs(attacker.tileX - entity.tileX) + math.abs(attacker.tileY - entity.tileY)
            if distance <= attackData.range then                
                StatusEffectManager.applyStatusEffect(entity, {type = "paralyzed", duration = 2, attacker = attacker}, world)
            end
        end
    end
    return true
end

return CombatActions