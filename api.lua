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

--- Define a variable locally
-- @param key string
-- @param value string
function api.set_local (key, value)
    txe.scope_set_local (key, value)
end


--- Get a variable value by name
-- @param key string
-- @param value string
function api.get (key)
    return txe.current_scope()[key]
end

--- Shortcut for api.get(key):render ()
-- @param key string
-- @param value string
function api.get_render (key)
    local result = txe.current_scope()[key]
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
function api.get_lua (key)
    local result = txe.current_scope()[key]
    if type(result) == table and result.renderLua then
        return result:renderLua ()
    else
        return result
    end
end
--- Alias to api.get_renderLua
api.getl = api.get_lua

--- Alias for api.set_local
-- @see api.set_local
api.setl = api.set_local

--- Require a lua file
-- @param path string
-- @return table|bool|nil
function api.require (path)
    local file, filepath, error_message = txe.search_for_files (nil, nil, {"?.lua", "?/init.lua"}, path, true)
    if file then
        file:close ()
        filepath = filepath:gsub('%.lua$', '')
        return require(filepath)
    else
        error(error_message, 2)
    end
end

--- Initializes the API methods visible to the user.
function txe.init_api ()
    local scope = txe.current_scope ()
    scope.txe = {}

    -- keep a reference
    txe.running_api = scope.txe

    for k, v in pairs(api) do
        scope.txe[k] = v
    end

    scope.txe.config = {}
    for k, v in pairs(txe.config) do
        scope.txe.config[k] = v
    end
end