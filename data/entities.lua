-- entities.lua
-- Contains functions for creating game entities.
-- It relies on the global Config, CharacterBlueprints, and EnemyBlueprints tables.

local Assets = require("modules.assets")
local Grid = require("modules.grid")
local Config = require("config")
local CharacterBlueprints = require("data.character_blueprints")
local EnemyBlueprints = require("data.enemy_blueprints")
local LevelUpSystem = require("systems.level_up_system")

local EntityFactory = {}

-- The 'options' table can be used to pass in extra creation data, like a specific level for an enemy.
function EntityFactory.createSquare(startTileX, startTileY, type, subType, options)
    local square = {}
    -- Core grid position (for game logic)
    square.tileX = startTileX
    square.tileY = startTileY
    -- Visual pixel position (for rendering and smooth movement)
    square.x, square.y = Grid.toPixels(startTileX, startTileY)
    square.size = Config.SQUARE_SIZE
    square.speed = Config.SLIDE_SPEED
    square.type = type or "player" -- "player" or "enemy"
    square.lastDirection = "down" -- Default starting direction
    square.components = {} -- All components will be stored here
    square.hasActed = false -- For turn-based logic
    square.components.move_is_committed = false -- New flag to prevent undoing a move.

    -- Set properties based on type/subType
    if square.type == "player" then
        square.playerType = subType -- e.g., "drapionsquare"
        local blueprint = CharacterBlueprints[subType]
        -- The 'color' property is now used for effects like the death shatter.
        -- We'll set it to the character's dominant color for visual consistency.
        square.color = {blueprint.dominantColor[1], blueprint.dominantColor[2], blueprint.dominantColor[3], 1}
        square.isFlying = blueprint.isFlying or false -- Add the flying trait to the entity
        square.species = blueprint.species
        square.canSwim = blueprint.canSwim or false -- Add the swimming trait to the entity
        square.weight = blueprint.weight or 1 -- Default to a light weight
        square.movement = blueprint.movement or 5 -- Default movement range in tiles
        square.originType = blueprint.originType
        square.maxHp = blueprint.maxHp
        square.attackStat = blueprint.attackStat
        square.defenseStat = blueprint.defenseStat
        square.magicStat = blueprint.magicStat
        square.resistanceStat = blueprint.resistanceStat
        square.witStat = blueprint.witStat
        square.maxWisp = blueprint.wispStat        
        -- A shallow copy is sufficient here since weapon names are strings.
        -- This prevents all instances of a character type from sharing the same weapon table.
        square.equippedWeapons = {}
        if blueprint.equippedWeapons then
            for slot, weaponName in pairs(blueprint.equippedWeapons) do
                square.equippedWeapons[slot] = weaponName
            end
        end
        square.attacks = blueprint.attacks
        square.displayName = blueprint.displayName -- Use display name from blueprint
        square.class = blueprint.class
        square.level = 1
        square.exp = 0
        square.maxExp = 100
        square.growths = blueprint.growths
        square.portrait = blueprint.portrait or "Default_Portrait"

        -- A mapping from the internal player type to the asset name for scalability.
        local playerSpriteMap = {
            clementine = "Clementine",
            biblo = "Biblo",
            winthrop = "Winthrop",
            mortimer = "Mortimer",
            cedric = "Cedric",
            ollo = "Ollo",
            plop = "Plop",
            dupe = "Dupe"
        }

        local spriteName = playerSpriteMap[subType]
        if spriteName and Assets.animations[spriteName] then
            square.components.animation = {
                animations = {
                    down = Assets.animations[spriteName].down:clone(),
                    left = Assets.animations[spriteName].left:clone(),
                    right = Assets.animations[spriteName].right:clone(),
                    up = Assets.animations[spriteName].up:clone()
                },
                current = "down",
                spriteSheet = Assets.images[spriteName]
            }
        end
        square.speedMultiplier = 1 -- For special movement speeds like dashes
        square.inventory = {} -- For future item system
    elseif square.type == "enemy" then
        square.enemyType = subType -- e.g., "standard"
        local blueprint = EnemyBlueprints[subType]
        square.color = {blueprint.dominantColor[1], blueprint.dominantColor[2], blueprint.dominantColor[3], 1}
        square.originType = blueprint.originType
        square.maxHp = blueprint.maxHp
        square.attackStat = blueprint.attackStat
        square.defenseStat = blueprint.defenseStat
        square.magicStat = blueprint.magicStat
        square.resistanceStat = blueprint.resistanceStat
        square.witStat = blueprint.witStat
        square.maxWisp = blueprint.wispStat
        square.class = blueprint.class        
        -- A shallow copy is sufficient here since weapon names are strings.
        square.equippedWeapons = {}
        if blueprint.equippedWeapons then
            for slot, weaponName in pairs(blueprint.equippedWeapons) do
                square.equippedWeapons[slot] = weaponName
            end
        end
        square.movement = blueprint.movement or 5 -- Default movement range in tiles
        square.weight = blueprint.weight
        square.attacks = blueprint.attacks
        square.lootValue = blueprint.lootValue or 0
        square.level = (options and options.level) or 1
        square.growths = blueprint.growths
        square.expReward = blueprint.expReward
        square.portrait = blueprint.portrait or "Default_Portrait"

        -- Apply level-up stat gains for enemies starting at > Lvl 1
        if square.level > 1 then
            for i = 2, square.level do
                LevelUpSystem.applyInstantLevelUp(square)
            end
        end

        -- Add animation component for enemies
        local enemySpriteMap = {
            brawler = "Brawler",
            archer = "Archer",
            punter = "Punter"
        }

        local spriteName = enemySpriteMap[subType]
        if spriteName and Assets.animations[spriteName] then
            square.components.animation = {
                animations = {
                    down = Assets.animations[spriteName].down:clone(),
                    left = Assets.animations[spriteName].left:clone(),
                    right = Assets.animations[spriteName].right:clone(),
                    up = Assets.animations[spriteName].up:clone()
                },
                current = "down",
                spriteSheet = Assets.images[spriteName]
            }
        end
    elseif square.type == "neutral" then
        -- Neutral units like the Shopkeep use CharacterBlueprints.
        square.playerType = subType -- e.g., "shopkeep"
        local blueprint = CharacterBlueprints[subType]
        square.color = {blueprint.dominantColor[1], blueprint.dominantColor[2], blueprint.dominantColor[3], 1}
        square.species = blueprint.species
        square.originType = blueprint.originType
        square.maxHp = blueprint.maxHp
        square.attackStat = blueprint.attackStat
        square.defenseStat = blueprint.defenseStat
        square.magicStat = blueprint.magicStat
        square.resistanceStat = blueprint.resistanceStat
        square.witStat = blueprint.witStat
        square.maxWisp = blueprint.wispStat
        square.movement = blueprint.movement
        square.weight = blueprint.weight
        square.equippedWeapons = {}
        if blueprint.equippedWeapons then
            for slot, weaponName in pairs(blueprint.equippedWeapons) do
                square.equippedWeapons[slot] = weaponName
            end
        end
        square.attacks = blueprint.attacks
        square.displayName = blueprint.displayName
        square.class = blueprint.class
        square.portrait = blueprint.portrait or "Default_Portrait"
        square.shopInventory = blueprint.shopInventory or {}

        -- A mapping from the internal neutral type to the asset name.
        local neutralSpriteMap = {
            shopkeep = "Shopkeep"
        }

        local spriteName = neutralSpriteMap[subType]
        if spriteName and Assets.animations[spriteName] then
            square.components.animation = {
                animations = {down = Assets.animations[spriteName].down:clone(), left = Assets.animations[spriteName].left:clone(), right = Assets.animations[spriteName].right:clone(), up = Assets.animations[spriteName].up:clone()},
                current = "down",
                spriteSheet = Assets.images[spriteName]
            }
        end
    end

    square.hp = square.maxHp -- All squares start with full HP
    square.wisp = square.maxWisp -- Start with full wisp

    -- A scalable way to handle status effects
    square.statusEffects = {}

    -- Add an AI component to enemies
    if square.type == "enemy" then
        square.components.ai = {}
    end

    -- Initialize current and target positions
    square.targetX = square.x
    square.targetY = square.y

    return square
