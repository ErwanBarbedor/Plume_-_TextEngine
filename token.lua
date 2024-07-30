--[[This file is part of Plume - TextEngine.

Plume - TextEngine is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

Plume - TextEngine is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Plume - TextEngine. If not, see <https://www.gnu.org/licenses/>.
]]

function txe.token (kind, value, line, pos, file, code)
    -- Token represente a small chunck of code :
    -- a macro, a newline, a word...
    -- Each token track his position in the source code
    return setmetatable({
        __type = "token",-- used for debugging
        kind   = kind,
        value  = value,
        line   = line,
        pos    = pos,
        file   = file,
        code   = code,
        source = function (self)
            return self.value
        end
    }, {})
end

local function tokens2number(x, y)
    -- Convert any number of tokens into number
    if type(x) == "table" and x.render then
        x = tonumber(x:render())
    else
        x = tonumber (x)
    end
    if type(y) == "table" and y.render then
        y = tonumber(y:render())
    else
        y = tonumber (y)
    end

    -- todo : error when x or y is nil
    return x, y
end

function txe.tokenlist (x)
    local kind = "block"
    local t = {}

    if type(x) == "table" then
        t = x
    else
        kind = x
    end

    local tokenlist = setmetatable({
        __type = "tokenlist",-- used for debugging
        kind   = kind,
        
        freeze_scope = function (self, scope)
            -- Each token keep a reference to given scope
            for _, token in ipairs(self) do
                token.frozen_scope = scope
            end
        end,
    
        source = function (self)
            -- "detokenize" the tokens, to retrieve the
            -- original code.
            local result = {}
            for _, token in ipairs(self) do
                if token.kind == "block" then
                    table.insert(result, txe.syntax.block_begin)
                elseif token.kind == "opt_block" then
                    table.insert(result, txe.syntax.opt_block_begin)
                end
                table.insert(result, token:source())
                if token.kind == "block" then
                    table.insert(result, txe.syntax.block_end)
                elseif token.kind == "opt_block" then
                    table.insert(result, txe.syntax.opt_block_end)
                end
            end

            return table.concat(result, "")
        end,
        render = txe.renderToken
    }, {
        -- Some metamethods, for convenience :
        -- Argument of macros are passed as tokenlist without rendered it.
        -- But \def add[x y] #{tonumber(x:render()) + tonumber(y:render())} is quite cumbersone.
        -- With metamethods, it became \def add[x y] #{x+y}
        __add = function(self, y)
            x, y = tokens2number (self, y)
            return x+y
        end,
        __sub = function(self, y)
            x, y = tokens2number (self, y)
            return x-y
        end,
        __mul = function(self, y)
            x, y = tokens2number (self, y)
            return x*y
        end,
        __div = function(self, y)
            x, y = tokens2number (self, y)
            return x/y
        end,
        __concat = function(self, y)
            if y.render then y = y:render () end
            return x:render () .. y
        end
    })

    for k, v in ipairs(t) do
        tokenlist[k] = v
    end
    
    return tokenlist
end