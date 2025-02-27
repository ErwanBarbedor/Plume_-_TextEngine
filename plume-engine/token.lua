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

return function (plume)
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
            source_lua = function (self)
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

    local function deprecate_implicit_render (f)
        return function (...)
            local scope = plume.get_scope ()
            local show_deprecation_warnings = scope:get("config", "show_deprecation_warnings")
            if show_deprecation_warnings then
                plume.warning(plume.traceback[#plume.traceback], 'implicit renderning will be removed in a future version. You will have to explicitly call render method, or use annotations.')
            end
            return f(...)
        end
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
                return deprecate_implicit_render(method)(tokens2number(x), tokens2number(y))
            end
        end

        for name, method in pairs(metamethods_unary_numeric) do
            metatable["__" .. name] = function (x)
                return deprecate_implicit_render(method)(tokens2number(x))
            end
        end

        for name, method in pairs(metamethods_binary_string) do
            metatable["__" .. name] = function (x, y)
                return deprecate_implicit_render(method)(tokens2number(x), tokens2number(y))
            end
        end

        for name, method in pairs(metamethods_unary_numeric) do
            metatable["__" .. name] = function (x)
                return deprecate_implicit_render(method)(tokens2number(x))
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

            -- Implicit rendering if key is a string method
            if not string[key] then
                return
            end

            local scope = plume.get_scope ()
            local show_deprecation_warnings = scope:get("config", "show_deprecation_warnings")
            if show_deprecation_warnings then
                plume.warning(plume.traceback[#plume.traceback], 'implicit renderning will be removed in a future version. You will have to explicitly call render method, or use annotations.')
            end

            local rendered = tostring(self:render_lua ())
            -- Handle both token:method and token.method call.
            return function (caller, ...)
                if caller == self then
                    return string[key] (rendered, ...)
                else
                    return string[key] (caller, ...)
                end
            end

        end

        local tokenlist = setmetatable({
            __type    = "tokenlist", --- Type of the table. Value : `"tokenlist"`
            kind      = kind,        --- Kind of tokenlist. Can be : `"block"`, `"opt_block"`, `"block_text"`, `"render-block"`.

            context   = nil,       --- The scope of the tokenlist. If set to false (default), search vars in the current scope.
            lua_cache = nil,       --- For eval tokens, cached loaded lua code.
            opening_token = nil, --- If the tokenlist is a "block" or an "opt_block",keep a reference to the opening brace, to track token list position in the code.
            closing_token = nil, --- If the tokenlist is a "block" or an "opt_block",keep a reference to the closing brace, to track token list position in the code.
            
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
                    if token.opening_token then
                        table.insert(result, token.opening_token:source ())
                    end

                    table.insert(result, token:source())
                    
                    if token.closing_token then
                        table.insert(result, token.closing_token:source ())
                    end
                end
                
                return table.concat(result, "")
            end,

            --- @api_method Get lua code as writed in the code file, after deleting comment and insert plume blocks.
            -- @return string The source code
            source_lua = function (self, temp, can_return, can_alter_return)
                if can_return == nil then can_return = true end
                if can_alter_return == nil then can_alter_return = true end

                local result = {}
                local i = 0
                local is_expression = true
                local last_kind = nil

                while i < #self do
                    i = i+1
                    local token = self[i]

                    if last_kind and token.kind == "lua_word" and last_kind == "lua_word" then
                        is_expression = false
                    elseif (last_kind == "lua_function" or last_kind == "lua_call") and (token.kind == "lua_word" or token.kind == "lua_function") then
                        is_expression = false
                    end

                    if token.kind ~= "space" and token.kind ~= "newline" then
                        last_kind = token.kind
                    end
                    
                    if token.kind == "lua_statement" then
                        table.insert(result, token.opening_token.value)
                        is_expression = false
                    elseif token.kind == "lua_function" then
                        table.insert(result, token.opening_token.value)
                    elseif token.kind == "lua_code" and token.value == "=" then
                        is_expression = false
                    elseif token.kind == "lua_statement_alone" then
                        is_expression = false
                        if token.value == "local" then
                            if can_return then
                                local name_pos = i+1

                                -- Capture the name of the variable (or "function" token)
                                while i <= #self and self[name_pos].kind == "space" do
                                    name_pos = name_pos + 1
                                end

                                local name = self[name_pos]

                                -- local can be used with variable declaration or affectation
                                if name.kind == "lua_word" then
                                    local variables_names = {}
                                    table.insert(variables_names, name.value)

                                    local last_is_variable = true
                                    local last
                                    
                                    -- Capture a succession of variables, separated by commas.
                                    while true do
                                        name_pos = name_pos+1
                                        -- print(last_is_variable, self[name_pos] and self[name_pos].kind )
                                        if name_pos > #self then
                                            last = nil
                                            break
                                        elseif self[name_pos].kind == "space" then
                                        elseif last_is_variable then
                                            if self[name_pos].kind ~= "lua_code" or self[name_pos].value ~= "," then
                                                last = self[name_pos]
                                                break
                                            end
                                            last_is_variable = false
                                        else
                                            if self[name_pos].kind == "lua_word" then
                                                table.insert(variables_names, self[name_pos].value)
                                                last_is_variable = true
                                            else
                                                last = nil
                                                break
                                            end
                                        end
                                    end

                                    for _, name in ipairs(variables_names) do
                                        table.insert(result, "plume.local_set('" .. name .. "')")
                                    end

                                    -- If local declaration without affectation,
                                    -- don't write variable name two times
                                    if not last or not last.value or last.value:sub(1, 1) ~= "=" then
                                        i = name_pos-1
                                    end

                                -- Or with function declaration
                                elseif name.kind == "lua_statement" and name.opening_token.value == "function" then
                                    local fname_pos = 1
                                    while fname_pos <= #name and name[fname_pos].kind ~= "lua_word" do
                                        fname_pos = fname_pos + 1
                                    end

                                    local fname = name[fname_pos]

                                    if fname then
                                        table.insert(result, "plume.local_set('" .. fname.value .. "')")
                                    end
                                end
                            else
                                table.insert(result, "local")
                            end
                        end
                    elseif token.kind == "lua_call" then
                        table.insert(result, plume.lua_syntax.call_begin)
                    elseif token.kind == "lua_index" then
                        table.insert(result, plume.lua_syntax.index_begin)
                    elseif token.kind == "lua_table" then
                        table.insert(result, plume.lua_syntax.table_begin)
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
                    elseif token.kind == "lua_return" then
                        is_expression = false
                        table.insert(result, " return ")
                        found_return  = true
                    elseif token.kind == "lua_function" or token.kind == "lua_call" or token.kind == "lua_index" or token.kind == "lua_table" then
                        table.insert(result, token:source_lua(temp, false, false))
                    elseif token.value ~= "local" then
                        table.insert(result, token:source_lua(temp, false, true))
                    end

                    if token.kind == "lua_statement" or token.kind == "lua_function" then
                        table.insert(result, token.closing_token.value)
                    elseif token.kind == "lua_call" then
                        table.insert(result, plume.lua_syntax.call_end)
                    elseif token.kind == "lua_index" then
                        table.insert(result, plume.lua_syntax.index_end)
                    elseif token.kind == "lua_table" then
                        table.insert(result, plume.lua_syntax.table_end)
                    end
                end

                if can_return then
                    if is_expression then
                        table.insert(result, 1, "return ")
                    end
                end

                return table.concat(result, "")
            end,

            --- @api_method Render the tokenlist and return true if it is empty
            -- @return bool Is the tokenlist empty?
            is_empty = function (self)
                local scope = plume.get_scope (self.context)
                local show_deprecation_warnings = scope:get("config", "show_deprecation_warnings")
                if show_deprecation_warnings then
                    plume.warning_deprecated_method (self, 'token:is_empty()', "0.15.0", "Use :string or :ref + render(), and then checks the length.")
                end
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
end