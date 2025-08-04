-- modules/draft_screen.lua
-- Contains the logic and drawing for the draft screen.

local Config = require("config")

local DraftScreen = {}

function DraftScreen.draw()
    -- Clear the screen with a background color
    love.graphics.clear(0.1, 0.1, 0.1, 1)

    -- Draw the placeholder text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Draft goes here", 0, Config.VIRTUAL_HEIGHT / 2 - 16, Config.VIRTUAL_WIDTH, "center")

    -- Draw a prompt to go back
    love.graphics.setColor(1, 1, 1, 0.6 + (math.sin(love.timer.getTime() * 2) + 1) / 2 * 0.4) -- Pulsing alpha
    love.graphics.printf("Press [Escape] to go back", 0, Config.VIRTUAL_HEIGHT / 2 + 20, Config.VIRTUAL_WIDTH, "center")
end

return DraftScreen