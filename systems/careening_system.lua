-- careening_system.lua
-- This system is responsible for updating all entities with the 'careening' status effect.

local Grid = require("modules.grid")
local WorldQueries = require("modules.world_queries")
local EffectFactory = require("modules.effect_factory")

local CareeningSystem = {}

function CareeningSystem.update(dt, world)
    for _, s in ipairs(world.all_entities) do
        if s.statusEffects and s.statusEffects.careening and s.hp > 0 then
            local effect = s.statusEffects.careening
            if not s.careenMoveTimer then s.careenMoveTimer = 0 end
            s.careenMoveTimer = s.careenMoveTimer + dt

            -- Use a while loop to handle movement. This makes it frame-rate independent
            -- and allows it to catch up if a frame takes too long.
            while s.careenMoveTimer >= 0.05 do
                s.careenMoveTimer = s.careenMoveTimer - 0.05 -- Decrement by the interval

                if effect.force > 0 then
                    local nextX, nextY = s.x, s.y
                    if effect.direction == "up" then nextY = s.y - Config.SQUARE_SIZE
                    elseif effect.direction == "down" then nextY = s.y + Config.SQUARE_SIZE
                    elseif effect.direction == "left" then nextX = s.x - Config.SQUARE_SIZE
                    elseif effect.direction == "right" then nextX = s.x + Config.SQUARE_SIZE
                    end

                    -- Collision check
                    local hitWall = nextX < 0 or nextX >= (world.map.width * world.map.tilewidth) or
                                    nextY < 0 or nextY >= (world.map.height * world.map.tileheight)

                    local nextTileX, nextTileY = Grid.toTile(nextX, nextY)
                    local hitTeammate = WorldQueries.isTileOccupiedBySameTeam(nextTileX, nextTileY, s, world)

                    if hitWall or hitTeammate then
                        EffectFactory.createRippleEffect(effect.attacker, s.x + s.size/2, s.y + s.size/2, 10, 3, "all")
                        s.statusEffects.careening = nil
                        break -- Exit the while loop as the effect is over
                    else
                        -- Update pixel position
                        s.x, s.targetX, s.y, s.targetY = nextX, nextX, nextY, nextY
                        -- Also update the logical tile position to stay in sync.
                        s.tileX, s.tileY = Grid.toTile(s.x, s.y)
                        effect.force = effect.force - 1
                        if effect.force <= 0 then s.statusEffects.careening = nil; break; end
                    end
                else
                    s.statusEffects.careening = nil -- Force is 0, stop careening
                    break -- Exit the while loop
                end
            end
        end
    end
end

return CareeningSystem