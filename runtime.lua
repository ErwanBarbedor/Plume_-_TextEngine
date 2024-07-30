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

-- A table that contain
-- all local environnements.
txe.lua_envs = {}

-- Cache lua code to not
-- call "load" multiple times
-- for the same chunck
txe.lua_cache    = {}

-- Track number of chunck,
-- To assign a number of each
-- of them.
txe.chunck_count = 0

-- Define 'load' function for Lua 5.1 compatibility
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

    -- print(token, token.frozen_env)

    if not txe.lua_cache[code] then
        --put chunck ref in the code, to retrieve it
        --in case of error
        txe.chunck_count = txe.chunck_count + 1
        code = "--token" .. txe.chunck_count .. "\n" .. code
        
        local loaded_func, load_err
        local chunck_env = token.frozen_env or txe.lua_envs[#txe.lua_envs]
        -- local chunck_env = txe.lua_envs[#txe.lua_envs]
        loaded_func, load_err = txe.load_lua_chunck(code, nil, "bt", chunck_env)

        if not loaded_func then
            load_err = load_err:gsub('^.-%]:[0-9]+:', '')
            txe.error(token, "(Lua syntax error)" .. load_err)
        end
        
        txe.lua_cache[code] = setmetatable({
            token=token,
            chunck_count=chunck_count 
        },{
            __call = function ()
                return loaded_func()
            end
        })
    end

    local result = { pcall(txe.lua_cache[code]) }
    local sucess = result[1]
    table.remove(result, 1)
    if not sucess then
        err = result[1]:gsub('^.-%]:[0-9]+:', '')
        txe.error(token, "(Lua error)" .. err)
    end

    return (table.unpack or unpack)(result)
end

function txe.freeze_lua_env (args)
    -- Each arg keep a reference to current lua env

    local last_env = txe.lua_envs[#txe.lua_envs] 
    for k, v in pairs(args) do
        if k ~= "..." then
            v:freeze_lua_env (last_env)
        end
    end
    for k, v in pairs(args["..."]) do
        v:freeze_lua_env (last_env)
    end
end

function txe.new_env (parent)
    return setmetatable({}, {
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

function txe.push_env ()
    -- Create a new environment with the 
    -- penultimate environment as parent.
    -- Keep a reference of it inside alive_env
    local last_env = txe.lua_envs[#txe.lua_envs]
    local new_env = txe.new_env (last_env)

    table.insert(txe.lua_envs, new_env)
end

function txe.pop_env ()
    -- Remove last create environnement
    -- Remove it also from alive_env
    table.remove(txe.lua_envs)
end

function txe.lua_env_set_local (key, value, env)
    -- Register a variable locally
    -- If not provided, "env" is the last created.
    local env = env or txe.lua_envs[#txe.lua_envs] 
    rawset (env, key, value)
end

function txe.purge_env ()
    txe.lua_envs = {}
    alive_envs = {}
    txe.push_env ()
end
txe.push_env ()

-- Save all lua standard functions to be available from "eval" macros
local lua_std_functions
if _VERSION == "Lua 5.1" then
    if jit then
        lua_std_functions = "math package arg module require assert string table type next pairs ipairs getmetatable setmetatable getfenv setfenv rawget rawset rawequal unpack select tonumber tostring error pcall xpcall loadfile load loadstring dofile gcinfo collectgarbage newproxy print _VERSION coroutine jit bit debug os io"
    else
        lua_std_functions = "string xpcall package tostring print os unpack require getfenv setmetatable next assert tonumber io rawequal collectgarbage arg getmetatable module rawset math debug pcall table newproxy type coroutineselect gcinfo pairs rawget loadstring ipairs _VERSION dofile setfenv load error loadfile"
    end
else -- Assume version is 5.4
    lua_std_functions = "load require error os warn ipairs collectgarbage package rawlen utf8 coroutine xpcall math select loadfile next rawget dofile table tostring _VERSION tonumber io pcall print setmetatable string debug arg assert pairs rawequal getmetatable type rawset"
end

txe.lua_std = {}
for name in lua_std_functions:gmatch('%S+') do
    txe.lua_std[name] = _G[name]
end

function txe.init_lua ()
    for k, v in pairs(txe.lua_std) do
        txe.lua_envs[1][k] = v
    end
end
txe.init_lua ()

function txe.reset ()
    -- Remove all session specific data
    txe.purge_env ()
    txe.macros = {}
    for k, v in pairs(txe.std_macros) do
        txe.macros[k] = v
    end
    txe.init_lua ()

    txe.last_error = nil
    txe.traceback = {}
end