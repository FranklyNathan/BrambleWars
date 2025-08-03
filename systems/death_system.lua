-- death_system.lua
-- Handles all logic related to entities reaching 0 HP, triggered by events.

local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")
local EffectFactory = require("modules.effect_factory")
local RescueHandler = require("modules.rescue_handler")
local PassiveSystem = require("systems.passive_system") -- For team-swapping logic
local StatSystem = require("systems.stat_system") -- To recalculate stats on revival

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

    -- Check for on-death passives like Combustive. This should happen BEFORE revival checks.
    if victim and world and reason.type ~= "drown" then
        -- We must check the unit's blueprint/weapon directly, because the "unit_died" event
        -- may have already removed the unit from the teamPassives cache.
        local passives = WorldQueries.getUnitPassiveList(victim)
        local victimHasCombustive = false
        for _, passiveName in ipairs(passives) do
            if passiveName == "Combustive" then
                victimHasCombustive = true
                break
            end
        end

        if victimHasCombustive and not victim.components.has_exploded then
            -- The 'attacker' for the explosion should always be the unit that exploded,
            -- so any resulting kills or effects are attributed to it.
            local explosionAttacker = victim
            -- Add a flag to prevent this unit from exploding more than once.
            victim.components.has_exploded = true
            -- Trigger the explosion ripple effect.
            EffectFactory.createRippleEffect(world, explosionAttacker, "combustive_explosion", victim.x + victim.size / 2, victim.y + victim.size / 2, 1, "all")
        end
    end

    -- Handle killer-based passives like Necromantia and Devourer.
    if killer and killer.hp > 0 and victim.type ~= killer.type then
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
            -- 1. Prevent normal death processing by setting HP > 0.
            victim.hp = 1

            -- 2. Remove from old team's passive list.
            PassiveSystem.remove_unit_from_passives(victim, world)

            -- 3. Remove from old team's unit list.
            local oldTeamList = (victim.type == "player") and world.players or world.enemies
            for i = #oldTeamList, 1, -1 do
                if oldTeamList[i] == victim then table.remove(oldTeamList, i); break; end
            end

            -- 4. Switch team type and add to new team list.
            victim.type = killer.type
            local newTeamList = (victim.type == "player") and world.players or world.enemies
            table.insert(newTeamList, victim)

            -- 5. Update AI component and reset state for revival.
            if victim.type == "enemy" then victim.components.ai = {} else victim.components.ai = nil end
            victim.hasActed = true -- Unit cannot act while reviving. This will be set to false when the animation finishes.

            -- Handle Proliferate. If the killer has it, the victim's passives are overridden.
            if killerPassivesSet.Proliferate then
                victim.overriddenPassives = WorldQueries.getUnitPassiveList(killer)
            else
                victim.overriddenPassives = nil -- Ensure any previous override is cleared.
            end

            victim.statusEffects = {} -- Clear all status effects.
            
            -- 6. Add to new team's passive list and recalculate stats.
            PassiveSystem.add_unit_to_passives(victim, world)

            -- New: Cut Max HP in half for the revived unit.
            -- To prevent repeated halving, we store the pre-revival max HP once.
            if not victim.necro_base_max_hp then
                victim.necro_base_max_hp = victim.maxHp
            end
            victim.maxHp = math.floor(victim.necro_base_max_hp / 2)

            StatSystem.recalculate_for_unit(victim, world)

            -- 7. Add the reviving animation component.
            victim.components.reviving = {
                timer = 1.0, -- Duration of the animation in seconds
                initialTimer = 1.0
            }

            -- 8. Create a visual effect and skip normal death processing.
            EffectFactory.createDamagePopup(world, victim, "Revived!", false, {0.8, 0.2, 0.8, 1}) -- Magenta text
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