local Class = require "libs.hump.class"
local Matrix = require "libs.matrix"
local Tween = require "libs.tween"

local Gem = require "src.game.Gem"
local Cursor = require "src.game.Cursor"
local Explosion = require "src.game.Explosion"
local Sounds = require "src.game.SoundEffects"
local Coin = require "src.game.Coin"

local Board = Class{}
Board.MAXROWS = 8
Board.MAXCOLS = 8
Board.TILESIZE = Gem.SIZE*Gem.SCALE 
function Board:init(x,y, stats)
    self.x = x
    self.y = y
    self.stats = stats
    self.cursor = Cursor(self.x,self.y,Board.TILESIZE+1)

    self.tiles = Matrix:new(Board.MAXROWS,Board.MAXCOLS)
    local coinI = math.random(1,8)
    local coinJ = math.random(1,8)
    for i=1, Board.MAXROWS do
        for j=1, Board.MAXCOLS do
            if i == coinI and j == coinJ then
                self.coin = Coin(self.x+(j-1)*Board.TILESIZE,self.y+(i-1)*Board.TILESIZE)
                self.tiles[i][j] = self.coin
            else
                self.tiles[i][j] = self:createGem(i,j)
            end
        end -- end for j
    end -- end for i
    self:fixInitialMatrix()

    self.tweenGem1 = nil
    self.tweenGem2 = nil
    self.explosions = {}
    self.arrayFallTweens = {}
    self.level = 1
    self.newCoin = false
end

function Board:createGem(row,col)
    return Gem(self.x+(col-1)*Board.TILESIZE,
               self.y+(row-1)*Board.TILESIZE,
               math.random(4,8) )
end

function Board:fixInitialMatrix()
    -- First we check horizontally
    for i = 1, Board.MAXROWS do
        local same = 1 
        for j = 2, Board.MAXCOLS do -- pay attention: starts as j=2
            if self.tiles[i][j].type == self.tiles[i][j-1].type then
                same = same+1 -- counting same types
                if same == 3 then -- match 3, fix it
                    self.tiles[i][j]:nextType()
                    same = 1
                end
            else
                same = 1
            end
        end
    end    

    -- Second we check vertically
    for j = 1, Board.MAXCOLS do -- pay attention: first loop is j
        local same = 1 
        for i = 2, Board.MAXROWS do -- second loop is i
            if self.tiles[i][j].type == self.tiles[i-1][j].type then
                same = same+1 -- counting same types
                if same == 3 then -- match 3, fix it
                    self.tiles[i][j]:nextType()
                    same = 1
                end
            else
                same = 1
            end
        end
    end    
end    

function Board:update(dt)
    for i=1, Board.MAXROWS do
        for j=1, Board.MAXCOLS do
            if self.tiles[i][j] then -- tile is not nil
                self.tiles[i][j]:update(dt)
            end -- end if
        end -- end for j
    end -- end for i

    for k=#self.explosions, 1, -1 do
        if self.explosions[k]:isActive() then
            self.explosions[k]:update(dt)
        else
            table.remove(self.explosions, k)
        end -- end if
    end -- end for explosions

    for k=#self.arrayFallTweens, 1, -1 do
        if self.arrayFallTweens[k]:update(dt) then
            -- the tween has completed its job
            table.remove(self.arrayFallTweens, k)
        end
    end -- end for tween Falls

    if #self.arrayFallTweens == 0 then
        self:matches()
    end

    if self.tweenGem1 ~= nil and self.tweenGem2~=nil then
        local completed1 = self.tweenGem1:update(dt)
        local completed2 = self.tweenGem2:update(dt)
        if completed1 and completed2 then
            self.tweenGem1 = nil
            self.tweenGem2 = nil
            local temp = self.tiles[mouseRow][mouseCol]
            self.tiles[mouseRow][mouseCol] = self.tiles[self.cursor.row][self.cursor.col]
            self.tiles[self.cursor.row][self.cursor.col] = temp
            self.cursor:clear()
            self:matches()
        end
    end
end

function Board:draw()
    for i=1, Board.MAXROWS do
        for j=1, Board.MAXCOLS do
            if self.tiles[i][j] then -- tile is not nil
                self.tiles[i][j]:draw()
            end -- end if
        end -- end for j
    end -- end for i

    self.cursor:draw()

    for k=1, #self.explosions do
        self.explosions[k]:draw()
    end
