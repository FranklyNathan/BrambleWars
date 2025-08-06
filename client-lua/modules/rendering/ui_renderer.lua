-- modules/rendering/ui_renderer.lua
-- Contains all drawing logic for world-space and screen-space UI

local Grid = require("modules.grid")
local Camera = require("modules.camera")
local Assets = require("modules.assets")
local AttackBlueprints = require("data.attack_blueprints")
local WeaponBlueprints = require("data.weapon_blueprints")
local AttackPatterns = require("modules.attack_patterns")
local WorldQueries = require("modules.world_queries")
local BattleInfoMenu = require("modules.battle_info_menu")
local UnitInfoMenu = require("modules.unit_info_menu")
local PromotionMenu = require("modules.promotion_menu")
local ShopMenu = require("modules.shop_menu")

local UIRenderer = {}

-- State for animated UI elements
local current_cursor_line_width = 2

--------------------------------------------------------------------------------
-- Local Helper Functions
--------------------------------------------------------------------------------

-- Helper to pre-calculate ripple brightness for all relevant tiles around a source.
local function calculate_ripple_brightness_map(world)
    local ripple_center_unit = world.ui.menus.unitInfo.rippleSourceUnit

    local ripple_active = world.ui.playerTurnState == "free_roam" or
                          world.ui.playerTurnState == "unit_selected" or
                          world.ui.playerTurnState == "enemy_range_display"

    if not ripple_center_unit or not ripple_active then
        return nil -- No ripple to calculate
    end

    local brightness_map = {}
    local elapsedTime = love.timer.getTime() - (world.ui.menus.unitInfo.rippleStartTime or love.timer.getTime())
    local rippleRadius = (elapsedTime * 10) % (15 + 3) -- (speed) % (maxRadius + width)
    local RIPPLE_WIDTH = 3
    local MAX_BRIGHTNESS = 0.2
    
    local search_radius = 15 + RIPPLE_WIDTH
    local startX = math.max(0, ripple_center_unit.tileX - search_radius)
    local endX = math.min(world.map.width - 1, ripple_center_unit.tileX + search_radius)
    local startY = math.max(0, ripple_center_unit.tileY - search_radius)
    local endY = math.min(world.map.height - 1, ripple_center_unit.tileY + search_radius)

    for tileY = startY, endY do
        brightness_map[tileY] = {}
        for tileX = startX, endX do
            local baseDist = math.abs(tileX - ripple_center_unit.tileX) + math.abs(tileY - ripple_center_unit.tileY)
            local deltaDist = math.abs(baseDist - rippleRadius)
            if deltaDist < RIPPLE_WIDTH then
                local brightness = (1 - (deltaDist / RIPPLE_WIDTH)) * MAX_BRIGHTNESS
                brightness_map[tileY][tileX] = brightness
            end
        end
    end

    return brightness_map
end

-- Helper to draw reachable tiles, coloring them based on whether they are landable.
local function draw_reachable_tiles(tileSet, baseAlpha, world, brightness_map)
    if not tileSet then return end
    local BORDER_WIDTH = 1
    local INSET_SIZE = Config.SQUARE_SIZE - (BORDER_WIDTH * 2)

    for posKey, data in pairs(tileSet) do
        local tileX = tonumber(string.match(posKey, "(-?%d+)"))
        local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
        if tileX and tileY then
            local finalAlpha = baseAlpha
            if brightness_map and brightness_map[tileY] and brightness_map[tileY][tileX] then
                finalAlpha = finalAlpha + brightness_map[tileY][tileX]
            end

            if data.landable then
                love.graphics.setColor(0.2, 0.4, 1, math.min(1, finalAlpha)) -- Blue for landable
                local pixelX, pixelY = Grid.toPixels(tileX, tileY)
                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
            end
        end
    end
end

-- Helper to draw a set of tiles with a specific color and transparency.
local function draw_tile_set(tileSet, r, g, b, a, world, brightness_map)
    if not tileSet then return end
    local BORDER_WIDTH = 1
    local INSET_SIZE = Config.SQUARE_SIZE - (BORDER_WIDTH * 2)

    for posKey, _ in pairs(tileSet) do
        local tileX = tonumber(string.match(posKey, "(-?%d+)"))
        local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
        if tileX and tileY then
            local finalAlpha = a
            if brightness_map and brightness_map[tileY] and brightness_map[tileY][tileX] then
                finalAlpha = finalAlpha + brightness_map[tileY][tileX]
            end

            love.graphics.setColor(r, g, b, math.min(1, finalAlpha))
            local pixelX, pixelY = Grid.toPixels(tileX, tileY)
            love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
        end
    end
end

-- Helper function for wrapping long strings of text, used by the action menu.
local function wrapText(text, limit, font)
    font = font or love.graphics.getFont()
    local lines = {}
    if not text then return lines end

    local currentLine = ""
    local currentWidth = 0

    for word in string.gmatch(text, "%S+") do
        local wordWidth = font:getWidth(word)
        if currentWidth > 0 and currentWidth + font:getWidth(" ") + wordWidth > limit then
            table.insert(lines, currentLine)
            currentLine = word
            currentWidth = wordWidth
        else
            if currentLine == "" then
                currentLine = word
            else
                currentLine = currentLine .. " " .. word
            end
            currentWidth = font:getWidth(currentLine)
        end
    end
    table.insert(lines, currentLine)
    return lines
