-- unit_attacks.lua
-- Contains all attack implementations.

local EffectFactory = require("modules.effect_factory")
local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")
local CombatActions = require("modules.combat_actions")
local AttackPatterns = require("modules.attack_patterns")
local Grid = require("modules.grid")
local StatusEffectManager = require("modules.status_effect_manager")
local Assets = require("modules.assets")
local EntityFactory = require("data.entities")
local CombatFormulas = require("modules.combat_formulas")
local ObjectBlueprints = require("data.object_blueprints")

local UnitAttacks = {}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- ATTACK IMPLEMENTATIONS
--------------------------------------------------------------------------------

-- Helper to get the currently selected target and make the attacker face them.
local function get_and_face_cycle_target(attacker, world)
    if not world.ui.targeting.cycle.active or not world.ui.targeting.cycle.targets[world.ui.targeting.cycle.selectedIndex] then
        return nil -- Failsafe, should not happen if called correctly.
    end
    local target = world.ui.targeting.cycle.targets[world.ui.targeting.cycle.selectedIndex]

    -- Make the attacker face the target.
    attacker.lastDirection = Grid.getDirection(attacker.tileX, attacker.tileY, target.tileX, target.tileY)

    -- Add the lunge component for the visual effect.
    attacker.components.lunge = { timer = 0.2, initialTimer = 0.2, direction = attacker.lastDirection }
    return target
end

-- Helper for cycle_target attacks that heal.
local function execute_cycle_target_heal_attack(attacker, world, attackInstanceId)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    local attackName = world.ui.targeting.selectedAttackName
    local attackData = AttackBlueprints[attackName]

    -- Healing moves always hit.
    local healAmount = CombatFormulas.calculateHealingAmount(attacker, attackData)
    CombatActions.applyDirectHeal(target, healAmount)
    EffectFactory.createDamagePopup(world, target, healAmount, false, {0.5, 1, 0.5, 1}) -- Green text

    -- Create a visual effect on the target tile.
    EffectFactory.addAttackEffect(world, {
        attacker = attacker,
        attackName = attackName,
        x = target.x, y = target.y,
        width = target.size, height = target.size,
        color = {0.5, 1, 0.5, 0.7},
        isHeal = true, targetType = "none",
        specialProperties = { attackInstanceId = attackInstanceId }
    })
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

    local attackName = world.ui.targeting.selectedAttackName

    -- Determine the correct target type based on the attacker's team.
    local targetType = (attacker.type == "player") and "enemy" or "player"

    local specialProperties = { attackInstanceId = attackInstanceId }
    -- Create the attack effect. The resolution system will handle the rest.    
    EffectFactory.addAttackEffect(world, {
        attacker = attacker,
        attackName = attackName,
        x = target.x,
        y = target.y,
        width = target.size,
        height = target.size,
        color = {1, 0, 0, 1},
        targetType = targetType,
        statusEffect = statusEffect,
        specialProperties = specialProperties
    })
    return true
end

-- Generic implementation for simple, cycle-target damage attacks.
-- It reads the status effect to apply from the attack's blueprint.
local function generic_cycle_target_damage_attack(attacker, world, attackInstanceId)
    local attackName = world.ui.targeting.selectedAttackName
    local attackData = AttackBlueprints[attackName]
    if not attackData then return false end

    -- Check the blueprint for a status effect to apply.
    local statusToApply = nil
    if attackData.statusEffect then
        -- Create a copy to avoid modifying the blueprint table
        statusToApply = {
            type = attackData.statusEffect.type,
            duration = attackData.statusEffect.duration
        }
    end

    return execute_cycle_target_damage_attack(attacker, world, statusToApply, attackInstanceId)
end

-- Shared attack functions, now using the new formulas and structure:
UnitAttacks.slash = generic_cycle_target_damage_attack
UnitAttacks.thrust = generic_cycle_target_damage_attack
UnitAttacks.lash = generic_cycle_target_damage_attack
UnitAttacks.loose = generic_cycle_target_damage_attack
UnitAttacks.bonk = generic_cycle_target_damage_attack
UnitAttacks.harm = generic_cycle_target_damage_attack
UnitAttacks.stab = generic_cycle_target_damage_attack

