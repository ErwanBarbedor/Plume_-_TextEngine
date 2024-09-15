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

--- Evaluates a Lua expression and returns the result.
-- @param token table The token containing the expression
-- @param code string The Lua code to evaluate (optional)
-- @param filename string If is extern lua code, name of the source file (optionnal)
-- @return any The result of the evaluation
function plume.eval_lua_expression (token, code, filename)
    code = code or token:source ()
    code = 'return ' .. code

    return plume.call_lua_chunk (token, code, filename)
end

--- Call Lua Statements
-- This function executes Lua statements provided in a token or code string.
-- @param token table The token containing the source Lua code.
-- @param code string Optional. The Lua code to be executed. If not provided, the code will be extracted from the token's source.
-- @param filename string If is extern lua code, name of the source file (optionnal)
-- @return any The result of executing the Lua chunk.
function plume.call_lua_statements (token, code, filename)
    code = code or token:source()

    -- Script cannot return value
    local end_code = code:gsub('%s+$', ''):match('[^;\n]-$')
    if end_code and end_code:match('^%s*return') then
        plume.error(token, "\\script cannot return value.")
    end

    -- Add function to capture local variables at the end of the provided code.
    code = code .. "\nplume.capture_local()"

    -- Call the modified Lua chunk using the plume module.
    return plume.call_lua_chunk(token, code, filename)
end


--- Loads, caches, and executes Lua code.
-- @param token table The token containing the code
-- or, if code is given, token used to throw error
-- @param code string The Lua code to execute (optional)
-- @param filename string If is extern lua code, name of the source file (optionnal)
-- @return any The result of the execution
function plume.call_lua_chunk(token, code, filename)
    code = code or token:source ()

    if not token.lua_cache then
        -- Put the chunk number in the code,
        -- to retrieve it in case of error.
        -- A bit messy, but each chunk executes
        -- in its own environment, even if they
        -- share the same code. A more elegant
        -- solution certainly exists,
        -- but this does the trick for now.
        plume.chunk_count = plume.chunk_count + 1
        code = "--chunk" .. plume.chunk_count .. "\n" .. code
        
        -- Load the code
        local loaded_function, load_err = plume.load_lua_chunk(code)

        -- In case of syntax error
        if not loaded_function then
            -- save it in the cache anyway, so
            -- that the error handler can find it 
            token.lua_cache = {code=code, filename=filename}
            table.insert(plume.lua_cache, token)
            plume.error(token, load_err, true)
        end

        local chunck = setmetatable({
            code=code,
            filename=filename
        },{
            __call = function ()
                -- If the token is locked in a specific
                -- scope, execute inside it.
                -- Else, execute inside current scope.
                local chunk_scope = plume.current_scope (token.context)
                plume.setfenv (loaded_function, chunk_scope.variables)

                return { xpcall (loaded_function, plume.error_handler) }
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

    make_field (scope, "variables", parent, source)
    make_field (scope, "macros", parent, source)

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

    return scope
end

--- Creates a new scope with the penultimate scope as parent.
function plume.push_scope (scope)
    local last_scope = plume.current_scope ()
    local new_scope = plume.create_scope (last_scope, scope)

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

