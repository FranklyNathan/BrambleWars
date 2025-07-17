-- unit_attacks.lua
-- Contains all attack implementations.

local EffectFactory = require("modules.effect_factory")
local WorldQueries = require("modules.world_queries")
local CombatActions = require("modules.combat_actions")
local AttackPatterns = require("modules.attack_patterns")
local Grid = require("modules.grid")
local Assets = require("modules.assets")
local EntityFactory = require("data.entities")
local AttackBlueprints = require("data.attack_blueprints")

local UnitAttacks = {}

--------------------------------------------------------------------------------
-- ATTACK IMPLEMENTATIONS
--------------------------------------------------------------------------------

-- Helper function to execute attacks based on a pattern generator.
-- This reduces code duplication by handling the common logic of iterating
-- through a pattern's effects and creating the corresponding attack visuals/logic.
local function executePatternAttack(square, power, patternFunc, isHeal, targetType, statusEffect, specialProperties)
    local effects = patternFunc(square)
    local color = isHeal and {0.5, 1, 0.5, 1} or {1, 0, 0, 1}
    -- If targetType isn't specified, determine it based on the attacker's type.
    targetType = targetType or (isHeal and "all" or (square.type == "player" and "enemy" or "player"))

    for _, effectData in ipairs(effects) do
        local s = effectData.shape
        EffectFactory.addAttackEffect(s.x, s.y, s.w, s.h, color, effectData.delay, square, power, isHeal, targetType, nil, statusEffect, specialProperties)
    end
end

-- Helper to get the currently selected target and make the attacker face them.
local function get_and_face_cycle_target(attacker, world)
    if not world.cycleTargeting.active or not world.cycleTargeting.targets[world.cycleTargeting.selectedIndex] then
        return nil -- Failsafe, should not happen if called correctly.
    end
    local target = world.cycleTargeting.targets[world.cycleTargeting.selectedIndex]

    -- Make the attacker face the target.
    local dx, dy = target.tileX - attacker.tileX, target.tileY - attacker.tileY
    if math.abs(dx) > math.abs(dy) then
        attacker.lastDirection = (dx > 0) and "right" or "left"
    else
        attacker.lastDirection = (dy > 0) and "down" or "up"
    end
    return target
end

-- Helper for cycle_target attacks that deal damage.
local function executeCycleTargetDamageAttack(attacker, power, world, statusEffect)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    -- Determine the correct target type based on the attacker's team.
    local targetType = (attacker.type == "player") and "enemy" or "player"

    -- 3. Execute the attack effect directly on the target's tile.
    EffectFactory.addAttackEffect(target.x, target.y, target.size, target.size, {1, 0, 0, 1}, 0, attacker, power, false, targetType, nil, statusEffect)
    return true
end

-- Helper for cycle_target attacks that fire a projectile.
local function executeCycleTargetProjectileAttack(attacker, power, world, isPiercing)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    -- Fire a projectile in that direction.
    local isEnemy = (attacker.type == "enemy")
    local newProjectile = EntityFactory.createProjectile(attacker.x, attacker.y, attacker.lastDirection, attacker, power, isEnemy, nil, isPiercing)
    world:queue_add_entity(newProjectile)
    return true
end

UnitAttacks.slash = function(attacker, power, world)
    return executeCycleTargetDamageAttack(attacker, power, world, nil)
end

UnitAttacks.longshot = function(attacker, power, world)
    return executeCycleTargetProjectileAttack(attacker, power, world, false)
end

UnitAttacks.fireball = function(attacker, power, world)
    return executeCycleTargetProjectileAttack(attacker, power, world, true)
end

UnitAttacks.venom_stab = function(attacker, power, world)
    local status = {type = "poison", duration = 3} -- Lasts 3 turns
    return executeCycleTargetDamageAttack(attacker, power, world, status)
end

