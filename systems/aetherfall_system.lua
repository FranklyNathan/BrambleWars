-- aetherfall_system.lua
-- Manages the reactive "Aetherfall" passive for Pidgeot.

local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")
local Grid = require("modules.grid")
local AttackBlueprints = require("data.attack_blueprints")
local EffectFactory = require("modules.effect_factory")
local StatusEffectManager = require("modules.status_effect_manager")

local AetherfallSystem = {}

-- Helper to find all units with the Aetherfall passive on a given team.
local function find_aetherfall_units(world, teamType)
    -- The PassiveSystem now populates this list each frame with all *living* units
    -- that have the Aetherfall passive. This is much more efficient and robust.
    return world.teamPassives[teamType].Aetherfall
end

-- Helper to find valid attack directions around a target.
local function find_adjacent_attack_directions(target, world, excludeUnit)
    local openDirections = {}
    -- The order is important for consistent attack visuals: Left, Right, Top, Bottom.
    local neighbors = {
        {dx = -1, dy = 0}, -- Left
        {dx = 1,  dy = 0}, -- Right
        {dx = 0,  dy = -1}, -- Top (Up)
        {dx = 0,  dy = 1}  -- Bottom (Down)
    }
    for _, move in ipairs(neighbors) do
        local checkX, checkY = target.tileX + move.dx, target.tileY + move.dy
        -- Check if the tile is within map bounds AND is not occupied.
        if checkX >= 0 and checkX < world.map.width and
           checkY >= 0 and checkY < world.map.height and
           not WorldQueries.isTileOccupied(checkX, checkY, excludeUnit, world) then
            table.insert(openDirections, move) -- Insert the direction vector {dx, dy}
        end
    end
    return openDirections
end

-- This function contains the core logic for triggering the passive.
local function check_and_trigger_aetherfall(airborne_target, attacker, world)
    -- Find all units that are hostile to the attacker and have the Aetherfall passive.
    local potential_reactors = {}
    for _, unit in ipairs(world.all_entities) do
        if unit.type and WorldQueries.areUnitsHostile(unit, airborne_target) and WorldQueries.hasPassive(unit, "Aetherfall", world) then
            table.insert(potential_reactors, unit)
        end
    end

    for _, reactor in ipairs(potential_reactors) do
        -- Get the reactor's basic attack. This is always the first move in their list.
        local moveList = WorldQueries.getUnitMoveList(reactor)
        local basicAttackName = moveList and moveList[1]

        -- Check all conditions for this unit
        local distance = math.abs(reactor.tileX - airborne_target.tileX) + math.abs(reactor.tileY - airborne_target.tileY)
        local canReact = not reactor.hasActed and
                         distance <= 16 and
                         not reactor.components.aetherfall_attack and -- Don't trigger if already attacking
                         basicAttackName -- The unit must have a basic attack to react.

        if canReact then
            local openDirections = find_adjacent_attack_directions(airborne_target, world, reactor)
            if #openDirections > 0 then
                -- Trigger the attack!
                reactor.components.aetherfall_attack = {
                    target = airborne_target,
                    attackDirections = openDirections, -- Store the initial list of valid directions.
                    nextDirectionIndex = 1,
                    hitTimer = 0.6, -- Wait for the airborne animation to reach its peak.
                    hitDelay = 0.2, -- Time between subsequent hits.
                    attackName = basicAttackName -- Store the attack to use.
                }
                -- One unit reacts, that's enough.
                break
            end
        end
    end
end

-- Listen for a status effect to trigger the passive.
EventBus:register("status_applied", function(data)
    local world = data.world
    local target = data.target
    local effect = data.effect
    local attacker = effect.attacker

    -- Condition 1: Was the 'airborne' status applied?
    if not world or effect.type ~= "airborne" or not attacker then
        return
    end

    -- Condition 2: Check for any hostile units with Aetherfall that can react.
    check_and_trigger_aetherfall(target, attacker, world)
end)

function AetherfallSystem.update(dt, world)
    -- This will process any active Aetherfall attacks for all entities.
    for _, unit in ipairs(world.all_entities) do
        if unit.components.aetherfall_attack then
            local attack = unit.components.aetherfall_attack
            attack.hitTimer = attack.hitTimer - dt

            if attack.hitTimer <= 0 and attack.nextDirectionIndex <= #attack.attackDirections then
                local target = attack.target
                if not target or target.hp <= 0 then
                    -- Target died mid-combo, end the attack immediately.
                    unit.components.aetherfall_attack = nil
                else
                    -- Get the next direction from the pre-calculated list.
                    local direction = attack.attackDirections[attack.nextDirectionIndex]
                    
                    -- Calculate the warp tile based on the target's CURRENT position.
                    local warpTileX = target.tileX + direction.dx
                    local warpTileY = target.tileY + direction.dy

                    -- Re-validate that the tile is still open before warping.
                    -- This handles cases where another unit moves into the spot.
                    if not WorldQueries.isTileOccupied(warpTileX, warpTileY, unit, world) then
                        -- Teleport the unit
                        unit.tileX, unit.tileY = warpTileX, warpTileY
                        unit.x, unit.y = Grid.toPixels(warpTileX, warpTileY)
                        EventBus:dispatch("unit_tile_changed", { unit = unit, world = world })
                        unit.targetX, unit.targetY = unit.x, unit.y

                        -- Make the unit face the target
                        local dx, dy = target.tileX - unit.tileX, target.tileY - unit.tileY
                        if math.abs(dx) > math.abs(dy) then unit.lastDirection = (dx > 0) and "right" or "left"
                        else unit.lastDirection = (dy > 0) and "down" or "up" end

                        -- Add the lunge component for the visual effect.
                        unit.components.lunge = { timer = 0.2, initialTimer = 0.2, direction = unit.lastDirection }

                        -- Execute the unit's basic attack.
                        local targetType = (unit.type == "player") and "enemy" or "player"
                        local specialProperties = {
                            isAetherfallAttack = true -- Flag to prevent counter-attacks.
                        }
                        EffectFactory.addAttackEffect(world, {
                            attacker = unit,
                            attackName = attack.attackName,
                            x = target.x,
                            y = target.y,
                            width = target.size,
                            height = target.size,
                            color = {1, 0, 0, 1},
                            targetType = targetType,
                            specialProperties = specialProperties
                        })
                    end

                    -- Update state for the next hit regardless of whether we attacked.
                    attack.nextDirectionIndex = attack.nextDirectionIndex + 1
                    attack.hitTimer = attack.hitDelay
                end
            end

            -- Re-check component existence before checking index, as it might have been nilled above.
            if unit.components.aetherfall_attack and unit.components.aetherfall_attack.nextDirectionIndex > #unit.components.aetherfall_attack.attackDirections then
               -- Attack is over. End the airborne status on the target.
                StatusEffectManager.remove(attack.target, "airborne", world)
                -- Clean up the component. The unit's turn is NOT consumed.
                unit.components.aetherfall_attack = nil

                -- After a reactive move like Aetherfall, the unit's "start of turn" position
                -- is now its new location. This ensures that if the player moves and then
                -- cancels, the unit returns to this new spot, not its original one.
                if attack.target.statusEffects.airborne then
                    attack.target.statusEffects.airborne.aetherfall_controlled = false
                end

            end
        end
    end
end

return AetherfallSystem