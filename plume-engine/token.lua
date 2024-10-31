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
        end,

         --- Returns the source code of the token
        -- @return string The source code
        sourceLua = function (self)
            return self.value
        end,
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
-- But \macro add[x y] ${tonumber(x:render()) + tonumber(y:render())} is quite cumbersome.
-- With metamethods, it becomes \macro add[x y] ${x+y}, with an implicit call to tokenlist:render ()
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
}

local metamethods_unary_string = {
    tostring = function (x) return x end,
}

-- Use load to avoid syntax error in prior versions of Lua.
if _VERSION == "Lua 5.3" or _VERSION == "Lua 5.4" then
    metamethods_binary_numeric.idiv = load("return function (x, y) return x//y end")()
    metamethods_binary_numeric.band = load("return function (x, y) return x&y end")()
    metamethods_binary_numeric.bor  = load("return function (x, y) return x|y end")()
    metamethods_binary_numeric.bxor = load("return function (x, y) return x~y end")()
    metamethods_binary_numeric.shl  = load("return function (x, y) return x>>y end")()
    metamethods_binary_numeric.shr  = load("return function (x, y) return x<<y end")()

    metamethods_unary_numeric.bnot = load("return function (x) return ~x end")()
end

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

        local rendered = self:render_lua ()
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
        __type    = "tokenlist", --- Type of the table. Value : `"tokenlist"`
        kind      = kind,        --- Kind of tokenlist. Can be : `"block"`, `"opt_block"`, `"block_text"`, `"render-block"`.
        
        -- Set to false instead of nil, so read these value don't trigger __index method.
        context   = false,       --- The scope of the tokenlist. If set to false (default), search vars in the current scope.
        lua_cache = false,       --- For eval tokens, cached loaded lua code.
        opening_token = false, --- If the tokenlist is a "block" or an "opt_block",keep a reference to the opening brace, to track token list position in the code.
        closing_token = false, --- If the tokenlist is a "block" or an "opt_block",keep a reference to the closing brace, to track token list position in the code.

        
        --- @intern_method Return debug informations about the tokenlist.
        -- @return debug_info A table containing fields : `file`, `line` (the first line of this code chunck), `lastline`, `pos` (first position of the code in the first line), `endpos`, `code` (The full code of the file).
        info = function (self)
            local first = self.opening_token or self[1]
            local last = self.closing_token or self[#self]

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

        --- @itern_method Copy the tokenlist.
        -- @return tokenlist The copied tokenlist.
        copy = function (self)
            local token_copy     = plume.tokenlist ()
            token_copy.kind      = self.kind
            token_copy.context   = self.context

            -- Hard fix, need a cleanup on token.first / token.last
            -- Uncomment break test "eval/Not to many eval"
            token_copy.opening_token = self.opening_token
            token_copy.closing_token = self.closing_token
            token_copy.lua_cache     = self.lua_cache

            for _, token in ipairs(self) do
                if token.__type == "tokenlist" then
                    table.insert(token_copy, token:copy())
                else
                    table.insert(token_copy, token)
                end
            end

            return token_copy

        end,

        --- @intern_method Freezes the scope for all tokens in the list.
        -- @param scope table The scope to freeze.
        -- @param forced boolean Force to re-freeze already frozen children?
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
    
        --- @api_method Returns the raw code of the tokenlist, as is writed in the source file.
        -- @return string The source code
        source = function (self)
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

        --- @api_method Get lua code as writed in the code file, after deleting comment and insert plume blocks.
        -- @return string The source code
        sourceLua = function (self, temp)
            local result = {}
            local i = 0
            -- for _, token in ipairs(self) do
            while i < #self do
                i = i+1
                local token = self[i]
                
                if token.kind == "block" then
                    table.insert(result, plume.syntax.block_begin)
                elseif token.kind == "opt_block" then
                    table.insert(result, plume.syntax.opt_block_begin)
                end

                if token.kind == "comment" then

                -- It is a plume block inside lua code.
                -- Insert a reference to the parsed tokenlist.
                elseif token.kind == "code" then
                    local index = math.random (1, 100000)
                    while temp['token' .. index] do index = index + 1 end

                    local text = token[2]
                    temp['token' .. index] = text
                    table.insert(result, "plume.temp.token" .. index)
                    
                    -- Add line jump in code, to keep same numbering as source code
                    for _ in text:source():gmatch('\n') do
                        table.insert(result, '\n')
                    end
                    
                else
                    table.insert(result, token:sourceLua(temp))
                end

                if token.kind == "block" then
                    table.insert(result, plume.syntax.block_end)
                elseif token.kind == "opt_block" then
                    table.insert(result, plume.syntax.opt_block_end)
                end
            end

            return table.concat(result, "")
        end,

        --- @api_method Determines if the block is an evaluation block (like `${1+1}`)
        -- @return boolean Returns true if the block is an evaluation block, false otherwise
        is_eval_block = function (self)
            local is_eval_block = false

            -- Check if the table has exactly 2 elements and the first element is of kind "macro"
            if #self == 2 and self[1].kind == "macro" then
                -- Check if the macro value is "$" or "eval"
                is_eval_block = is_eval_block or self[1].value == "$"
                is_eval_block = is_eval_block or self[1].value == "eval"
            end

            return is_eval_block
        end,


        --- @api_method Render the tokenlist and return true if it is empty
        -- @return bool Is the tokenlist empty?
        is_empty = function (self)
            return #self:render() == 0
        end,
        render    = plume.render_token,
        render_lua = plume.render_token_lua
    }, metatable)

    for k, v in ipairs(t) do
        tokenlist[k] = v
    end
    
    return tokenlist
end

--- Retrieves a line by its line number in the source code.
-- @param source string The source code
-- @param noline number The line number to retrieve
-- @return string The line at the specified line number
function plume.get_line(source, noline)
    local current_line = 1
    for line in (source.."\n"):gmatch("(.-)\n") do
        if noline == current_line then
            return line
        end
        current_line = current_line + 1
    end
end

--- Returns information about a token.
-- @param token table The token to get information about
-- @return table A table containing file, line number, line content,
-- and position information
function plume.token_info (token)

    local file, token_noline, token_line, code, beginpos, endpos

    -- code token is just a container
    if token.kind == "code" then
        token = token[2]
    end

    -- Find all informations about the token
    if token.kind == "opt_block" or token.kind == "block" then
        file = token:info().file
        token_noline = token:info().line
        code = token:info().code
        beginpos = token:info().pos

        if token:info().lastline == token_noline then
            endpos = token:info().endpos+1
        else
            endpos = beginpos+1
        end
    elseif token.kind == "block_text" then
        file = token:info().file
        token_noline = token:info().line
        code = token:info().code
        beginpos = token:info().pos

        endpos = token[#token].pos + #token[#token].value
    else
        file = token.file
        token_noline = token.line
        code = token.code
        beginpos = token.pos
        endpos = token.pos+#token.value
    end

    return {
        file     = file,
        noline   = token_noline,
        line     = plume.get_line (code, token_noline),
        beginpos = beginpos,
        endpos   = endpos
    }
end