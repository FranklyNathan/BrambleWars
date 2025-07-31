-- world.lua
-- The World object is the single source of truth for all entity data and collections.

local EventBus = require("modules.event_bus")
local Camera = require("modules.camera")
local Assets = require("modules.assets")
local Grid = require("modules.grid")
local StatusEffectManager = require("modules.status_effect_manager")
local EntityFactory = require("data.entities")
local ObjectBlueprints = require("data.object_blueprints")
local WeaponBlueprints = require("data.weapon_blueprints")

local World = {}
World.__index = World

function World.new(gameMap)
    local self = setmetatable({}, World)
    self.map = gameMap -- Store the loaded map data
    self.all_entities = {}
    self.players = {}
    self.enemies = {}
    self.projectiles = {}
    self.grapple_hooks = {}
    self.obstacles = {}
    self.attackEffects = {}
    self.particleEffects = {}
    self.damagePopups = {}
    self.pendingCounters = {}
    self.new_entities = {}
    self.afterimageEffects = {}
    self.rippleEffectQueue = {}
    self.ascension_shadows = {}
    self.enemyPathfindingCache = {} -- Cache for AI pathfinding data for the current turn.

    -- Player's global inventory
    self.playerInventory = {
        weapons = {} -- A table where keys are weapon blueprint keys and values are the quantity.
    }

    -- Core game state
    self.turn = "player" -- "player" or "enemy"
    self.turnCount = 1 -- To track game progression for reinforcements
    self.reinforcementTiles = {} -- To store spawn locations
    self.winTiles = {} -- To store win condition locations
    self.gameState = "gameplay" -- "gameplay", "paused", "game_over"

    -- UI and player turn state are grouped into a 'ui' sub-table for better organization.
    -- This separates the transient state of the user interface from the persistent state of the game world.
    self.ui = {
        playerTurnState = "free_roam", -- e.g., "free_roam", "unit_selected", "action_menu"
        previousPlayerTurnState = nil, -- Stores the state before entering a sub-state like 'unit_info_locked'
        selectedUnit = nil, -- The unit currently selected by the player
        mapCursorTile = {x = 0, y = 0}, -- The player's cursor on the game grid, in tile coordinates
        turnShouldEnd = false, -- Flag to defer ending the turn
        cursorInput = {
            timer = 0,
            initialDelay = 0.35, -- Time before repeat starts
            repeatDelay = 0.05,  -- Time between subsequent repeats
            activeKey = nil
        },

        -- Pathing and range display data
        pathing = {
            reachableTiles = nil, -- Tiles the selected unit can move to
            attackableTiles = nil, -- Full attack range of a selected unit
            came_from = nil, -- Pathfinding data for path reconstruction
            cost_so_far = nil, -- Pathfinding cost data
            movementPath = nil, -- List of nodes for the movement arrow
            hoverReachableTiles = nil, -- For hover previews
            hoverAttackableTiles = nil, -- For hover previews
            groundAimingGrid = nil, -- Valid tiles for ground-aiming attacks
            rangeFadeEffect = nil, -- For fading out range indicators
            moveDestinationEffect = nil, -- For the descending cursor effect
        },

        -- Targeting-specific data
        targeting = {
            selectedAttackName = nil, -- The name of the attack being targeted
            attackAoETiles = nil, -- The shape of the attack for the targeting preview
            cycle = { active = false, targets = {}, selectedIndex = 1 },
            rescue = { active = false, targets = {}, selectedIndex = 1 },
            drop = { active = false, tiles = {}, selectedIndex = 1 },
            shove = { active = false, targets = {}, selectedIndex = 1 },
            take = { active = false, targets = {}, selectedIndex = 1 },
        },

        -- Menu states
        menus = {
            action = { active = false, unit = nil, options = {}, selectedIndex = 1 },
            map = { active = false, options = {}, selectedIndex = 1 },
            battleInfo = { active = false },
            unitInfo = {
                active = false,
                unit = nil,
                rippleStartTime = 0,
                rippleSourceUnit = nil,
                isLocked = false, -- For the new locked-in inspection mode
                selectedIndex = 1
            },
            weaponSelect = {
                active = false,
                unit = nil,
                options = {},
                selectedIndex = 1,
                equippedByOther = {} -- To track weapons used by other units
            },
            enemyRangeDisplay = {
                active = false,
                unit = nil,
                reachableTiles = nil,
                attackableTiles = nil
            },
            promotion = {
                active = false,
                unit = nil,
                options = {},
                selectedIndex = 1
            },
        },

        -- For the animated stat gains on level up
        levelUpStatAnimation = {
            active = false,
            unit = nil,
            statGains = nil,
            phase = "idle", -- "showing_gains", "finished"
            timer = 0
        },

        -- For the animated EXP bar
        expGainAnimation = {
            active = false,
            state = "idle", -- "filling", "shrinking"
            unit = nil,
            expStart = 0,
            expCurrentDisplay = 0,
            expGained = 0,
            animationTimer = 0,
            animationDuration = 1.0,
            shrinkTimer = 0,
            shrinkDuration = 0.3
        }
    }

    self.roster = {}

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
        "clementine", "plop", "dupe",
        "winthrop", "biblo", "mortimer",
        "ollo", "cedric"
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
        -- 1. Collect and sort spawn points to ensure a consistent order.
        local spawnPoints = {}
        for _, spawnPoint in ipairs(self.map.layers["PlayerSpawns"].objects) do
            table.insert(spawnPoints, spawnPoint)
        end
        -- Sort by name, e.g., "SpawnTile1", "SpawnTile2", ...
        table.sort(spawnPoints, function(a, b) return a.name < b.name end)

        -- 2. Iterate through the character roster and assign them to spawn points.
        for i, playerType in ipairs(characterOrder) do
            local spawnPoint = spawnPoints[i]
            if spawnPoint and self.roster[playerType] then
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

    -- Create and place obstacles from the map's object and tile layers.
    local obstacleLayerNames = {"Obstacles", "Trees", "Walls", "Boxes"}
    for _, layerName in ipairs(obstacleLayerNames) do
        local layer = self.map.layers[layerName]
        if layer then
            if layer.type == "objectgroup" then
                for _, obj in ipairs(layer.objects) do
                    -- Tiled positions objects with GIDs from their bottom-left corner.
                    -- We must account for this difference, as rectangle objects are positioned from their top-left.
                    local objTopLeftX = obj.x
                    local objTopLeftY = obj.y
                    if obj.gid then
                        -- This is a tile object, so adjust its Y-position from bottom-left to top-left.
                        objTopLeftY = obj.y - obj.height
                    end
                    local tileX, tileY = Grid.toTile(objTopLeftX, objTopLeftY)
                    -- Recalculate pixel coordinates from tile coordinates to ensure perfect grid alignment.
                    local pixelX, pixelY = Grid.toPixels(tileX, tileY)

                    local obstacle = {
                        x = pixelX, y = pixelY,
                        tileX = tileX, tileY = tileY,
                        width = obj.width, height = obj.height, size = obj.width,
                        weight = (obj.properties and tonumber(obj.properties.weight)) or 100, isObstacle = true,
                        isImpassable = (obj.properties and obj.properties.isImpassable) or false,
                        components = {},
                        objectType = "generic" -- Default type
                    }

                    -- If the object is on a "Trees" layer, or has a Tiled type of "tree",
                    -- treat it as a destructible tree by applying the blueprint.
                    if (layerName == "Trees") or (obj.type == "tree") then
                        local blueprint = ObjectBlueprints.tree
                        if blueprint then
                            for k, v in pairs(blueprint) do obstacle[k] = v end
                            obstacle.hp = obstacle.maxHp
                            obstacle.witStat = obstacle.witStat or 0
                            obstacle.statusEffects = obstacle.statusEffects or {}
                            obstacle.objectType = "tree"
                            obstacle.sprite = Assets.images.Flag -- Assign the tree sprite
                        end
                    end
                    self:queue_add_entity(obstacle)
                end
            elseif layer.type == "tilelayer" then
                for y = 1, layer.height do
                    for x = 1, layer.width do
                        local tile = layer.data[y] and layer.data[y][x]
                        if tile then -- A tile exists here
                            local tileX, tileY = x - 1, y - 1 -- Tiled data is 1-based, our grid is 0-based
                            local pixelX, pixelY = Grid.toPixels(tileX, tileY)

                            local obstacle = {
                                x = pixelX, y = pixelY,
                                tileX = tileX, tileY = tileY,
                                width = tile.width, height = tile.height, size = tile.width,
                                isObstacle = true,
                                components = {},
                                objectType = "generic"
                            }

                            -- If the tile is on a "Trees" layer, treat it as a destructible tree.
                            if layerName == "Trees" then
                                local blueprint = ObjectBlueprints.tree
                                if blueprint then
                                    for k, v in pairs(blueprint) do obstacle[k] = v end
                                    obstacle.hp = obstacle.maxHp
                                    obstacle.witStat = obstacle.witStat or 0
                                    obstacle.statusEffects = obstacle.statusEffects or {}
                                    obstacle.objectType = "tree"
                                    obstacle.sprite = Assets.images.Flag -- Assign the tree sprite
                                end
                            end
                            self:queue_add_entity(obstacle)
                        end
                    end
                end
            end
        end
    end

    -- New: Parse reinforcement tiles from the map.
    if self.map.layers["ReinforcementTiles"] then
        local layer = self.map.layers["ReinforcementTiles"]
        if layer.type == "tilelayer" then
            for y = 1, layer.height do
                for x = 1, layer.width do
                    local tile = layer.data[y] and layer.data[y][x]
                    if tile then -- A tile exists here, marking it as a spawn point.
                        local tileX, tileY = x - 1, y - 1 -- Tiled data is 1-based, our grid is 0-based
                        table.insert(self.reinforcementTiles, {x = tileX, y = tileY})
                    end
                end
            end
        end
    end

    -- New: Parse win condition tiles from the map.
    if self.map.layers["WinTiles"] then
        local layer = self.map.layers["WinTiles"]
        if layer.type == "tilelayer" then
            for y = 1, layer.height do
                for x = 1, layer.width do
                    local tile = layer.data[y] and layer.data[y][x]
                    if tile then -- A tile exists here, marking it as a win condition point.
                        local tileX, tileY = x - 1, y - 1 -- Tiled data is 1-based, our grid is 0-based
                        table.insert(self.winTiles, {x = tileX, y = tileY})
                    end
                end
            end
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
        player.startOfMoveTileX, player.startOfMoveTileY = player.tileX, player.tileY
    end

    -- Set the initial cursor position to the first player.
    if self.players[1] then
        self.ui.mapCursorTile.x = self.players[1].tileX
        self.ui.mapCursorTile.y = self.players[1].tileY
    end

    -- Process all queued additions to ensure entities like walls and obstacles are fully loaded.
    self:process_additions_and_deletions()

    -- The player's inventory of unequipped weapons starts empty.
    -- Weapons are added to it when they are found or unequipped.
    self.playerInventory.weapons = { durendal = 1 }

    return self
