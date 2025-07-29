-- systems/action_menu_preview_system.lua
-- This system is responsible for calculating and displaying the attack preview
-- when the player is navigating the action menu.

local RangeCalculator = require("modules.range_calculator")
local AttackPatterns = require("modules.attack_patterns")
local AttackBlueprints = require("data.attack_blueprints")
local EventBus = require("modules.event_bus")

local ActionMenuPreviewSystem = {}

-- This is the function from the traceback.
-- It's responsible for calculating and setting the preview tiles based on the selected action.
local function refresh_preview(world)
    local menu = world.ui.menus.action

    -- FIX: Add a guard clause. If the menu doesn't exist, is not active, or has no unit,
    -- clear any lingering preview data and exit. This prevents the error.
    if not menu or not menu.active or not menu.unit then
        if menu then -- Ensure menu table exists before trying to nil out properties
            menu.previewAttackableTiles = nil
            menu.previewAoeShapes = nil
        end
        return
    end

    -- Default to no preview, and clear any previous preview.
    menu.previewAttackableTiles = nil
    menu.previewAoeShapes = nil

    local selectedOption = menu.options[menu.selectedIndex]
    if not selectedOption then return end

    local attackName = selectedOption.key
    local attackData = AttackBlueprints[attackName]

    if attackData then
        if attackData.targeting_style == "ground_aim" then
            menu.previewAoeShapes = AttackPatterns.getGroundAimPreviewShapes(attackName, menu.unit.tileX, menu.unit.tileY)
        else
            menu.previewAttackableTiles = RangeCalculator.calculateSingleAttackRange(menu.unit, attackName, world)
        end
    end
end

-- This function is called when the player state changes.
-- It's used to clear the preview when the menu closes, and to show the initial preview when it opens.
local function refresh_preview_callback(data)
    -- The refresh_preview function now has internal checks to see if the menu is active,
    -- so it's safe to call it. It will correctly show the preview when the menu becomes
    -- active, and clear it when it becomes inactive.
    refresh_preview(data.world)
end

-- Listen for when the player scrolls through the action menu.
EventBus:register("action_menu_selection_changed", refresh_preview_callback)

-- Listen for when the player's state changes (e.g., opening or closing the action menu).
EventBus:register("player_state_changed", refresh_preview_callback)

return ActionMenuPreviewSystem