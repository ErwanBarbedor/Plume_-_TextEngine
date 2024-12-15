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
--- @api_variable Hook to the internal `plume` table, for experimented users.
api.engine   = plume

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
-- @note `plume.get` may return a tokenlist, so may have to call `plume.get (name):render ()` or `plume.get (name):render_lua ()`. See [get_render](#get_render) and [get_render_lua](#get_render_lua).
function api.get (key)
    local scope = plume.get_scope()
    return scope:get("variables", key)
end

--- @api_method Get a variable value by name in the current scope. If the variable has a render method (see [render](#render)), call it and return the result. Otherwise, return the variable.
-- @param key string The variable name
-- @alias getr
-- @return value The required variable.
function api.get_render (key)
    local scope = plume.get_scope()
    local result = scope:get("variables", key)
    if type(result) == table and result.render then
        return result:render ()
    else
        return result
    end
end
api.getr = api.get_render

--- @api_method Get a variable value by name in the current scope. If the variable has a render_lua method (see [render_lua](#render_lua)), call it and return the result. Otherwise, return the variable.
-- @param key string The variable name
-- @alias lget
-- @return value The required variable.
function api.get_lua (key)
    local scope = plume.get_scope()
    local result = scope:get("variables", key)
    if type(result) == table and result.render_lua then
        return result:render_lua ()
    else
        return result
    end
end

--- @api_method Sets a global variable in the current scope.
-- @param key string The key for the variable to set.
-- @param value any The value to associate with the key.
function api.set(key, value)
    local scope = plume.get_scope()
    scope:set("variables", key, value)
end

--- @api_method Sets a local variable in the current scope.
-- @param key string The key for the local variable to set.
-- @param value any The value to associate with the key.
function api.local_set(key, value)
    local scope = plume.get_scope()
    scope:set_local("variables", key, value)
end

api.lset = api.local_set

--- Calls a macro with the specified name and optional parameters.
-- @param name string The name of the macro to call.
-- @param positionals table A table of positional parameters for the macro.
-- @param optionals table A table of optional parameters for the macro.
-- @return any The result of the macro call.
function api.call_macro(name, positionals, optionals)
    local scope = plume.get_scope()
    local macro = scope:get("macros", name)

    local params = plume.init_macro_params()

    positionals = positionals or {}
    optionals = optionals or {}

    for index, name in ipairs(macro.params) do
        params.positionals[name] = positionals[index]
    end

    for name, value in pairs(optionals) do
         if macro.default_opt_params[name] == nil then
            if macro.variable_parameters_number then
                params.others.keywords[name] = value
            else
                plume.error_unknown_parameter (plume.traceback[#plume.traceback], macro.name, name, macro.default_opt_params)
            end
        else
            params.keywords[name] = value
        end
    end

    local result = plume.call_macro(macro, plume.traceback[#plume.traceback], params)
    return result
end


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
function api.register_macro(name, params_number, f, is_local)
    local macro_params = {}
    for i=1, params_number do
        table.insert(macro_params, "x"..i)
    end
    plume.register_macro(name, macro_params, {}, function (params)
        local rparams = {}
        for i=1, params_number do
            rparams[i] = params.positionals['x' .. i]
        end
        return f(plume.unpack(rparams))
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

--- @api_method Check if we are inside a given macro
-- @param name string the name of the macro
-- @return bool True if we are inside a macro with the given name, false otherwise.
function api.is_called_by (name)
    for i = #plume.traceback, 1, -1 do
        if name == plume.traceback[i].value
            or plume.syntax.escape .. name == plume.traceback[i].value
        then
            return true
        end
    end
    return false
end

function api.warnings_all ()
    local scope = plume.get_scope()
    for warning in (
        [[show_deprecation_warnings 
        show_macro_overwrite_warnings
        show_beginner_warning
        ]]):gmatch('%S+') do
        scope:set("config", warning, true)
    end
end



--- Initializes the API methods visible to the user through `plume` variable.
function plume.init_api ()
    local plume_reference = {}

    local global_scope = plume.get_scope ()
    global_scope:set_local("variables", "plume", plume_reference)

    -- keep a reference to the user `plume` variable
    plume.running_api = plume_reference

    --- Creates field accessors for global and local scopes.
    -- Sets up tables in `plume_reference` allowing field access and modification.
    -- Fields are accessed either in a global context or a local context.
    -- @param field string The name of the field to create accessor functions for.
    local function make_field_access(field)
        -- Create global scope accessor and modifier for the specified field.
        plume_reference[field] = setmetatable({}, {
            __newindex = function(self, k, v)
                global_scope:set(field, k, v)
            end,

            __index = function(self, k)
                return global_scope:get(field, k)
            end
        })

        -- Create local scope accessor and modifier for the specified field.
        plume_reference["local_" .. field] = setmetatable({}, {
            __newindex = function(self, k, v)
                local scope = plume.get_scope()
                scope:set_local(field, k, v)
            end,

            __index = function(self, k)
                local scope = plume.get_scope()
                return scope:get(field, k)
            end
        })

        -- Create an alias for local
        plume_reference["l" .. field] = plume_reference["local_" .. field]
    end


    for k, v in pairs(api) do
        plume_reference[k] = v
    end

    -- User can edit configuration and annotations,
    -- locally and globally, through a table
    make_field_access ("config")
    make_field_access ("annotations")

    -- Used to pass temp variable
    plume_reference.temp = setmetatable({},
        {
            __index    = plume.temp,
            __newindex = function ()
                error ("Cannot write 'plume.temp'")
            end
        }
    )

    -- Import annotations
    require "plume-engine.annotations" (global_scope)

    -- Add deprecations
    -- plume.deprecate (name, version, alternative)
end

