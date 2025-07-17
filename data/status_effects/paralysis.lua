-- data/status_effects/paralysis.lua
return {
    type = "paralysis",
    duration = 1, -- Lasts 1 turn (until the start of the affected unit's next turn)
    -- "tick" is not needed for paralysis, as it doesn't have any effect that occurs *during* the turn.
    -- The movement restriction is handled by checking for the status in WorldQueries.getUnitMovement
    properties = {
        visual = {color = {1.0, 1.0, 0.2, 0.5}} -- Yellow overlay
    }
}