UnitAttacks.sever = generic_cycle_target_damage_attack
UnitAttacks.venom_stab = generic_cycle_target_damage_attack
UnitAttacks.uppercut = generic_cycle_target_damage_attack
UnitAttacks.longshot = generic_cycle_target_damage_attack

UnitAttacks.shockstrike = function(attacker, world, attackInstanceId)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    local attackName = "shockstrike"
    local attackData = AttackBlueprints[attackName]
    if not attackData then return false end

    local statusToApply = nil
    -- Check for a chance-based status effect.
    if attackData.statusEffect and attackData.statusChance then
        if love.math.random() < attackData.statusChance then
            statusToApply = {
                type = attackData.statusEffect.type,
                duration = attackData.statusEffect.duration
            }
        end
    end

    local targetType = (attacker.type == "player") and "enemy" or "player"
    local specialProperties = { attackInstanceId = attackInstanceId }

    EffectFactory.addAttackEffect(world, {
        attacker = attacker, attackName = attackName, x = target.x, y = target.y,
        width = target.size, height = target.size, color = {1, 0, 0, 1},
        targetType = targetType, statusEffect = statusToApply, specialProperties = specialProperties
    })
    return true
end

UnitAttacks.disarm = function(attacker, world, attackInstanceId)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    local attackName = "disarm"
    local attackData = AttackBlueprints[attackName]
    if not attackData then return false end

    -- Apply damage
    local targetType = (attacker.type == "player") and "enemy" or "player"
    EffectFactory.addAttackEffect(world, {
        attacker = attacker, attackName = attackName, x = target.x, y = target.y,
        width = target.size, height = target.size, color = {1, 0, 0, 1},
        targetType = targetType,
        specialProperties = { attackInstanceId = attackInstanceId }
    })

    -- Apply disarm status if they have a weapon
    if target.equippedWeapon then
        local statusToApply = { type = "disarmed", duration = 1, originalWeapon = target.equippedWeapon }
        StatusEffectManager.applyStatusEffect(target, statusToApply, world)
        target.equippedWeapon = nil -- Unequip the weapon
    end
    return true
end

UnitAttacks.shunt = function(attacker, world, attackInstanceId)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    -- 1. Apply damage to the target.
    local attackName = "shunt"
    local targetType = (attacker.type == "player") and "enemy" or "player"
    local specialProperties = { attackInstanceId = attackInstanceId }
    EffectFactory.addAttackEffect(world, {
        attacker = attacker,
        attackName = attackName,
        x = target.x, y = target.y,
        width = target.size, height = target.size,
        color = {1, 0, 0, 1},
        targetType = targetType,
        specialProperties = specialProperties
    })

    -- 2. Check if the tile behind the target is empty and push them.
    local dx = target.tileX - attacker.tileX
    local dy = target.tileY - attacker.tileY
    local behindTileX, behindTileY = target.tileX + dx, target.tileY + dy

    if not WorldQueries.isTileOccupied(behindTileX, behindTileY, nil, world) then
        -- The tile is empty, so we can push the target.
        local destPixelX, destPixelY = Grid.toPixels(behindTileX, behindTileY)
        target.targetX, target.targetY = destPixelX, destPixelY
        -- Update the logical tile position immediately.
        target.tileX, target.tileY = behindTileX, behindTileY
        EventBus:dispatch("unit_tile_changed", { unit = target, world = world })
        -- Give it a speed boost for a quick slide.
        target.speedMultiplier = 3
    end

    return true
end