end

-- Manages the transition between player and enemy turns.
function World:endTurn()
    if self.turn == "player" then
        -- Announce that the player's turn has ended so systems can react.
        EventBus:dispatch("player_turn_ended", {world = self})
        self.turn = "enemy"
        -- Clean up any lingering player selection UI state by resetting the selected unit.
        self.ui.selectedUnit = nil
        -- Reset player state so they are no longer greyed out.
        for _, player in ipairs(self.players) do
            player.hasActed = false
        end
    elseif self.turn == "enemy" then
        self.turnCount = self.turnCount + 1 -- Increment turn count at the start of the new player turn.
        for _, enemy in ipairs(self.enemies) do
            if enemy.hp > 0 then StatusEffectManager.processTurnStart(enemy, self) end
        end
        -- Announce that the enemy's turn has ended.
        EventBus:dispatch("enemy_turn_ended", {world = self})
        self.turn = "player"
        self.ui.playerTurnState = "free_roam"
        -- Reset enemy state so they are no longer greyed out.
        for _, enemy in ipairs(self.enemies) do
           enemy.hasActed = false
        end
        -- Reset player state for their upcoming turn.
        for _, player in ipairs(self.players) do
           player.hasActed = false
           -- Store the starting position for the upcoming move, in case of cancellation.
           player.startOfMoveTileX, player.startOfMoveTileY = player.tileX, player.tileY
           player.startOfMoveDirection = player.lastDirection
        end
        -- Clear the AI pathfinding cache for the next enemy turn.
        self.enemyPathfindingCache = {}

        -- At the start of the player's turn, move the cursor to the first available unit.
        for _, p in ipairs(self.players) do
            if p.hp > 0 and not p.hasActed then
                self.ui.mapCursorTile.x = p.tileX
                self.ui.mapCursorTile.y = p.tileY
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
    elseif entity.type == "grapple_hook" then
        table.insert(self.grapple_hooks, entity)
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
    elseif entity.type == "grapple_hook" then
        list = self.grapple_hooks
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