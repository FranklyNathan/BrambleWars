-- modules/battle_info_menu.lua
-- Contains the drawing logic for the battle forecast UI.

local Camera = require("modules.camera")
local Assets = require("modules.assets")
local BattleInfoMenu = {}

function BattleInfoMenu.draw(world)
    if not world.ui.menus.battleInfo or not world.ui.menus.battleInfo.active then
        return
    end

	local menu = world.ui.menus.battleInfo
	local font = love.graphics.getFont()

	-- Define column and row dimensions
	local playerColWidth = 80
	local labelColWidth = 40
	local enemyColWidth = 80
	local rowHeight = 20 -- The height of one text row (e.g., HP, Dmg)
	local numTextRows = 5 -- Name, HP, Dmg, Hit, Crit
	local textMenuHeight = numTextRows * rowHeight

	local menuWidth = playerColWidth + labelColWidth + enemyColWidth
	-- Positioning logic: Center the menu above or below the combatants.
	local attacker = menu.attacker
	local target = menu.target
	local screenAttackerX, screenAttackerY = attacker.x - Camera.x, attacker.y - Camera.y
	local screenTargetX, screenTargetY = target.x - Camera.x, target.y - Camera.y

	-- Find the bounding box of both units.
	local topUnitY = math.min(screenAttackerY, screenTargetY)
	local bottomUnitY = math.max(screenAttackerY + attacker.size, screenTargetY + target.size)
	local horizontalCenter = (screenAttackerX + screenTargetX + target.size) / 2

	-- Decide on vertical placement.
	local spaceBelow = Config.VIRTUAL_HEIGHT - bottomUnitY
	local spaceAbove = topUnitY
	local textRowsY -- The Y coordinate for the top of the "Name" row.
	if spaceBelow > textMenuHeight + 20 or spaceBelow > spaceAbove then
		-- Place below: Align the name row below the units.
		textRowsY = bottomUnitY + 10
	else
		-- Place above: Align the name row above the units, leaving space for the text menu itself.
		textRowsY = topUnitY - textMenuHeight - 10
	end

	-- Center horizontally.
	local menuX = horizontalCenter - menuWidth / 2
	menuX = math.max(5, math.min(menuX, Config.VIRTUAL_WIDTH - menuWidth - 5))

	-- Clamp the vertical position to the screen edges.
	textRowsY = math.max(5, math.min(textRowsY, Config.VIRTUAL_HEIGHT - textMenuHeight - 5))
	
	-- Define colors and column positions
	local playerColor = {0.1, 0.1, 0.7, 0.9} -- Blue
	local labelColor = {0.2, 0.2, 0.1, 0.9} -- Brown/Gold
	local enemyColor = {0.7, 0.1, 0.1, 0.9} -- Red
	local playerColX = menuX
	local labelColX = menuX + playerColWidth
	local enemyColX = labelColX + labelColWidth

	-- Helper to safely format values for display, preventing scientific notation.
	local function format_value(val)
		if type(val) == "number" then
			return string.format("%.0f", val) -- Format as an integer string.
		end
		return tostring(val) -- Handles strings like "--" or "15!"
	end

	-- Helper to draw a single row of the forecast.
	local function draw_row(y, text1, text2, text3)
		-- Draw backgrounds
		love.graphics.setColor(playerColor)
		love.graphics.rectangle("fill", playerColX, y, playerColWidth, rowHeight)
		love.graphics.setColor(labelColor)
		love.graphics.rectangle("fill", labelColX, y, labelColWidth, rowHeight)
		love.graphics.setColor(enemyColor)
		love.graphics.rectangle("fill", enemyColX, y, enemyColWidth, rowHeight)

		-- Draw text
		love.graphics.setColor(1, 1, 1, 1) -- White text for all
		local textY = y + (rowHeight - font:getHeight()) / 2
		love.graphics.printf(text1, playerColX, textY, playerColWidth, "center")
		love.graphics.printf(text2, labelColX, textY, labelColWidth, "center")
		love.graphics.printf(text3, enemyColX, textY, enemyColWidth, "center")
	end

	-- Draw all rows
	local attackerName = menu.attacker.displayName or menu.attacker.enemyType
	local targetName = menu.target.displayName or menu.target.enemyType
	draw_row(textRowsY + rowHeight * 0, attackerName, "Vs.", targetName)
	draw_row(textRowsY + rowHeight * 1, format_value(menu.playerHP), "HP", format_value(menu.enemyHP))
	draw_row(textRowsY + rowHeight * 2, format_value(menu.playerDamage), "Dmg", format_value(menu.enemyDamage))
	draw_row(textRowsY + rowHeight * 3, format_value(menu.playerHitChance), "Hit", format_value(menu.enemyHitChance))
	draw_row(textRowsY + rowHeight * 4, format_value(menu.playerCritChance), "Crit", format_value(menu.enemyCritChance))
end

return BattleInfoMenu