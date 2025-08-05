-- systems/unit_info_system.lua
-- Manages the display of the unit info menu based on game events.

local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")
local Pathfinding = require("modules.pathfinding")
local RangeCalculator = require("modules.range_calculator")

local UnitInfoSystem = {}

-- Tracks the last unit for which a hover preview was calculated to prevent redundant calculations.
UnitInfoSystem.last_previewed_unit = nil

--- Calculates and displays the hover preview ranges.
-- This is an expensive function that should only be called when needed.
-- @param unit (table) The unit to show the preview for.
-- @param world (table) The main game world.
local function show_hover_preview(unit, world)
    if not unit or unit.hasActed then
        world.ui.pathing.hoverReachableTiles = nil
        world.ui.pathing.hoverAttackableTiles = nil
        return
    end

    -- This is the expensive part that was causing lag.
    local reachable, _, _ = Pathfinding.calculateReachableTiles(unit, world)
    world.ui.pathing.hoverReachableTiles = reachable
    world.ui.pathing.hoverAttackableTiles = RangeCalculator.calculateAttackableTiles(unit, world, reachable)
end

-- This is the core logic. It's called by event handlers to update the UI.
function UnitInfoSystem.refresh_display(world)
    -- If a level up is happening, we *always* show the info panel for that unit.
    -- This takes precedence over all other logic.
    if world.ui.levelUpAnimation and world.ui.levelUpAnimation.active then
        world.ui.menus.unitInfo.active = true
        world.ui.menus.unitInfo.unit = world.ui.levelUpAnimation.unit
        -- Clear hover previews during level up to avoid visual clutter.
        world.ui.pathing.hoverReachableTiles = nil
        world.ui.pathing.hoverAttackableTiles = nil
        world.ui.menus.unitInfo.rippleSourceUnit = nil -- Disable ripple during level up
        return -- Exit early, level-up display takes precedence.
    end

    -- If an EXP gain animation is active, show the panel for that unit.
    -- This is checked after level-up because level-up is a more specific state.
    local expGainAnim = world.ui.expGainAnimation
    if expGainAnim and expGainAnim.active then
        world.ui.menus.unitInfo.active = true
        world.ui.menus.unitInfo.unit = expGainAnim.unit
        -- When an EXP gain animation starts, automatically expand the details panel
        -- so the EXP bar is visible for the animation.
        if not world.ui.menus.unitInfo.detailsAnimation.active then
            world.ui.menus.unitInfo.detailsAnimation.active = true
            world.ui.menus.unitInfo.detailsAnimation.timer = 0
        end
        world.ui.pathing.hoverReachableTiles = nil
        world.ui.pathing.hoverAttackableTiles = nil
        world.ui.menus.unitInfo.rippleSourceUnit = nil
        return -- Exit early, EXP gain display takes precedence.
    end

    -- If a major action is happening (animations, etc.), or a menu is open that should
    -- hide the info box, then we ensure it's hidden.
    local shouldHide = WorldQueries.isActionOngoing(world) or
                       world.ui.playerTurnState == "unit_moving" or -- Hide while a unit is moving.
                       world.ui.menus.action.active or -- Hide when the action menu is open.
                       world.ui.menus.map.active -- Hide when the map menu is open.

    if shouldHide then
        world.ui.menus.unitInfo.active = false
        world.ui.pathing.hoverReachableTiles = nil
        world.ui.pathing.hoverAttackableTiles = nil
        -- Also reset the preview tracker when hiding the UI.
        UnitInfoSystem.last_previewed_unit = nil
        return
    end

    local unit_to_display = nil
    -- In targeting mode, the info box should always show the current target, not what's under the cursor.
    if world.ui.playerTurnState == "cycle_targeting" and world.ui.targeting.cycle.active and #world.ui.targeting.cycle.targets > 0 then
        unit_to_display = world.ui.targeting.cycle.targets[world.ui.targeting.cycle.selectedIndex]
    else
        -- In all other states, get the unit under the current cursor position.
        unit_to_display = WorldQueries.getUnitAt(world.ui.mapCursorTile.x, world.ui.mapCursorTile.y, nil, world)
    end

    -- New check: If the unit to display is a special tile target, don't show the info menu.
    -- Tile targets are placeholders and don't have the full data of a unit.
    if unit_to_display and unit_to_display.isTileTarget then
        unit_to_display = nil
    end

    -- Determine the true source of the ripple effect based on the game state.
    local ripple_source_unit = nil
    if world.ui.playerTurnState == "unit_selected" then
        ripple_source_unit = world.ui.selectedUnit
    elseif world.ui.playerTurnState == "enemy_range_display" then
        ripple_source_unit = world.ui.menus.enemyRangeDisplay.unit
    else
        -- In all other states (like free_roam), the ripple follows the hovered/targeted unit.
        ripple_source_unit = unit_to_display
    end

    -- If the ripple's source unit has changed, reset the animation timer.
    if ripple_source_unit ~= world.ui.menus.unitInfo.rippleSourceUnit then
        world.ui.menus.unitInfo.rippleStartTime = love.timer.getTime()
    end
    world.ui.menus.unitInfo.rippleSourceUnit = ripple_source_unit

    -- The unit being displayed in the info box is separate from the ripple source.
    world.ui.menus.unitInfo.unit = unit_to_display
    world.ui.menus.unitInfo.active = (unit_to_display ~= nil)

    -- The unit that should have a range preview is the one under the cursor, but only in free_roam.
    -- In other states (like 'unit_selected' or 'cycle_targeting'), we don't show a hover preview.
    local unit_to_preview = nil
    if world.ui.playerTurnState == "free_roam" then
        unit_to_preview = unit_to_display
    end

    -- Check if the unit we should be previewing has changed since the last time we checked.
    if unit_to_preview ~= UnitInfoSystem.last_previewed_unit then
        -- The unit has changed, so we need to update the preview.
        UnitInfoSystem.last_previewed_unit = unit_to_preview

        if unit_to_preview then
            -- A new unit is being hovered in free_roam, calculate its preview.
            show_hover_preview(unit_to_preview, world)
        else
            -- No unit is being hovered, or we are not in free_roam. Clear the preview.
            world.ui.pathing.hoverReachableTiles = nil
            world.ui.pathing.hoverAttackableTiles = nil
        end
    end
end

-- Event handler for when the cursor moves to a new tile.
local function on_cursor_moved(data)
    UnitInfoSystem.refresh_display(data.world)
end

-- Event handler for when the player's turn state changes.
-- This helps hide/show the menu correctly when selecting/deselecting units or opening menus.
local function on_player_state_changed(data)
    UnitInfoSystem.refresh_display(data.world)
end

-- Event handler for when the player cycles to a new target.
local function on_cycle_target_changed(data)
    UnitInfoSystem.refresh_display(data.world)
end

-- We also need to refresh when an action completes, as this might change what should be displayed.
local function on_action_finalized(data)
    UnitInfoSystem.refresh_display(data.world)
end

-- Event handler for when an EXP gain animation starts.
local function on_exp_gain_started(data)
    UnitInfoSystem.refresh_display(data.world)
end

-- Register the event listeners. This code runs when the module is required.
EventBus:register("cursor_moved", on_cursor_moved)
EventBus:register("player_state_changed", on_player_state_changed)
EventBus:register("cycle_target_changed", on_cycle_target_changed)
EventBus:register("action_finalized", on_action_finalized)
EventBus:register("exp_gain_started", on_exp_gain_started)

return UnitInfoSystem