UnitAttacks.slipstep = function(attacker, world, attackInstanceId)
    -- Manually get the target without the lunge from the helper.
    if not world.ui.targeting.cycle.active or not world.ui.targeting.cycle.targets[world.ui.targeting.cycle.selectedIndex] then
        return false
    end
    local target = world.ui.targeting.cycle.targets[world.ui.targeting.cycle.selectedIndex]

    -- Make the attacker face the target.
    attacker.lastDirection = Grid.getDirection(attacker.tileX, attacker.tileY, target.tileX, target.tileY)

    -- 1. Apply damage to the target.
    local attackName = "slipstep"
    local targetType = (attacker.type == "player") and "enemy" or "player"
    local specialProperties = { attackInstanceId = attackInstanceId }
    EffectFactory.addAttackEffect(world, {
        attacker = attacker,
        attackName = attackName,
        x = target.x, y = target.y,
        width = target.size, height = target.size,
        color = {1, 0, 0, 1},
        targetType = targetType,
        specialProperties = specialProperties
    })

    -- 2. Store original positions and swap logical/target positions for the animation.
    local attackerOldTileX, attackerOldTileY, attackerOldPixelX, attackerOldPixelY = attacker.tileX, attacker.tileY, attacker.x, attacker.y
    local targetOldTileX, targetOldTileY, targetOldPixelX, targetOldPixelY = target.tileX, target.tileY, target.x, target.y
    attacker.tileX, attacker.tileY, attacker.targetX, attacker.targetY = targetOldTileX, targetOldTileY, targetOldPixelX, targetOldPixelY
    target.tileX, target.tileY, target.targetX, target.targetY = attackerOldTileX, attackerOldTileY, attackerOldPixelX, attackerOldPixelY
    EventBus:dispatch("unit_tile_changed", { unit = attacker, world = world })
    EventBus:dispatch("unit_tile_changed", { unit = target, world = world })

    -- 3. Give them a speed boost for a quick animation.
    attacker.speedMultiplier, target.speedMultiplier = 3, 3
    return true
end

UnitAttacks.fireball = function(attacker, world, attackInstanceId)
    -- Fireball is a projectile attack.
    return executeCycleTargetProjectileAttack(attacker, "fireball", world, true, attackInstanceId)
end

UnitAttacks.impale = function(attacker, world, attackInstanceId)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    -- Check for a unit or obstacle behind the primary target
    local dx = target.tileX - attacker.tileX
    local dy = target.tileY - attacker.tileY
    local behindTileX, behindTileY = target.tileX + dx, target.tileY + dy

    local secondaryUnit = WorldQueries.getUnitAt(behindTileX, behindTileY, target, world)
    local behindObstacle = WorldQueries.getObstacleAt(behindTileX, behindTileY, world)
    
    local impaledSomething = false
    local attackName = "impale"
    local targetType = (attacker.type == "player") and "enemy" or "player"
    
    -- Check for secondary unit first
    if secondaryUnit and secondaryUnit.type ~= attacker.type then
        impaledSomething = true
        -- Secondary target takes normal damage.
        local secondarySpecialProperties = { attackInstanceId = attackInstanceId }
        EffectFactory.addAttackEffect(world, {
            attacker = attacker,
            attackName = attackName,
            x = secondaryUnit.x, y = secondaryUnit.y,
            width = secondaryUnit.size, height = secondaryUnit.size,
            color = {1, 0, 0, 1},
            targetType = targetType,
            specialProperties = secondarySpecialProperties
        })
    -- If no unit, check for a valid obstacle (not a trap).
    elseif behindObstacle and not behindObstacle.isTrap then
        impaledSomething = true
    end

    -- Now apply damage to the primary target
    local primarySpecialProperties = { attackInstanceId = attackInstanceId }
    if impaledSomething then
        primarySpecialProperties.damageMultiplier = 1.5
        -- Add the knockback animation component to the target.
        target.components.knockback_animation = {
            timer = 0.25, -- A short, snappy animation.
            initialTimer = 0.25,
            direction = attacker.lastDirection, -- The direction of the knockback.
            distance = 8 -- The max pixel distance of the knockback.
        }
    end
    
    EffectFactory.addAttackEffect(world, {
            attacker = attacker,
            attackName = attackName,
            x = target.x, y = target.y,
            width = target.size, height = target.size,
            color = {1, 0, 0, 1},
            targetType = targetType,
        specialProperties = primarySpecialProperties
    })

    return true
