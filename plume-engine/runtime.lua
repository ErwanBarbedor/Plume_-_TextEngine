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

if _VERSION == "Lua 5.1" then
    plume.load_lua_chunk  = loadstring
    plume.setfenv = setfenv
    plume.unpack  = unpack
elseif _VERSION == "Lua 5.2" or _VERSION == "Lua 5.3" or _VERSION == "Lua 5.4" then
    plume.load_lua_chunk = load
    plume.unpack  = table.unpack
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

--- Loads, caches, and executes Lua code.
-- @param token table The token containing the code
-- or, if code is given, token used to throw error
-- @param code string The Lua code to execute (optional)
-- @param filename string If is extern lua code, name of the source file (optionnal)
-- @return any The result of the execution
function plume.call_lua_chunk(token, code, filename)
    -- Used to store references to inserted plume blocks
    local temp = {}
    code = code or token:source_lua (temp)

    if not token.lua_cache then
        -- Edit the code to add a "return", in case of an expression,
        -- or plume.capture_local() at the end in case of statement.
        -- Also put the chunk number in the code, to retrieve it in case of error.
        -- A bit messy, but each chunk executes in its own environment, even if they
        -- share the same code. A more elegant solution certainly exists,
        -- but this does the trick for now.
        plume.chunk_count = plume.chunk_count + 1
        code = "--chunk" .. plume.chunk_count .. '\n' .. code
        
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
            code              = code,
            filename          = filename
        },{
            __call = function ()
                -- The function can write and read variable of the current scope
                local scope = plume.get_scope(token.context)
                plume.setfenv (loaded_function, scope:bridge_to("variables"))

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

    table.insert(plume.write_stack, {})
    local result = token.lua_cache ()

    local sucess = result[1]
    table.remove(result, 1)

    if not sucess then
        plume.error(token, result[1], true)
    end

    return (unpack or table.unpack)(result)
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
            if parent  then
                parent[field_name][key] = value
            else
                rawset(self, key, value)
            end
        end,
    })
end


--- Creates a new scope with the given parent.
-- @param parent scope The parent scope
-- @return table The new scope
function plume.create_scope (parent)
    local scope = {}

    -- Store all variables values, accessibles from user
    make_field (scope, "variables",   parent)
    -- Store references to declared local variables in the current scope,
    -- but with a nil value
    make_field (scope, "nil_local",   parent)
    -- Store macro
    make_field (scope, "macros",      parent)
    -- Store default parameters for macro
    make_field (scope, "default",     parent)
    -- Store configuration
    make_field (scope, "config",      parent)
    -- Store annotations functions
    make_field (scope, "annotations", parent)

    --- Returns all variables of the given field that are visible from this scope.
    -- @param self table The current scope.
    -- @param field string The field from which to retrieve variables.
    -- @return table A table containing all variables from the given field.
    function scope.get_all(self, field)
        local t = {}
        
        for k, _ in pairs(self[field]) do
            table.insert(t, k)
        end

        if field == "variables" then
            for k, _ in pairs(self["nil_local"]) do
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

    --- Registers a variable locally in the given scope
    -- @param key string The key to set
    -- @param value any The value to set
    function scope.set_local(self, field, key, value)
        if value ~= nil then
            rawset (scope[field], key, value)
        else
            -- If the value is nil, keep a reference
            -- '@' is to make the name unique
            rawset (scope["nil_local"], field .. "@" .. key, true)
        end
    end

    --- Registers a variable globaly
    -- @param key string The key to set
    -- @param value any The value to set
    function scope.set(self, field, key, value)
        -- If no parent or if the variable is already registered
        -- save it in this scope
        -- Otherwise send the value to the parent
        if not parent or rawget(scope[field], key) ~= nil or rawget(scope.nil_local, field.."@"..key)  then
            rawset (scope[field], key, value)
        else
            parent:set (field, key, value)
        end
    end

    --- Get the value of a given variable. Return local value if it exists, else search recursively in parents
    -- @param key string The key to set
    -- @param value any The value to set
    function scope.get(self, field, key)
        -- If the value is nil, recursively call the parent.
        local value = rawget(scope[field], key)

        if value ~= nil or rawget(scope.nil_local, field.."@"..key) then
            return value
        elseif parent then
            return parent:get(field, key)
        end
    end

    --- Creates a bridge object to interact with a specific scope field as table
    -- @param field string The name of the field in the scope to bridge to
    function scope.bridge_to(self, field)
        return setmetatable({}, {
            __newindex = function(self, key, value)
                scope:set(field, key, value)
            end,

            __index = function(self, key)
                return scope:get(field, key)
            end
        })
    end

    return scope
end

--- Creates a new scope with the penultimate scope as parent.
function plume.push_scope (scope)
    local last_scope = plume.get_scope ()
    local new_scope = plume.create_scope (scope or last_scope)

    table.insert(plume.scopes, new_scope)

    return new_scope
end

--- Removes the last created scope.
function plume.pop_scope ()
    table.remove(plume.scopes)
end

--- Returns the current scope or, if not nil, the scope given as a parameter.
-- @param scope table Return this scope if not nil
-- @return table The current scope
function plume.get_scope (scope)
    return scope or plume.scopes[#plume.scopes]
end

