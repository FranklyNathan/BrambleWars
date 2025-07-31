-- assets.lua
-- A central module for loading and managing game assets like images, sounds, and animations.

local anim8 = require("libraries.anim8")

local Assets = {
    images = {},
    animations = {},
    sounds = {},
    shaders = {},
    fonts = {}
}

-- This function should be called once in love.load()
function Assets.load()
    -- Load images
    Assets.images.Clementine = love.graphics.newImage("assets/PlayerUnits/Clementine.png")
    Assets.images.Plop = love.graphics.newImage("assets/PlayerUnits/Plop.png")
    Assets.images.Dupe = love.graphics.newImage("assets/PlayerUnits/Dupe.png")
    Assets.images.Winthrop = love.graphics.newImage("assets/PlayerUnits/Winthrop.png")
    Assets.images.Biblo = love.graphics.newImage("assets/PlayerUnits/Biblo.png")
    Assets.images.Mortimer = love.graphics.newImage("assets/PlayerUnits/Mortimer.png")
    Assets.images.Ollo = love.graphics.newImage("assets/PlayerUnits/Ollo.png")
    Assets.images.Cedric = love.graphics.newImage("assets/PlayerUnits/Cedric.png")
    Assets.images.Brawler = love.graphics.newImage("assets/brawler.png")
    Assets.images.Archer = love.graphics.newImage("assets/archer.png")
    Assets.images.Flag = love.graphics.newImage("assets/tree.png") -- For Sceptile's attack
    Assets.images.Punter = love.graphics.newImage("assets/punter.png")

    -- Load portraits
    Assets.images.Default_Portrait = love.graphics.newImage("assets/Portraits/Default_Portrait.png")

    -- Load sounds
    Assets.sounds.cursor_move = love.audio.newSource("assets/sfx/cursor_move.wav", "static")
    Assets.sounds.cursor_move:setVolume(0.4)
    Assets.sounds.menu_scroll = love.audio.newSource("assets/sfx/menu_scroll.wav", "static")
    Assets.sounds.menu_scroll:setVolume(0.7)
    Assets.sounds.back_out = love.audio.newSource("assets/sfx/back_out.wav", "static")
    Assets.sounds.menu_scroll:setVolume(0.7)
    Assets.sounds.attack_hit = love.audio.newSource("assets/sfx/attack_hit.ogg", "static")
    Assets.sounds.attack_hit:setVolume(0.6)    
    Assets.sounds.attack_miss = love.audio.newSource("assets/sfx/attack_miss.ogg", "static")
    Assets.sounds.attack_miss:setVolume(0.6)

    -- Define animation grids
    -- We assume each character sprite is 64x64 pixels per frame.
    -- The sheet has 4 animations (down, left, right, up), each in its own row.
    -- We assume each animation has 4 frames.
    local frameWidth = 64
    local frameHeight = 64
    local animSpeed = 0.15 -- A shared speed for walking animations
    
    -- Grid and animations for Drapion (drapionsquare)
    local gClementine = anim8.newGrid(frameWidth, frameHeight, Assets.images.Clementine:getWidth(), Assets.images.Clementine:getHeight())
    Assets.animations.Clementine = {
        down  = anim8.newAnimation(gClementine('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gClementine('1-4', 2), animSpeed),
        right = anim8.newAnimation(gClementine('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gClementine('1-4', 4), animSpeed)
    }

    -- Grid and animations for Venusaur (venusaursquare)
    local gWinthrop = anim8.newGrid(frameWidth, frameHeight, Assets.images.Winthrop:getWidth(), Assets.images.Winthrop:getHeight())
    Assets.animations.Winthrop = {
        down  = anim8.newAnimation(gWinthrop('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gWinthrop('1-4', 2), animSpeed),
        right = anim8.newAnimation(gWinthrop('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gWinthrop('1-4', 4), animSpeed)
    }

    -- Grid and animations for Florges (florgessquare)
    local gBiblo = anim8.newGrid(frameWidth, frameHeight, Assets.images.Biblo:getWidth(), Assets.images.Biblo:getHeight())
    Assets.animations.Biblo = {
        down  = anim8.newAnimation(gBiblo('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gBiblo('1-4', 2), animSpeed),
        right = anim8.newAnimation(gBiblo('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gBiblo('1-4', 4), animSpeed)
    }

    -- Grid and animations for Magnezone (magnezonesquare)
    local gMortimer = anim8.newGrid(frameWidth, frameHeight, Assets.images.Mortimer:getWidth(), Assets.images.Mortimer:getHeight())
    Assets.animations.Mortimer = {
        down  = anim8.newAnimation(gMortimer('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gMortimer('1-4', 2), animSpeed),
        right = anim8.newAnimation(gMortimer('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gMortimer('1-4', 4), animSpeed)
    }

    -- Grid and animations for Tangrowth (tangrowthsquare)
    local gOllo = anim8.newGrid(frameWidth, frameHeight, Assets.images.Ollo:getWidth(), Assets.images.Ollo:getHeight())
    Assets.animations.Ollo = {
        down  = anim8.newAnimation(gOllo('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gOllo('1-4', 2), animSpeed),
        right = anim8.newAnimation(gOllo('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gOllo('1-4', 4), animSpeed)
    }

    -- Grid and animations for Electivire (electiviresquare)
    local gCedric = anim8.newGrid(frameWidth, frameHeight, Assets.images.Cedric:getWidth(), Assets.images.Cedric:getHeight())
    Assets.animations.Cedric = {
        down  = anim8.newAnimation(gCedric('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gCedric('1-4', 2), animSpeed),
        right = anim8.newAnimation(gCedric('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gCedric('1-4', 4), animSpeed)
    }

    -- Grid and animations for Plop (plop)
    local gPlop = anim8.newGrid(frameWidth, frameHeight, Assets.images.Plop:getWidth(), Assets.images.Plop:getHeight())
    Assets.animations.Plop = {
        down  = anim8.newAnimation(gPlop('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gPlop('1-4', 2), animSpeed),
        right = anim8.newAnimation(gPlop('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gPlop('1-4', 4), animSpeed)
    }

    -- Grid and animations for Pidgeot (pidgeotsquare)
    local gDupe = anim8.newGrid(frameWidth, frameHeight, Assets.images.Dupe:getWidth(), Assets.images.Dupe:getHeight())
    Assets.animations.Dupe = {
        down  = anim8.newAnimation(gDupe('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gDupe('1-4', 2), animSpeed),
        right = anim8.newAnimation(gDupe('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gDupe('1-4', 4), animSpeed)
    }

    -- Grid and animations for Brawler
    local gBrawler = anim8.newGrid(frameWidth, frameHeight, Assets.images.Brawler:getWidth(), Assets.images.Brawler:getHeight())
    Assets.animations.Brawler = {
        down  = anim8.newAnimation(gBrawler('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gBrawler('1-4', 2), animSpeed),
        right = anim8.newAnimation(gBrawler('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gBrawler('1-4', 4), animSpeed)
    }

    -- Grid and animations for Archer
    local gArcher = anim8.newGrid(frameWidth, frameHeight, Assets.images.Archer:getWidth(), Assets.images.Archer:getHeight())
    Assets.animations.Archer = {
        down  = anim8.newAnimation(gArcher('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gArcher('1-4', 2), animSpeed),
        right = anim8.newAnimation(gArcher('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gArcher('1-4', 4), animSpeed)
    }

    -- Grid and animations for Punter
    local gPunter = anim8.newGrid(frameWidth, frameHeight, Assets.images.Punter:getWidth(), Assets.images.Punter:getHeight())
    Assets.animations.Punter = {
        down  = anim8.newAnimation(gPunter('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gPunter('1-4', 2), animSpeed),
        right = anim8.newAnimation(gPunter('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gPunter('1-4', 4), animSpeed)
    }

    local function load_data_files(path)
        local data = {}
        for _, file in ipairs(love.filesystem.getDirectoryItems(path)) do
            if file:sub(-4) == ".lua" then
                local name = file:sub(1, -5)
            data[name] = require(path .. name)
            end
        end
        return data
    end
    -- Load shaders, with a fallback for older systems that don't support them.
    -- We use a protected call (pcall) to safely attempt to load the shader.
    -- This is more robust than love.graphics.isSupported() as it works on older LÖVE versions.
    local success, shader_or_error = pcall(love.graphics.newShader, "assets/shaders/outline.glsl")
    if success then
        Assets.shaders.outline = shader_or_error
    else
        Assets.shaders.outline = nil
    end

    local success_solid, shader_or_error_solid = pcall(love.graphics.newShader, "assets/shaders/solid_color.glsl")
    if success_solid then
        Assets.shaders.solid_color = shader_or_error_solid
    else
        Assets.shaders.solid_color = nil
    end

    local success_grey, shader_or_error_grey = pcall(love.graphics.newShader, "assets/shaders/greyscale.glsl")
    if success_grey then
        Assets.shaders.greyscale = shader_or_error_grey
    else
        Assets.shaders.greyscale = nil
    end

    -- Load fonts required by the UI systems.
    local fontPath = "assets/Px437_DOS-V_TWN16.ttf"
    Assets.fonts.small = love.graphics.newFont(fontPath, 12)
    Assets.fonts.medium = love.graphics.newFont(fontPath, 16)
    Assets.fonts.large = love.graphics.newFont(fontPath, 20)
    Assets.fonts.title = love.graphics.newFont(fontPath, 64) -- For large headers like "Game Over"

    Assets.status_effects = load_data_files("data/status_effects/")
    -- You can add more assets here as your game grows
    -- For example:
    -- Assets.images.enemy_goblin = love.graphics.newImage("assets/goblin.png")
    -- Assets.sounds.sword_swing = love.audio.newSource("assets/sword.wav", "static")
end

return Assets