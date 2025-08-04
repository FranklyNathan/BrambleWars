-- data/status_effects/airborne.lua
return {
    type = "airborne",
    duration = 2, -- Standard airborne lasts for 2 seconds (for the visual).
    -- The Aetherfall system will now manage the duration of this status,
    -- but we keep a default duration for cases where Aetherfall is not involved.
    externalControl = true, -- The Aetherfall system can manage this effect's duration.
    on_apply = function(target, world)
        -- This effect could play a sound or animation when applied (if needed)
    end,
    properties = {
        visual = {
            -- The visual handling is already largely implemented in Renderer.lua.
            -- We could add more properties here if we want more control (e.g., a unique animation).
        }
    }
}
