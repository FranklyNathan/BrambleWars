-- systems/level_up_display_system.lua
-- Manages the state and timing for the level-up animation sequence,
-- which is visually rendered by the a file that is not yet created.

local EventBus = require("modules.event_bus")
local PromotionSystem = require("systems.promotion_system")
local StatSystem = require("systems.stat_system")
local LevelUpSystem = require("systems.level_up_system")

local LevelUpDisplaySystem = {}

-- Configuration for animation timing
LevelUpDisplaySystem.INITIAL_DELAY = 0.5     -- Time before the first stat appears
LevelUpDisplaySystem.STAT_REVEAL_DELAY = 0.2  -- Time between each stat's "+1" popping in
LevelUpDisplaySystem.POP_IN_DURATION = 0.15   -- How long the "+1" pop-in animation lasts
LevelUpDisplaySystem.PLUS_ONE_DURATION = 1.0   -- How long the "+1" text stays visible after all have appeared
LevelUpDisplaySystem.FADE_OUT_DURATION = 0.4   -- How long it takes for the "+1" to fade
LevelUpDisplaySystem.FINISH_DELAY = 1.0       -- How long the final stats are shown before the animation ends

-- State variables
LevelUpDisplaySystem.active = false
LevelUpDisplaySystem.unit = nil
LevelUpDisplaySystem.animationState = "idle" -- "idle", "starting", "revealing", "holding", "fading", "applying_stats", "finished"
LevelUpDisplaySystem.timer = 0

-- The order in which stats will be displayed during level up for consistency.
local STAT_DISPLAY_ORDER = {
    "maxHp",
    "attackStat",
    "defenseStat",
    "magicStat",
    "resistanceStat",
    "witStat",
    "maxWisp"
}

--- Starts the level-up animation sequence by creating a state object for the UI renderer to use.
-- @param unit (table): The unit that is leveling up.
-- @param gains (table): A table of stat increases, e.g., {maxHp = 1, attackStat = 1}
-- @param world (table): The main game world table.
function LevelUpDisplaySystem.start(unit, gains, world)
    if LevelUpDisplaySystem.active then return end -- Don't start a new one if one is in progress

    -- Set up the system's internal state
    LevelUpDisplaySystem.active = true
    LevelUpDisplaySystem.unit = unit
    LevelUpDisplaySystem.animationState = "starting"
    LevelUpDisplaySystem.timer = LevelUpDisplaySystem.INITIAL_DELAY

    -- Create the state object that the UI renderer will read from.
    world.ui.levelUpAnimation = {
        active = true,
        unit = LevelUpDisplaySystem.unit,
        statGains = gains, -- The actual stat increases
        statsToReveal = {},
        statsShown = {}, -- This will be populated with {startTime = t} for each stat
        phase = "starting" -- The current phase for the renderer to read
    }

    -- Populate the list of stats to reveal in the correct order
    for _, statName in ipairs(STAT_DISPLAY_ORDER) do
        if gains[statName] and gains[statName] > 0 then
            table.insert(world.ui.levelUpAnimation.statsToReveal, statName)
        end
    end

    -- Dispatch an event to force the UI to refresh and show the unit info panel.
    EventBus:dispatch("player_state_changed", { world = world })
end

--- Applies the final stat changes to the unit model and updates the UI state.
-- @param world (table): The main game world table.
function LevelUpDisplaySystem.applyStatChanges(world)
    local anim = world.ui.levelUpAnimation
    if not LevelUpDisplaySystem.unit or not anim or not anim.statGains then return end

    -- Apply the stat gains permanently
    for stat, gain in pairs(anim.statGains) do
        LevelUpDisplaySystem.unit[stat] = LevelUpDisplaySystem.unit[stat] + gain
    end

    -- Handle level, EXP, and HP restoration
    LevelUpDisplaySystem.unit.level = LevelUpDisplaySystem.unit.level + 1
    LevelUpDisplaySystem.unit.exp = LevelUpDisplaySystem.unit.exp - LevelUpDisplaySystem.unit.maxExp

    -- Recalculate final stats to account for the base stat gains.
    StatSystem.recalculate_for_unit(LevelUpDisplaySystem.unit)

    -- Fully heal the unit to its new final max HP and Wisp.
    LevelUpDisplaySystem.unit.hp = LevelUpDisplaySystem.unit.finalMaxHp
    LevelUpDisplaySystem.unit.wisp = LevelUpDisplaySystem.unit.finalMaxWisp

    -- Update the UI state to remove the "+1"s and change colors back to normal.
    -- The renderer will stop drawing "+1"s because the fade is over.
    anim.isLevelGreen = false
    -- The renderer will now show the unit's new, updated stats.
