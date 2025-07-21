-- unit_attacks.lua
-- Contains all attack implementations.

local EffectFactory = require("modules.effect_factory")
local WorldQueries = require("modules.world_queries")
local CombatActions = require("modules.combat_actions")
local AttackPatterns = require("modules.attack_patterns")
local Grid = require("modules.grid")
local StatusEffectManager = require("modules.status_effect_manager")
local Assets = require("modules.assets")
local EntityFactory = require("data.entities")
local CombatFormulas = require("modules.combat_formulas")

local UnitAttacks = {}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- ATTACK IMPLEMENTATIONS
--------------------------------------------------------------------------------

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

    -- Add the lunge component for the visual effect.
    attacker.components.lunge = { timer = 0.2, initialTimer = 0.2, direction = attacker.lastDirection }
    return target
end

-- Helper for cycle_target attacks that heal.
local function execute_cycle_target_heal_attack(attacker, world, attackInstanceId)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    local attackName = world.selectedAttackName
    local attackData = AttackBlueprints[attackName]

    -- Healing moves always hit.
    local healAmount = CombatFormulas.calculateHealingAmount(attacker, attackData)
    if CombatActions.applyDirectHeal(target, healAmount) then
        local specialProperties = { attackInstanceId = attackInstanceId }
        -- Create a visual effect on the target tile.
        EffectFactory.addAttackEffect(attacker, attackName, target.x, target.y, target.size, target.size, {0.5, 1, 0.5, 0.7}, 0, true, "none", nil, nil, specialProperties)
        -- Create a popup number for the healing.
        EffectFactory.createDamagePopup(target, healAmount, false, {0.5, 1, 0.5, 1}) -- Green text
    end

    return true -- Turn is consumed.
end

-- Helper for cycle_target attacks that fire a projectile.
local function executeCycleTargetProjectileAttack(attacker, attackName, world, isPiercing, attackInstanceId)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    local attackData = AttackBlueprints[attackName]

    -- Fire a projectile in that direction.
    local isEnemy = (attacker.type == "enemy")
    local newProjectile = EntityFactory.createProjectile(attacker.x, attacker.y, attacker.lastDirection, attacker, attackName, attackData.power, isEnemy, nil, isPiercing, attackInstanceId)
    world:queue_add_entity(newProjectile)
    return true
end

-- Helper for cycle_target attacks that deal damage.
local function execute_cycle_target_damage_attack(attacker, world, statusEffect, attackInstanceId)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    local attackName = world.selectedAttackName

    -- Determine the correct target type based on the attacker's team.
    local targetType = (attacker.type == "player") and "enemy" or "player"

    local specialProperties = { attackInstanceId = attackInstanceId }
    -- Create the attack effect. The resolution system will handle the rest.
    EffectFactory.addAttackEffect(attacker, attackName, target.x, target.y, target.size, target.size, {1, 0, 0, 1}, 0, false, targetType, nil, statusEffect, specialProperties)
    return true
end

-- Shared attack functions, now using the new formulas and structure:

UnitAttacks.froggy_rush = function(attacker, world, attackInstanceId)
    return execute_cycle_target_damage_attack(attacker, world, nil, attackInstanceId)
end

UnitAttacks.quill_jab = function(attacker, world, attackInstanceId)
    return execute_cycle_target_damage_attack(attacker, world, nil, attackInstanceId)
end

UnitAttacks.snap = function(attacker, world, attackInstanceId)
    return execute_cycle_target_damage_attack(attacker, world, nil, attackInstanceId)
end

UnitAttacks.walnut_toss = function(attacker, world, attackInstanceId)
    return execute_cycle_target_damage_attack(attacker, world, nil, attackInstanceId)
end

UnitAttacks.slash = function(attacker, world, attackInstanceId)
    return execute_cycle_target_damage_attack(attacker, world, nil, attackInstanceId)
end

UnitAttacks.venom_stab = function(attacker, world, attackInstanceId)
    local status = {type = "poison", duration = 3} -- Lasts 3 turns
    return execute_cycle_target_damage_attack(attacker, world, status, attackInstanceId)
end

UnitAttacks.fireball = function(attacker, world, attackInstanceId)
    -- Fireball is a projectile attack.
    return executeCycleTargetProjectileAttack(attacker, "fireball", world, true, attackInstanceId)
end

UnitAttacks.uppercut = function(attacker, world, attackInstanceId)
    local status = {type = "airborne", duration = 1.2} -- Shortened for a snappier feel
    return execute_cycle_target_damage_attack(attacker, world, status, attackInstanceId)
