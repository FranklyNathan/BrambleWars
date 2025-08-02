-- systems/tile_hazard_system.lua
-- Applies the effects of tile statuses when a unit moves onto them.

local EventBus = require("modules.event_bus")
local CombatActions = require("modules.combat_actions")
local TileStatusBlueprints = require("data.tile_status_blueprints")
local EffectFactory = require("modules.effect_factory")

local TileHazardSystem = {}

-- This function is called whenever a unit's logical tile position changes.
local function on_unit_tile_changed(data)
    local unit = data.unit
    local world = data.world

    if not unit or unit.hp <= 0 or not world.tileStatuses then return end

    local posKey = unit.tileX .. "," .. unit.tileY
    local status = world.tileStatuses[posKey]

    if status and not unit.isFlying then
        local blueprint = TileStatusBlueprints[status.type]
        if not blueprint then return end

        if status.type == "aflame" then
            -- Check for Infernal passive before applying damage.
            local hasInfernal = false
            if unit.type and world.teamPassives[unit.type] and world.teamPassives[unit.type].Infernal then
                for _, provider in ipairs(world.teamPassives[unit.type].Infernal) do
                    if provider == unit then
                        hasInfernal = true
                        break
                    end
                end
            end

            if not hasInfernal and blueprint.damage and blueprint.damage > 0 then
                CombatActions.applyDirectDamage(world, unit, blueprint.damage, false, nil)
            end
        elseif status.type == "frozen" then
            -- Check if the unit's weight exceeds the ice's limit.
            if unit.weight and blueprint.weightLimit and unit.weight > blueprint.weightLimit then
                -- Break the ice!
                world.tileStatuses[posKey] = nil -- Remove the frozen status.
                unit.components.movement_path = nil -- Stop any further movement.
                EffectFactory.createShatterEffect(world, unit.x, unit.y, unit.size, {0.8, 0.9, 1, 1}) -- Icy blue/white color
                -- Re-dispatch the event so other systems (like drowning) can react to the now-water tile.
                EventBus:dispatch("unit_tile_changed", { unit = unit, world = world })
            end
        end
    end
end

EventBus:register("unit_tile_changed", on_unit_tile_changed)

return TileHazardSystem