end

--- The main update loop for the animation state machine.
-- @param dt (number): The delta time since the last frame.
-- @param world (table): The main game world table.
function LevelUpDisplaySystem.update(dt, world)
    if not LevelUpDisplaySystem.active then return end

    LevelUpDisplaySystem.timer = LevelUpDisplaySystem.timer - dt

    local anim = world.ui.levelUpAnimation
    if not anim or not anim.active then LevelUpDisplaySystem.active = false; return; end -- Failsafe

    -- Keep the renderer's 'phase' property in sync with the system's state.
    anim.phase = LevelUpDisplaySystem.animationState

    if LevelUpDisplaySystem.animationState == "starting" and LevelUpDisplaySystem.timer <= 0 then
        LevelUpDisplaySystem.animationState = "revealing"
        LevelUpDisplaySystem.timer = LevelUpDisplaySystem.STAT_REVEAL_DELAY
    elseif LevelUpDisplaySystem.animationState == "revealing" and LevelUpDisplaySystem.timer <= 0 then
        if #anim.statsToReveal > 0 then
            -- Reveal the next stat, storing its start time for the pop animation.
            local statName = table.remove(anim.statsToReveal, 1)
            anim.statsShown[statName] = { startTime = love.timer.getTime() }
            LevelUpDisplaySystem.timer = LevelUpDisplaySystem.STAT_REVEAL_DELAY
        else
            -- All stats have been revealed, move to the holding phase
            LevelUpDisplaySystem.animationState = "holding"
            LevelUpDisplaySystem.timer = LevelUpDisplaySystem.PLUS_ONE_DURATION
        end
    elseif LevelUpDisplaySystem.animationState == "holding" and LevelUpDisplaySystem.timer <= 0 then
        -- The hold time is over. Start fading out the "+1"s.
        LevelUpDisplaySystem.animationState = "fading"
        LevelUpDisplaySystem.timer = LevelUpDisplaySystem.FADE_OUT_DURATION
        anim.fadeStartTime = love.timer.getTime()
    elseif LevelUpDisplaySystem.animationState == "fading" and LevelUpDisplaySystem.timer <= 0 then
        -- The fade is complete. Apply the stats to the model and update the UI.
        LevelUpDisplaySystem.animationState = "applying_stats"
        -- No timer here, just transition to the next state immediately.
        LevelUpDisplaySystem.applyStatChanges(world)
    elseif LevelUpDisplaySystem.animationState == "applying_stats" then
        -- The stats have been applied, now just wait for the final display before finishing.
        LevelUpDisplaySystem.animationState = "finished"
        LevelUpDisplaySystem.timer = LevelUpDisplaySystem.FINISH_DELAY
    elseif LevelUpDisplaySystem.animationState == "finished" and LevelUpDisplaySystem.timer <= 0 then
        -- Animation is fully complete.
        local unit = LevelUpDisplaySystem.unit
        LevelUpDisplaySystem.active = false
        world.ui.levelUpAnimation.active = false

        -- Check if another level-up is pending for the same unit.
        local leveledUpAgain = LevelUpSystem.checkForLevelUp(unit, world)

        if not leveledUpAgain then
            -- No more level-ups. Now check for promotion.
            -- The PromotionSystem will handle setting hasActed and finalizing the action.
            if unit.level == 2 then
                PromotionSystem.start(unit, world)
            else
                -- No promotion, so finalize the action now.
                unit.hasActed = true
                EventBus:dispatch("action_finalized", { unit = unit, world = world })
            end
        end
        -- If leveledUpAgain is true, a new animation has started, so we do nothing here.
    end
end

return LevelUpDisplaySystem