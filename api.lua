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

-- Manage methods that are visible from user
local api = {}

--- @api_variable Version of plume.
api._VERSION = plume._VERSION
--- @api_variable Lua version compatible with this plume distribution.
api._LUA_VERSION = plume._LUA_VERSION

--- @api_method Capture the local _lua_ variable and save it in the _plume_ local scope. This is automatically called by plume at the end of `$` block in statement-mode.
-- @note Mainly internal use, you shouldn't use this function.
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

--- @api_method Searches for a file using the [plume search system](macros.md#include) and open it in the given mode. Return the opened file and the full path of the file.
-- @param path string The path where to search for the file.
-- @param open_mode="r" string Mode to open the file.
-- @param silent_fail=false boolean If true, the search will not raise an error if no file is found.
-- @return file The file found during the search, opened in the given mode.
-- @return founded_path The path of the file founded.
function api.open (path, open_mode, silent_fail)
    return plume.open (nil, {"?"}, path, open_mode, silent_fail)
end

--- @api_method Get a variable value by name in the current scope.
-- @param key string The variable name.
-- @return value The required variable.
-- @note `plume.get` may return a tokenlist, so may have to call `plume.get (name):render ()` or `plume.get (name):renderLua ()`. See [get_render](#get_render) and [get_renderLua](#get_renderLua).
function api.get (key)
    return plume.current_scope().variables[key]
end

--- @api_method Get a variable value by name in the current scope. If the variable has a render method (see [render](#render)), call it and return the result. Otherwise, return the variable.
-- @param key string The variable name
-- @alias getr
-- @return value The required variable.
function api.get_render (key)
    local result = plume.current_scope().variables[key]
    if type(result) == table and result.render then
        return result:render ()
    else
        return result
    end
end
api.getr = api.get_render

--- @api_method Get a variable value by name in the current scope. If the variable has a renderLua method (see [renderLua](#renderLua)), call it and return the result. Otherwise, return the variable.
-- @param key string The variable name
-- @alias lget
-- @return value The required variable.
function api.lua_get (key)
    local result = plume.current_scope().variables[key]
    if type(result) == table and result.renderLua then
        return result:renderLua ()
    else
        return result
    end
end
api.lget = api.lua_get

-- To remove in 1.0   --
api.setl = api.set_local
------------------------

--- @api_method Works like Lua's require, but uses Plume's file search system.
-- @param path string Path of the lua file to load
-- @return lib The require lib
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

--- @api_method Create a macro from a lua function.
-- @param name string Name of the macro
-- @param arg_number Number of paramters to capture
-- @param f function
-- @param is_local bool Is the new macro local?
function api.export(name, params_number, f, is_local)
    local def_params = {}
    for i=1, params_number do
        table.insert(def_params, "x"..i)
    end
    plume.register_macro(name, def_params, {}, function (params)
        local rparams = {}
        for i=1, params_number do
            rparams[i] = params.positionnals['x' .. i]:render()
        end
        -- <Lua 5.1>
        if _VERSION == "Lua 5.1" then
            return f(unpack(rparams))
        end
        -- </Lua>
        -- <Lua 5.2 5.3 5.4>
        if _VERSION == "Lua 5.2" or _VERSION == "Lua 5.3" or _VERSION == "Lua 5.4" then
            return f(table.unpack(rparams))
        end
        -- </Lua>
    end, nil, is_local)
end

--- @api_method Create a local macro from a lua function.
-- @param name string Name of the macro
-- @param arg_number Number of paramters to capture
-- @param f function
-- @param is_local bool Is the new macro local?
function api.export_local(name, params_number, f)
    api.export(name, params_number, f, true)
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