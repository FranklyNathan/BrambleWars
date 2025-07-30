-- projectile_system.lua
-- Handles the movement and collision logic for all projectiles.

local Grid = require("modules.grid")
local AttackBlueprints = require("data.attack_blueprints")
local EffectFactory = require("modules.effect_factory")
local WorldQueries = require("modules.world_queries")
local CombatFormulas = require("modules.combat_formulas")
local CombatActions = require("modules.combat_actions")

local ProjectileSystem = {}

function ProjectileSystem.update(dt, world)
    -- Iterate backwards to safely remove projectiles
    for i = #world.projectiles, 1, -1 do
        local p = world.projectiles[i]
        local comp = p.components.projectile

        comp.timer = comp.timer - dt
        if comp.timer <= 0 then
            comp.timer = comp.timer + comp.moveDelay

            -- 1. Move the projectile one step and update its tile coordinates.
            p.x, p.y = Grid.getDestination(p.x, p.y, comp.direction, comp.moveStep)
            p.tileX, p.tileY = Grid.toTile(p.x, p.y)

            -- 2. Check for map boundary collision.
            if p.tileX < 0 or p.tileX >= world.map.width or p.tileY < 0 or p.tileY >= world.map.height then
                p.isMarkedForDeletion = true
            else
                -- 3. Check for collision with units.
                local targetType = comp.isEnemyProjectile and "player" or "enemy"
                local targets = (targetType == "player") and world.players or world.enemies
                for _, target in ipairs(targets) do
                    if target.hp > 0 and not comp.hitTargets[target] and target.tileX == p.tileX and target.tileY == p.tileY then
                        local attackData = AttackBlueprints[comp.attackName]
                        local damage = CombatFormulas.calculateBaseDamage(comp.attacker, target, attackData)
                        CombatActions.applyDirectDamage(world, target, damage, false, comp.attacker)
                        
                        comp.hitTargets[target] = true -- Mark as hit to prevent multi-hits.

                        if not comp.isPiercing then
                            p.isMarkedForDeletion = true
                            break -- Stop checking other targets.
                        end
                    end
                end

                -- 4. Check for collision with obstacles, but only if the projectile is still active.
                if not p.isMarkedForDeletion then
                    local hitObstacle = WorldQueries.getObstacleAt(p.tileX, p.tileY, world)
                    if hitObstacle and not comp.hitTargets[hitObstacle] then
                        if hitObstacle.hp then -- It's a destructible obstacle (e.g., a tree).
                            local attackData = AttackBlueprints[comp.attackName]
                            local damage = CombatFormulas.calculateBaseDamage(comp.attacker, hitObstacle, attackData)
                            CombatActions.applyDirectDamage(world, hitObstacle, damage, false, comp.attacker)
                            
                            comp.hitTargets[hitObstacle] = true -- Mark as hit.

                            if not comp.isPiercing then
                                p.isMarkedForDeletion = true
                            end
                        else -- It's an indestructible obstacle (e.g., a box).
                            p.isMarkedForDeletion = true
                        end
                    end
                end
            end
        end
    end
end

return ProjectileSystem