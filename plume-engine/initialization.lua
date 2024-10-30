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

-- Initialisation of Plume - TextEngine

plume._LUA_VERSION = _VERSION
-- Save all lua standard functions to be available from "eval" macros
local lua_std_functions

if _VERSION == "Lua 5.1" then
    if jit then
        plume._LUA_VERSION = "Lua jit"
        lua_std_functions = "_VERSION assert bit collectgarbage coroutine debug dofile error gcinfo getfenv getmetatable io ipairs jit load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset require select setfenv setmetatable string table tonumber tostring type unpack xpcall"
    else
        lua_std_functions = "_VERSION assert collectgarbage coroutine debug dofile error gcinfo getfenv getmetatable io ipairs load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset require select setfenv setmetatable string table tonumber tostring type unpack xpcall"
    end
elseif _VERSION == "Lua 5.2" then
    lua_std_functions = "_VERSION assert bit32 collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile loadstring math module next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type unpack xpcall"
elseif _VERSION == "Lua 5.3" then
    lua_std_functions = "_VERSION assert bit32 collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile math next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type utf8 xpcall"
elseif _VERSION == "Lua 5.4" then
    lua_std_functions = "_VERSION assert collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile math next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type utf8 warn xpcall"
end

plume.lua_std_functions = {}
for name in lua_std_functions:gmatch('%S+') do
    plume.lua_std_functions[name] = _G[name]
end

--- Resets or initializes all session-specific tables.
function plume.init ()
    -- A table that contain
    -- all local scopes.
    plume.scopes = {}

    -- Create the first local scope
    -- (indeed, the global one)
    local global_scope = plume.push_scope ()

    --- @scope_variable _G Globale table of variables.
    global_scope:set("variables", "_G", global_scope:bridge_to("variables"))

    -- Used to pass temp variable
    plume.temp = {}
    
    -- Init methods that are visible from user
    plume.init_api ()

    -- Cache lua code to not
    -- call "load" multiple times
    -- for the same chunk
    plume.lua_cache    = {}

    -- Track number of chunks,
    -- To assign a number of each
    -- of them.
    plume.chunk_count = 0

    -- Used to store call to plume.write
    plume.write_stack = {}
        
    -- Add all std function into
    -- global scope
    for k, v in pairs(plume.lua_std_functions) do
        global_scope:set("variables", k, v)
    end

    -- Initialise configuration
    for k, v in pairs(plume.config) do
        global_scope:set("config", k, v)
    end

    plume.load_macros()

    -- Deprecate
    -- plume.deprecate("name", "version removal", "alternative")

    -- Warning cache
    plume.warning_cache = {}

    -- Initialise error tracing
    plume.last_error = nil
    plume.traceback = {}
end