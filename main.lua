-- main.lua
-- Orchestrator for the Grid Combat game.
-- Loads all modules and runs the main game loop.

-- Load data, modules, and systems
local World = require("modules.world")
AttackBlueprints = require("data.attack_blueprints")
EnemyBlueprints = require("data.enemy_blueprints")
Config = require("config")
local Assets = require("modules.assets")
local AnimationSystem = require("systems.animation_system")
CharacterBlueprints = require("data.character_blueprints")
EntityFactory = require("data.entities")
local StatusSystem = require("systems.status_system")
local LevelUpDisplaySystem = require("systems.level_up_display_system")
local CareeningSystem = require("systems.careening_system")
local StatSystem = require("systems.stat_system")
local EffectTimerSystem = require("systems.effect_timer_system")
local ProjectileSystem = require("systems.projectile_system")
local MovementSystem = require("systems.movement_system")
local UnitInfoSystem = require("systems.unit_info_system")
local BattleInfoSystem = require("systems.battle_info_system")
local EnemyTurnSystem = require("systems.enemy_turn_system")
local TurnBasedMovementSystem = require("systems.turn_based_movement_system")
local CounterAttackSystem = require("systems.counter_attack_system")
local MoveRevertSystem = require("systems.move_revert_system")
local PassiveSystem = require("systems.passive_system")
local ActionFinalizationSystem = require("systems.action_finalization_system")
local AttackResolutionSystem = require("systems.attack_resolution_system")
local ActionMenuPreviewSystem = require("systems.action_menu_preview_system")
local AetherfallSystem = require("systems.aetherfall_system")
local GrappleHookSystem = require("systems.grapple_hook_system")
local WhiplashSystem = require("systems.whiplash_system")
local DeathSystem = require("systems.death_system")
local Renderer = require("modules.renderer") 
local BloodrushSystem = require("systems.bloodrush_system")
local HustleSystem = require("systems.hustle_system")
local HealingWindsSystem = require("systems.healing_winds_system")
local PromotionSystem = require("systems.promotion_system")
local CombatActions = require("modules.combat_actions")
local EventBus = require("modules.event_bus")
local Camera = require("modules.camera")
local WispRegenerationSystem = require("systems.wisp_regeneration_system")
local InputHandler = require("modules.input_handler")
local EnvironmentHazardSystem = require("systems.environment_hazard_system")
local TileStatusSystem = require("systems.tile_status_system")
local TileHazardSystem = require("systems.tile_hazard_system")

world = nil -- Will be initialized in love.load after assets are loaded

local canvas
local scale = 1

-- A data-driven list of systems to run in the main update loop.
-- This makes adding, removing, or reordering systems trivial.
-- The order is important: Intent -> Action -> Resolution
local update_systems = {
    -- 1. State and timer updates (timers, visual state changes)
    EffectTimerSystem,
    LevelUpDisplaySystem,

    -- 2. Movement and Animation (physical state updates)
    TurnBasedMovementSystem,
    MovementSystem,
    AnimationSystem,

    -- 3. AI and Player Actions (decision making)
    EnemyTurnSystem, -- Player actions are handled by InputHandler

    -- 4. Update ongoing effects of actions
    ProjectileSystem,
    GrappleHookSystem,
    CounterAttackSystem,
    CareeningSystem,
    AetherfallSystem,

    -- 5. Resolve the consequences of actions
    AttackResolutionSystem,

    -- 6. Finalize the turn state after all actions are resolved
    ActionFinalizationSystem,
}

-- It's good practice to put your setup logic in its own function so it can be called again for a reset.
function resetGame()
    -- This function re-initializes the game world, effectively resetting the game.
    local sti = require("libraries.sti")
    local mapPath = "maps/" .. Config.CURRENT_MAP_NAME .. ".lua"

    -- Add the same robust error checking from love.load()
    if not love.filesystem.getInfo(mapPath) then
        error("FATAL: Map file not found at '" .. mapPath .. "'. Please ensure the file exists in the 'maps' folder.")
    end
    local success, gameMap_or_error = pcall(sti, mapPath)
    if not success then
        error("FATAL: The map library 'sti' failed to load the map '" .. mapPath .. "'.\n" ..
              "This can be caused by a syntax error in the .lua map file, or an issue with the tileset image.\n" ..
              "Original error: " .. tostring(gameMap_or_error))
    end
    local gameMap = gameMap_or_error
    if not gameMap or not gameMap.width or not gameMap.tilewidth then
        error("FATAL: Map loaded, but it is not a valid map object (missing width/tilewidth). File: '" .. mapPath .. "'.")
    end
    world = World.new(gameMap)