UnitAttacks.phantom_step = function(square, power, world)
    -- 1. Get the selected target from the cycle targeting system.
    if not world.cycleTargeting.active or not world.cycleTargeting.targets[world.cycleTargeting.selectedIndex] then
        return false -- Failsafe, should not happen if called correctly.
    end
    local target = world.cycleTargeting.targets[world.cycleTargeting.selectedIndex]

    -- 2. Calculate the destination tile behind the target.
    local dx, dy = 0, 0
    if target.lastDirection == "up" then dy = 1
    elseif target.lastDirection == "down" then dy = -1
    elseif target.lastDirection == "left" then dx = 1
    elseif target.lastDirection == "right" then dx = -1
    end
    local teleportTileX, teleportTileY = target.tileX + dx, target.tileY + dy
    local teleportX, teleportY = Grid.toPixels(teleportTileX, teleportTileY)

    -- 3. Teleport the attacker. The input handler already validated this tile is empty.
    square.x, square.y = teleportX, teleportY
    square.targetX, square.targetY = teleportX, teleportY
    square.tileX, square.tileY = teleportTileX, teleportTileY

    -- 4. Make the attacker face the target from the new position.
    square.lastDirection = (target.tileX > square.tileX and "right") or (target.tileX < square.tileX and "left") or (target.tileY > square.tileY and "down") or "up"

    -- 5. Execute the attack on the target's tile.
    local status = {type = "airborne", duration = 2, attacker = square} -- Ensure the duration is specified
    local targetType = (square.type == "player") and "enemy" or "player"
    EffectFactory.addAttackEffect(target.x, target.y, target.size, target.size, {1, 0, 0, 1}, 0, square, power, false, targetType, nil, status) -- Applying airborne here



    return true
end

UnitAttacks.invigorating_aura = function(attacker, power, world)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end
    -- 3. If the friendly target has already acted, refresh their turn.
    if target.hasActed then
        target.hasActed = false
        EffectFactory.createDamagePopup(target, "Refreshed!", false, {0.5, 1, 0.5, 1}) -- Green text
    end

    -- 4. Create a visual effect on the target tile so the player sees the action.
    EffectFactory.addAttackEffect(target.x, target.y, target.size, target.size, {0.5, 1, 0.5, 0.7}, 0, attacker, 0, true, "none")
    return true
end

UnitAttacks.eruption = function(attacker, power, world)
    -- This is the new model for a ground_aim AoE attack.
    -- 1. Get the target tile from the ground aiming cursor.
    local targetTileX, targetTileY = world.mapCursorTile.x, world.mapCursorTile.y
    local centerX, centerY = Grid.toPixels(targetTileX, targetTileY)
    -- Center the explosion on the middle of the tile.
    centerX = centerX + Config.SQUARE_SIZE / 2
    centerY = centerY + Config.SQUARE_SIZE / 2

    -- 2. We can still use the ripple pattern generator, but we call it directly with the cursor's position.
    local rippleCenterSize = 1
    local effects = AttackPatterns.ripple(centerX, centerY, rippleCenterSize)
    local color = {1, 0, 0, 1}
    local targetType = (attacker.type == "player" and "enemy" or "player")

    for _, effectData in ipairs(effects) do
        EffectFactory.addAttackEffect(effectData.shape.x, effectData.shape.y, effectData.shape.w, effectData.shape.h, color, effectData.delay, attacker, power, false, targetType)
    end
    return true
end

UnitAttacks.shockwave = function(attacker, power, world)    
    -- The targeting and effect application is handled in the CombatActions module.
    -- This function simply returns true to indicate the attack was triggered.
    return CombatActions.executeShockwave(attacker, AttackBlueprints.shockwave, world)
end

UnitAttacks.uppercut = function(attacker, power, world)
    local status = {type = "airborne", duration = 2} -- Ensure the duration is specified
    return executeCycleTargetDamageAttack(attacker, power, world, status)
end

