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

--- Loads a Lua chunk with compatibility for Lua 5.1.
-- @param code string The Lua code to load
-- @param _ nil Unused parameter
-- @param _ nil Unused parameter
-- @param env table The environment to load the chunk in
-- @return function|nil, string The loaded function or nil and an error message
if _VERSION == "Lua 5.1" or jit then
    function plume.load_lua_chunk (code, _, _, env)
        local f, err = loadstring(code)
        if f then
            setfenv(f, env)
        end
        return f, err
    end
else
    plume.load_lua_chunk = load
end

--- Evaluates a Lua expression and returns the result.
-- @param token table The token containing the expression
-- @param code string The Lua code to evaluate (optional)
-- @return any The result of the evaluation
function plume.eval_lua_expression (token, code)
    code = code or token:source ()
    code = 'return ' .. code

    return plume.call_lua_chunk (token, code)
end

--- Loads, caches, and executes Lua code.
-- @param token table The token containing the code
-- or, if code is given, token used to throw error
-- @param code string The Lua code to execute (optional)
-- @return any The result of the execution
function plume.call_lua_chunk(token, code)
    code = code or token:source ()

    if not plume.lua_cache[code] then
        -- Put the chunk number in the code,
        -- to retrieve it in case of error.
        -- A bit messy, but each chunk executes
        -- in its own environment, even if they
        -- share the same code. A more elegant
        -- solution certainly exists,
        -- but this does the trick for now.
        plume.chunk_count = plume.chunk_count + 1
        code = "--chunk" .. plume.chunk_count .. "\n" .. code
        
        -- If the token is locked in a specific
        -- scope, execute inside it.
        -- Else, execute inside current scope.
        local chunk_scope = token.context or plume.current_scope ()
        local loaded_function, load_err = plume.load_lua_chunk(code, nil, "bt", chunk_scope)

        -- If loading chunk failed
        if not loaded_function then
            -- save it in the cache anyway, so
            -- that the error handler can find it 
            plume.lua_cache[code] = {token=token, chunk_count=plume.chunk_count}
            plume.error(token, load_err, true)
        end

        plume.lua_cache[code] = setmetatable({
            token=token,
            chunk_count=plume.chunk_count
        },{
            __call = function ()
                return { xpcall (loaded_function, plume.error_handler) }
            end
        })
    end

    local result = plume.lua_cache[code] ()
    local sucess = result[1]
    table.remove(result, 1)

    if not sucess then
        plume.error(token, result[1], true)
    end

    -- Lua 5.1 compatibility
    return (table.unpack or unpack)(result)
end

--- Creates a new scope with the given parent.
-- @param parent table The parent scope
-- @return table The new scope
function plume.create_scope (parent)
    local scope = {}
    -- Add a self-reference
    scope.__scope = scope

    return setmetatable(scope, {
        __index = function (self, key)
            -- Return registered value.
            -- If value is nil, recursively
            -- call parent
            local value = rawget(self, key)
            if value then
                return value
            elseif parent then
                return parent[key]
            end
        end,
        __newindex = function (self, key, value)
            -- Register new value
            -- if has parent, send value to parent.
            -- else, register it
            if parent then
                parent[key] = value
            else
                rawset(self, key, value)
            end
        end,
    })
end

--- Creates a new scope with the penultimate scope as parent.
function plume.push_scope ()
    local last_scope = plume.current_scope ()
    local new_scope = plume.create_scope (last_scope)

    table.insert(plume.scopes, new_scope)
end

--- Removes the last created scope.
function plume.pop_scope ()
    table.remove(plume.scopes)
end

--- Registers a variable locally in the given scope.
-- If not given scope, will use the current scope.
-- @param key string The key to set
-- @param value any The value to set
-- @param scope table The scope to set the variable in (optional)
function plume.scope_set_local (key, value, scope)
    -- Register a variable locally
    -- If not provided, "scope" is the last created.
    local scope = scope or plume.current_scope ()
    rawset (scope, key, value)
end

--- Returns the current scope.
-- @return table The current scope
function plume.current_scope ()
    return plume.scopes[#plume.scopes]
end