end

UnitAttacks.mend = function(attacker, world, attackInstanceId)
    return execute_cycle_target_heal_attack(attacker, world, attackInstanceId)
end

UnitAttacks.phantom_step = function(square, world, attackInstanceId)
     -- 1. Get the selected target from the cycle targeting system.
     if not world.ui.targeting.cycle.active or not world.ui.targeting.cycle.targets[world.ui.targeting.cycle.selectedIndex] then
         return false -- Failsafe, should not happen if called correctly.
     end
     local target = world.ui.targeting.cycle.targets[world.ui.targeting.cycle.selectedIndex]
 
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
     EventBus:dispatch("unit_tile_changed", { unit = square, world = world })
 
     -- 4. Make the attacker face the target from the new position and add a lunge for visual feedback.
     -- This must be done *after* teleporting.
     square.lastDirection = Grid.getDirection(teleportTileX, teleportTileY, target.tileX, target.tileY)
     square.components.lunge = { timer = 0.2, initialTimer = 0.2, direction = square.lastDirection }

     -- 5. Apply damage to the target by creating an attack effect.
     local attackName = "phantom_step"
     local status = {type = "stunned", duration = 1}
     local targetType = (square.type == "player") and "enemy" or "player"
     local specialProperties = { attackInstanceId = attackInstanceId }
     EffectFactory.addAttackEffect(world, {
        attacker = square,
        attackName = attackName,
        x = target.x,
        y = target.y,
        width = target.size,
        height = target.size,
        color = {1, 0, 0, 1},
        targetType = targetType,
        statusEffect = status,
        specialProperties = specialProperties
     })
     return true
 end

UnitAttacks.invigoration = function(attacker, world, attackInstanceId)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    -- If the friendly target has already acted, refresh their turn.
    if target.hasActed then
        target.hasActed = false
        EffectFactory.createDamagePopup(world, target, "Refreshed!", false, {0.5, 1, 0.5, 1}) -- Green text
    end

    local specialProperties = { attackInstanceId = attackInstanceId }
    -- Create a visual effect on the target tile so the player sees the action.
    EffectFactory.addAttackEffect(world, {
        attacker = attacker,
        attackName = "invigoration",
        x = target.x,
        y = target.y,
        width = target.size,
        height = target.size,
        color = {0.5, 1, 0.5, 0.7},
        isHeal = true, targetType = "none",
        specialProperties = specialProperties
    })
    return true
end

UnitAttacks.kindle = function(attacker, world, attackInstanceId)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    -- Failsafe: Ensure the target can have wisp.
    if not target.wisp or not target.maxWisp then
        return false
    end

    local wispBefore = target.wisp
    target.wisp = math.min(target.finalMaxWisp, target.wisp + 3)
    local wispRestored = target.wisp - wispBefore

    if wispRestored > 0 then
        EffectFactory.createDamagePopup(world, target, "Wisp +" .. wispRestored, false, {1, 1, 0.5, 1}) -- Yellow text
    else
        EffectFactory.createDamagePopup(world, target, "Wisp Full", false, {0.8, 0.8, 0.8, 1}) -- Grey text
    end

    -- Create a visual effect on the target tile.
    EffectFactory.addAttackEffect(world, {
        attacker = attacker,
        attackName = "kindle",
        x = target.x, y = target.y,
        width = target.size, height = target.size,
        color = {1, 1, 0.5, 0.7}, -- Yellowish color
        isHeal = true, -- Prevents counter-attacks and treats it as a friendly action.
        targetType = "none",
        specialProperties = { attackInstanceId = attackInstanceId }
    })
    return true
end

