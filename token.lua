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

--- Creates a new token.
-- Token represents a small chunk of code:
-- a macro, a newline, a word...
-- Each token tracks its position in the source code
-- @param kind string The kind of token (text, escape, ...)
-- @param value string Information about token behavior, may be different from code
-- @param line number The line number where the token appears
-- @param pos number The position in the line where the token starts
-- @param file string The file where the token appears
-- @param code string The full source code
-- @return token A new token object
function txe.token (kind, value, line, pos, file, code)
    return setmetatable({
        __type = "token",-- used mainly for debugging
        kind   = kind,
        value  = value,
        line   = line,
        pos    = pos,
        file   = file,
        code   = code,
        --- Returns the source code of the token
        -- @return string The source code
        source = function (self)
            return self.value
        end
    }, {})
end

--- Convert two elements into numbers
-- @param x token|number|string Element to convert
-- @param y token|number|string Element to convert
-- @return number, number The converted numbers
local function tokens2number(x, y)
    
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

--- Creates a new tokenlist.
-- @param x string|table Either a kind string or a table of tokens
-- @return tokenlist A new tokenlist object
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
        
        --- Get information (line, file, ...) about the tokenlist
        -- The line will be the line of the first token
        -- @return table
        info = function (self)
            local first = self.first or self[1]
            local last = self.last or self[#self]
            return {
                file = first.file,
                line = first.line,
                lastline = last.line,
                code = first.code,
                pos  = first.pos,
                endpos = last.pos
            }
        end,

        --- Freezes the scope for all tokens in the list
        -- @param scope table The scope to freeze
        set_context = function (self, scope)
            -- Each token keeps a reference to given scope
            for _, token in ipairs(self) do
                token.context = scope
            end
        end,
    
        --- Returns the source code of the tokenlist
        -- @return string The source code
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
        -- Arguments of macros are passed as tokenlist without rendering it.
        -- But \def add[x y] #{tonumber(x:render()) + tonumber(y:render())} is quite cumbersome.
        -- With metamethods, it becomes \def add[x y] #{x+y}
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
