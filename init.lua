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

-- Save all lua standard functions to be available from "eval" macros
local lua_std_functions
if _VERSION == "Lua 5.1" then
    if jit then
        lua_std_functions = "math package arg module require assert string table type next pairs ipairs getmetatable setmetatable getfenv setfenv rawget rawset rawequal unpack select tonumber tostring error pcall xpcall loadfile load loadstring dofile gcinfo collectgarbage newproxy print _VERSION coroutine jit bit debug os io"
    else
        lua_std_functions = "string xpcall package tostring print os unpack require getfenv setmetatable next assert tonumber io rawequal collectgarbage arg getmetatable module rawset math debug pcall table newproxy type coroutineselect gcinfo pairs rawget loadstring ipairs _VERSION dofile setfenv load error loadfile"
    end
else -- Assume version is 5.4
    if _VERSION ~= "Lua 5.4" then
        print("Warning : unsuported version '" .. _VERSION .. "'.")
    end
    lua_std_functions = "load require error os warn ipairs collectgarbage package rawlen utf8 coroutine xpcall math select loadfile next rawget dofile table tostring _VERSION tonumber io pcall print setmetatable string debug arg assert pairs rawequal getmetatable type rawset"
end

txe.lua_std_functions = {}
for name in lua_std_functions:gmatch('%S+') do
    txe.lua_std_functions[name] = _G[name]
end

function txe.init ()
    -- Reset or initialise all
    -- sessions specifics table

    -- A table that contain
    -- all local scopes.
    txe.scopes = {}

    -- Create the first local scope
    -- (indeed, the global one)
    txe.push_scope ()

    -- Cache lua code to not
    -- call "load" multiple times
    -- for the same chunck
    txe.lua_cache    = {}

    -- Track number of chunck,
    -- To assign a number of each
    -- of them.
    txe.chunck_count = 0
        
    -- Add all std function into
    -- global scope
    for k, v in pairs(txe.lua_std_functions) do
        txe.scopes[1][k] = v
    end

    -- Add all std macros to
    -- the macro table
    txe.macros = {}
    for k, v in pairs(txe.std_macros) do
        txe.macros[k] = v
    end

    -- Initialise error tracing
    txe.last_error = nil
    txe.traceback = {}
end