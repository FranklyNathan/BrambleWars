-- systems/action_menu_preview_system.lua
-- Manages showing the attack range preview when hovering over moves in the action menu.

local RangeCalculator = require("modules.range_calculator")
local AttackPatterns = require("modules.attack_patterns")
local AttackBlueprints = require("data.attack_blueprints")

local ActionMenuPreviewSystem = {}

-- Keep track of the last state to avoid recalculating every frame.
local lastUnit = nil
local lastIndex = -1

function ActionMenuPreviewSystem.update(dt, world)
    local menu = world.actionMenu
    if menu.active and world.playerTurnState == "action_menu" then
        -- Check if the selected unit or the highlighted menu item has changed.
        if menu.unit ~= lastUnit or menu.selectedIndex ~= lastIndex then
            lastUnit = menu.unit
            lastIndex = menu.selectedIndex

            -- Clear previous previews before calculating new ones.
            menu.previewAttackableTiles = nil
            menu.previewAoeShapes = nil

            local selectedOption = menu.options[lastIndex]
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
    else
        -- If the menu is not active, ensure the preview is cleared and state is reset.
        if menu.previewAttackableTiles then menu.previewAttackableTiles = nil end
        if menu.previewAoeShapes then menu.previewAoeShapes = nil end
        lastUnit = nil
        lastIndex = -1
    end
end

return ActionMenuPreviewSystem