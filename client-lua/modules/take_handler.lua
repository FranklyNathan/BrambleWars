-- modules/take_handler.lua
-- Contains the logic for executing the Take command.

local RescueHandler = require("modules/rescue_handler") -- We can reuse the penalty calculation

local TakeHandler = {}

-- Executes the Take action.
-- The taker receives the carried unit from the carrier.
function TakeHandler.take(taker, carrier, world)
    if not taker or not carrier or not carrier.carriedUnit then return false end

    local carriedUnit = carrier.carriedUnit

    -- 1. Reset the original carrier's state.
    carrier.carriedUnit = nil
    carrier.rescuePenalty = 0
    carrier.weight = carrier.baseWeight

    -- 2. Apply the carried unit to the new taker.
    taker.carriedUnit = carriedUnit
    taker.rescuePenalty = RescueHandler.calculateMovementPenalty(taker, carriedUnit)
    taker.weight = taker.baseWeight + carriedUnit.baseWeight

    return true
end

return TakeHandler