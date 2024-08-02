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
    function txe.load_lua_chunk (code, _, _, env)
        local f, err = loadstring(code)
        if f then
            setfenv(f, env)
        end
        return f, err
    end
else
    txe.load_lua_chunk = load
end

--- Evaluates a Lua expression and returns the result.
-- @param token table The token containing the expression
-- @param code string The Lua code to evaluate (optional)
-- @return any The result of the evaluation
function txe.eval_lua_expression (token, code)
    code = code or token:source ()
    code = 'return ' .. code

    return txe.call_lua_chunk (token, code)
end

--- Loads, caches, and executes Lua code.
-- @param token table The token containing the code
-- or, if code is given, token used to throw error
-- @param code string The Lua code to execute (optional)
-- @return any The result of the execution
function txe.call_lua_chunk(token, code)
    code = code or token:source ()

    if not txe.lua_cache[code] then
        -- Put the chunk number in the code,
        -- to retrieve it in case of error.
        -- A bit messy, but each chunk executes
        -- in its own environment, even if they
        -- share the same code. A more elegant
        -- solution certainly exists,
        -- but this does the trick for now.
        txe.chunk_count = txe.chunk_count + 1
        code = "--chunk" .. txe.chunk_count .. "\n" .. code
        
        -- If the token is locked in a specific
        -- scope, execute inside it.
        -- Else, execute inside current scope.
        local chunk_scope = token.frozen_scope or txe.current_scope ()
        local loaded_function, load_err = txe.load_lua_chunk(code, nil, "bt", chunk_scope)

        -- If loading chunk failed
        if not loaded_function then
            -- save it in the cache anyway, so
            -- that the error handler can find it 
            txe.lua_cache[code] = {token=token, chunk_count=txe.chunk_count}
            txe.error(token, load_err, true)
        end

        txe.lua_cache[code] = setmetatable({
            token=token,
            chunk_count=txe.chunk_count
        },{
            __call = function ()
                return { xpcall (loaded_function, txe.error_handler) }
            end
        })
    end

    local result = txe.lua_cache[code] ()
    local sucess = result[1]
    table.remove(result, 1)

    if not sucess then
        txe.error(token, result[1], true)
    end

    -- Lua 5.1 compatibility
    return (table.unpack or unpack)(result)
end

--- Adds a reference to the current scope in each argument.
-- @param args table The arguments to freeze
function txe.freeze_scope (args)
    -- Add a reference to current scope
    -- in each arg.

    local last_scope = txe.current_scope ()
    for k, v in pairs(args) do
        if k ~= "__args" then
            v:freeze_scope (last_scope)
        end
    end
    for k, v in ipairs(args.__args) do
        v:freeze_scope (last_scope)
    end
end

--- Creates a new scope with the given parent.
-- @param parent table The parent scope
-- @return table The new scope
function txe.create_scope (parent)
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
            -- Only if no parent has it
            if (parent and not parent[key]) or not parent then
                rawset(self, key, value)
            elseif parent then
                parent[key] = value
            end
        end,
    })
end

--- Creates a new scope with the penultimate scope as parent.
function txe.push_scope ()
    local last_scope = txe.current_scope ()
    local new_scope = txe.create_scope (last_scope)

    table.insert(txe.scopes, new_scope)
end

--- Removes the last created scope.
function txe.pop_scope ()
    table.remove(txe.scopes)
end

--- Registers a variable locally in the given scope.
-- If not given scope, will use the current scope.
-- @param key string The key to set
-- @param value any The value to set
-- @param scope table The scope to set the variable in (optional)
function txe.scope_set_local (key, value, scope)
    -- Register a variable locally
    -- If not provided, "scope" is the last created.
    local scope = scope or txe.current_scope ()
    rawset (scope, key, value)
end

--- Returns the current scope.
-- @return table The current scope
function txe.current_scope ()
    return txe.scopes[#txe.scopes]
end