end

function EntityFactory.createProjectile(x, y, direction, attacker, attackName, power, isEnemy, statusEffect, isPiercing, attackInstanceId)
    local projectile = {}
    projectile.x = x
    projectile.y = y
    projectile.size = Config.SQUARE_SIZE
    projectile.type = "projectile" -- A new type for rendering/filtering

    projectile.components = {}
    projectile.components.projectile = {
        direction = direction,
        moveStep = Config.SQUARE_SIZE,
        moveDelay = 0.05,
        timer = 0.05,
        attacker = attacker,
        attackName = attackName,
        power = power,
        isEnemyProjectile = isEnemy,
        statusEffect = statusEffect,
        isPiercing = isPiercing or false, -- Add the piercing flag
        hitTargets = {}, -- Keep track of who has been hit to prevent multi-hits
        attackInstanceId = attackInstanceId
    }

    -- Projectiles don't need a full renderable component yet,
    -- as the renderer has a special loop for them.

    return projectile
end

function EntityFactory.createGrappleHook(attacker, power, range)
    local hook = {}
    hook.x = attacker.x
    hook.y = attacker.y
    hook.size = Config.SQUARE_SIZE / 2 -- Make it smaller than a full tile
    hook.type = "grapple_hook" -- A new type for specific systems
    hook.color = {1, 0.4, 0.7, 1} -- Pink

    hook.components = {}
    hook.components.grapple_hook = {
        attacker = attacker,
        power = power,
        direction = attacker.lastDirection,
        speed = Config.SLIDE_SPEED * 4, -- Very fast
        maxDistance = (range or 7) * Config.SQUARE_SIZE,
        distanceTraveled = 0,
        state = "firing" -- "firing", "retracting", "hit"
    }

    return hook
end

return EntityFactory