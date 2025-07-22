-- world.lua
-- The World object is the single source of truth for all entity data and collections.

local EventBus = require("modules.event_bus")
local Camera = require("modules.camera")
local Assets = require("modules.assets")
local Grid = require("modules.grid")
local StatusEffectManager = require("modules.status_effect_manager")
local EntityFactory = require("data.entities")

local World = {}
World.__index = World

function World.new(gameMap)
    local self = setmetatable({}, World)
    self.map = gameMap -- Store the loaded map data
    self.all_entities = {}
    self.players = {}
    self.enemies = {}
    self.projectiles = {}
    self.obstacles = {}
    self.attackEffects = {}
    self.particleEffects = {}
    self.damagePopups = {}
    self.liveCombatDisplays = {} -- For the new combat UI
    self.pendingCounters = {}
    self.new_entities = {}
    self.afterimageEffects = {}
    self.enemyPathfindingCache = {} -- Cache for AI pathfinding data for the current turn.

    -- Turn-based state
    self.turn = "player" -- "player" or "enemy"
    self.selectedUnit = nil -- The unit currently selected by the player
    self.playerTurnState = "free_roam" -- e.g., "free_roam", "unit_selected", "unit_moving", "action_menu", "attack_targeting", "map_menu"
    self.mapCursorTile = {x = 0, y = 0} -- The player's cursor on the game grid, in tile coordinates
    self.reachableTiles = nil -- Will hold the table of tiles the selected unit can move to
    self.came_from = nil -- Holds pathfinding data for path reconstruction
    self.movementPath = nil -- Will hold the list of nodes for the movement arrow
    self.actionMenu = { active = false, unit = nil, options = {}, selectedIndex = 1 } -- For post-move actions
    self.mapMenu = { active = false, options = {}, selectedIndex = 1 } -- For actions on empty tiles
    self.actionDescriptionMenu = { active = false, text = "" } -- For attack descriptions
    self.hoverReachableTiles = nil -- For hover previews
    self.hoverAttackableTiles = nil -- For hover previews
    self.selectedAttackName = nil -- The name of the attack being targeted
    self.attackAoETiles = nil -- The shape of the attack for the targeting preview
    self.attackableTiles = nil -- The full attack range of a selected unit
    self.groundAimingGrid = nil -- The grid of valid tiles for ground-aiming attacks
        self.cycleTargeting = { -- For abilities that cycle through targets
        active = false,
        targets = {},
        selectedIndex = 1

    }
    self.rescueTargeting = { -- For selecting a unit to rescue
        active = false,
        targets = {},
        selectedIndex = 1
    }
    self.dropTargeting = { -- For selecting a tile to drop a unit
        active = false,
        tiles = {},
        selectedIndex = 1

    }
    self.shoveTargeting = { -- For selecting a unit to shove
        active = false,
        targets = {},
        selectedIndex = 1
    }
    self.takeTargeting = { -- For selecting a unit to take from
        active = false,
        targets = {},
        selectedIndex = 1
    }
    self.enemyRangeDisplay = { -- For showing a single enemy's movement/attack range
        active = false,
        unit = nil,
        reachableTiles = nil,
        attackableTiles = nil
    }
    self.cursorInput = {
        timer = 0,
        initialDelay = 0.35, -- Time before repeat starts
        repeatDelay = 0.05,  -- Time between subsequent repeats
        activeKey = nil
    }

    self.battleInfoMenu = { active = false }
    self.unitInfoMenu = {active = false, unit = nil, rippleStartTime = 0, rippleSourceUnit = nil}
    self.turnShouldEnd = false -- New flag to defer ending the turn
    -- Game State and UI
    self.gameState = "gameplay"
    self.roster = {}
    self.characterGrid = {}
    self.cursorPos = {x = 1, y = 1}
    self.selectedSquare = nil

    -- Holds the state of active passives for each team, calculated once per frame.
    -- The boolean flags are set by the PassiveSystem and read by other systems.
    self.teamPassives = {
        player = {
            Bloodrush = {},
            HealingWinds = {},
            Whiplash = {},
            Aetherfall = {}
        },
        enemy = {
            -- Enemies can also have team-wide passives.
            Bloodrush = {},
            HealingWinds = {},
            Whiplash = {},
            Aetherfall = {}
        }
    }

    -- Define the full roster in a fixed order based on the asset load sequence.
    -- This order determines their position in the party select grid.
    local characterOrder = {
        "drapionsquare", "sceptilesquare", "pidgeotsquare",
        "venusaursquare", "florgessquare", "magnezonesquare",
        "tangrowthsquare", "electiviresquare"
    }

    -- Create all playable characters and store them in the roster.
    -- The roster holds the state of all characters (like HP), even when they are not in the active party.
    -- We create them at a default (0,0) position. Their actual starting positions
    -- will be set when they are added to the active party or swapped in.

    -- Define the starting positions for the player party (bottom-middle of the screen).
    -- Create all playable characters and store them in the roster.
    for _, playerType in ipairs(characterOrder) do
        local playerEntity = EntityFactory.createSquare(0, 0, "player", playerType)
        self.roster[playerType] = playerEntity
    end

    -- Populate the active party based on the map's "PlayerSpawns" object layer.
    if self.map.layers["PlayerSpawns"] then
        for _, spawnPoint in ipairs(self.map.layers["PlayerSpawns"].objects) do
            -- The 'name' property of the Tiled object should match the character's blueprint key.
            local playerType = spawnPoint.name
            if self.roster[playerType] then
                local playerEntity = self.roster[playerType]
                -- Tiled object coordinates are in pixels. Convert them to tile coordinates.
                local tileX, tileY = Grid.toTile(spawnPoint.x, spawnPoint.y)
                playerEntity.tileX, playerEntity.tileY = tileX, tileY
                playerEntity.x, playerEntity.y = Grid.toPixels(tileX, tileY)
                playerEntity.targetX, playerEntity.targetY = playerEntity.x, playerEntity.y
                self:_add_entity(playerEntity)
            end
        end
    end

    -- Create and place enemies based on the map's "EnemySpawns" object layer.
    if self.map.layers["EnemySpawns"] then
        for _, spawnPoint in ipairs(self.map.layers["EnemySpawns"].objects) do
            local enemyType = spawnPoint.name
            local tileX, tileY = Grid.toTile(spawnPoint.x, spawnPoint.y)
            self:_add_entity(EntityFactory.createSquare(tileX, tileY, "enemy", enemyType))
        end
    end

    -- Create and place obstacles from the map's object layers.
    -- This looks for a layer named "Obstacles" or "Trees" and makes them fully interactive.
    local obstacleLayer = self.map.layers["Obstacles"] or self.map.layers["Trees"]
    if obstacleLayer and obstacleLayer.type == "objectgroup" then
        for _, obj in ipairs(obstacleLayer.objects) do
            -- Tiled positions objects with GIDs from their bottom-left corner.
            -- We need to adjust the y-coordinate to be top-left for our game's logic.
            local objTopLeftY = obj.y - obj.height
            local tileX, tileY = Grid.toTile(obj.x, objTopLeftY)
            -- Recalculate pixel coordinates from tile coordinates to ensure perfect grid alignment.
            local pixelX, pixelY = Grid.toPixels(tileX, tileY)

            local obstacle = {
                x = pixelX,
                y = pixelY,
                tileX = tileX,
                tileY = tileY,
                width = obj.width,
                height = obj.height,
                size = obj.width, -- Assuming square obstacles for now
                weight = (obj.properties and obj.properties.weight) or "Heavy",
                components = {}, -- Ensure all entities have a components table for system compatibility.
                sprite = Assets.images.Flag, -- For now, all obstacles use the same tree sprite.
                isObstacle = true -- A flag to identify these objects as obstacles.
            }
            -- Add the obstacle to all relevant entity lists so it's recognized by all game systems.
            self:queue_add_entity(obstacle)
        end
    end

    -- Set the initial camera position based on a "CameraStart" object in the map.
    -- If not found, it will default to (0,0) and pan to the first player.
    local cameraStartX, cameraStartY = nil, nil
    -- Search for the camera start object in any object layer.
    for _, layer in ipairs(self.map.layers) do
        if layer.type == "objectgroup" and layer.objects then
            for _, obj in ipairs(layer.objects) do
                if obj.name == "CameraStart" then
                    -- Center the camera on this object's position.
                    cameraStartX = obj.x - (Config.VIRTUAL_WIDTH / 2)
                    cameraStartY = obj.y - (Config.VIRTUAL_HEIGHT / 2)
                    break -- Found it, no need to search further.
                end
            end
        end
        if cameraStartX then break end -- Exit outer loop too
    end

    if cameraStartX and cameraStartY then
        -- Clamp the initial camera position to the map boundaries.
        local mapPixelWidth = self.map.width * self.map.tilewidth
        local mapPixelHeight = self.map.height * self.map.tileheight
        Camera.x = math.max(0, math.min(cameraStartX, mapPixelWidth - Config.VIRTUAL_WIDTH))
        Camera.y = math.max(0, math.min(cameraStartY, mapPixelHeight - Config.VIRTUAL_HEIGHT))
    end

    -- Manually initialize start-of-turn positions for the very first turn.
    -- This ensures the "undo move" feature works from the start.
    for _, player in ipairs(self.players) do
        player.startOfTurnTileX, player.startOfTurnTileY = player.tileX, player.tileY
    end

    -- Set the initial cursor position to the first player.
    if self.players[1] then
        self.mapCursorTile.x = self.players[1].tileX
        self.mapCursorTile.y = self.players[1].tileY
    end

    -- Populate the 3x3 character selection grid based on the fixed order.
    local gridX, gridY = 1, 1
    for _, playerType in ipairs(characterOrder) do
        -- Ensure the row exists before trying to add to it.
        if not self.characterGrid[gridY] then self.characterGrid[gridY] = {} end

        self.characterGrid[gridY][gridX] = playerType
        gridX = gridX + 1
        if gridX > 3 then
            gridX = 1
            gridY = gridY + 1
        end
    end

    return self
