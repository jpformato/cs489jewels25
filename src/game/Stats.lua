local Class = require "libs.hump.class"
local Timer = require "libs.hump.timer"
local Tween = require "libs.tween" 
local Sounds = require "src.game.SoundEffects"

local statFont = love.graphics.newFont(26)

local Stats = Class{}
function Stats:init()
    self.y = 10 -- we will need it for tweening later
    self.level = 1 -- current level    
    self.totalScore = 0 -- total score so far
    self.targetScore = 1000
    self.maxSecs = 99 -- max seconds for the level
    self.elapsedSecs = 0 -- elapsed seconds
    self.timeOut = false -- when time is out
    self.tweenLevel = nil -- for later
    self.tweenCombo = nil
    self.combo = 0
    self.y2 = 100
    Timer.every(1,function() self:clock() end)
end

function Stats:draw()
    if self.y > 10 then
        love.graphics.setColor(0,0,0.6)
        love.graphics.rectangle("fill",0,self.y-10,gameWidth,26*2)
    end
    love.graphics.setColor(1,0,1) -- Magenta
    love.graphics.printf("Level "..tostring(self.level), statFont, gameWidth/2-60,self.y,100,"center")
    if self.y <= 10 then
        love.graphics.printf("Time "..tostring(self.elapsedSecs).."/"..tostring(self.maxSecs), statFont,10,10,200)
        love.graphics.printf("Score "..tostring(self.totalScore), statFont,gameWidth-210,10,200,"right")
    end
    if self.y2 > 100 then
        love.graphics.printf("x"..tostring(self.combo), statFont, gameWidth/2 + 150, self.y2, 100, "center")
    end
    love.graphics.setColor(1,1,1) -- White
end
    
function Stats:update(dt) -- for now, empty function
    Timer.update(dt)
    if self.tweenLevel then
        self.tweenLevel:update(dt)
    end
    if self.tweenCombo then
        self.tweenCombo:update(dt)
    end
end

function Stats:addScore(n)
    self.totalScore = self.totalScore + n*self.combo
    if self.totalScore > self.targetScore then
        self:levelUp()
    end
end

function Stats:levelUp()
    Sounds['levelUp']:play()
    self.level = self.level +1
    self.targetScore = self.targetScore+self.level*1000
    self.elapsedSecs = 0
    self.y = gameHeight/2
    self.tweenLevel = Tween.new(1,self,{y=10})
end

function Stats:clock()
    self.elapsedSecs = self.elapsedSecs + 1
    if self.elapsedSecs > self.maxSecs then
        self.timeOut = true
    end
end

function Stats:reset()
    self.level = 1 -- current level    
    self.totalScore = 0 -- total score so far
    self.targetScore = 1000
    self.elapsedSecs = 0 -- elapsed seconds
    self.timeOut = false -- when time is out
    self.tweenLevel = nil -- for later
    self.combo = 0
    self.tweenCombo = nil
end

function Stats:comboUp()
    self.combo = self.combo + 1
    if self.combo > 1 then
        self.y2 = gameHeight/2
        self.tweenCombo = Tween.new(1,self,{y2=100})
    end
end

function Stats:comboReset()
    self.combo = 0
end

function Stats:coinPoints()
    self.totalScore = self.totalScore + 500
    if self.totalScore > self.targetScore then
        self:levelUp()
    end
end
    
return Stats
    