UnitAttacks.bodyguard = function(attacker, world, attackInstanceId)
    -- 1. Get the selected destination tile from the secondary targeting state.
    -- The input handler has already validated the tile and set up the state.
    local secondary = world.ui.targeting.secondary
    if not secondary.active or not secondary.tiles[secondary.selectedIndex] then
        return false -- Failsafe, should not happen if called correctly.
    end
    local destinationTile = secondary.tiles[secondary.selectedIndex]

    -- 2. Teleport the attacker to the chosen tile.
    local teleportX, teleportY = Grid.toPixels(destinationTile.tileX, destinationTile.tileY)
    attacker.x, attacker.y = teleportX, teleportY
    attacker.targetX, attacker.targetY = teleportX, teleportY
    attacker.tileX, attacker.tileY = destinationTile.tileX, destinationTile.tileY
    EventBus:dispatch("unit_tile_changed", { unit = attacker, world = world })

    -- 3. Make the attacker face the primary target for a better visual.
    local primaryTarget = secondary.primaryTarget
    if primaryTarget then
        attacker.lastDirection = Grid.getDirection(attacker.tileX, attacker.tileY, primaryTarget.tileX, primaryTarget.tileY)
    end

    -- 4. Create a visual effect for feedback.
    EffectFactory.createDamagePopup(world, attacker, "Bodyguard!", false, {0.2, 0.8, 1.0, 1}) -- Cyan text

    -- 5. The move consumes the unit's turn and bypasses Hustle.
    attacker.components.turn_ended_by_move = true
    attacker.components.action_in_progress = true
    return true
end

UnitAttacks.eruption = function(attacker, world, attackInstanceId)
    -- This is the new model for a ground_aim AoE attack.
    -- 1. Get the target tile from the ground aiming cursor.
    local targetTileX, targetTileY = world.ui.mapCursorTile.x, world.ui.mapCursorTile.y
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
        EffectFactory.addAttackEffect(world, {
            attacker = attacker,
            attackName = "eruption",
            x = effectData.shape.x,
            y = effectData.shape.y,
            width = effectData.shape.w,
            height = effectData.shape.h,
            color = color,
            delay = effectData.delay,
            targetType = targetType,
            specialProperties = specialProperties
        })
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
    local targetTileX, targetTileY = world.ui.mapCursorTile.x, world.ui.mapCursorTile.y

    -- 2. Validate that the target tile is empty.
    if not WorldQueries.isTileLandable(targetTileX, targetTileY, attacker, world) then
        return false -- Attack fails if the tile is not landable for this unit.
    end

    -- 3. Store original position and immediately update the logical position.
    -- This ensures that when 'airborne' is applied and Aetherfall triggers,
    -- the attacker is no longer considered to be on their starting tile.
    local startTileX, startTileY = attacker.tileX, attacker.tileY
    EventBus:dispatch("unit_tile_changed", { unit = attacker, world = world })
    attacker.tileX, attacker.tileY = targetTileX, targetTileY

    -- 4. Set the attacker's target destination and speed for the visual movement.
    local targetPixelX, targetPixelY = Grid.toPixels(targetTileX, targetTileY)
    attacker.targetX, attacker.targetY = targetPixelX, targetPixelY
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

    -- 7. Create a visual effect at the destination tile.
    -- This provides feedback that the action was successful.
    EffectFactory.addAttackEffect(world, {
        attacker = attacker,
        attackName = "quick_step",
        x = targetPixelX,
        y = targetPixelY,
        width = Config.SQUARE_SIZE,
        height = Config.SQUARE_SIZE,
        color = {0.2, 0.8, 0.3, 0.7}, -- A light green to indicate a utility move
        targetType = "none", -- This effect doesn't target anything for damage.
        specialProperties = { attackInstanceId = attackInstanceId }
    })

    return true -- Consume the turn.
end

