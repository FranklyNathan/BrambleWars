-- systems/action_menu_preview_system.lua
-- Manages showing the attack range preview when hovering over moves in the action menu.

local EventBus = require("modules.event_bus")
local RangeCalculator = require("modules.range_calculator")
local AttackPatterns = require("modules.attack_patterns")
local AttackBlueprints = require("data.attack_blueprints")

local ActionMenuPreviewSystem = {}

-- This is the core logic. It's called by event handlers to update the preview.
function ActionMenuPreviewSystem.refresh_preview(world)
    local menu = world.actionMenu

    -- Always clear previous previews before calculating new ones.
    menu.previewAttackableTiles = nil
    menu.previewAoeShapes = nil

    -- Only show a preview if the action menu is active in the correct state.
    if menu.active and world.playerTurnState == "action_menu" then
        local selectedOption = menu.options[menu.selectedIndex]
        if selectedOption and selectedOption.key then
            local attackData = AttackBlueprints[selectedOption.key]
            -- Check if the selected option is a valid attack with a range.
            if attackData and (attackData.useType == "physical" or attackData.useType == "magical" or attackData.useType == "utility") then
                menu.previewAttackableTiles = RangeCalculator.calculateSingleAttackRange(menu.unit, selectedOption.key, world)

                -- If it's a ground-aimed attack, also generate the AoE shape preview.
                if attackData.targeting_style == "ground_aim" then
                    -- We show a representative AoE centered on the attacker's current tile.
                    menu.previewAoeShapes = AttackPatterns.getGroundAimPreviewShapes(selectedOption.key, menu.unit.tileX, menu.unit.tileY)
                end
            end
        end
    end
    -- If the menu is not active, the previews are already nilled out at the start of the function.
end

-- Event handler for when the selection in the action menu changes.
local function on_selection_changed(data)
    ActionMenuPreviewSystem.refresh_preview(data.world)
end

-- Event handler for when the player's turn state changes.
-- This is crucial for clearing the preview when the action menu is closed or opened.
local function on_player_state_changed(data)
    ActionMenuPreviewSystem.refresh_preview(data.world)
end

-- Register the event listeners.
EventBus:register("action_menu_selection_changed", on_selection_changed)
EventBus:register("player_state_changed", on_player_state_changed)

return ActionMenuPreviewSystem