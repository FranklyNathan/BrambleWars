-- modules/input_handlers/draft_screen_handler.lua
-- Handles input on the draft screen.

local Assets = require("modules.assets")
local InputHelpers = require("modules.input_helpers")

local DraftScreenHandler = {}

function DraftScreenHandler.handle_key_press(key)
    if key == "k" then -- Escape is handled globally, but this is for other potential back actions
        InputHelpers.play_back_out_sound()
        return "main_menu"
    end
end

return DraftScreenHandler