-- renderer.lua
-- Contains all drawing logic for the game.

local Grid = require("modules.grid")
local Camera = require("modules.camera")
local Assets = require("modules.assets")
local CharacterBlueprints = require("data.character_blueprints")
local AttackBlueprints = require("data.attack_blueprints")
local WeaponBlueprints = require("data.weapon_blueprints")
local AttackPatterns = require("modules.attack_patterns")
local WorldQueries = require("modules.world_queries")
local BattleInfoMenu = require("modules.battle_info_menu")
local UnitInfoMenu = require("modules.unit_info_menu")
local TileStatusBlueprints = require("data.tile_status_blueprints")
local PromotionMenu = require("modules.promotion_menu")
local ShopMenu = require("modules/shop_menu")
local EntityRenderer = require("modules.rendering.entity_renderer")
local UIRenderer = require("modules.rendering.ui_renderer")
local EffectRenderer = require("modules.rendering.effect_renderer")

local Renderer = {}

-- State for animated UI elements
local current_cursor_line_width = 2

-- New helper to draw tile statuses based on their render layer.
local function draw_tile_statuses_by_layer(world, layer)
    if not world.tileStatuses then return end

    for posKey, status in pairs(world.tileStatuses) do
        local blueprint = TileStatusBlueprints[status.type]
        if blueprint and blueprint.renderLayer == layer then
            -- Construct image name from blueprint name (e.g., "Tall Grass" -> "TallGrass")
            local imageName = string.gsub(blueprint.name, " ", "")
            local image = Assets.images[imageName]
            if image then
                local tileX = tonumber(string.match(posKey, "(-?%d+)"))
                local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
                if tileX and tileY then
                    local pixelX, pixelY = Grid.toPixels(tileX, tileY)
                    
                    local alpha = 1.0
                    -- Add a subtle pulsating alpha to make the fire feel more alive.
                    if status.type == "aflame" then
                        alpha = 0.7 + (math.sin(love.timer.getTime() * 5) + 1) / 2 * 0.2 -- Pulsates between 0.7 and 0.9
                    end

                    love.graphics.setColor(1, 1, 1, alpha)
                    love.graphics.draw(image, pixelX, pixelY, 0, 1, 1)
                end
            end
        end
    end
end

local function draw_all_entities(world)
    -- Create a single list of all units and obstacles to be drawn.
    local drawOrder = {}
    for _, p in ipairs(world.players) do
        table.insert(drawOrder, p)
    end
    for _, e in ipairs(world.enemies) do
        table.insert(drawOrder, e)
    end
    for _, n in ipairs(world.neutrals) do
        table.insert(drawOrder, n)
    end
    for _, o in ipairs(world.obstacles) do
        table.insert(drawOrder, o)
    end

    -- Sort the list by Y-coordinate. Entities lower on the screen (higher y) are drawn later (on top).
    table.sort(drawOrder, function(a, b)
        return a.y < b.y
    end)

    -- Draw all units and obstacles in the correct Z-order.
    for _, entity in ipairs(drawOrder) do
        if entity.isObstacle then
            if entity.sprite then
                local baseAlpha = 1
                if entity.components.fade_out then
                    baseAlpha = entity.components.fade_out.timer / entity.components.fade_out.initialTimer
                end
                love.graphics.setColor(1, 1, 1, baseAlpha)
                local w, h = entity.sprite:getDimensions()
                local drawX = entity.x + entity.size / 2
                local drawY = entity.y + entity.size
                love.graphics.draw(entity.sprite, drawX, drawY, 0, 1, 1, w / 2, h)
            end
        else -- It's a character
            if not (entity.components and (entity.components.ascended or entity.components.burrowed)) or (entity.components and entity.components.ascending_animation) then
                local is_active = (entity.type == "player" and entity == world.ui.selectedUnit)
                EntityRenderer.drawEntity(entity, world, is_active)
            end
        end
    end

    -- Draw health bars for combatting units on top of everything else.
    for _, entity in ipairs(drawOrder) do
        if WorldQueries.isUnitInCombat(entity, world) then
            EntityRenderer.drawAllBars(entity, world)
        end
    end
end

--------------------------------------------------------------------------------
-- MAIN DRAW FUNCTION
--------------------------------------------------------------------------------

function Renderer.draw(world)
    -- 1. Clear the screen with a background color
    love.graphics.clear(0.1, 0.1, 0.1, 1)

    -- 2. Draw the Tiled map.
    -- The 'sti' library handles its own drawing to an internal canvas and resets the graphics state.
    -- Because of this, we can't use Camera.apply() for the map itself. Instead, we must pass
    -- the camera's translation directly to the map's draw function.
    if world.map then
        world.map:draw(-math.floor(Camera.x), -math.floor(Camera.y))
    end

    -- New: Draw our manually created procedural batches. These are drawn after the main map
    -- but before other entities, effectively acting as new map layers.
    if world.proceduralBatches then
        love.graphics.setColor(1, 1, 1, 1) -- Ensure color is reset
        local camOffsetX = -math.floor(Camera.x)
        local camOffsetY = -math.floor(Camera.y)
        -- The order here determines the draw order (e.g., Water is drawn first, then Mud, then Ground).
        if world.proceduralBatches.Water then love.graphics.draw(world.proceduralBatches.Water, camOffsetX, camOffsetY) end
        if world.proceduralBatches.Mud then love.graphics.draw(world.proceduralBatches.Mud, camOffsetX, camOffsetY) end
        if world.proceduralBatches.Ground then love.graphics.draw(world.proceduralBatches.Ground, camOffsetX, camOffsetY) end
    end

    -- 3. Now, apply the camera's transformation to draw all other world-space objects
    -- (entities, UI elements like range indicators, etc.) so they are positioned correctly
    -- relative to the map.
    Camera.apply()

    -- Draw background tile statuses (e.g., Frozen)
    draw_tile_statuses_by_layer(world, "background")

    UIRenderer.drawWorldSpaceUI(world)
    EffectRenderer.drawBackground(world) -- Draw effects that should be behind entities
    draw_all_entities(world)
    EffectRenderer.drawForeground(world) -- Draw effects that should be on top of entities

    -- Draw foreground tile statuses (e.g., Aflame, Tall Grass)
    draw_tile_statuses_by_layer(world, "foreground")

    Camera.revert()

    -- 4. Draw all screen-space UI. The UIRenderer now handles all game states.
    UIRenderer.drawScreenSpaceUI(world)

    -- 5. Reset graphics state to be safe
    love.graphics.setColor(1, 1, 1, 1)
end

return Renderer