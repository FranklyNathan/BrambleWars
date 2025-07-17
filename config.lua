-- config.lua
-- Contains all the global constants for the game.

local Config = {
    SQUARE_SIZE = 32,
    SLIDE_SPEED = 200,
    FLASH_DURATION = 0.2,
    BASE_CRIT_CHANCE = 0.05,
    POISON_DAMAGE_PER_TURN = 10,
    -- The size of the visible game area in pixels (24x18 tiles)
    VIRTUAL_WIDTH = 768,  -- 24 * 32
    VIRTUAL_HEIGHT = 576, -- 18 * 32
    -- The name of the map file to load from the 'maps' folder (without .lua extension)
    CURRENT_MAP_NAME = "DefaultMap",
}

return Config