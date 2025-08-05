-- modules/input_handlers/burrow_teleport_handler.lua
-- Handles input when the player is selecting a molehill to teleport to.

local InputHelpers = require("modules.input_helpers")
local Grid = require("modules.grid")
local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")
local Assets = require("modules.assets")

local BurrowTeleportHandler = {}

-- Helper to find the single burrowed unit.
local function findBurrowedUnit(world)
    for _, unit in ipairs(world.all_entities) do
        if unit.components and unit.components.burrowed then
            return unit
        end
    end
    return nil
end

function BurrowTeleportHandler.handle_key_press(key, world)
    local molehillSelect = world.ui.targeting.molehill_select
    if not molehillSelect or not molehillSelect.active then return end

    local indexChanged = false
    if key == "a" or key == "d" then
        if key == "a" then
            molehillSelect.selectedIndex = molehillSelect.selectedIndex - 1
            if molehillSelect.selectedIndex < 1 then molehillSelect.selectedIndex = #molehillSelect.targets end
        else -- "d"
            molehillSelect.selectedIndex = molehillSelect.selectedIndex + 1
            if molehillSelect.selectedIndex > #molehillSelect.targets then molehillSelect.selectedIndex = 1 end
        end
        indexChanged = true
    elseif key == "j" then -- Confirm teleport
        InputHelpers.play_confirm_sound()
        local burrowedUnit = findBurrowedUnit(world)

        if not burrowedUnit then
            -- Failsafe: if no unit is burrowed, cancel the action.
            molehillSelect.active = false
            InputHelpers.set_player_turn_state("free_roam", world)
            return
        end

        -- 2. Get the destination molehill tile.
        local destination = molehillSelect.targets[molehillSelect.selectedIndex]
        if not destination then return end -- Failsafe

        -- New: Validate that the destination tile is actually landable (not occupied).
        if not WorldQueries.isTileLandable(destination.tileX, destination.tileY, burrowedUnit, world) then
            -- TODO: Play a "cannot" sound effect.
            return
        end

        -- 3. Store movement used so far this turn.
        -- We look at the pathing data that was calculated when the unit was first selected.
        local pathingData = world.ui.pathing
        local currentTileKey = burrowedUnit.tileX .. "," .. burrowedUnit.tileY
        local cost = 0
        if pathingData and pathingData.cost_so_far and pathingData.cost_so_far[currentTileKey] then
            cost = pathingData.cost_so_far[currentTileKey]
        end
        -- This needs to be cumulative across the entire turn, in case Burrow is used multiple times.
        burrowedUnit.components.total_movement_used_this_turn = (burrowedUnit.components.total_movement_used_this_turn or 0) + cost

        -- 4. Teleport the unit.
        local destPixelX, destPixelY = Grid.toPixels(destination.tileX, destination.tileY)
        burrowedUnit.x, burrowedUnit.y = destPixelX, destPixelY
        burrowedUnit.targetX, burrowedUnit.targetY = destPixelX, destPixelY
        burrowedUnit.tileX, burrowedUnit.tileY = destination.tileX, destination.tileY
        EventBus:dispatch("unit_tile_changed", { unit = burrowedUnit, world = world })

        -- 5. Change unit's state from burrowed to reviving.
        burrowedUnit.components.burrowed = nil
        burrowedUnit.components.reviving = { timer = 0.5, initialTimer = 0.5, source = "burrow" }

        -- 6. Clean up the UI state.
        molehillSelect.active = false
        molehillSelect.targets = {}
        
    elseif key == "k" or key == "b" then -- Cancel Burrow (B is a common back button)
        InputHelpers.play_back_out_sound()
        local burrowedUnit = findBurrowedUnit(world)

        if burrowedUnit then
            -- The action is spent. Calculate the movement cost to get here.
            -- This ensures the unit's remaining movement is correct after canceling.
            local pathingData = world.ui.pathing
            local currentTileKey = burrowedUnit.tileX .. "," .. burrowedUnit.tileY
            local cost = 0
            if pathingData and pathingData.cost_so_far and pathingData.cost_so_far[currentTileKey] then
                cost = pathingData.cost_so_far[currentTileKey]
            end
            -- Add this cost to the total for the turn.
            burrowedUnit.components.total_movement_used_this_turn = (burrowedUnit.components.total_movement_used_this_turn or 0) + cost

            -- The action is already in progress. Pop the unit back out at its current location.
            burrowedUnit.components.burrowed = nil
            burrowedUnit.components.reviving = { timer = 0.5, initialTimer = 0.5, source = "burrow" }
        end

        -- Clean up the UI state and return to free roam regardless of whether a unit was found.
        molehillSelect.active = false
        molehillSelect.targets = {}
        InputHelpers.set_player_turn_state("free_roam", world)
    end

    if indexChanged then
        if Assets.sounds.cursor_move then Assets.sounds.cursor_move:stop(); Assets.sounds.cursor_move:play() end
        local newTarget = molehillSelect.targets[molehillSelect.selectedIndex]
        if newTarget then
            world.ui.mapCursorTile.x, world.ui.mapCursorTile.y = newTarget.tileX, newTarget.tileY
            EventBus:dispatch("cursor_moved", { tileX = newTarget.tileX, tileY = newTarget.tileY, world = world })
        end
    end
end

return BurrowTeleportHandler