-- systems/unit_info_system.lua
-- Manages the display of the unit info menu based on cursor hover.

local WorldQueries = require("modules.world_queries")
local Pathfinding = require("modules.pathfinding")
local RangeCalculator = require("modules.range_calculator")

local UnitInfoSystem = {}

function UnitInfoSystem.update(dt, world)
    local menu = world.unitInfoMenu
    if not menu then return end

    -- Only show the hover menu in specific states.
    if world.playerTurnState == "free_roam" or world.playerTurnState == "unit_selected" then
        local unit = WorldQueries.getUnitAt(world.mapCursorTile.x, world.mapCursorTile.y, nil, world)

        if unit then
            -- A unit is being hovered.
            menu.active = true
            menu.unit = unit
            print("[UnitInfoSystem] Hovering over: " .. (unit.displayName or unit.enemyType))
            -- Calculate and store hover ranges, but only if the unit isn't the currently selected one
            -- to avoid drawing two sets of ranges for the same unit.
            if unit ~= world.selectedUnit then
                print("[UnitInfoSystem] Calculating hover ranges...")
                local reachable, _ = Pathfinding.calculateReachableTiles(unit, world)
                world.hoverReachableTiles = reachable
                world.hoverAttackableTiles = RangeCalculator.calculateAttackableTiles(unit, world, reachable)
                local reachableCount = 0; for _ in pairs(world.hoverReachableTiles) do reachableCount = reachableCount + 1 end
                local attackableCount = 0; for _ in pairs(world.hoverAttackableTiles) do attackableCount = attackableCount + 1 end
                print(string.format("[UnitInfoSystem] Found %d reachable tiles and %d attackable tiles.", reachableCount, attackableCount))
            else
                print("[UnitInfoSystem] Hovered unit is the selected unit. Skipping range calculation.")
            end
        else
            -- No unit is being hovered.
            menu.active = false
            menu.unit = nil
            if world.hoverReachableTiles then print("[UnitInfoSystem] Clearing hover ranges.") end
            world.hoverReachableTiles = nil
            world.hoverAttackableTiles = nil
        end
    else
        -- We are not in a state where the hover menu should be shown.
        menu.active = false
        menu.unit = nil
        if world.hoverReachableTiles then print("[UnitInfoSystem] Clearing hover ranges due to state change.") end
        world.hoverReachableTiles = nil
        world.hoverAttackableTiles = nil
    end
end

return UnitInfoSystem