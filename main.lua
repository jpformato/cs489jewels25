-- Jack Formato

local Globals = require "src.Globals"
local Push = require "libs.push"
local Background = require "src.game.Background"
local Gem = require "src.game.Gem"
local Board = require "src.game.Board"
local Border = require "src.game.Border"
local Explosion = require "src.game.Explosion"
local Sounds = require "src.game.SoundEffects"
local Stats = require "src.game.Stats"

-- Load is executed only once; used to setup initial resource for your game
function love.load()
    love.window.setTitle("CS489 Jewels")
    Push:setupScreen(gameWidth, gameHeight, windowWidth, windowHeight, {fullscreen = false, resizable = true})
    math.randomseed(os.time()) -- RNG setup for later

    titleFont = love.graphics.newFont(32)

    bg1 = Background("graphics/bg/background1.png",30)
    bg2 = Background("graphics/bg/background2.png",60)

    gem1 = Gem(100,50,5)
    gem2 = Gem(500,50,6)

    stats = Stats()
    board = Board(140,80,stats)
    border = Border(110,50,380,380)

    testexp = Explosion()
end

-- When the game window resizes
function love.resize(w,h)
    Push:resize(w,h) -- must called Push to maintain game resolution
end

-- Event for keyboard pressing
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "F2" or key == "tab" then
        debugFlag = not debugFlag
    elseif key == "return" and gameState=="start" then
        Sounds['playStateMusic']:play()
        gameState = "play"
    elseif key == "return" and gameState == "over" then
        stats:reset()
        Sounds['playStateMusic']:play()
        gameState = "play"
    end
end

-- Event to handle mouse pressed (there is another for mouse release)
function love.mousepressed(x, y, button, istouch)
    local gx, gy = Push:toGame(x,y)
    if button == 1 then -- regurlar mouse click
        board:mousepressed(gx,gy)
    elseif debugFlag then
        if button == 2 and love.keyboard.isDown("lctrl","rctrl") then
           testexp:trigger(gx,gy)
        elseif button == 2 then
            board:cheatGem(gx,gy)
        end
    end
end

-- Update is executed each frame, dt is delta time (a fraction of a sec)
function love.update(dt)
    if stats.timeOut and gameState ~= "over" then
        gameState = "over"
        Sounds['timeOut']:play()
    end

    bg1:update(dt)
    bg2:update(dt)
    testexp:update(dt)
    stats:update(dt)

    if gameState == "start" then

        gem1:update(dt)
        gem2:update(dt)
    elseif gameState == "play" then
        board:update(dt)

    elseif gameState == "over" then
        Sounds['playStateMusic']:pause()
        -- for later, if we needed
    end
end

-- Draws the game after the update
function love.draw()
    Push:start()

    -- always draw between Push:start() and Push:finish()
    if gameState== "start" then
        drawStartState()
    elseif gameState == "play" then
        drawPlayState()    
    elseif gameState == "over" then
        drawGameOverState()    
    end

    if testexp:isActive() then
        testexp:draw()
    end
    if debugFlag then
        love.graphics.print("DEBUG ON",20,gameHeight-20)
    end

    Push:finish()
end

function drawStartState()
    bg1:draw()
    bg2:draw()

    love.graphics.printf("CS489 Jewels",titleFont,0,50,
        gameWidth,"center")
    love.graphics.printf("Press Enter to Play or Escape to exit",
        0,90, gameWidth,"center")

    gem1:draw()
    gem2:draw()    
end

function drawPlayState()
    bg1:draw()
    bg2:draw()

    board:draw()

    border:draw()
    stats:draw()
end

function drawGameOverState()
    love.graphics.printf("GameOver",titleFont,0,50,
        gameWidth,"center")
    love.graphics.printf("Press Enter to Play or Escape to exit",
        0,90, gameWidth,"center")
    love.graphics.printf("Level: "..stats.level, 0, 130, gameWidth, "center")
    love.graphics.printf("Score: "..stats.totalScore, 0, 170, gameWidth, "center")
end
