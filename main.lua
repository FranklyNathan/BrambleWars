-- main.lua
-- Orchestrator for the Grid Combat game.
-- Loads all modules and runs the main game loop.

-- Load data, modules, and systems
local World = require("modules.world")
AttackBlueprints = require("data/attack_blueprints")
EnemyBlueprints = require("data.enemy_blueprints")
Config = require("config")
local Assets = require("modules.assets")
local AnimationSystem = require("systems/animation_system")
CharacterBlueprints = require("data.character_blueprints")
EntityFactory = require("data.entities")
local StatusSystem = require("systems.status_system")
local CareeningSystem = require("systems.careening_system")
local StatSystem = require("systems.stat_system")
local EffectTimerSystem = require("systems.effect_timer_system")
local ProjectileSystem = require("systems.projectile_system")
local MovementSystem = require("systems/movement_system")
local UnitInfoSystem = require("systems.unit_info_system")
local BattleInfoSystem = require("systems/battle_info_system")
local EnemyTurnSystem = require("systems/enemy_turn_system")
local TurnBasedMovementSystem = require("systems/turn_based_movement_system")
local CounterAttackSystem = require("systems.counter_attack_system")
local PassiveSystem = require("systems.passive_system")
local ActionFinalizationSystem = require("systems/action_finalization_system")
local AttackResolutionSystem = require("systems.attack_resolution_system")
local ActionMenuPreviewSystem = require("systems.action_menu_preview_system")
local RescueAnimationSystem = require("systems/rescue_animation_system")
local AetherfallSystem = require("systems.aetherfall_system")
local GrappleHookSystem = require("systems/grapple_hook_system")
local DeathSystem = require("systems.death_system")
local Renderer = require("modules/renderer") 
local BloodrushSystem = require("systems.bloodrush_system")
local CombatActions = require("modules/combat_actions")
local EventBus = require("modules/event_bus")
local Camera = require("modules.camera")
local WispRegenerationSystem = require("systems/wisp_regeneration_system")
local InputHandler = require("modules/input_handler")

world = nil -- Will be initialized in love.load after assets are loaded
GameFont = nil -- Will hold our loaded font

local canvas
local scale = 1

-- A data-driven list of systems to run in the main update loop.
-- This makes adding, removing, or reordering systems trivial.
-- The order is important: Intent -> Action -> Resolution
local update_systems = {
    -- 1. State and timer updates
    StatSystem,
    EffectTimerSystem,
    PassiveSystem,
    UnitInfoSystem,
    BattleInfoSystem,
    ActionMenuPreviewSystem,
    -- 2. Movement and Animation (update physical state)
    TurnBasedMovementSystem,
    MovementSystem,
    AnimationSystem,
    RescueAnimationSystem,
    -- 3. AI and Player Actions (decide what to do)
    EnemyTurnSystem,
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

-- love.load() is called once when the game starts.
-- It's used to initialize game variables and load assets.
function love.load()
    sti = require'libraries.sti' -- Load the Simple Tiled Implementation library for maps
    love.graphics.setDefaultFilter("nearest", "nearest") -- Ensures crisp scaling

    -- Load all game assets (images, animations, sounds)
    Assets.load()

    -- Load the map specified in the config file.
    local mapPath = "maps/" .. Config.CURRENT_MAP_NAME .. ".lua"

    -- Add more specific checks to help diagnose loading issues.
    if not love.filesystem.getInfo(mapPath) then
        error("FATAL: Map file not found at '" .. mapPath .. "'. Please ensure the file exists in the 'maps' folder.")
    end

    -- This check is specific to DefaultMap.lua. If you change maps, you might need to update this.
    if not love.filesystem.getInfo("maps/PokeTiles.png") then
        error("FATAL: Tileset 'PokeTiles.png' not found in the 'maps' folder. The map '" .. Config.CURRENT_MAP_NAME .. "' requires it to load.")
    end

    -- Use pcall to safely load the map and get a detailed error message if it fails
    local success, gameMap_or_error = pcall(sti, mapPath)
    if not success then
        error("FATAL: The map library 'sti' failed to load the map '" .. mapPath .. "'.\n" ..
              "This can be caused by a syntax error in the .lua map file, or an issue with the tileset image.\n" ..
              "Original error: " .. tostring(gameMap_or_error))
    end
    local gameMap = gameMap_or_error

    -- Add a final check to ensure the map object is valid.
    if not gameMap or not gameMap.width or not gameMap.tilewidth then
        error("FATAL: Map loaded, but it is not a valid map object (missing width/tilewidth). File: '" .. mapPath .. "'.")
    end

    -- The world must be created AFTER assets are loaded, so entities can get their sprites.
    world = World.new(gameMap)

    -- Load the custom font. Replace with your actual font file and its native size.
    -- For pixel fonts, using the intended size (e.g., 8, 16) is crucial for sharpness.
    GameFont = love.graphics.newFont("assets/Px437_DOS-V_TWN16.ttf", 16)

    love.graphics.setFont(GameFont)

    canvas = love.graphics.newCanvas(Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT)
    canvas:setFilter("nearest", "nearest")

    -- Initialize factories and modules that need a reference to the world
    local EffectFactory = require("modules.effect_factory")
    EffectFactory.init(world)

    -- Set the background color
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1, 1) -- Dark grey

end

-- love.update(dt) is called every frame.
-- dt is the time elapsed since the last frame (delta time).
-- It's used for game logic, such as updating player positions and attacks.
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
        if world.turnShouldEnd then
            world:endTurn()
            world.turnShouldEnd = false -- Reset the flag
        end

        -- Process all entity additions and deletions that were queued by the systems.
        world:process_additions_and_deletions()

    elseif world.gameState == "party_select" then
        -- When paused, we want all character sprites on the select screen to animate.
        -- We loop through the entire roster and update their 'down' animation specifically.
        for _, entity in pairs(world.roster) do
            if entity and entity.components.animation then
                local downAnim = entity.components.animation.animations.down
                downAnim:resume() -- Ensure the animation is playing before updating it.
                downAnim:update(dt)
            end
        end
    end -- End of if world.gameState == "gameplay"
end

-- love.keypressed(key) is used for discrete actions, like switching players or attacking.
function love.keypressed(key)
    -- Pass the current state to the handler and get the new state back.
    world.gameState = InputHandler.handle_key_press(key, world.gameState, world)
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
        
