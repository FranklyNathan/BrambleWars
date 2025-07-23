-- assets.lua
-- A central module for loading and managing game assets like images, sounds, and animations.

local anim8 = require("libraries.anim8")

local Assets = {
    images = {},
    animations = {},
    sounds = {},
    shaders = {}
}

-- This function should be called once in love.load()
function Assets.load()
    -- Load images
    Assets.images.Drapion = love.graphics.newImage("assets/Drapion.png")
    Assets.images.Sceptile = love.graphics.newImage("assets/Sceptile.png")
    Assets.images.Pidgeot = love.graphics.newImage("assets/Pidgeot.png")
    Assets.images.Venusaur = love.graphics.newImage("assets/Venusaur.png")
    Assets.images.Florges = love.graphics.newImage("assets/Florges.png")
    Assets.images.Magnezone = love.graphics.newImage("assets/Magnezone.png")
    Assets.images.Tangrowth = love.graphics.newImage("assets/Tangrowth.png")
    Assets.images.Electivire = love.graphics.newImage("assets/Electivire.png")
    Assets.images.Brawler = love.graphics.newImage("assets/brawler.png")
    Assets.images.Archer = love.graphics.newImage("assets/archer.png")
    Assets.images.Flag = love.graphics.newImage("assets/tree.png") -- For Sceptile's attack
    Assets.images.Punter = love.graphics.newImage("assets/punter.png")

    -- Load portraits
    Assets.images.Default_Portrait = love.graphics.newImage("assets/Portraits/Default_Portrait.png")
    Assets.images.Sceptile_Portrait = love.graphics.newImage("assets/Portraits/Sceptile_Portrait.png")
    Assets.images.Rapidash_Portrait = love.graphics.newImage("assets/Portraits/Rapidash_Portrait.png")

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
    local gDrapion = anim8.newGrid(frameWidth, frameHeight, Assets.images.Drapion:getWidth(), Assets.images.Drapion:getHeight())
    Assets.animations.Drapion = {
        down  = anim8.newAnimation(gDrapion('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gDrapion('1-4', 2), animSpeed),
        right = anim8.newAnimation(gDrapion('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gDrapion('1-4', 4), animSpeed)
    }

    -- Grid and animations for Venusaur (venusaursquare)
    local gVenusaur = anim8.newGrid(frameWidth, frameHeight, Assets.images.Venusaur:getWidth(), Assets.images.Venusaur:getHeight())
    Assets.animations.Venusaur = {
        down  = anim8.newAnimation(gVenusaur('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gVenusaur('1-4', 2), animSpeed),
        right = anim8.newAnimation(gVenusaur('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gVenusaur('1-4', 4), animSpeed)
    }

    -- Grid and animations for Florges (florgessquare)
    local gFlorges = anim8.newGrid(frameWidth, frameHeight, Assets.images.Florges:getWidth(), Assets.images.Florges:getHeight())
    Assets.animations.Florges = {
        down  = anim8.newAnimation(gFlorges('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gFlorges('1-4', 2), animSpeed),
        right = anim8.newAnimation(gFlorges('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gFlorges('1-4', 4), animSpeed)
    }

    -- Grid and animations for Magnezone (magnezonesquare)
    local gMagnezone = anim8.newGrid(frameWidth, frameHeight, Assets.images.Magnezone:getWidth(), Assets.images.Magnezone:getHeight())
    Assets.animations.Magnezone = {
        down  = anim8.newAnimation(gMagnezone('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gMagnezone('1-4', 2), animSpeed),
        right = anim8.newAnimation(gMagnezone('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gMagnezone('1-4', 4), animSpeed)
    }

    -- Grid and animations for Tangrowth (tangrowthsquare)
    local gTangrowth = anim8.newGrid(frameWidth, frameHeight, Assets.images.Tangrowth:getWidth(), Assets.images.Tangrowth:getHeight())
    Assets.animations.Tangrowth = {
        down  = anim8.newAnimation(gTangrowth('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gTangrowth('1-4', 2), animSpeed),
        right = anim8.newAnimation(gTangrowth('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gTangrowth('1-4', 4), animSpeed)
    }

    -- Grid and animations for Electivire (electiviresquare)
    local gElectivire = anim8.newGrid(frameWidth, frameHeight, Assets.images.Electivire:getWidth(), Assets.images.Electivire:getHeight())
    Assets.animations.Electivire = {
        down  = anim8.newAnimation(gElectivire('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gElectivire('1-4', 2), animSpeed),
        right = anim8.newAnimation(gElectivire('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gElectivire('1-4', 4), animSpeed)
    }

    -- Grid and animations for Sceptile (sceptilesquare)
    local gSceptile = anim8.newGrid(frameWidth, frameHeight, Assets.images.Sceptile:getWidth(), Assets.images.Sceptile:getHeight())
    Assets.animations.Sceptile = {
        down  = anim8.newAnimation(gSceptile('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gSceptile('1-4', 2), animSpeed),
        right = anim8.newAnimation(gSceptile('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gSceptile('1-4', 4), animSpeed)
    }

    -- Grid and animations for Pidgeot (pidgeotsquare)
    local gPidgeot = anim8.newGrid(frameWidth, frameHeight, Assets.images.Pidgeot:getWidth(), Assets.images.Pidgeot:getHeight())
    Assets.animations.Pidgeot = {
        down  = anim8.newAnimation(gPidgeot('1-4', 1), animSpeed),
        left  = anim8.newAnimation(gPidgeot('1-4', 2), animSpeed),
        right = anim8.newAnimation(gPidgeot('1-4', 3), animSpeed),
        up    = anim8.newAnimation(gPidgeot('1-4', 4), animSpeed)
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
        -- Shader creation failed, likely because they are not supported on this system/LÖVE version.
        Assets.shaders.outline = nil
        print("Warning: Could not load outline shader. Shaders may not be supported. Error: " .. tostring(shader_or_error))
    end

    local success_solid, shader_or_error_solid = pcall(love.graphics.newShader, "assets/shaders/solid_color.glsl")
    if success_solid then
        Assets.shaders.solid_color = shader_or_error_solid
    else
        -- Shader creation failed, likely because they are not supported on this system/LÖVE version.
        Assets.shaders.solid_color = nil
        print("Warning: Could not load solid_color shader. Shaders may not be supported. Error: " .. tostring(shader_or_error_solid))
    end

    local success_grey, shader_or_error_grey = pcall(love.graphics.newShader, "assets/shaders/greyscale.glsl")
    if success_grey then
        Assets.shaders.greyscale = shader_or_error_grey
    else
        -- Shader creation failed, likely because they are not supported on this system/LÖVE version.
        Assets.shaders.greyscale = nil
        print("Warning: Could not load greyscale shader. Shaders may not be supported. Error: " .. tostring(shader_or_error_grey))
    end

    Assets.status_effects = load_data_files("data/status_effects/")
    -- You can add more assets here as your game grows
    -- For example:
    -- Assets.images.enemy_goblin = love.graphics.newImage("assets/goblin.png")
    -- Assets.sounds.sword_swing = love.audio.newSource("assets/sword.wav", "static")
end

return Assets