end

function Board:cheatGem(x,y)
    if x > self.x and y > self.y 
       and x < self.x+Board.MAXCOLS*Board.TILESIZE
       and y < self.y+Board.MAXROWS*Board.TILESIZE then
        -- Click inside the board coords
        local cheatRow,cheatCol = self:convertPixelToMatrix(x,y)
        self.tiles[cheatRow][cheatCol]:nextType()
    end
end

function Board:mousepressed(x,y)
    if x > self.x and y > self.y 
       and x < self.x+Board.MAXCOLS*Board.TILESIZE
       and y < self.y+Board.MAXROWS*Board.TILESIZE then
        -- Click inside the board coords
        mouseRow, mouseCol = self:convertPixelToMatrix(x,y)

        if self.cursor.row == mouseRow and self.cursor.col == mouseCol then
            self.cursor:clear()
        elseif self:isAdjacentToCursor(mouseRow,mouseCol) then
            -- adjacent click, swap gems
            self:tweenStartSwap(mouseRow,mouseCol,self.cursor.row,self.cursor.col)
        else -- sets cursor to clicked place
            self.cursor:setCoords(self.x+(mouseCol-1)*Board.TILESIZE,
                    self.y+(mouseRow-1)*Board.TILESIZE)
            self.cursor:setMatrixCoords(mouseRow,mouseCol)
        end
    
    end -- end if

end

function Board:isAdjacentToCursor(row,col)
    local adjCol = self.cursor.row == row 
       and (self.cursor.col == col+1 or self.cursor.col == col-1)
    local adjRow = self.cursor.col == col 
       and (self.cursor.row == row+1 or self.cursor.row == row-1)
    return adjCol or adjRow
end

function Board:convertPixelToMatrix(x,y)
    local col = 1+math.floor((x-self.x)/Board.TILESIZE)
    local row = 1+math.floor((y-self.y)/Board.TILESIZE)
    return row,col 
end

function Board:tweenStartSwap(row1,col1,row2,col2)
    stats:comboReset()
    local x1 = self.tiles[row1][col1].x
    local y1 = self.tiles[row1][col1].y

    local x2 = self.tiles[row2][col2].x
    local y2 = self.tiles[row2][col2].y

    self.tweenGem1 = Tween.new(0.3,self.tiles[row1][col1],{x = x2, y = y2})
    self.tweenGem2 = Tween.new(0.3,self.tiles[row2][col2],{x = x1, y = y1})
end

function Board:findHorizontalMatches()
    local matches = {}
    for i = 1, Board.MAXROWS do 
        local same = 1
        for j = 2, Board.MAXCOLS do
            if self.tiles[i][j].type == self.tiles[i][j-1].type then
                same = same +1
            elseif same > 2 then -- match-3+
                table.insert(matches,{row=i, col=(j-same), size=same})
                same = 1
            else -- different but no match-3
                same = 1
            end
        end -- end for j

        if same > 2 then
            table.insert(matches,{row=i, col=(Board.MAXCOLS-same+1), size=same})
            same = 1
        end
    end -- end for i

    return matches
end

function Board:findVerticalMatches()
    -- Almost the same func as findHorizontalMatches, bascially changing i for j
    local matches = {}
    for j = 1, Board.MAXCOLS do 
        local same = 1
        for i = 2, Board.MAXROWS do
            if self.tiles[i][j].type == self.tiles[i-1][j].type then
                same = same +1
            elseif same > 2 then -- match-3+
                table.insert(matches,{row=(i-same), col=j, size=same})
                same = 1
            else -- different but no match-3
                same = 1
            end
        end -- end for j

        if same > 2 then
            table.insert(matches,{row=(Board.MAXROWS+1-same), col=j, size=same})
            same = 1
        end
    end -- end for i

    return matches
end

