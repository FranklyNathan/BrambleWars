-- range_logic.lua
-- Contains helper functions for range calculations, especially for basic attacks.

local RangeLogic = {}

-- Checks if a target is within range for a given attack based on its range type.
function RangeLogic.isInRange(attacker, target, attackData)
    local dx = math.abs(attacker.tileX - target.tileX)
    local dy = math.abs(attacker.tileY - target.tileY)
    local distance = dx + dy

    if attackData.rangetype == "standard_range" then
        if attackData.range == 1 then
            return distance == 1
        elseif attackData.range == 2 then
            return distance == 1 or -- Range 1
                   (dx == 1 and dy == 1) or -- diagonals
                   (dx == 2 and dy == 0) or (dx == 0 and dy == 2) -- 2 tiles away
        else
            return false
        end
    elseif attackData.rangetype == "ranged_only" then
        return  (dx == 1 and dy == 1) or -- diagonals
                (dx == 2 and dy == 0) or (dx == 0 and dy == 2) -- 2 tiles away
    else
        -- Default fallback, should not be needed if rangetype is always defined.
        return distance == 1
    end
end

return RangeLogic