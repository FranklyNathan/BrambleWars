-- modules/main_menu.lua
-- Contains the logic and drawing for the main menu.

local InputHelpers = require("modules.input_helpers")
local Assets = require("modules.assets")
local Config = require("config")

local MainMenu = {}

MainMenu.state = {
    options = {
        { text = "Play", key = "play" },
        { text = "Draft", key = "draft" }
    },
    selectedIndex = 1
}

function MainMenu.handle_key_press(key)
    local menu = MainMenu.state
    if not menu or not menu.options or #menu.options == 0 then return end

    if key == "w" or key == "s" then
        local oldIndex = menu.selectedIndex
        if key == "w" then
            menu.selectedIndex = (menu.selectedIndex - 2 + #menu.options) % #menu.options + 1
        elseif key == "s" then
            menu.selectedIndex = menu.selectedIndex % #menu.options + 1
        end
        if oldIndex ~= menu.selectedIndex and Assets.sounds.menu_scroll then
            Assets.sounds.menu_scroll:stop(); Assets.sounds.menu_scroll:play()
        end
    elseif key == "j" then
        InputHelpers.play_main_menu_select_sound()
        local selectedOption = menu.options[menu.selectedIndex]
        if selectedOption.key == "play" then return "start_game"
        elseif selectedOption.key == "draft" then
            require('tests.websocket_tests')
            return "draft_mode"
        end
    end
end

-- Helper to draw a standard menu slice.
local function drawSlice(x, y, width, height, text, isSelected, font)
    -- Save the current color to prevent it from "leaking" to other draw calls.
    local r, g, b, a = love.graphics.getColor()

    -- Set background color
    if isSelected then
        love.graphics.setColor(0.95, 0.95, 0.7, 0.9) -- Cream/yellow for selected
    else
        love.graphics.setColor(0.2, 0.2, 0.1, 0.9) -- Dark brown/grey
    end
    love.graphics.rectangle("fill", x, y, width, height)

    -- Set text color
    if isSelected then
        love.graphics.setColor(0, 0, 0, 1) -- Black
    else
        love.graphics.setColor(1, 1, 1, 1) -- White
    end

    local textY = y + (height - font:getHeight()) / 2
    love.graphics.printf(text, x, textY, width, "center")

    -- Restore the original color so it doesn't affect other parts of the game.
    love.graphics.setColor(r, g, b, a)
end

function MainMenu.draw()
    -- Clear the screen to prevent artifacts from previous game states (like the draft screen).
    love.graphics.clear(0.1, 0.1, 0.1, 1)

    local originalFont = love.graphics.getFont() -- Save the original font

    local font = Assets.fonts.large or love.graphics.getFont()
    local titleFont = Assets.fonts.title or love.graphics.newFont("assets/Px437_DOS-V_TWN16.ttf", 64)

    -- Draw Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Bramble Wars", 0, Config.VIRTUAL_HEIGHT / 4, Config.VIRTUAL_WIDTH, "center")
    love.graphics.setFont(font)

    -- Menu layout
    local menuWidth = 200
    local sliceHeight = 40
    local menuHeight = #MainMenu.state.options * (sliceHeight + 10)
    local menuX = (Config.VIRTUAL_WIDTH - menuWidth) / 2
    local menuY = Config.VIRTUAL_HEIGHT / 2 - menuHeight / 2

    -- Draw options
    for i, option in ipairs(MainMenu.state.options) do
        local yPos = menuY + (i - 1) * (sliceHeight + 10)
        drawSlice(menuX, yPos, menuWidth, sliceHeight, option.text, i == MainMenu.state.selectedIndex, font)
    end

    love.graphics.setFont(originalFont) -- Restore the original font
end

return MainMenu