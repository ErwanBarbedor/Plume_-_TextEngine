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

-- Define a 'load' function for Lua 5.1 compatibility
if _VERSION == "Lua 5.1" or jit then
    function txe.load_lua_chunck (code, _, _, env)
        local f, err = loadstring(code)
        if f then
            setfenv(f, env)
        end
        return f, err
    end
else
    txe.load_lua_chunck = load
end

function txe.eval_lua_expression (token, code)
    -- Evaluation the given lua code
    -- and return the result.
    -- This result is cached.
    code = code or token:source ()
    code = 'return ' .. code

    return txe.call_lua_chunck (token, code)
end

function txe.call_lua_chunck(token, code)
    -- Load, cache and execute code
    -- find in the given token or string.
    -- If the string is given, token is use only
    -- to throw error.

    code = code or token:source ()

    if not txe.lua_cache[code] then
        -- Put the chunck number in the code,
        -- to retrieve it in case of error
        txe.chunck_count = txe.chunck_count + 1
        code = "--chunck" .. txe.chunck_count .. "\n" .. code
        
        -- If the token is locked in a specific
        -- scope, execute inside it.
        -- Else, execute inside current scope.
        local chunck_scope = token.frozen_scope or txe.current_scope ()
        local loaded_function, load_err = txe.load_lua_chunck(code, nil, "bt", chunck_scope)

        -- If loading the chunck failling, remove file
        -- information from the message and throw the error.
        if not loaded_function then
            txe.error(token, load_err, true, code)
        end

        txe.lua_cache[code] = setmetatable({
            token=token,
            chunck_count=txe.chunck_count
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

function txe.push_scope ()
    -- Create a new scope with the 
    -- penultimate scope as parent.
    local last_scope = txe.current_scope ()
    local new_scope = txe.create_scope (last_scope)

    table.insert(txe.scopes, new_scope)
end

function txe.pop_scope ()
    -- Remove last create scope
    table.remove(txe.scopes)
end

function txe.scope_set_local (key, value, scope)
    -- Register a variable locally
    -- If not provided, "scope" is the last created.
    local scope = scope or txe.current_scope ()
    rawset (scope, key, value)
end

function txe.current_scope ()
    return txe.scopes[#txe.scopes]
end