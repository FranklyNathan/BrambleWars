-- death_system.lua
-- Handles all logic related to entities reaching 0 HP, triggered by events.

local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")
local EffectFactory = require("modules.effect_factory")
local RescueHandler = require("modules.rescue_handler")
local PassiveSystem = require("systems.passive_system") -- For team-swapping logic
local StatSystem = require("systems.stat_system") -- To recalculate stats on revival
local Assets = require("modules.assets")
local CombatActions = require("modules.combat_actions")
local PassiveBlueprints = require("data/passive_blueprints")

local DeathSystem = {}

-- Helper function to change the player's turn state and notify other systems.
local function set_player_turn_state(newState, world)
    local oldState = world.ui.playerTurnState
    if oldState ~= newState then
        world.ui.playerTurnState = newState
        EventBus:dispatch("player_state_changed", { oldState = oldState, newState = newState, world = world })
    end
end

-- Event listener for unit deaths
EventBus:register("unit_died", function(data)
    local victim = data.victim
    local world = data.world
    local killer = data.killer
    local reason = data.reason or {} -- Default to an empty table to prevent errors.

    -- If the dying unit was carrying someone, drop them on the tile where the carrier died.
    -- This happens before the fade-out so the carried unit appears immediately.
    if victim and victim.carriedUnit then
        RescueHandler.drop(victim, victim.tileX, victim.tileY, world)
    end

    -- If a player unit dies mid-move (e.g., from a trap or drowning),
    -- ensure the visual effect on the destination tile is cleared.
    -- Also, end their turn and return control to the player to prevent getting stuck.
    if victim and victim.type == "player" and victim.components.movement_path then
        world.ui.pathing.moveDestinationEffect = nil
        victim.hasActed = true
        victim.components.movement_path = nil -- Stop any further movement.
        set_player_turn_state("free_roam", world)
    end

    -- Check for on-death passives. This should happen BEFORE revival checks.
    if victim and world and reason.type ~= "drown" then
        local passives = WorldQueries.getUnitPassiveList(victim)

        for _, passiveName in ipairs(passives) do
            local passiveData = PassiveBlueprints[passiveName]
            if passiveData and passiveData.trigger == "on_death" and not victim.components.has_exploded then
                local effectData = passiveData.on_death_effect
                if effectData and effectData.type == "ripple" then
                    -- The 'attacker' for the explosion should always be the unit that exploded.
                    victim.components.has_exploded = true -- Prevent multiple explosions.
                    EffectFactory.createRippleEffect(world, victim, effectData.attackName, victim.x + victim.size / 2, victim.y + victim.size / 2, 1, effectData.targetType)
                end
            end
        end
    end

    -- Handle killer-based passives like Necromantia and Devourer.
    if killer and killer.hp > 0 and victim.type ~= killer.type then
        -- New: If a player kills an enemy, grant Nutmegs.
        if killer.type == "player" and victim.type == "enemy" and victim.lootValue and victim.lootValue > 0 then
            world.playerInventory.nutmegs = (world.playerInventory.nutmegs or 0) + victim.lootValue
            local popupText = "+" .. victim.lootValue .. " Nutmegs"
            -- Use a gold/yellow color for the popup, appearing over the defeated enemy.
            EffectFactory.createDamagePopup(world, victim, popupText, false, {1, 0.8, 0.2, 1})
        end

        -- Create a set for efficient lookups of the killer's passives.
        local killerPassivesList = WorldQueries.getUnitPassiveList(killer)
        local killerPassivesSet = {}
        for _, passiveName in ipairs(killerPassivesList) do
            killerPassivesSet[passiveName] = true
        end

        -- Check for Devourer first. This should happen even if the unit is subsequently revived by Necromantia.
        if killerPassivesSet.Devourer then
            local victimPassives = WorldQueries.getUnitPassiveList(victim)

            if #victimPassives > 0 then
                local currentKillerPassives = WorldQueries.getUnitPassiveList(killer)
                local newPassives = {}
                local passiveExists = {}

                -- Add killer's current passives
                for _, p in ipairs(currentKillerPassives) do
                    if not passiveExists[p] then table.insert(newPassives, p); passiveExists[p] = true; end
                end

                -- Add victim's passives
                for _, p in ipairs(victimPassives) do
                    if not passiveExists[p] then table.insert(newPassives, p); passiveExists[p] = true; end
                end

                -- Update the killer's passives
                PassiveSystem.remove_unit_from_passives(killer, world)
                killer.overriddenPassives = newPassives
                PassiveSystem.add_unit_to_passives(killer, world)
                StatSystem.recalculate_for_unit(killer, world)
                EffectFactory.createDamagePopup(world, killer, "Devoured!", false, {1, 0.5, 0.2, 1}) -- Orange text
            end
        end

        -- Check for Necromantia, which prevents the unit's final death.
        if killerPassivesSet.Necromantia then
            -- Use the new helper function to handle the conversion.
            CombatActions.convertUnitAllegiance(victim, killer, world, {
                popupText = "Revived!",
                popupColor = {0.8, 0.2, 0.8, 1}, -- Magenta text
                skipDefaultHeal = false, -- We want the default full heal.
                onConvert = function(unitToConvert, newTeamOwner, wrld)
                    -- This function runs *before* stat recalculation and healing.
                    -- It contains all the Necromantia-specific logic.

                    -- Handle Proliferate. If the killer has it, the victim's passives are overridden.
                    if killerPassivesSet.Proliferate then
                        unitToConvert.overriddenPassives = WorldQueries.getUnitPassiveList(newTeamOwner)
                    else
                        unitToConvert.overriddenPassives = nil -- Ensure any previous override is cleared.
                    end

                    -- Cut Max HP in half for the revived unit, but only the first time.
                    if not unitToConvert.isUndead then
                        unitToConvert.maxHp = math.floor(unitToConvert.maxHp / 2)
                        unitToConvert.isUndead = true
                    end

                    -- Add the reviving animation component.
                    unitToConvert.components.reviving = { timer = 1.0, initialTimer = 1.0 }
                end
            })
            return
        end
    end

    if victim and victim.hp <= 0 and not victim.isMarkedForDeletion and not victim.components.fade_out then 
        -- Instead of instant deletion, start a fade-out effect.
        victim.components.fade_out = {
            timer = 1, -- The duration of the fade in seconds.
            initialTimer = 1
        }
        -- The unit will be marked for deletion by the effect_timer_system once the fade is complete.
    end
end)

return DeathSystem