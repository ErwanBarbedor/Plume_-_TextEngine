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
function plume.token (kind, value, line, pos, file, code)
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

--- Convert one element into number
-- @param x tokenlist|number|string Element to convert
-- @return number The converted numbers
local function tokens2number(x)
    local nx, rx
    if type(x) == "table" and x.render then
        rx  = x:render()
        nx = tonumber(rx)
    else
        nx = tonumber (x)
    end

    if not nx then
        if type(x) == "table" and x.__type == "tokenlist" then
            plume.internal_error ("Cannot convert a token rendered as '".. rx .."' into number.")
        else
            error ("Cannot convert '" .. x .. "' (" .. type(x) .. ") into number.")
        end
    end

    return nx
end

--- Convert one element into string
-- @param x tokenlist|number|string Element to convert
-- @return number The converted numbers
local function tokens2string(x, y)
    
    if type(x) == "table" and x.render then
        x = x:render()
    else
        x = tostring(x)
    end

    return x
end

-- Categorize metamethods , for convenience :
-- Arguments of macros are passed as tokenlist without rendering it.
-- But \def add[x y] #{tonumber(x:render()) + tonumber(y:render())} is quite cumbersome.
-- With metamethods, it becomes \def add[x y] #{x+y}, with an implicit call to tokenlist:render ()
local metamethods_binary_numeric = {
    add  = function (x, y) return x+y end,
    sub  = function (x, y) return x-y end,
    div  = function (x, y) return x/y end,
    mul  = function (x, y) return x*y end,
    mod  = function (x, y) return x%y end,
    pow  = function (x, y) return x^y end,
    lt   = function (x, y) return x<y end,
    le   = function (x, y) return x<=y end
}

local metamethods_unary_numeric = {
    unm = function (x) return -x end
}

local metamethods_binary_string = {
    concat = function (x, y) return x..y end,
    eq     = function (x, y) return x==y end
}

local metamethods_unary_string = {
    tostring = function (x) return x end,
}

-- Use load to avoid syntax error in prior versions of Lua.
-- <Lua 5.3 5.4>
if _VERSION == "Lua 5.3" or _VERSION == "Lua 5.4" then
    metamethods_binary_numeric.idiv = load("return function (x, y) return x//y end")()
    metamethods_binary_numeric.band = load("return function (x, y) return x&y end")()
    metamethods_binary_numeric.bor  = load("return function (x, y) return x|y end")()
    metamethods_binary_numeric.bxor = load("return function (x, y) return x~y end")()
    metamethods_binary_numeric.shl  = load("return function (x, y) return x>>y end")()
    metamethods_binary_numeric.shr  = load("return function (x, y) return x<<y end")()

    metamethods_unary_numeric.bnot = load("return function (x) return ~x end")()
end
-- </Lua>

--- Creates a new tokenlist.
-- @param x string|table Either a kind string or a table of tokens
-- @return tokenlist A new tokenlist object
function plume.tokenlist (x)
    local kind = "block"
    local t = {}

    if type(x) == "table" then
        t = x
    elseif x then
        kind = x
    end

    local metatable = {}

    for name, method in pairs(metamethods_binary_numeric) do
        metatable["__" .. name] = function (x, y)
            return method (tokens2number(x), tokens2number(y))
        end
    end

    for name, method in pairs(metamethods_unary_numeric) do
        metatable["__" .. name] = function (x)
            return method (tokens2number(x))
        end
    end

    for name, method in pairs(metamethods_binary_string) do
        metatable["__" .. name] = function (x, y)
            return method (tokens2string(x), tokens2string(y))
        end
    end

    for name, method in pairs(metamethods_unary_numeric) do
        metatable["__" .. name] = function (x)
            return method (tokens2string(x))
        end
    end

    function metatable.__index (self, key)
        if tonumber (key) then
            return rawget(self, key)
        end

        local result = rawget(self, key)
        if result then
            return result
        end

        local rendered = self:renderLua ()
        if type(rendered) == "string" then
            if string[key] then
                -- Handle both token:method and token.method call.
                return function (caller, ...)
                    if caller == self then
                        return string[key] (rendered, ...)
                    else
                        return string[key] (caller, ...)
                    end
                end
            else
                return
            end
        elseif type(rendered) ~= "table" then
            return
        end

        return rawget(rendered, key)
    end

    local tokenlist = setmetatable({
        __type  = "tokenlist",-- used for debugging
        kind      = kind,
        context   = false,
        first     = false,
        last      = false,
        lua_cache = false,
        
        --- Get information (line, file, ...) about the tokenlist
        -- The line will be the line of the first token
        -- @return table
        info = function (self)
            local first = self.first or self[1]
            local last = self.last or self[#self]

            if first.__type == "tokenlist" then
                first = first:info()
            end
            if last.__type == "tokenlist" then
                last = last:info()
            end

            return {
                file = first.file,
                line = first.line,
                lastline = last.line,
                code = first.code,
                pos  = first.pos,
                endpos = last.pos
            }
        end,

        --- @api_method Copy the tokenlist
        -- @return tokenlist
        copy = function (self)
            local token_copy     = plume.tokenlist ()
            token_copy.kind      = self.kind
            token_copy.context   = self.context
            token_copy.first     = self.first
            token_copy.last      = self.last
            token_copy.lua_cache = self.lua_cache

            for _, token in ipairs(self) do
                if token.__type == "tokenlist" then
                    table.insert(token_copy, token:copy())
                else
                    table.insert(token_copy, token)
                end
            end

            return token_copy

        end,

        --- Freezes the scope for all tokens in the list
        -- @param scope table The scope to freeze
        set_context = function (self, scope, forced)
            -- Each token keeps a reference to given scope
            for _, token in ipairs(self) do
                if token.__type == "tokenlist" then
                    token:set_context (scope, forced)
                end
                if forced then
                    token.context = scope
                else
                    token.context = token.context or scope
                end
            end
        end,
    
        --- @api_method Returns the source code of the tokenlist
        -- @return string The source code
        source = function (self)
            -- "detokenize" the tokens, to retrieve the
            -- original code.
            local result = {}
            for _, token in ipairs(self) do
                if token.kind == "block" then
                    table.insert(result, plume.syntax.block_begin)
                elseif token.kind == "opt_block" then
                    table.insert(result, plume.syntax.opt_block_begin)
                end
                table.insert(result, token:source())
                if token.kind == "block" then
                    table.insert(result, plume.syntax.block_end)
                elseif token.kind == "opt_block" then
                    table.insert(result, plume.syntax.opt_block_end)
                end
            end

            return table.concat(result, "")
        end,

        --- @api_method Render the tokenlist and check if empty
        -- @return bool
        is_empty = function (self)
            return #self:render() == 0
        end,
        render    = plume.renderToken,
        renderLua = plume.renderTokenLua
    }, metatable)

    for k, v in ipairs(t) do
        tokenlist[k] = v
    end
    
    return tokenlist
end