function Board:matches()
    local horMatches = self:findHorizontalMatches()
    local verMatches = self:findVerticalMatches() 
    local score = 0

    if #horMatches > 0 or #verMatches > 0 then -- if there are matches
        local crow, ccol = nil
        for i=1, Board.MAXROWS do   -- find the coin on the board
            for j=1, Board.MAXCOLS do
                -- if it is the coin set crow and ccol
                if self.tiles[i][j] == self.coin then
                    crow = i
                    ccol = j
                    break
                end
            end -- end for j

            if crow then -- break if found
                break
            end
        end -- end for i

        for k, match in pairs(horMatches) do
            score = score + 2^match.size * 10   
            for j=0, match.size-1 do
                self:createExplosion(match.row,match.col+j)
                self.tiles[match.row][match.col+j] = nil

                -- Check if it is next to coin
                if crow and ccol then
                    local rowDiff = math.abs(crow - match.row)
                    local colDiff = math.abs(ccol - (match.col+j))
                    if rowDiff == 1 and colDiff == 0 or rowDiff == 0 and colDiff == 1 then
                        print("YES")
                        self.coin:scored()
                        self.tiles[crow][ccol] = nil
                        stats:coinPoints()
                        self.newCoin = true
                    end
                end
            end -- end for j 
        end -- end for each horMatch

        for k, match in pairs(verMatches) do
            score = score + 2^match.size * 10   
            for i=0, match.size-1 do
                self:createExplosion(match.row+i,match.col)
                self.tiles[match.row+i][match.col] = nil

                -- Check if it is next to coin
                if crow and ccol then
                    local rowDiff = math.abs(crow - (match.row+i))
                    local colDiff = math.abs(ccol - match.col)
                    if rowDiff == 1 and colDiff == 0 or rowDiff == 0 and colDiff == 1 then
                        print("YES")
                        self.coin:scored()
                        self.tiles[crow][ccol] = nil
                        stats:coinPoints()
                        self.newCoin = true
                    end
                end
            end -- end for i 
        end -- end for each verMatch

        if Sounds["breakGems"]:isPlaying() then
            Sounds["breakGems"]:stop()
        end
        Sounds["breakGems"]:play()

        stats:comboUp()
        self.stats:addScore(score)

        self:shiftGems()
        self:generateNewGems()

        -- add a new coin randomly (shouldve prob generated a new one like the other gems, but
            -- didn't come up with a good idea)
        if stats.level > self.level and self.coin.x == nil then
            self.level = stats.level
            local newI = math.random(1,8)
            local newJ = math.random(1,8)
            self.coin:newLocation(self.x+(newJ-1)*Board.TILESIZE,self.y+(newI-1)*Board.TILESIZE)
            self.tiles[newI][newJ] = self.coin
        end
    end -- end if (has matches)
end

function Board:createExplosion(row,col)
    local exp = Explosion()
    local gem = self.tiles[row][col]
    if gem then
        local r, g, b = gem:color()
        exp:setColor(r, g, b)
        exp:trigger(self.x+(col-1)*Board.TILESIZE+Board.TILESIZE/2,
                self.y+(row-1)*Board.TILESIZE+Board.TILESIZE/2)  
        table.insert(self.explosions, exp) -- add exp to our array
    end
end

function Board:shiftGems() 
    for j = 1, Board.MAXCOLS do
        for i = Board.MAXROWS, 2, -1 do -- find an empty space
            if self.tiles[i][j] == nil then -- current pos is empty
            -- seek a gem on top to move here
                for k = i-1, 1, -1 do 
                    if self.tiles[k][j] ~= nil then -- found a gem
                        self.tiles[i][j] = self.tiles[k][j]
                        self.tiles[k][j] = nil
                        self:tweenGemFall(i,j) -- tween fall animation 
                        break -- ends for k loop earlier
                    end -- end if found gem
                end -- end for k
            end -- end if empty pos
        end -- end for i
    end -- end for j
end -- end function

function Board:tweenGemFall(row,col)
    local tweenFall = Tween.new(0.5,self.tiles[row][col],
            {y = self.y+(row-1)*Board.TILESIZE})
    table.insert(self.arrayFallTweens, tweenFall)
end

function Board:generateNewGems()
    for j = 1, Board.MAXCOLS do
        local topY = self.y-1*Board.TILESIZE -- y pos above the first gem 
        for i = Board.MAXROWS, 1, -1  do -- find an empty space
            if self.tiles[i][j] == nil then -- empty, create new gem & tween 
                self.tiles[i][j] = Gem(self.x+(j-1)*Board.TILESIZE,topY, math.random(4,8))
                self:tweenGemFall(i,j)
                topY = topY - Board.TILESIZE -- move y further up 
            end -- end if empty space
        end -- end for i
    end -- end for j        
end -- end function generateNewGems()

return Board