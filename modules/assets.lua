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
    -- Helper function to safely load an image and print a detailed error if it fails.
    -- This prevents a single missing asset from crashing the entire loading process.
    local function loadImage(path)
        local success, image_or_error = pcall(love.graphics.newImage, path)
        if not success then
            print(string.format("[ASSET ERROR] Failed to load image at path: '%s'", path))
            print(string.format("              LÖVE Error: %s", tostring(image_or_error)))
            return nil -- Return nil so the game doesn't crash if it tries to use the missing image.
        end
        return image_or_error
    end

    -- Load images
    Assets.images.Clementine = loadImage("assets/PlayerUnits/Clementine.png")
    Assets.images.Plop = loadImage("assets/PlayerUnits/Plop.png")
    Assets.images.Dupe = loadImage("assets/PlayerUnits/Dupe.png")
    Assets.images.Winthrop = loadImage("assets/PlayerUnits/Winthrop.png")
    Assets.images.Biblo = loadImage("assets/PlayerUnits/Biblo.png")
    Assets.images.Mortimer = loadImage("assets/PlayerUnits/Mortimer.png")
    Assets.images.Ollo = loadImage("assets/PlayerUnits/Ollo.png")
    Assets.images.Cedric = loadImage("assets/PlayerUnits/Cedric.png")
    Assets.images.Brawler = loadImage("assets/brawler.png")
    Assets.images.Archer = loadImage("assets/archer.png")
    Assets.images.Flag = loadImage("assets/tree.png") -- For Sceptile's attack
    Assets.images.Punter = loadImage("assets/punter.png")
    Assets.images.BearTrap = loadImage("assets/beartrap.png")
    Assets.images.Aflame = loadImage("assets/Aflame.png") -- For the new tile status
    Assets.images.Frozen = loadImage("assets/Frozen.png") -- For the new tile status

    -- Load portraits
    Assets.images.Default_Portrait = loadImage("assets/Portraits/Default_Portrait.png")

    -- Load Weapon Icons
    Assets.images.weaponIcons = {
        sword = loadImage("assets/WeaponIcons/Sword.png"),
        lance = loadImage("assets/WeaponIcons/Lance.png"),
        whip = loadImage("assets/WeaponIcons/Whip.png"),
        bow = loadImage("assets/WeaponIcons/Bow.png"),
        staff = loadImage("assets/WeaponIcons/Staff.png"),
        tome = loadImage("assets/WeaponIcons/Tome.png"),
        dagger = loadImage("assets/WeaponIcons/Dagger.png")
    }

    -- Load Origin Icons
    Assets.images.originIcons = {
        forestborn = loadImage("assets/OriginIcons/Forest.png"),
        cavernborn = loadImage("assets/OriginIcons/Cavern.png"),
        marshborn  = loadImage("assets/OriginIcons/Marsh.png")
    }


    -- Load sounds
    local function loadSound(path, volume)
        local success, sound_or_error = pcall(love.audio.newSource, path, "static")
        if not success then
            print(string.format("[ASSET ERROR] Failed to load sound at path: '%s'", path))
            print(string.format("              LÖVE Error: %s", tostring(sound_or_error)))
            return nil
        end
        sound_or_error:setVolume(volume or 1.0)
        return sound_or_error
    end

    Assets.sounds.cursor_move = loadSound("assets/sfx/cursor_move.wav", 0.4)
    Assets.sounds.menu_scroll = loadSound("assets/sfx/menu_scroll.wav", 0.7)
    Assets.sounds.back_out = loadSound("assets/sfx/back_out.wav", 0.7)
    Assets.sounds.attack_hit = loadSound("assets/sfx/attack_hit.ogg", 0.6)
    Assets.sounds.attack_miss = loadSound("assets/sfx/attack_miss.ogg", 0.6)

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

-- Helper function to safely retrieve a weapon icon by its type.
-- This centralizes the logic and prevents nil errors.
function Assets.getWeaponIcon(weaponType)
    if not weaponType or not Assets.images.weaponIcons then
        return nil
    end
    local icon = Assets.images.weaponIcons[weaponType]
    return icon
end

-- Helper function to safely retrieve an origin icon by its type.
function Assets.getOriginIcon(originType)
    if not originType or not Assets.images.originIcons then
        return nil
    end
    return Assets.images.originIcons[originType]
end


return Assets