UnitAttacks.quick_step = function(attacker, power, world)
    -- 1. Get the target tile from the ground aiming cursor.
    local targetTileX, targetTileY = world.mapCursorTile.x, world.mapCursorTile.y

    -- 2. Validate that the target tile is empty.
    if WorldQueries.isTileOccupied(targetTileX, targetTileY, attacker, world) then
        return false -- Attack fails, turn is not consumed.
    end

    -- 3. Store original position and immediately update the logical position.
    -- This ensures that when 'airborne' is applied and Aetherfall triggers,
    -- the attacker is no longer considered to be on their starting tile.
    local startTileX, startTileY = attacker.tileX, attacker.tileY
    attacker.tileX, attacker.tileY = targetTileX, targetTileY

    -- 4. Set the attacker's target destination and speed for the visual movement.
    attacker.targetX, attacker.targetY = Grid.toPixels(targetTileX, targetTileY)
    attacker.speedMultiplier = 2

    -- 5. Determine the path from the *original* position and apply 'airborne' to enemies passed through.
    local dx = targetTileX - startTileX
    local dy = targetTileY - startTileY
    local distance = math.max(math.abs(dx), math.abs(dy))

    if distance > 1 then -- Only check for pass-through if moving more than one tile.
        local dirX = dx / distance
        local dirY = dy / distance

        -- Determine which list of units to check against for collision.
        local targetsToCheck = (attacker.type == "player") and world.enemies or world.players

        -- Iterate over the tiles between the start and end point.
        for i = 1, distance - 1 do
            local pathTileX = startTileX + i * dirX
            local pathTileY = startTileY + i * dirY

            for _, unitToHit in ipairs(targetsToCheck) do
                if unitToHit.tileX == pathTileX and unitToHit.tileY == pathTileY and unitToHit.hp > 0 then                
                    StatusEffectManager.applyStatusEffect(unitToHit, {type = "airborne", attacker = attacker}, world)
                end
            end
        end
    end

    -- 6. Make the attacker face the direction of movement.
    if math.abs(dx) > math.abs(dy) then
        attacker.lastDirection = (dx > 0) and "right" or "left"
    else
        attacker.lastDirection = (dy > 0) and "down" or "up"
    end

    return true -- Consume the turn.
end

UnitAttacks.grovecall = function(square, power, world)
    -- This is the new model for a ground_aim attack.
    -- 1. Get the target tile from the ground aiming cursor.
    local targetTileX, targetTileY = world.mapCursorTile.x, world.mapCursorTile.y

    -- 2. Validate that the target tile is empty.
    -- This query will be updated later to check the new obstacles list.
    if WorldQueries.isTileOccupied(targetTileX, targetTileY, nil, world) then
        return false -- Attack fails, turn is not consumed.
    end

    -- 3. Create the new obstacle object and add it to the world's list.
    local landX, landY = Grid.toPixels(targetTileX, targetTileY)
    local newObstacle = {
        x = landX,
        y = landY,
        tileX = targetTileX,
        tileY = targetTileY,
        width = Config.SQUARE_SIZE,
        height = Config.SQUARE_SIZE,
        size = Config.SQUARE_SIZE,
        weight = "Permanent",
        sprite = Assets.images.Flag, -- The tree sprite
        isObstacle = true
    }
    world:queue_add_entity(newObstacle)

    -- Create a visual effect on the target tile so the player sees the action.
    EffectFactory.addAttackEffect(landX, landY, Config.SQUARE_SIZE, Config.SQUARE_SIZE, {0.2, 0.8, 0.3, 0.7}, 0, square, 0, false, "none")

    return true -- Attack succeeds, turn is consumed.
end

UnitAttacks.hookshot = function(attacker, power, world)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    -- 3. Get the blueprint data to find the range and fire the hook.
    local attackData = AttackBlueprints.hookshot
    local range = attackData.range
    local newHook = EntityFactory.createGrappleHook(attacker, power, range)
    world:queue_add_entity(newHook)
    return true
end

return UnitAttacks