end

UnitAttacks.mend = function(attacker, world, attackInstanceId)
    return execute_cycle_target_heal_attack(attacker, world, attackInstanceId)
end

-- The rest of your unit attack functions remain largely unchanged, as they don't directly involve damage calculation:

UnitAttacks.longshot = function(attacker, world, attackInstanceId)
    return execute_cycle_target_damage_attack(attacker, world, nil, attackInstanceId)
end

UnitAttacks.phantom_step = function(square, world, attackInstanceId)
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
 
     -- 4. Make the attacker face the target from the new position and add a lunge for visual feedback.
     square.lastDirection = (target.tileX > square.tileX and "right") or (target.tileX < square.tileX and "left") or (target.tileY > square.tileY and "down") or "up"
     square.components.lunge = { timer = 0.2, initialTimer = 0.2, direction = square.lastDirection }

     -- 5. Apply damage to the target by creating an attack effect.
     local attackName = "phantom_step"
     local status = {type = "stunned", duration = 1}
     local targetType = (square.type == "player") and "enemy" or "player"
     local specialProperties = { attackInstanceId = attackInstanceId }
     EffectFactory.addAttackEffect(square, attackName, target.x, target.y, target.size, target.size, {1, 0, 0, 1}, 0, false, targetType, nil, status, specialProperties)
 
     return true
 end

UnitAttacks.invigoration = function(attacker, world, attackInstanceId)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    -- If the friendly target has already acted, refresh their turn.
    if target.hasActed then
        target.hasActed = false
        EffectFactory.createDamagePopup(target, "Refreshed!", false, {0.5, 1, 0.5, 1}) -- Green text
    end

    local specialProperties = { attackInstanceId = attackInstanceId }
    -- Create a visual effect on the target tile so the player sees the action.
    EffectFactory.addAttackEffect(attacker, "invigoration", target.x, target.y, target.size, target.size, {0.5, 1, 0.5, 0.7}, 0, true, "none", nil, nil, specialProperties)
    return true
end

UnitAttacks.eruption = function(attacker, world, attackInstanceId)
    -- This is the new model for a ground_aim AoE attack.
    -- 1. Get the target tile from the ground aiming cursor.
    local targetTileX, targetTileY = world.mapCursorTile.x, world.mapCursorTile.y
    local centerX, centerY = Grid.toPixels(targetTileX, targetTileY)
    -- Center the explosion on the middle of the tile.
    centerX = centerX + Config.SQUARE_SIZE / 2
    centerY = centerY + Config.SQUARE_SIZE / 2

    -- 2. We can still use the ripple pattern generator, but we call it directly with the cursor's position.
    local rippleCenterSize = 1
    local effects = AttackPatterns.eruption_aoe(centerX, centerY, rippleCenterSize)
    local color = {1, 0, 0, 1}
    local targetType = (attacker.type == "player" and "enemy" or "player")
    local specialProperties = { attackInstanceId = attackInstanceId }

    for _, effectData in ipairs(effects) do
        EffectFactory.addAttackEffect(attacker, "eruption", effectData.shape.x, effectData.shape.y, effectData.shape.w, effectData.shape.h, color, effectData.delay, false, targetType, nil, nil, specialProperties)
    end
    return true
end

UnitAttacks.shockwave = function(attacker, world, attackInstanceId)
    -- Shockwave now always hits all valid targets.
    local targets = WorldQueries.findValidTargetsForAttack(attacker, "shockwave", world)

    for _, target in ipairs(targets) do
        StatusEffectManager.applyStatusEffect(target, {type = "paralyzed", duration = 2, attacker = attacker}, world)
    end

    return true -- Turn is consumed.
end

UnitAttacks.quick_step = function(attacker, world, attackInstanceId)
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
                    StatusEffectManager.applyStatusEffect(unitToHit, {type = "airborne", duration = 2, attacker = attacker}, world)
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

UnitAttacks.grovecall = function(square, world, attackInstanceId)
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

    local specialProperties = { attackInstanceId = attackInstanceId }
    -- Create a visual effect on the target tile so the player sees the action.
    EffectFactory.addAttackEffect(square, "grovecall", landX, landY, Config.SQUARE_SIZE, Config.SQUARE_SIZE, {0.2, 0.8, 0.3, 0.7}, 0, false, "none", nil, nil, specialProperties)

    return true -- Attack succeeds, turn is consumed.
end

UnitAttacks.hookshot = function(attacker, world, attackInstanceId)
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