end

function love.load()
    -- Load all game assets (images, sounds, animations). This must be done before creating the world.
    Assets.load()

    -- The world must be created AFTER assets are loaded, so entities can get their sprites and animations.
    resetGame()

    -- Load the custom font. Replace with your actual font file and its native size.
    -- For pixel fonts, using the intended size (e.g., 8, 16) is crucial for sharpness.
    local gameFont = love.graphics.newFont("assets/Px437_DOS-V_TWN16.ttf", 16)
    love.graphics.setFont(gameFont)

    canvas = love.graphics.newCanvas(Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT)
    canvas:setFilter("nearest", "nearest")

    love.graphics.setBackgroundColor(0.1, 0.1, 0.1, 1) -- Dark grey

end

function love.update(dt)
    -- Only update game logic if not paused
    if world.gameState == "gameplay" then
        -- Handle continuous input for things like holding down keys for cursor movement.
        InputHandler.handle_continuous_input(dt, world)

        -- Update the camera position based on the cursor
        Camera.update(dt, world)

        -- Update the map (for animated tiles, etc.). This is a crucial step for the 'sti' library.
        world.map:update(dt)

        -- Main system update loop
        for _, system in ipairs(update_systems) do
            if system and system.update then system.update(dt, world) end
        end

        -- Check if the turn should end, AFTER all systems have run for this frame.
        if world.ui.turnShouldEnd then
            world:endTurn()
            world.ui.turnShouldEnd = false -- Reset the flag
        end

        -- Process all entity additions and deletions that were queued by the systems.
        world:process_additions_and_deletions()

    end
end

-- love.keypressed() is called once when a key is pressed.
-- It's used to handle single, discrete actions.
function love.keypressed(key, scancode, isrepeat)
    -- We only care about the initial press, not repeats, for this handler.
    if not isrepeat then
        local newState = InputHandler.handle_key_press(key, world.gameState, world)
        if newState == "reset" then
            -- The input handler signaled a game reset.
            resetGame()
        else
            -- Otherwise, update the game state as normal.
            world.gameState = newState
        end
    end
end

function love.resize(w, h)
    -- Calculate the new scale factor to fit the virtual resolution inside the new window size, preserving aspect ratio.
    local scaleX = w / Config.VIRTUAL_WIDTH
    local scaleY = h / Config.VIRTUAL_HEIGHT
    -- By flooring the scale factor, we ensure we only scale by whole numbers (1x, 2x, 3x, etc.),
    -- which preserves a perfect pixel grid and eliminates distortion.
    -- We use math.max(1, ...) to prevent the scale from becoming 0 on very small windows.
    scale = math.max(1, math.floor(math.min(scaleX, scaleY)))
end


function love.draw()
    -- 1. Draw the entire game world to the off-screen canvas at its native resolution.
    love.graphics.setCanvas(canvas)

    -- This draws the map, entities, health bars, etc.
    Renderer.draw(world)

    love.graphics.setCanvas()

    -- 2. Draw the canvas to the screen, scaled and centered to fit the window.
    -- This creates letterboxing/pillarboxing as needed.
    local w, h = love.graphics.getDimensions()
    local canvasX = math.floor((w - Config.VIRTUAL_WIDTH * scale) / 2)
    local canvasY = math.floor((h - Config.VIRTUAL_HEIGHT * scale) / 2)

    love.graphics.draw(canvas, canvasX, canvasY, 0, scale, scale)
end

-- love.quit() is called when the game closes.
-- You can use it to save game state or clean up resources.
function love.quit()
    -- No specific cleanup needed for this simple game.
end
        