UnitAttacks.grovecall = function(square, world, attackInstanceId)
    -- This is the new model for a ground_aim attack.
    -- 1. Get the target tile from the ground aiming cursor.
    local targetTileX, targetTileY = world.ui.mapCursorTile.x, world.ui.mapCursorTile.y

    -- 2. Validate that the target tile is empty.
    -- Use isTileLandable with a nil unit to check if the ground itself is valid for placing an object.
    if not WorldQueries.isTileLandable(targetTileX, targetTileY, nil, world) then
        return false -- Attack fails if the tile is occupied, water, etc.
    end

    -- 3. Create the new tree obstacle by cloning the blueprint.
    -- This ensures it has all the necessary properties (hp, stats, etc.) to be targetable.
    local landX, landY = Grid.toPixels(targetTileX, targetTileY)
    local blueprint = ObjectBlueprints.tree
    if not blueprint then return false end -- Failsafe

    local newObstacle = {}
    -- Copy all properties from the blueprint
    for k, v in pairs(blueprint) do
        newObstacle[k] = v
    end

    -- Set position and state
    newObstacle.x, newObstacle.y = landX, landY
    newObstacle.tileX, newObstacle.tileY = targetTileX, targetTileY
    newObstacle.width, newObstacle.height, newObstacle.size = Config.SQUARE_SIZE, Config.SQUARE_SIZE, Config.SQUARE_SIZE
    newObstacle.isObstacle = true
    newObstacle.hp = newObstacle.maxHp -- Set current HP to max HP
    newObstacle.statusEffects = {} -- Initialize status effects table
    newObstacle.components = {} -- Initialize components table
    newObstacle.sprite = Assets.images.Flag -- Explicitly assign the sprite asset, just like in world.lua

    world:queue_add_entity(newObstacle)

    local specialProperties = { attackInstanceId = attackInstanceId }
    -- 4. Create a visual effect on the target tile so the player sees the action.
    EffectFactory.addAttackEffect(world, {
        attacker = square,
        attackName = "grovecall",
        x = landX,
        y = landY,
        width = Config.SQUARE_SIZE,
        height = Config.SQUARE_SIZE,
        color = {0.2, 0.8, 0.3, 0.7},
        targetType = "none",
        specialProperties = specialProperties
    })

    return true -- Attack succeeds, turn is consumed.
end

UnitAttacks.trap_set = function(square, world, attackInstanceId)
    -- 1. Get the target tile from the ground aiming cursor.
    local targetTileX, targetTileY = world.ui.mapCursorTile.x, world.ui.mapCursorTile.y

    -- 2. Validate that the target tile is empty.
    if not WorldQueries.isTileLandable(targetTileX, targetTileY, nil, world) then
        return false -- Attack fails if the tile is occupied, water, etc.
    end

    -- 3. Create the new trap obstacle by cloning the blueprint.
    local landX, landY = Grid.toPixels(targetTileX, targetTileY)
    local blueprint = ObjectBlueprints.beartrap
    if not blueprint then return false end -- Failsafe

    local newObstacle = {}
    -- Copy all properties from the blueprint
    for k, v in pairs(blueprint) do newObstacle[k] = v end

    -- Set position and state
    newObstacle.x, newObstacle.y = landX, landY
    newObstacle.tileX, newObstacle.tileY = targetTileX, targetTileY
    newObstacle.width, newObstacle.height, newObstacle.size = Config.SQUARE_SIZE, Config.SQUARE_SIZE, Config.SQUARE_SIZE
    newObstacle.isObstacle = true
    newObstacle.hp = newObstacle.maxHp
    newObstacle.statusEffects = {}
    newObstacle.components = {}
    newObstacle.sprite = Assets.images.BearTrap

    world:queue_add_entity(newObstacle)

    local specialProperties = { attackInstanceId = attackInstanceId }
    -- 4. Create a visual effect on the target tile so the player sees the action.
    EffectFactory.addAttackEffect(world, {
        attacker = square, attackName = "trap_set", x = landX, y = landY,
        width = Config.SQUARE_SIZE, height = Config.SQUARE_SIZE, color = {0.2, 0.8, 0.3, 0.7},
        targetType = "none", specialProperties = specialProperties
    })
    return true
end

