-- modules/status_effect_manager.lua
-- Centralizes the management of status effects.

local EventBus = require("modules.event_bus")
local EffectFactory = require("modules.effect_factory")
local TileStatusBlueprints = require("data.tile_status_blueprints")
local Grid = require("modules.grid")
local WorldQueries = require("modules.world_queries")
local Assets = require("modules.assets")

local StatusEffectManager = {}


-- Apply a status effect to a target.
function StatusEffectManager.apply(target, effectData, world)
    local effectType = effectData.type
    local blueprint = Assets.status_effects[effectType]

    -- If a blueprint exists, merge its properties into the effectData.
    -- The properties in effectData (like duration, attacker) will override blueprint defaults.
    if blueprint then
        for k, v in pairs(blueprint) do
            if effectData[k] == nil then
                effectData[k] = v
            end
        end
    end

    -- If totalDuration isn't specified, set it to the initial duration.
    -- This is crucial for animations that depend on the original duration.
    if effectData.duration and not effectData.totalDuration then
        effectData.totalDuration = effectData.duration
    end

    -- Apply effect.
    target.statusEffects[effectType] = effectData
    effectData.target = target

    EventBus:dispatch("status_applied", {target = target, effect = effectData, world = world})
end
-- Remove a status effect from a target.
function StatusEffectManager.remove(target, effectType, world)
    if not target or not target.statusEffects or not target.statusEffects[effectType] then return end

    -- Remove effect.
    local effectData = target.statusEffects[effectType]
    target.statusEffects[effectType] = nil

    -- Dispatch event for the removal of a status effect, allowing other systems to react.
    EventBus:dispatch("status_removed", {target = target, effect = effectData, world = world})
end

-- Process status effects at the start of a unit's turn (for ticking effects).
function StatusEffectManager.processTurnStart(target, world)
   if not target or not target.statusEffects then return end
   --[[ The logic for ticking effect durations is now handled by status_system.lua
       at the end of each turn. This function is now only for effects that
       actively trigger at the start of a unit's turn. ]]--
end

-- New function: Apply a status effect (moved from CombatActions)
function StatusEffectManager.applyStatusEffect(target, effectData, world)
    StatusEffectManager.apply(target, effectData, world)
end

-- New function to handle setting a tile on fire and spreading it to adjacent flammable tiles.
function StatusEffectManager.igniteTileAndSpread(tileX, tileY, world, duration)
    local posKey = tileX .. "," .. tileY

    -- Check if the tile is valid to be set on fire at all.
    if not WorldQueries.isTileValidForGroundStatus(tileX, tileY, world) then
        return
    end

    local existingStatus = world.tileStatuses[posKey]
    local blueprint = existingStatus and TileStatusBlueprints[existingStatus.type]

    -- Set the tile aflame. This overwrites the tall grass or whatever was there.
    world.tileStatuses[posKey] = { type = "aflame", duration = duration }

    -- Create a small burst of particles for visual feedback.
    local pixelX, pixelY = Grid.toPixels(tileX, tileY)
    -- Use a modified shatter effect with fewer particles and fiery colors.
    EffectFactory.createShatterEffect(world, pixelX, pixelY, Config.SQUARE_SIZE, {1, 0.5, 0, 1}, 15)

    -- If the tile that was just replaced was flammable, flag it to start the spread.
    if blueprint and blueprint.spreads_fire then
        world.tileStatuses[posKey].is_spreading = true
        world.tileStatuses[posKey].spread_timer = 0.2 -- A short delay before it spreads to neighbors.
    end
end

-- Helper function to calculate the direction for careening effects based on the effect's center.
function StatusEffectManager.calculateCareeningDirection(target, effectX, effectY, effectWidth, effectHeight)
    local effectCenterX, effectCenterY = effectX + effectWidth / 2, effectY + effectHeight / 2
    local dx, dy = target.x - effectCenterX, target.y - effectCenterY
    return (math.abs(dx) > math.abs(dy)) and ((dx > 0) and "right" or "left") or ((dy > 0) and "down" or "up")
end

return StatusEffectManager