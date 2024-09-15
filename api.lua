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

-- Manage methods that are visible from user (not much for now)
local api = {}

api._VERSION = plume._VERSION
api._LUA_VERSION = plume._LUA_VERSION

--- Captures and stores all local variables
-- in the current scope.
function api.capture_local()
    local index = 1
    local calling_token = plume.traceback[#plume.traceback]
    while true do
        local key, value = debug.getlocal(2, index)
        if key then
            plume.current_scope (calling_token.context):set_local("variables", key, value)
        else
            break
        end
        index = index + 1 
    end
end

--- Searches for a file in the given path and open it in the given mode.
-- @param path string The path where to search for the file.
-- @param safe_mode boolean If true, the search will not raise an error if no file is found.
-- @param open_mode boolean Defaut "r". Mode to open the file.
-- @return file The file found during the search.
-- @return fpath string The path of the file found.
function api.open (path, open_mode, silent_fail)
    return plume.open (nil, {"?"}, path, open_mode, silent_fail)
end

--- Get a variable value by name
-- @param key string
-- @param value string
function api.get (key)
    return plume.current_scope().variables[key]
end

--- Shortcut for api.get(key):render ()
-- @param key string
-- @param value string
function api.get_render (key)
    local result = plume.current_scope().variables[key]
    if type(result) == table and result.render then
        return result:render ()
    else
        return result
    end
end
--- Alias to api.get_render
api.getr = api.get_render

--- Shortcut for api.get(key):renderLua ()
-- @param key string
-- @param value string
function api.lua_get (key)
    local result = plume.current_scope().variables[key]
    if type(result) == table and result.renderLua then
        return result:renderLua ()
    else
        return result
    end
end
--- Alias to api.get_renderLua
api.lget = api.lua_get

--- Alias for api.set_local
-- @see api.set_local
api.setl = api.set_local

--- Require a lua file
-- @param path string
-- @return table|bool|nil
function api.require (path)
    local file, filepath, error_message = plume.open (nil, {"?.lua", "?/init.lua"}, path, "r", true)
    if file then
        file:close ()
        filepath = filepath:gsub('%.lua$', '')
        return require(filepath)
    else
        error(error_message, 2)
    end
end

--- Export a lua function as a macro.
-- @param name string Name of the macro (optionnal)
-- @param arg_number Number of arguments to capture
-- @param f function

function api.export(name, arg_number, f)
    local def_args = {}
    for i=1, arg_number do
        table.insert(def_args, "x"..i)
    end
    plume.register_macro(name, def_args, {}, function (args)
        local rargs = {}
        for i=1, arg_number do
            rargs[i] = args['x' .. i]:render()
        end
        -- <Lua 5.1>
        if _VERSION == "Lua 5.1" then
            return f(unpack(rargs))
        end
        -- </Lua>
        -- <Lua 5.2 5.3 5.4>
        if _VERSION == "Lua 5.2" or _VERSION == "Lua 5.3" or _VERSION == "Lua 5.4" then
            return f(table.unpack(rargs))
        end
        -- </Lua>
    end)
end

--- Initializes the API methods visible to the user.
function plume.init_api ()
    local scope = plume.current_scope ().variables
    scope.plume = {}

    -- keep a reference
    plume.running_api = scope.plume

    for k, v in pairs(api) do
        scope.plume[k] = v
    end

    scope.plume.config = {}
    for k, v in pairs(plume.config) do
        scope.plume.config[k] = v
    end
end