end

local function draw_weapon_select_menu(world)
    local menu = world.ui.menus.weaponSelect
    if not menu.active then return end

    local font = love.graphics.getFont()

    local menuWidth = 190
    local unitInfoMenuX = Config.VIRTUAL_WIDTH - 200 - 10
    local menuX = unitInfoMenuX - menuWidth - 10

    local sliceHeight = 22
    local headerHeight = 30
    local menuHeight = headerHeight + (#menu.options * sliceHeight)
    local menuY = 10

    love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
    love.graphics.setColor(0.8, 0.8, 0.9, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Equip Weapon", menuX, menuY + 5, menuWidth, "center")

    local yOffset = menuY + headerHeight
    for i, optionKey in ipairs(menu.options) do
        local isSelected = (i == menu.selectedIndex)
        local textY = yOffset + (sliceHeight - font:getHeight()) / 2
        local textX = menuX + 10

        if optionKey == "unequip" then
            if isSelected then
                love.graphics.setColor(0.95, 0.95, 0.7, 0.9)
                love.graphics.rectangle("fill", menuX + 1, yOffset, menuWidth - 2, sliceHeight)
                love.graphics.setColor(0, 0, 0, 1)
            else
                love.graphics.setColor(1, 1, 1, 1)
            end
            love.graphics.print("Unequip", textX, textY)
        else
            local weapon = WeaponBlueprints[optionKey]
            if weapon then
                if isSelected then
                    love.graphics.setColor(0.95, 0.95, 0.7, 0.9)
                    love.graphics.rectangle("fill", menuX + 1, yOffset, menuWidth - 2, sliceHeight)
                end

                if isSelected then love.graphics.setColor(0, 0, 0, 1) else love.graphics.setColor(1, 1, 1, 1) end

                local weaponIcon = Assets.getWeaponIcon(weapon.type)
                if weaponIcon then
                    local iconY = yOffset + (sliceHeight - weaponIcon:getHeight()) / 2
                    love.graphics.draw(weaponIcon, textX, iconY, 0, 1, 1)
                    textX = textX + weaponIcon:getWidth() + 4
                end

                love.graphics.print(weapon.name, textX, textY)

                local quantity = world.playerInventory.weapons[optionKey] or 0
                local quantityText = "x" .. quantity
                local quantityWidth = font:getWidth(quantityText)
                love.graphics.print(quantityText, menuX + menuWidth - quantityWidth - 10, textY)
            end
        end
        yOffset = yOffset + sliceHeight
    end
end

local function draw_action_menu(world)
    local menu = world.ui.menus.action
    local unit = menu.unit
    if not unit then return end

    local screenUnitX = unit.x - Camera.x
    local screenUnitY = unit.y - Camera.y
    local font = love.graphics.getFont()

    local selectedOption = menu.options[menu.selectedIndex]
    local selectedAttackData = selectedOption and AttackBlueprints[selectedOption.key]

    local menuWidth = 180
    local sliceHeight = 25
    local mainOptionsHeight = #menu.options * sliceHeight

    local powerSliceHeight = sliceHeight
    local descText = (selectedAttackData and selectedAttackData.description) or ""
    local wrappedLines = wrapText(descText, menuWidth - 20, font)
    local descLineHeight = font:getHeight() * 1.2
    local descriptionSliceHeight = 10 + 4 * descLineHeight

    local menuHeight = mainOptionsHeight + powerSliceHeight + descriptionSliceHeight
    local menuX = screenUnitX + unit.size + 5
    local menuY = screenUnitY + (unit.size / 2) - mainOptionsHeight

    if menuX + menuWidth > Config.VIRTUAL_WIDTH then menuX = screenUnitX - menuWidth - 5 end
    if menuY + menuHeight > Config.VIRTUAL_HEIGHT then menuY = Config.VIRTUAL_HEIGHT - menuHeight end
    menuX = math.max(0, menuX)
    menuY = math.max(0, menuY)

    local horizontalShift = 10

    for i, option in ipairs(menu.options) do
        local sliceX = menuX
        local sliceY = menuY + (i - 1) * sliceHeight
        local sliceColor, textColor

        local is_usable = true
        local attackData = AttackBlueprints[option.key]
        if attackData then
            if attackData.wispCost and menu.unit.wisp < attackData.wispCost then
                is_usable = false
            end
            if is_usable and attackData.targeting_style == "cycle_target" then
                local validTargets = WorldQueries.findValidTargetsForAttack(menu.unit, option.key, world)
                if #validTargets == 0 then
                    is_usable = false
                end
            end
        end

        if i == menu.selectedIndex then
            sliceX = sliceX - horizontalShift
            sliceColor = {0.95, 0.95, 0.7, 0.9}
            textColor = {0, 0, 0, 1}
        else
            sliceColor = {0.2, 0.2, 0.1, 0.9}
            textColor = {1, 1, 1, 1}
        end

        if not is_usable then
            sliceColor = {0.2, 0.2, 0.2, 0.8}
            textColor = {0.5, 0.5, 0.5, 1}
        end

        love.graphics.setColor(sliceColor)
        love.graphics.rectangle("fill", sliceX, sliceY, menuWidth, sliceHeight)

        love.graphics.setColor(textColor)
        local textY = sliceY + (sliceHeight - font:getHeight()) / 2
        love.graphics.print(option.text, sliceX + 10, textY)

        if attackData and attackData.wispCost and attackData.wispCost > 0 then
            local wispString = string.rep("♦", attackData.wispCost)
            local wispWidth = font:getWidth(wispString)
            love.graphics.setColor(textColor)
            love.graphics.print(wispString, sliceX + menuWidth - wispWidth - 10, textY)
        end
    end

    local powerSliceY = menuY + mainOptionsHeight
    local powerValueText = "--"
    if selectedAttackData then
        if selectedAttackData.displayPower then
            powerValueText = selectedAttackData.displayPower
        elseif selectedAttackData.power and selectedAttackData.power > 0 then
            powerValueText = tostring(selectedAttackData.power)
        end
    end

    love.graphics.setColor(0.2, 0.2, 0.1, 0.9)
    love.graphics.rectangle("fill", menuX, powerSliceY, menuWidth, powerSliceHeight)

    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", menuX, powerSliceY, menuWidth, 2)

    love.graphics.setColor(1, 1, 1, 1)
    local textY = powerSliceY + (powerSliceHeight - font:getHeight()) / 2
    love.graphics.print("Power", menuX + 10, textY)

    local valueWidth = font:getWidth(powerValueText)
    love.graphics.print(powerValueText, menuX + menuWidth - valueWidth - 10, textY)

    local descriptionSliceY = powerSliceY + powerSliceHeight

    love.graphics.setColor(0.2, 0.2, 0.1, 0.9)
    love.graphics.rectangle("fill", menuX, descriptionSliceY, menuWidth, descriptionSliceHeight)

    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", menuX, descriptionSliceY, menuWidth, 2)

    love.graphics.setColor(1, 1, 1, 1)
    for i, line in ipairs(wrappedLines) do
        local lineY = descriptionSliceY + 5 + (i - 1) * descLineHeight
        love.graphics.print(line, menuX + 10, lineY)
    end
end

local function draw_map_menu(world)
    local menu = world.ui.menus.map
    local cursorTile = world.ui.mapCursorTile
    local worldCursorX, worldCursorY = Grid.toPixels(cursorTile.x, cursorTile.y)
    local font = love.graphics.getFont()

    local screenCursorX = worldCursorX - Camera.x
    local screenCursorY = worldCursorY - Camera.y

    local maxTextWidth = 0
    for _, option in ipairs(menu.options) do
        maxTextWidth = math.max(maxTextWidth, font:getWidth(option.text))
    end
    local menuWidth = maxTextWidth + 20
    local menuHeight = #menu.options * 20 + 10
    local menuX = screenCursorX + Config.SQUARE_SIZE + 5
    local menuY = screenCursorY

    if menuX + menuWidth > Config.VIRTUAL_WIDTH then menuX = screenCursorX - menuWidth - 5 end
    if menuY + menuHeight > Config.VIRTUAL_HEIGHT then menuY = Config.VIRTUAL_HEIGHT - menuHeight end
    menuX = math.max(0, menuX)
    menuY = math.max(0, menuY)

    love.graphics.setColor(0.1, 0.1, 0.2, 0.8)
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
    love.graphics.setColor(0.8, 0.8, 0.9, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
    love.graphics.setLineWidth(1)

    for i, option in ipairs(menu.options) do
        local yPos = menuY + 5 + (i - 1) * 20
        if i == menu.selectedIndex then
            love.graphics.setColor(1, 1, 0, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        love.graphics.print(option.text, menuX + 10, yPos)
    end
end


function UIRenderer.drawWorldSpaceUI(world)
    -- New: Calculate the ripple brightness map once per frame.
    local brightness_map = calculate_ripple_brightness_map(world)

    -- Draw Turn-Based UI Elements (Ranges, Path, Cursor)
    local BORDER_WIDTH = 1
    local INSET_SIZE = Config.SQUARE_SIZE - (BORDER_WIDTH * 2)

    -- New: Draw pulsating WinTiles. This is drawn first so other UI elements appear on top.
    -- This should be visible during both player and enemy turns.
    if world.winTiles and #world.winTiles > 0 then
        local alpha = 0.3 + (math.sin(love.timer.getTime() * 3) + 1) / 2 * 0.3 -- Pulsates between 0.3 and 0.6 alpha
        love.graphics.setColor(0.2, 1.0, 0.2, alpha) -- Pulsating green
        for _, tile in ipairs(world.winTiles) do
            local pixelX, pixelY = Grid.toPixels(tile.x, tile.y)
            love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
        end
        love.graphics.setColor(1, 1, 1, 1) -- Reset color
    end

    -- Helper to draw the cursor's corner shapes.
    local function draw_cursor_corners(x, y, size, cornerLength, offset)
        -- Top-left
        love.graphics.line(x + offset + cornerLength, y + offset, x + offset, y + offset, x + offset, y + offset + cornerLength)
        -- Top-right
        love.graphics.line(x + size - offset - cornerLength, y + offset, x + size - offset, y + offset, x + size - offset, y + offset + cornerLength)
        -- Bottom-left
        love.graphics.line(x + offset + cornerLength, y + size - offset, x + offset, y + size - offset, x + offset, y + size - offset - cornerLength)
        -- Bottom-right
        love.graphics.line(x + size - offset - cornerLength, y + size - offset, x + size - offset, y + size - offset, x + size - offset, y + size - offset - cornerLength)
    end

    if world.gameState == "gameplay" and world.turn == "player" then
        -- Draw the action menu's attack preview
        if world.ui.menus.action.active and world.ui.menus.action.previewAttackableTiles then
            draw_tile_set(world.ui.menus.action.previewAttackableTiles, 1, 0.2, 0.2, 0.5, world, brightness_map) -- Brighter red
        end

        -- Draw the action menu's AoE preview for ground-targeted attacks
        if world.ui.menus.action.active and world.ui.menus.action.previewAoeShapes then
            love.graphics.setColor(1, 0.2, 0.2, 0.6) -- Semi-transparent red, same as ground_aiming preview
            for _, effectData in ipairs(world.ui.menus.action.previewAoeShapes) do
                local s = effectData.shape
                if s.type == "rect" then
                    love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)
                end
            end
            love.graphics.setColor(1, 1, 1, 1) -- Reset color
        end

                -- New: Draw the fading range indicators after a move is confirmed.
        if world.ui.pathing.rangeFadeEffect and world.ui.pathing.rangeFadeEffect.active then
            local effect = world.ui.pathing.rangeFadeEffect
            local progress = effect.timer / effect.initialTimer -- Fades from 1 down to 0

            -- Draw fading attackable tiles (danger zone)
            if effect.attackableTiles then
                draw_tile_set(effect.attackableTiles, 1, 0.2, 0.2, 0.3 * progress, world, brightness_map)
            end

            -- Draw fading reachable tiles (movement range)
            if effect.reachableTiles then
                draw_reachable_tiles(effect.reachableTiles, 0.6 * progress, world, brightness_map)
            end
        end

        -- 1. Draw the full attack range for the selected unit (the "danger zone").
        local showDangerZone = world.ui.playerTurnState == "unit_selected" or world.ui.playerTurnState == "ground_aiming" or world.ui.playerTurnState == "cycle_targeting"
        if showDangerZone and world.ui.pathing.attackableTiles then
            draw_tile_set(world.ui.pathing.attackableTiles, 1, 0.2, 0.2, 0.3, world, brightness_map)
        end

        -- Draw hovered unit's danger zone (fainter)
        if world.ui.menus.unitInfo.active and world.ui.pathing.hoverAttackableTiles then
            draw_tile_set(world.ui.pathing.hoverAttackableTiles, 1, 0.2, 0.2, 0.2, world, brightness_map)
        end

        -- Draw hovered unit's movement range
        if world.ui.menus.unitInfo.active and world.ui.pathing.hoverReachableTiles then
            draw_reachable_tiles(world.ui.pathing.hoverReachableTiles, 0.2, world, brightness_map)
        end

        -- 2. Draw the movement range for the selected unit. This is drawn on top of the attack range.
        if world.ui.playerTurnState == "unit_selected" and world.ui.pathing.reachableTiles then 
            draw_reachable_tiles(world.ui.pathing.reachableTiles, 0.6, world, brightness_map)
        end

        -- Draw enemy range display if active
        if world.ui.menus.enemyRangeDisplay.active then
            draw_tile_set(world.ui.menus.enemyRangeDisplay.attackableTiles, 1, 0.2, 0.2, 0.4, world, brightness_map) -- Red for attack range
            draw_reachable_tiles(world.ui.menus.enemyRangeDisplay.reachableTiles, 0.4, world, brightness_map) -- Blue/Red for movement
        end

        -- 3. Draw the movement path.
        if world.ui.playerTurnState == "unit_selected" and world.ui.pathing.movementPath and #world.ui.pathing.movementPath > 0 then
            local pathTiles = {}
            for _, node in ipairs(world.ui.pathing.movementPath) do
                local tileX, tileY = Grid.toTile(node.x, node.y)
                pathTiles[tileX .. "," .. tileY] = true
            end
            draw_tile_set(pathTiles, 1, 1, 0.5, 0.8, world, brightness_map) -- Gold color
        end

        -- Draw the move destination effect (descending cursor and glowing tile)
        if world.ui.pathing.moveDestinationEffect then
            local effect = world.ui.pathing.moveDestinationEffect
            local pixelX, pixelY = Grid.toPixels(effect.tileX, effect.tileY)
            local size = Config.SQUARE_SIZE

            if effect.state == "descending" then
                -- Animate the cursor morphing into a filled square.
                local progress = 1 - (effect.timer / effect.initialTimer) -- Goes from 0 to 1
                local cornerLength = 8

                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setLineWidth(6) -- Use the thick "locked in" line width

                if progress < 0.5 then
                    -- Phase 1: Animate outline formation. The L-shapes grow and the whole shape shrinks by 1px.
                    local outline_progress = progress / 0.5 -- This sub-progress goes from 0 to 1.

                    -- Interpolate the position and size to shrink the cursor by 1px on each side.
                    local anim_x = pixelX + 4 * outline_progress -- Shrink significantly to account for thick cursor line.
                    local anim_y = pixelY + 4 * outline_progress
                    local anim_size = size - 8 * outline_progress

                    local current_len = cornerLength + ((anim_size / 2) - cornerLength) * outline_progress

                    -- Draw the 8 elongating lines from the corners.
                    love.graphics.line(anim_x, anim_y, anim_x + current_len, anim_y) -- Top-left H
                    love.graphics.line(anim_x, anim_y, anim_x, anim_y + current_len) -- Top-left V
                    love.graphics.line(anim_x + anim_size, anim_y, anim_x + anim_size - current_len, anim_y) -- Top-right H
                    love.graphics.line(anim_x + anim_size, anim_y, anim_x + anim_size, anim_y + current_len) -- Top-right V
                    love.graphics.line(anim_x, anim_y + anim_size, anim_x + current_len, anim_y + anim_size) -- Bottom-left H
                    love.graphics.line(anim_x, anim_y + anim_size, anim_x, anim_y + anim_size - current_len) -- Bottom-left V
                    love.graphics.line(anim_x + anim_size, anim_y + anim_size, anim_x + anim_size - current_len, anim_y + anim_size) -- Bottom-right H
                    love.graphics.line(anim_x + anim_size, anim_y + anim_size, anim_x + anim_size, anim_y + anim_size - current_len) -- Bottom-right V
                else
                    -- Phase 2: The outline is now a full square. Animate the fill from the corners.
                    local fill_progress = (progress - 0.5) / 0.5 -- This sub-progress goes from 0 to 1.

                    -- The cursor is now fully shrunken to match the inset tile size.
                    local inset_x = pixelX + 4
                    local inset_y = pixelY + 4
                    local inset_size = size - 8

                    -- First, draw the complete square outline that was formed in Phase 1.
                    love.graphics.rectangle("line", inset_x, inset_y, inset_size, inset_size)

                    -- Calculate the distance the fill should travel from each edge.
                    local fill_distance = (inset_size / 2) * fill_progress

                    -- Draw four rectangles, one growing from each perimeter edge, to fill the square.
                    love.graphics.rectangle("fill", inset_x, inset_y, inset_size, fill_distance) -- Top
                    love.graphics.rectangle("fill", inset_x, inset_y + inset_size - fill_distance, inset_size, fill_distance) -- Bottom
                    love.graphics.rectangle("fill", inset_x, inset_y, fill_distance, inset_size) -- Left
                    love.graphics.rectangle("fill", inset_x + inset_size - fill_distance, inset_y, fill_distance, inset_size) -- Right
                end
                love.graphics.setLineWidth(1)
            elseif effect.state == "glowing" then
                -- Animate the tile glowing with a pulsating effect.
                local glowAlpha = 0.4 + (math.sin(love.timer.getTime() * 8) + 1) / 2 * 0.3 -- Pulsates between 0.4 and 0.7
                love.graphics.setColor(1, 1, 1, glowAlpha)
                -- Use the inset dimensions to match the final frame of the descending animation.
                local inset_x = pixelX + 1
                local inset_y = pixelY + 1
                local inset_size = size - 2
                love.graphics.rectangle("fill", inset_x, inset_y, inset_size, inset_size)
            end
        end

        -- 4. Draw the map cursor.
        if world.ui.playerTurnState == "free_roam" or world.ui.playerTurnState == "unit_selected" or
           world.ui.playerTurnState == "cycle_targeting" or world.ui.playerTurnState == "ground_aiming" or
           world.ui.playerTurnState == "enemy_range_display" or
           world.ui.playerTurnState == "rescue_targeting" or world.ui.playerTurnState == "drop_targeting" or
           world.ui.playerTurnState == "shove_targeting" or world.ui.playerTurnState == "take_targeting" or
           world.ui.playerTurnState == "secondary_targeting" or -- For Bodyguard
           world.ui.playerTurnState == "tile_cycling" or -- For Homecoming
           world.ui.playerTurnState == "burrow_teleport_selecting" -- For Burrow
           then
            -- Animate the cursor's line width for a "lock in" effect
            local target_cursor_line_width = 2 -- Normal thickness
            if world.ui.playerTurnState == "unit_selected" or world.ui.playerTurnState == "enemy_range_display" then
                target_cursor_line_width = 6 -- Thicker when a unit is selected
            end
            -- Lerp the current width towards the target width for a smooth animation
            current_cursor_line_width = current_cursor_line_width + (target_cursor_line_width - current_cursor_line_width) * 0.2

            love.graphics.setColor(1, 1, 1, 1) -- White cursor outline
            love.graphics.setLineWidth(current_cursor_line_width)
            local baseCursorPixelX, baseCursorPixelY
            if world.ui.playerTurnState == "cycle_targeting" and world.ui.targeting.cycle.active and #world.ui.targeting.cycle.targets > 0 then
                local target = world.ui.targeting.cycle.targets[world.ui.targeting.cycle.selectedIndex]
                if target then
                    if target.isTileTarget then
                        -- For tile targets, convert their tile coordinates to pixels.
                        baseCursorPixelX, baseCursorPixelY = Grid.toPixels(target.tileX, target.tileY)
                    else
                        -- For units/obstacles, use their existing pixel coordinates.
                        baseCursorPixelX, baseCursorPixelY = target.x, target.y
                    end
                else
                    baseCursorPixelX, baseCursorPixelY = Grid.toPixels(world.ui.mapCursorTile.x, world.ui.mapCursorTile.y)
                end
            else
                baseCursorPixelX, baseCursorPixelY = Grid.toPixels(world.ui.mapCursorTile.x, world.ui.mapCursorTile.y)
            end

            -- New: Hover and projected shadow logic
            local hover_offset = math.floor(-4 + math.sin(love.timer.getTime() * 4) * 2) -- Bob up and down in 1px increments
            local cursorPixelX = baseCursorPixelX
            local cursorPixelY = baseCursorPixelY + hover_offset
            local cornerLength = 8 -- A fixed length for the corner lines.
            local size = Config.SQUARE_SIZE
            local offset = 0 -- No more pulsing animation

            -- Draw the shadow on the ground tile by drawing the cursor shape in black.
            love.graphics.setColor(0, 0, 0, 0.25)
            draw_cursor_corners(baseCursorPixelX, baseCursorPixelY, size, cornerLength, offset)

            -- Draw the actual cursor itself (now hovering)
            love.graphics.setColor(1, 1, 1, 1) -- White cursor outline
            draw_cursor_corners(cursorPixelX, cursorPixelY, size, cornerLength, offset)
            love.graphics.setLineWidth(1) -- Reset line width
        end

        -- Draw the ground aiming grid (the valid area for ground-targeted attacks)
        if world.ui.playerTurnState == "ground_aiming" and world.ui.pathing.groundAimingGrid then
            draw_tile_set(world.ui.pathing.groundAimingGrid, 0.2, 0.8, 1, 0.4, world, brightness_map) -- A light, cyan-ish color
        end

        -- 5. Draw the Attack AoE preview
        if world.ui.playerTurnState == "ground_aiming" and world.ui.targeting.attackAoETiles then
            love.graphics.setColor(1, 0.2, 0.2, 0.6) -- Semi-transparent red
            for _, effectData in ipairs(world.ui.targeting.attackAoETiles) do
                local s = effectData.shape
                if s.type == "rect" then
                    love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)
                elseif s.type == "line_set" then
                    -- Could render lines here in the future if needed for previews
                end
            end
            love.graphics.setColor(1, 1, 1, 1) -- Reset color
        end

        -- 6. Draw Cycle Targeting UI (previews, etc.)
        if world.ui.playerTurnState == "cycle_targeting" and world.ui.targeting.cycle.active then
            local cycle = world.ui.targeting.cycle
            if #cycle.targets > 0 then
                local target = cycle.targets[cycle.selectedIndex]
                local attacker = world.ui.menus.action.unit
                local attackData = world.ui.targeting.selectedAttackName and AttackBlueprints[world.ui.targeting.selectedAttackName]

                if target and attacker and attackData then
                    if attackData.useType == "support" then
                        -- Draw a green overlay on the targeted ally.
                        love.graphics.setColor(0.2, 1, 0.2, 0.3) -- Semi-transparent green.
                        love.graphics.rectangle("fill", target.x + BORDER_WIDTH, target.y + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                    elseif world.ui.targeting.selectedAttackName== "phantom_step" then
                        -- Special preview for Phantom Step: show target and destination.
                        love.graphics.setColor(1, 0.2, 0.2, 0.3) -- Semi-transparent red
                        love.graphics.rectangle("fill", target.x + BORDER_WIDTH, target.y + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                        local dx, dy = 0, 0
                        if target.lastDirection == "up" then dy = 1
                        elseif target.lastDirection == "down" then dy = -1
                        elseif target.lastDirection == "left" then dx = 1
                        elseif target.lastDirection == "right" then dx = -1
                        end
                        local behindTileX, behindTileY = target.tileX + dx, target.tileY + dy
                        local behindPixelX, behindPixelY = Grid.toPixels(behindTileX, behindTileY)
                        love.graphics.setColor(0.2, 0.4, 1, 0.3) -- Semi-transparent blue
                        love.graphics.rectangle("fill", behindPixelX + BORDER_WIDTH, behindPixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                    elseif attackData.patternType and type(AttackPatterns[attackData.patternType]) == "function" then
                        -- New: Handle functional patterns like line_of_sight.
                        -- The attacker's direction is already set by the targeting system.
                        local patternFunc = AttackPatterns[attackData.patternType]
                        local attackShapes = patternFunc(attacker, world)
                        love.graphics.setColor(1, 0.2, 0.2, 0.3) -- Semi-transparent red
                        for _, effectData in ipairs(attackShapes) do
                            local s = effectData.shape
                            if s.type == "rect" then
                                love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)
                            end
                        end
                    elseif world.ui.targeting.selectedAttackName== "hookshot" then
                        -- Special preview for Hookshot: draw a line to the target.
                        love.graphics.setColor(1, 0.2, 0.2, 0.3) -- Semi-transparent red
                        local dist = math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY)

                        if attacker.tileX == target.tileX then -- Vertical line
                            local dirY = (target.tileY > attacker.tileY) and 1 or -1
                            for i = 1, dist do
                                local pixelX, pixelY = Grid.toPixels(attacker.tileX, attacker.tileY + i * dirY)
                                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                            end
                        elseif attacker.tileY == target.tileY then -- Horizontal line
                            local dirX = (target.tileX > attacker.tileX) and 1 or -1
                            for i = 1, dist do
                                local pixelX, pixelY = Grid.toPixels(attacker.tileX + i * dirX, attacker.tileY)
                                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                            end
                        end
                    elseif world.ui.targeting.selectedAttackName== "shockwave" then
                        -- Special preview for Shockwave: show the AoE around the attacker.
                        love.graphics.setColor(1, 0.2, 0.2, 0.6) -- Semi-transparent red
                        if attacker and attackData.range then
                            for dx = -attackData.range, attackData.range do
                                for dy = -attackData.range, attackData.range do
                                    if math.abs(dx) + math.abs(dy) <= attackData.range then
                                        local tileX, tileY = attacker.tileX + dx, attacker.tileY + dy
                                        local pixelX, pixelY = Grid.toPixels(tileX, tileY)
                                        love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                                    end
                                end
                            end
                        end
                    else
                        -- Default preview for all other attacks (standard melee, ranged, etc.):
                        -- Just highlight the selected target tile.
                        local pixelX, pixelY
                        if target.isTileTarget then
                            -- For tile targets, convert their tile coordinates to pixels.
                            pixelX, pixelY = Grid.toPixels(target.tileX, target.tileY)
                        else
                            -- For units/obstacles, use their existing pixel coordinates.
                            pixelX, pixelY = target.x, target.y
                        end
                        love.graphics.setColor(1, 0.2, 0.2, 0.3) -- Semi-transparent red
                        love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                    end
                end
            end
        end

        -- 7. Draw Rescue/Drop Targeting UI
        if world.ui.playerTurnState == "rescue_targeting" and world.ui.targeting.rescue.active then
            local rescue = world.ui.targeting.rescue
            -- Draw all potential targets with a base color
            love.graphics.setColor(0.2, 1, 0.2, 0.4) -- Semi-transparent green
            for _, target in ipairs(rescue.targets) do
                local pixelX, pixelY = Grid.toPixels(target.tileX, target.tileY)
                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
            end

            -- Draw the selected target with a brighter color
            if #rescue.targets > 0 then
                local selectedTarget = rescue.targets[rescue.selectedIndex]
                if selectedTarget then
                    love.graphics.setColor(0.2, 1, 0.2, 0.7) -- Brighter green
                    local pixelX, pixelY = Grid.toPixels(selectedTarget.tileX, selectedTarget.tileY)
                    love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                end
            end
        elseif world.ui.playerTurnState == "drop_targeting" and world.ui.targeting.drop.active then
            local drop = world.ui.targeting.drop
            -- Draw all potential drop tiles with a base color
            love.graphics.setColor(1, 0.8, 0.2, 0.4) -- Semi-transparent yellow/gold
            for _, tile in ipairs(drop.tiles) do
                local pixelX, pixelY = Grid.toPixels(tile.tileX, tile.tileY)
                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
            end

            -- Draw the selected tile with a brighter color
            if #drop.tiles > 0 then
                local selectedTile = drop.tiles[drop.selectedIndex]
                if selectedTile then
                    love.graphics.setColor(1, 0.8, 0.2, 0.7) -- Brighter yellow/gold
                    local pixelX, pixelY = Grid.toPixels(selectedTile.tileX, selectedTile.tileY)
                    love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                end
            end
        elseif world.ui.playerTurnState == "shove_targeting" and world.ui.targeting.shove.active then
            local shove = world.ui.targeting.shove
            -- Draw all potential targets with a base color
            love.graphics.setColor(0.2, 0.8, 1, 0.4) -- Semi-transparent cyan
            for _, target in ipairs(shove.targets) do
                local pixelX, pixelY = Grid.toPixels(target.tileX, target.tileY)
                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
            end

            -- Draw the selected target with a brighter color
            if #shove.targets > 0 then
                local selectedTarget = shove.targets[shove.selectedIndex]
                if selectedTarget then
                    -- Highlight the target itself with a bright cyan
                    love.graphics.setColor(0.2, 0.8, 1, 0.7)
                    local pixelX, pixelY = Grid.toPixels(selectedTarget.tileX, selectedTarget.tileY)
                    love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)

                    -- Also highlight the destination tile with the same color
                    local shover = world.ui.menus.action.unit
                    if shover then
                        local dx = selectedTarget.tileX - shover.tileX
                        local dy = selectedTarget.tileY - shover.tileY
                        local destTileX, destTileY = selectedTarget.tileX + dx, selectedTarget.tileY + dy
                        local destPixelX, destPixelY = Grid.toPixels(destTileX, destTileY)
                        love.graphics.rectangle("fill", destPixelX + BORDER_WIDTH, destPixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                    end
                end
            end
        elseif world.ui.playerTurnState == "take_targeting" and world.ui.targeting.take.active then
            local take = world.ui.targeting.take
            -- Draw all potential targets with a base color
            love.graphics.setColor(0.8, 0.2, 0.8, 0.4) -- Semi-transparent magenta
            for _, target in ipairs(take.targets) do
                local pixelX, pixelY = Grid.toPixels(target.tileX, target.tileY)
                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
            end

            -- Draw the selected target with a brighter color
            if #take.targets > 0 then
                local selectedTarget = take.targets[take.selectedIndex]
                if selectedTarget then
                    love.graphics.setColor(0.8, 0.2, 0.8, 0.7) -- Brighter magenta
                    local pixelX, pixelY = Grid.toPixels(selectedTarget.tileX, selectedTarget.tileY)
                    love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                end
            end
        elseif world.ui.playerTurnState == "secondary_targeting" and world.ui.targeting.secondary.active then
            local secondary = world.ui.targeting.secondary
            -- Draw all potential destination tiles with a base color.
            love.graphics.setColor(0.2, 0.8, 1, 0.4) -- Semi-transparent cyan
            for _, tile in ipairs(secondary.tiles) do
                local pixelX, pixelY = Grid.toPixels(tile.tileX, tile.tileY)
                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
            end

            -- Draw the selected tile with a brighter color.
            if #secondary.tiles > 0 then
                local selectedTile = secondary.tiles[secondary.selectedIndex]
                if selectedTile then
                    love.graphics.setColor(0.2, 0.8, 1, 0.7) -- Brighter cyan
                    local pixelX, pixelY = Grid.toPixels(selectedTile.tileX, selectedTile.tileY)
                    love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                end
            end
        elseif world.ui.playerTurnState == "tile_cycling" and world.ui.targeting.tile_cycle.active then
            local tileCycle = world.ui.targeting.tile_cycle
            -- Draw all potential destination tiles with a base color.
            love.graphics.setColor(0.2, 1.0, 0.2, 0.4) -- Semi-transparent green (like win tiles)
            for _, tile in ipairs(tileCycle.tiles) do
                local pixelX, pixelY = Grid.toPixels(tile.tileX, tile.tileY)
                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
            end

            -- Draw the selected tile with a brighter color.
            if #tileCycle.tiles > 0 then
                local selectedTile = tileCycle.tiles[tileCycle.selectedIndex]
                if selectedTile then
                    love.graphics.setColor(0.2, 1.0, 0.2, 0.7) -- Brighter green
                    local pixelX, pixelY = Grid.toPixels(selectedTile.tileX, selectedTile.tileY)
                    love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                end
            end
        end
    end
end


function UIRenderer.drawScreenSpaceUI(world)
    if world.gameState == "gameplay" then
        -- Draw Action Menu
        if world.ui.menus.action.active and not (world.ui.pathing.rangeFadeEffect and world.ui.pathing.rangeFadeEffect.active) then
            draw_action_menu(world)
        end
        -- Draw Map Menu
        if world.ui.menus.map.active then
            draw_map_menu(world)
        end
        -- Draw Battle Info Menu
        BattleInfoMenu.draw(world)
        -- Draw Unit Info Menu
        UnitInfoMenu.draw(world)
        -- Draw Weapon Select Menu
        draw_weapon_select_menu(world)
        -- Draw Promotion Menu
        PromotionMenu.draw(world)
        -- Draw Shop Menu
        ShopMenu.draw(world)
    elseif world.gameState == "paused" then
        UIRenderer.drawPauseScreen(world)
    elseif world.gameState == "game_over" then
        UIRenderer.drawGameOverScreen(world)
    end
end

    
function UIRenderer.drawGameOverScreen(world)
    -- Draw a dark, semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT)

    -- Draw "GAME OVER" text
    love.graphics.setColor(1, 0.1, 0.1, 1) -- Red
    local currentFont = love.graphics.getFont()
    -- Temporarily use a larger font for dramatic effect
    -- We create it here but don't store it, as it's only for this screen.
    local largeFont = love.graphics.newFont("assets/Px437_DOS-V_TWN16.ttf", 64)
    love.graphics.setFont(largeFont)
    love.graphics.printf("GAME OVER", 0, Config.VIRTUAL_HEIGHT / 2 - 64, Config.VIRTUAL_WIDTH, "center")

    -- Draw prompt to exit
    love.graphics.setFont(currentFont) -- Revert to the normal font
    love.graphics.setColor(1, 1, 1, 0.6 + (math.sin(love.timer.getTime() * 2) + 1) / 2 * 0.4) -- Pulsing alpha
    love.graphics.printf("Press [Escape] to Exit", 0, Config.VIRTUAL_HEIGHT / 2 + 20, Config.VIRTUAL_WIDTH, "center")
end

function UIRenderer.drawPauseScreen(world)
    -- Draw a dark, semi-transparent overlay to dim the game world but keep it visible.
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT)

    -- Draw "PAUSED" text using a large font.
    love.graphics.setColor(1, 1, 1, 1) -- White
    local currentFont = love.graphics.getFont()
    -- Use the pre-loaded title font for consistency.
    local largeFont = Assets.fonts.title or love.graphics.newFont("assets/Px437_DOS-V_TWN16.ttf", 64)
    love.graphics.setFont(largeFont)
    love.graphics.printf("PAUSED", 0, Config.VIRTUAL_HEIGHT / 2 - 64, Config.VIRTUAL_WIDTH, "center")

    -- Draw a prompt to resume the game.
    love.graphics.setFont(currentFont) -- Revert to the normal font
    love.graphics.setColor(1, 1, 1, 0.6 + (math.sin(love.timer.getTime() * 2) + 1) / 2 * 0.4) -- Pulsing alpha
    love.graphics.printf("Press [Escape] to Resume", 0, Config.VIRTUAL_HEIGHT / 2 + 20, Config.VIRTUAL_WIDTH, "center")

    -- Draw a prompt to reset the game.
    love.graphics.setColor(1, 1, 1, 0.5) -- A slightly dimmer, non-pulsing white
    love.graphics.printf("Press [L] to Reset", 0, Config.VIRTUAL_HEIGHT / 2 + 40, Config.VIRTUAL_WIDTH, "center")
end

return UIRenderer