UnitAttacks.ascension = function(attacker, world, attackInstanceId)
    -- 1. Get the target tile from the ground aiming cursor.
    local targetTileX, targetTileY = world.ui.mapCursorTile.x, world.ui.mapCursorTile.y

    -- 2. Add the 'ascended' component to the attacker.
    -- This component makes the unit untargetable and invisible.
    attacker.components.ascended = {
        targetTileX = targetTileX,
        targetTileY = targetTileY
    }

    -- 3. Add a shadow marker to the world for the renderer.
    -- The shadow indicates where the unit will land.
    table.insert(world.ascension_shadows, {
        unit = attacker,
        tileX = targetTileX,
        tileY = targetTileY
    })

    -- 4. The move consumes the unit's turn.
    -- The action_finalization_system will set hasActed = true.
    local attackData = AttackBlueprints.ascension
    if attackData.ends_turn_immediately then
        -- This flag tells the Hustle system not to grant a second action.
        attacker.components.turn_ended_by_move = true
    end
    attacker.components.action_in_progress = true
    return true
end

UnitAttacks.taunt = function(attacker, world, attackInstanceId)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    local attackName = "taunt"
    local attackData = AttackBlueprints[attackName]
    if not attackData then return false end

    -- Apply the status effect directly.
    local statusToApply = {
        type = attackData.statusEffect.type,
        duration = attackData.statusEffect.duration,
        attacker = attacker -- IMPORTANT: store who applied the taunt
    }
    StatusEffectManager.applyStatusEffect(target, statusToApply, world)

    -- Create a visual effect on the target tile.
    EffectFactory.addAttackEffect(world, {
        attacker = attacker, attackName = attackName, x = target.x, y = target.y,
        width = target.size, height = target.size, color = {1, 0.2, 0.2, 0.7},
        targetType = "none", specialProperties = { attackInstanceId = attackInstanceId }
    })
    return true
end

UnitAttacks.aegis = function(attacker, world, attackInstanceId)
    local attackName = "aegis"
    local attackData = AttackBlueprints[attackName]
    if not attackData then return false end

    -- Apply the status effect to self.
    local statusToApply = {
        type = attackData.statusEffect.type,
        duration = attackData.statusEffect.duration,
        attacker = attacker
    }
    StatusEffectManager.applyStatusEffect(attacker, statusToApply, world)

    -- Create a visual effect on the user.
    EffectFactory.addAttackEffect(world, {
        attacker = attacker, attackName = attackName, x = attacker.x, y = attacker.y,
        width = attacker.size, height = attacker.size, color = {1, 0.85, 0.2, 0.7},
        targetType = "none", specialProperties = { attackInstanceId = attackInstanceId }
    })
    return true
end

UnitAttacks.battle_cry = function(attacker, world, attackInstanceId)
    local attackName = "battle_cry"
    local attackData = AttackBlueprints[attackName]
    if not attackData then return false end

    -- 1. Apply Invincible to self. Duration is 1.5 to last through the end-of-turn tick.
    StatusEffectManager.applyStatusEffect(attacker, {type = "invincible", duration = 1.5, attacker = attacker}, world)

    -- 2. Find and taunt all enemies within range using the centralized query.
    local targets = WorldQueries.findValidTargetsForAttack(attacker, attackName, world)
    for _, target in ipairs(targets) do
        -- Apply Taunt status to the enemy.
        StatusEffectManager.applyStatusEffect(target, {type = "taunted", duration = 1, attacker = attacker}, world)
    end

    -- 3. Create a single, large visual effect centered on the attacker to represent the cry.
    EffectFactory.addAttackEffect(world, {
        attacker = attacker, attackName = attackName, x = attacker.x, y = attacker.y,
        width = attacker.size, height = attacker.size,
        -- A distinct color for the battle cry effect.
        color = {1, 0.5, 0, 0.7}, -- Orange
        targetType = "none", specialProperties = { attackInstanceId = attackInstanceId }
    })
    return true
end