end

-- Manages the transition between player and enemy turns.
function World:endTurn()
    if self.turn == "player" then
        -- Announce that the player's turn has ended so systems can react.
        EventBus:dispatch("player_turn_ended", {world = self})
        self.turn = "enemy"
        -- Clean up any lingering player selection UI state.
        self.selectedUnit = nil
        -- Reset player state so they are no longer greyed out.
        for _, player in ipairs(self.players) do
            player.hasActed = false
        end
    elseif self.turn == "enemy" then
        for _, enemy in ipairs(self.enemies) do
            if enemy.hp > 0 then StatusEffectManager.processTurnStart(enemy, self) end
        end
        -- Announce that the enemy's turn has ended.
        EventBus:dispatch("enemy_turn_ended", {world = self})
        self.turn = "player"
        self.playerTurnState = "free_roam"
        -- Reset enemy state so they are no longer greyed out.
        for _, enemy in ipairs(self.enemies) do
           enemy.hasActed = false
        end
        -- Reset player state for their upcoming turn.
        for _, player in ipairs(self.players) do
           player.hasActed = false
           -- Store the starting position for this turn, in case of move cancellation.
           player.startOfTurnTileX, player.startOfTurnTileY = player.tileX, player.tileY
        end
        -- Clear the AI pathfinding cache for the next enemy turn.
        self.enemyPathfindingCache = {}

        -- At the start of the player's turn, move the cursor to the first available unit.
        for _, p in ipairs(self.players) do
            if p.hp > 0 and not p.hasActed then
                self.mapCursorTile.x = p.tileX
                self.mapCursorTile.y = p.tileY
                break -- Found the first one, stop searching.
            end
        end
    end
