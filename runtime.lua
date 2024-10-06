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

-- Manage scopes and runtime lua executions


-- <Lua 5.1>
if _VERSION == "Lua 5.1" then
    plume.load_lua_chunk  = loadstring
    plume.setfenv = setfenv
end
-- </Lua>
-- <Lua 5.2 5.3 5.4>
if _VERSION == "Lua 5.2" or _VERSION == "Lua 5.3" or _VERSION == "Lua 5.4" then
    plume.load_lua_chunk = load

    --- Sets the environment of a given function.
    -- Uses the debug library to achieve setfenv functionality
    -- by modifying the _ENV upvalue of the function.
    -- @param func function The function whose environment is to be set.
    -- @param env table The new environment table to be set for the function.
    -- @return The function with the modified environment.
    function plume.setfenv(func, env)
        -- Initialize the upvalue index to 1
        local i = 1

        -- Iterate through the upvalues of the function
        while true do
            -- Retrieve the name of the upvalue at index i
            local name = debug.getupvalue(func, i)

            -- Check if the current upvalue is _ENV
            if name == "_ENV" then
                -- Use debug.upvaluejoin to set the new environment for _ENV
                debug.upvaluejoin(func, i, (function() return env end), 1)
                break
            -- If there are no more upvalues to check, break the loop
            elseif not name then
                break
            end

            -- Increment the upvalue index
            i = i + 1
        end

        -- Return the function with the updated environment
        return func
    end
end
-- </Lua>

-- This function checks if a given string represents a Lua expression or statement based on its initial keywords.
-- It returns true for expressions and false for statements.
-- @param s The string to check
-- @return boolean
local function is_lua_expression(s)
    local statement_keywords = {
        "if", "local", "for", "while", "repeat", "return", "break", "goto", "do"
    }
    local first_word = s:match("%s*(%S+)")

    for _, keyword in ipairs(statement_keywords) do
        if first_word == keyword then
            return false
        end
    end

    -- any identifier follower by "," or "=" cannot be an expression
    if s:match("^%s*[a-z-A-Z_][%w_%.]-%s*,") then
        return false
    end

    -- any identifier follower by "=" (and not "=") cannot be an expression
    if s:match("^%s*[a-z-A-Z_][%w_%.]-%s*=%s*[^=]") then
        return false
    end

    -- Any string begining with a comment cannot be an expression.
    -- Trick to force statement detection.
    if s:match("^%s*%-%-+") then
        return false
    end

    -- Any string begining with a function declaration cannot be an expression.
    if s:match("^%s*function%s*[a-zA-Z]") then
        return false
    end

    return true
end

--- Loads, caches, and executes Lua code.
-- @param token table The token containing the code
-- or, if code is given, token used to throw error
-- @param code string The Lua code to execute (optional)
-- @param filename string If is extern lua code, name of the source file (optionnal)
-- @return any The result of the execution
function plume.call_lua_chunk(token, code, filename)
    -- Used to store references to inserted plume blocks
    local temp = {}
    code = code or token:sourceLua (temp)

    if not token.lua_cache then
        -- Edit the code to add a "return", in case of an expression,
        -- or plume.capture_local() at the end in case of statement.
        -- Also put the chunk number in the code, to retrieve it in case of error.
        -- A bit messy, but each chunk executes in its own environment, even if they
        -- share the same code. A more elegant solution certainly exists,
        -- but this does the trick for now.
        plume.chunk_count = plume.chunk_count + 1
        local plume_code
        if is_lua_expression (code) then
            code = "--chunk" .. plume.chunk_count .. '\nreturn ' .. code
            plume_code = code
        else
             -- Script cannot return value
            local end_code = code:gsub('%s+$', ''):match('[^;\n]-$')
            if end_code and end_code:match('^%s*return') then
                plume.error(token, "\\script cannot return value.")
            end

            code = "--chunk" .. plume.chunk_count .. '\n' .. code
            -- Add function to capture local variables at the end of the provided code.
            plume_code = code .. "\nplume.capture_local()"
        end
        
        -- Load the given code, without any change
        -- to keep syntax error message
        local loaded_function, load_err = plume.load_lua_chunk(code)
        -- In case of syntax error
        if not loaded_function then
            -- save it in the cache anyway, so
            -- that the error handler can find it 
            token.lua_cache = {code=code, filename=filename}
            table.insert(plume.lua_cache, token)
            plume.error(token, load_err, true)
        end

        -- If no syntax error, load the edited code
        if code ~= plume_code then
            loaded_function, load_err = plume.load_lua_chunk(plume_code)
        end
            

        local chunck = setmetatable({
            code=plume_code,
            filename=filename
        },{
            __call = function ()
                -- If the token is locked in a specific
                -- scope, execute inside it.
                -- Else, execute inside current scope.

                local chunk_scope = plume.current_scope (token.context)
                plume.setfenv (loaded_function, chunk_scope.variables)

                for k, v in pairs(temp) do
                    plume.temp[k] = v
                end

                local result = { xpcall (loaded_function, plume.error_handler) }

                -- Dont remove plume variable for now. May be a memory leak, 
                -- but however function return ${foo} end could not work.
                -- for k, v in pairs(temp) do
                --     plume.temp[k] = nil
                -- end

                return result
            end
        })

        token.lua_cache = chunck
        -- Track the code for debug purpose
        table.insert(plume.lua_cache, token)
    end

    local result = token.lua_cache ()
    local sucess = result[1]
    table.remove(result, 1)

    if not sucess then
        plume.error(token, result[1], true)
    end

    -- <Lua 5.1>
    if _VERSION == "Lua 5.1" then
        return unpack(result)
    end
    -- </Lua>
    -- <Lua 5.2 5.3 5.4>
    if _VERSION == "Lua 5.2" or _VERSION == "Lua 5.3" or _VERSION == "Lua 5.4" then
        return table.unpack (result)
    end
    -- </Lua>