UnitAttacks.homecoming = function(attacker, world, attackInstanceId)
    -- 1. Get the selected destination tile from the tile_cycle targeting state.
    -- The input handler has already validated the tile and set up the state.
    local tileCycle = world.ui.targeting.tile_cycle
    if not tileCycle.active or not tileCycle.tiles[tileCycle.selectedIndex] then
        return false -- Failsafe
    end
    local destinationTile = tileCycle.tiles[tileCycle.selectedIndex]

    -- 2. Teleport the attacker.
    local teleportX, teleportY = Grid.toPixels(destinationTile.tileX, destinationTile.tileY)
    attacker.x, attacker.y = teleportX, teleportY
    attacker.targetX, attacker.targetY = teleportX, teleportY
    attacker.tileX, attacker.tileY = destinationTile.tileX, destinationTile.tileY
    EventBus:dispatch("unit_tile_changed", { unit = attacker, world = world })

    -- 3. Create a visual effect for feedback.
    EffectFactory.createDamagePopup(world, attacker, "Zwoop!", false, {0.2, 0.8, 1.0, 1}) -- Cyan text

    -- 4. The move consumes the unit's turn and bypasses Hustle.
    attacker.components.turn_ended_by_move = true
    attacker.components.action_in_progress = true
    return true
end

UnitAttacks.hookshot = function(attacker, world, attackInstanceId)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end

    -- 3. Get the blueprint data to find the range and fire the hook.
    local attackData = AttackBlueprints.hookshot
    local range = attackData.range
    local power = attackData.power
    local newHook = EntityFactory.createGrappleHook(attacker, power, range)

    world:queue_add_entity(newHook)
    return true
end

UnitAttacks.ice_beam = function(attacker, world, attackInstanceId)
    local target = get_and_face_cycle_target(attacker, world)
    if not target then return false end
 
    local attackName = "ice_beam"
    local attackData = AttackBlueprints[attackName]
    if not attackData then return false end
 
    -- Use Bresenham's line algorithm to get all tiles in the path.
    local startX, startY = attacker.tileX, attacker.tileY
    local endX, endY = target.tileX, target.tileY
    local line_tiles = {}
    local dx = math.abs(endX - startX)
    local dy = -math.abs(endY - startY)
    local sx = (startX < endX) and 1 or -1
    local sy = (startY < endY) and 1 or -1
    local err = dx + dy
    local x0, y0 = startX, startY
 
    while true do
        -- Don't include the attacker's own tile in the beam.
        if not (x0 == startX and y0 == startY) then
            table.insert(line_tiles, {tileX = x0, tileY = y0})
        end
        if x0 == endX and y0 == endY then break end
        local e2 = 2 * err
        if e2 >= dy then err = err + dy; x0 = x0 + sx; end
        if e2 <= dx then err = err + dx; y0 = y0 + sy; end
    end
 
    local targetType = (attacker.type == "player") and "enemy" or "player"
    local beamColor = {0.2, 0.8, 1.0, 0.8} -- Cyan
    local stepDelay = 0.04 -- Time between each tile appearing
    local persistDuration = 0.3 -- How long the full beam stays visible
    local hasHitUnit = false
 
    for i, tile in ipairs(line_tiles) do
        local pixelX, pixelY = Grid.toPixels(tile.tileX, tile.tileY)
        local initialDelay = (i - 1) * stepDelay
        local flashDuration = ((#line_tiles - i) * stepDelay) + persistDuration
 
        local unitOnTile = WorldQueries.getUnitAt(tile.tileX, tile.tileY, attacker, world)
 
        local effectToCreate = {
            attacker = attacker, attackName = attackName, x = pixelX, y = pixelY,
            width = Config.SQUARE_SIZE, height = Config.SQUARE_SIZE, color = beamColor,
            delay = initialDelay, duration = flashDuration,
            specialProperties = { attackInstanceId = attackInstanceId }
        }
 
        if not hasHitUnit and unitOnTile and (unitOnTile.type == targetType or unitOnTile.isObstacle) then
            effectToCreate.targetType = targetType -- This effect will do damage.
            hasHitUnit = true
        else
            effectToCreate.targetType = "none" -- This effect is visual-only (but can still freeze water).
        end
        
        EffectFactory.addAttackEffect(world, effectToCreate)
    end

    return true
end

return UnitAttacks