end

-- Queues a new entity to be added at the end of the frame.
function World:queue_add_entity(entity)
    if not entity then return end
    table.insert(self.new_entities, entity)
end

-- Adds an entity to all relevant lists.
function World:_add_entity(entity)
    if not entity then return end
    -- When an entity is added, it should not be marked for deletion.
    -- This cleans up state from previous removals (e.g. a dead character from the roster being re-added)
    -- and prevents duplication bugs during party swaps.
    entity.isMarkedForDeletion = nil
    -- Ensure all entities have a components table for system compatibility.
    -- This is a safety net for entities created without one.
    if not entity.components then
        entity.components = {}
    end

    -- Initialize properties for the rescue system, if it's a unit.
    -- This ensures all units have these fields when they are first added or re-added.
    if entity.type == "player" or entity.type == "enemy" then
        -- baseWeight should be set once from the blueprint's weight.
        if entity.weight and not entity.baseWeight then
            entity.baseWeight = entity.weight
        end
        entity.carriedUnit = entity.carriedUnit or nil
        entity.rescuePenalty = entity.rescuePenalty or 0
        entity.isCarried = entity.isCarried or false
    end

    table.insert(self.all_entities, entity)
    if entity.type == "player" then
        table.insert(self.players, entity)
    elseif entity.type == "enemy" then
        table.insert(self.enemies, entity)
    elseif entity.type == "projectile" then
        table.insert(self.projectiles, entity)
    elseif entity.isObstacle then
        table.insert(self.obstacles, entity)
    end

    -- Dispatch event so systems can react to the new entity.
    EventBus:dispatch("unit_added", { unit = entity, world = self })
end

-- Removes an entity from its specific list.
function World:_remove_from_specific_list(entity)
    local list
    if entity.type == "player" then
        list = self.players
    elseif entity.type == "enemy" then
        list = self.enemies
    elseif entity.type == "projectile" then
        list = self.projectiles
    elseif entity.isObstacle then
        list = self.obstacles
    end

    if list then
        for i = #list, 1, -1 do
            if list[i] == entity then
                table.remove(list, i)
                return
            end
        end
    end
end

-- Processes all additions and deletions at the end of the frame.
function World:process_additions_and_deletions()
    -- Process deletions first
    for i = #self.all_entities, 1, -1 do
        local entity = self.all_entities[i]
        if entity.isMarkedForDeletion then
            self:_remove_from_specific_list(entity)
            table.remove(self.all_entities, i)
        end
    end

    -- Process additions
    for _, entity in ipairs(self.new_entities) do
        self:_add_entity(entity)
    end
    self.new_entities = {} -- Clear the queue
end

return World