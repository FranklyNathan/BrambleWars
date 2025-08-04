-- tests/status_effect_manager_test.lua

local busted = require "busted.runner"()
local StatusEffectManager = require "modules.status_effect_manager"

-- Mock required modules that StatusEffectManager depends on.
local EventBus = {
    dispatch = function() end -- Mock dispatch function
}
local Config = {}

local CombatActions = {
    applyDirectDamage = function() end -- Mock applyDirectDamage
}

local EffectFactory = {
    createDamagePopup = function() end -- Mock createDamagePopup
}

-- Replace the actual modules with our mocks for testing.
_G.EventBus = EventBus
_G.Config = Config
_G.CombatActions = CombatActions
_G.EffectFactory = EffectFactory

describe("StatusEffectManager", function()
    it("should apply a status effect", function()
        local target = { statusEffects = {} }
        local effectData = { type = "poison", duration = 3 }
        StatusEffectManager.apply(target, effectData)
        assert.is_not_nil(target.statusEffects.poison)
        assert.equal(target.statusEffects.poison, effectData)
    end)

    it("should remove a status effect", function()
        local target = { statusEffects = { poison = { type = "poison", duration = 3 } } }
        StatusEffectManager.remove(target, "poison")
        assert.is_nil(target.statusEffects.poison)
    end)

    it("should process turn start - paralyze", function()
        local target = { statusEffects = { paralyzed = { type = "paralyzed", duration = 2 } } }
        StatusEffectManager.processTurnStart(target) -- Removed world arg
        assert.equal(target.statusEffects.paralyzed.duration, 1)
        StatusEffectManager.processTurnStart(target) -- Removed world arg
        assert.is_nil(target.statusEffects.paralyzed)
    end)

    it("should process turn start - airborne", function()
        local target = { statusEffects = { airborne = { type = "airborne", duration = 2 } } }
        StatusEffectManager.processTurnStart(target) -- Removed world arg
        assert.equal(target.statusEffects.airborne.duration, 1)
        StatusEffectManager.processTurnStart(target)
        assert.is_nil(target.statusEffects.airborne)
    end)

    it("should process turn start - poison", function()
        local target = { maxHp = 100, statusEffects = { poison = { type = "poison" } } }

        -- Use spy to check if the mocked functions are called
        local applyDamageSpy = spy.on(CombatActions, "applyDirectDamage")
        local createPopupSpy = spy.on(EffectFactory, "createDamagePopup")

        StatusEffectManager.processTurnStart(target) -- Removed world arg

        assert.spy(applyDamageSpy).was_called_with(target, 5, false, nil, { createPopup = false })
        assert.spy(createPopupSpy).was_called_with(target, "Poison! -5", false, { 0.5, 0.1, 0.8, 1 })
        -- We're not checking the *removal* of poison, as it's not handled by processTurnStart
    end)

    it("should calculate careening direction", function()
        local target = { x = 100, y = 100 }
        local direction = StatusEffectManager.calculateCareeningDirection(target, 50, 50, 20, 20)
        assert.equal(direction, "right")
    end)
end)