end

--- Creates a scope field
-- @param scope table The scope where the field is created.
-- @param field_name string The name of the field to create.
-- @param parent table The parent table for inheritance.
-- @param source table The source table for raw field access.
local function make_field(scope, field_name, parent, source)
    scope[field_name] = setmetatable({}, {
        __index = function (self, key)
            -- Return the registered value.
            -- If the value is nil, recursively call the parent.
            local value
            if source then
                value = rawget(source[field_name], key)
            else
                value = rawget(self, key)
            end

            if value then
                return value
            elseif parent then
                return parent[field_name][key]
            end
        end,
        __newindex = function (self, key, value)
            -- Register a new value.
            -- If there is a parent and the key does not exist in the source,
            -- send the value to the parent. Otherwise, register it.
            if parent and not (source and rawget(source.variables, key)) then
                parent[field_name][key] = value
            elseif source then
                rawset(source[field_name], key, value)
            else
                rawset(self, key, value)
            end
        end,
    })
end


--- Creates a new scope with the given parent.
-- @param parent scope The parent scope
-- @param source scope An optionnal scope to copy
-- @return table The new scope
function plume.create_scope (parent, source)
    local scope = {}

    -- <DEV>
    if parent then
        scope.__parent = parent
        table.insert(parent.__childs, scope)
    end
    scope.__childs = {}
    -- </DEV>

    -- Store all variables, accessibles from user
    make_field (scope, "variables", parent, source)
    -- Store macro
    make_field (scope, "macros",    parent, source)
    -- Store default parameters for macro
    make_field (scope, "default",   parent, source)
    -- Store configuration
    make_field (scope, "config",    parent, source)

    --- Returns all variables of the given field that are visible from this scope.
    -- @param self table The current scope.
    -- @param field string The field from which to retrieve variables.
    -- @return table A table containing all variables from the given field.
    function scope.get_all(self, field)
        local t = {}
        
        if source then
            for _, k in ipairs(source:get_all(field)) do
                table.insert(t, k)
            end
        else
            for k, _ in pairs(self[field]) do
                table.insert(t, k)
            end
        end

        -- If a parent scope exists, recursively get variables from the parent's field
        if parent then
            for  _, k in ipairs(parent:get_all(field)) do
                table.insert(t, k)
            end
        end

        return t
    end

    --- Registers a variable locally in the given scope.
    -- @param key string The key to set
    -- @param value any The value to set
    function scope.set_local(self, field, key, value)
        rawset (scope[field], key, value)
    end

    --- Registers a variable globaly
    -- @param key string The key to set
    -- @param value any The value to set
    function scope.set(self, field, key, value)
        scope[field][key] = value
    end

    --- @scope_variable _L Local table of variables.
    scope.variables._L = scope.variables

    return scope
end

--- Creates a new scope with the penultimate scope as parent.
function plume.push_scope (scope)
    local last_scope = plume.current_scope ()
    local new_scope = plume.create_scope (scope or last_scope)

    table.insert(plume.scopes, new_scope)
end


--- Removes the last created scope.
function plume.pop_scope ()
    table.remove(plume.scopes)
end

--- Returns the current scope.
-- @param scope table Return this scope if not nil
-- @return table The current scope
function plume.current_scope (scope)
    return scope or plume.scopes[#plume.scopes]
end

