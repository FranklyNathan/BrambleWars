-- modules/status_effect_manager.lua
-- Centralizes the management of status effects.

local EventBus = require("modules.event_bus")
local EffectFactory = require("modules.effect_factory")
-- CombatActions is no longer required

local StatusEffectManager = {}


-- Apply a status effect to a target.
function StatusEffectManager.apply(target, effectData, world)
    -- If totalDuration isn't specified, set it to the initial duration.
    -- This is crucial for animations that depend on the original duration.
    if effectData.duration and not effectData.totalDuration then
        effectData.totalDuration = effectData.duration
    end

    -- Apply effect.
    target.statusEffects[effectData.type] = effectData
    effectData.target = target

    EventBus:dispatch("status_applied", {target = target, effect = effectData, world = world})
end
-- Remove a status effect from a target.
function StatusEffectManager.remove(target, effectType)
    if not target or not target.statusEffects or not target.statusEffects[effectType] then return end

    -- Remove effect.
    local effectData = target.statusEffects[effectType]
    target.statusEffects[effectType] = nil

    -- Dispatch event for the removal of a status effect, allowing other systems to react.
    EventBus:dispatch("status_removed", {target = target, effect = effectData})
end

-- Process status effects at the start of a unit's turn (for ticking effects).
function StatusEffectManager.processTurnStart(target, world)
   if not target or not target.statusEffects then return end
   --[[ The logic for ticking effect durations is now handled by status_system.lua
       at the end of each turn. This function is now only for effects that
       actively trigger at the start of a unit's turn. ]]--

    -- Poison: Apply damage at turn start.
    if target.statusEffects.poison then
        -- Require CombatActions locally to avoid a circular dependency.
        local CombatActions = require("modules.combat_actions")
        local effect = target.statusEffects.poison
        local damage = 5 -- Per your request, poison now deals a flat amount of damage.

       -- Create an "invisible" damage event to apply poison damage
       CombatActions.applyDirectDamage(world, target, damage, false, effect.attacker, {createPopup = false})

       -- Create a "Poison!" popup to signal the damage
       local popupText = "Poison! -" .. damage
       EffectFactory.createDamagePopup(target, popupText, false, {0.5, 0.1, 0.8, 1}) -- Dark purple text
   end
end

-- New function: Apply a status effect (moved from CombatActions)
function StatusEffectManager.applyStatusEffect(target, effectData, world)
    StatusEffectManager.apply(target, effectData, world)
end

-- Helper function to calculate the direction for careening effects based on the effect's center.
function StatusEffectManager.calculateCareeningDirection(target, effectX, effectY, effectWidth, effectHeight)
    local effectCenterX, effectCenterY = effectX + effectWidth / 2, effectY + effectHeight / 2
    local dx, dy = target.x - effectCenterX, target.y - effectCenterY
    return (math.abs(dx) > math.abs(dy)) and ((dx > 0) and "right" or "left") or ((dy > 0) and "down" or "up")
end

return StatusEffectManager