-- systems/promotion_system.lua
-- Manages the logic for class promotions.

local EventBus = require("modules.event_bus")

local ClassBlueprints = require("data.class_blueprints")
local StatSystem = require("systems.stat_system")

local PromotionSystem = {}

-- Helper function to change the player's turn state.
local function set_player_turn_state(newState, world)
    local oldState = world.ui.playerTurnState
    if oldState ~= newState then
        world.ui.playerTurnState = newState
        EventBus:dispatch("player_state_changed", { oldState = oldState, newState = newState, world = world })
    end
end

-- Starts the promotion sequence for a unit.
function PromotionSystem.start(unit, world)
    local currentClassData = ClassBlueprints[unit.class]
    if not currentClassData or not next(currentClassData.promotions) then
        -- This unit cannot promote, so finalize their action.
        unit.hasActed = true
        EventBus:dispatch("action_finalized", { world = world })
        return
    end

    local menu = world.ui.menus.promotion
    menu.active = true
    menu.unit = unit
    menu.options = {}
    menu.selectedIndex = 1

    -- Populate options from blueprints
    for classId, promotionData in pairs(currentClassData.promotions) do
        table.insert(menu.options, {
            classId = classId,
            name = promotionData.name,
            stat_bonuses = promotionData.stat_bonuses
        })
    end

    set_player_turn_state("promotion_select", world)
end

-- Applies the chosen promotion to the unit.
function PromotionSystem.apply(unit, selectedOption, world)
    if not unit or not selectedOption then return end

    local bonuses = selectedOption.stat_bonuses
    local newClassId = selectedOption.classId

    -- 1. Apply stat bonuses to the unit's base stats.
    for stat, bonus in pairs(bonuses) do
        if unit[stat] then unit[stat] = unit[stat] + bonus end
    end
    if bonuses.maxHp and bonuses.maxHp > 0 then unit.hp = unit.hp + bonuses.maxHp end

    -- 2. Change the unit's class.
    unit.class = newClassId


    -- 3. Force a recalculation of the unit's final stats.
    StatSystem.recalculate_for_unit(unit)

    -- 4. Finalize the unit's action for the turn.
    unit.hasActed = true
    EventBus:dispatch("action_finalized", { world = world })
    set_player_turn_state("free_roam", world)
end

return PromotionSystem