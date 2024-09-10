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

-- <Lua 5.1>
if _VERSION == "Lua 5.1" then
    if jit then
        plume._LUA_VERSION = "Lua jit"
        lua_std_functions = "math package arg module require assert string table type next pairs ipairs getmetatable setmetatable getfenv setfenv rawget rawset rawequal unpack select tonumber tostring error pcall xpcall loadfile load loadstring dofile gcinfo collectgarbage newproxy print _VERSION coroutine jit bit debug os io"
    else
        lua_std_functions = "string xpcall package tostring print os unpack require getfenv setmetatable next assert tonumber io rawequal collectgarbage arg getmetatable module rawset math debug pcall table newproxy type coroutine select gcinfo pairs rawget loadstring ipairs _VERSION dofile setfenv load error loadfile"
    end
end
-- </Lua 5.1>
-- <Lua 5.2>
if _VERSION == "Lua 5.2" then
    lua_std_functions = "setmetatable print unpack type table bit32 error loadstring pairs package select require io module debug math tonumber loadfile dofile os rawequal rawget next collectgarbage rawlen assert rawset pcall coroutine xpcall tostring ipairs string load getmetatable _VERSION"
end
-- </Lua 5.2>
-- <Lua 5.3>
if _VERSION == "Lua 5.3" then
    lua_std_functions = "coroutine print loadfile assert dofile next io setmetatable string os ipairs require getmetatable rawequal select type pcall collectgarbage _VERSION pairs bit32 debug package rawlen math error load rawset rawget table utf8 tonumber tostring xpcall"
end
-- </Lua 5.3>
-- <Lua 5.4>
if _VERSION == "Lua 5.4" then
    lua_std_functions = "load require error os warn ipairs collectgarbage package rawlen utf8 coroutine xpcall math select loadfile next rawget dofile table tostring _VERSION tonumber io pcall print setmetatable string debug arg assert pairs rawequal getmetatable type rawset"
end
-- </Lua 5.4>

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
    plume.push_scope ()

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

    -- Stack of executed files
    plume.file_stack = {}
        
    -- Add all std function into
    -- global scope
    for k, v in pairs(plume.lua_std_functions) do
        plume.scopes[1][k] = v
    end

    -- Add all std macros to
    -- the macro table
    plume.macros = {}
    for k, v in pairs(plume.std_macros) do
        v.user_opt_args = {}
        plume.macros[k] = v
    end

    -- Initialise error tracing
    plume.last_error = nil
    plume.traceback = {}
end