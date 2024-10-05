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

-- Define some useful macro like set, raw, config, ...



--- Affect a value to a variable
local function set(params, calling_token, is_local)
    -- A macro to set variable to a value
    local key = params.positionnals.key:render()
    if not plume.is_identifier(key) then
        plume.error(params.positionnals.key, "'" .. key .. "' is an invalid name for a variable.")
    end

    local value = params.positionnals.value:render ()
    
    if is_local then
        plume.current_scope (calling_token.context):set_local("variables", key, value)
    else
        plume.current_scope (calling_token.context):set("variables", key, value) 
    end
end

--- \set
-- Affect a value to a variable.
-- @param key The name of the variable.
-- @param value The value of the variable.
-- @note Value is always stored as a string. To store lua object, use `#{var = ...}`
plume.register_macro("set", {"key", "value"}, {}, function(params, calling_token)
    set(params, calling_token, false)
    return ""
end, nil, false, true)

--- \local_set
-- Affect a value to a variable locally.
-- @param key The name of the variable.
-- @param value The value of the variable.
-- @note Value is always stored as a string. To store lua object, use `#{var = ...}`
-- @alias `lset`
plume.register_macro("local_set", {"key", "value"}, {}, function(params, calling_token)
    set(params, calling_token, true)
    return ""
end, nil, false, true)

--- lset
-- Alias for [local_set](#local_set)
-- @param key The name of the variable.
-- @param value The value of the variable.
-- @note Value is always stored as a string. To store lua object, use `#{var = ...}`
plume.register_macro("lset", {"key", "value"}, {}, function(params, calling_token)
    set(params, calling_token, true)
    return ""
end, nil, false, true)

--- \raw
-- Return the given body without render it.
-- @param body 
plume.register_macro("raw", {"body"}, {}, function(params)
    return params.positionnals['body']:source ()
end, nil, false, true)

--- \config
-- Edit plume configuration.
-- @param key Name of the paramter.
-- @param value New value to save.
-- @note Will raise an error if the key doesn't exist. See [config](config.md) to get all available parameters.
plume.register_macro("config", {"name", "value"}, {}, function(params, calling_token)
    local name   = params.positionnals.name:render ()
    local value  = params.positionnals.value:renderLua ()
    local config = plume.running_api.config

    if config[name] == nil then
        plume.error (calling_token, "Unknow configuration entry '" .. name .. "'.")
    end

    config[name] = value
end, nil, false, true)

function plume.deprecate (name, version, alternative)
    local macro = plume.current_scope()["macros"][name]

    if not macro then
        return nil
    end

    local macro_f = macro.macro

    macro.macro = function (params, calling_token)
        if plume.running_api.config.show_deprecation_warnings then
            plume.warning(calling_token, "Macro '" .. name .. "' is deprecated, and will be removed in version " .. version .. ". Use '" .. alternative .. "' instead.")
        end

        return macro_f (params, calling_token)
    end

    return true
end

--- \deprecate
-- Mark a macro as "deprecated". An error message will be printed each time you call it, except if you set `plume.config.show_deprecation_warnings` to `false`.
-- @param name Name of an existing macro.
-- @param version Version where the macro will be deleted.
-- @param alternative Give an alternative to replace this macro.
plume.register_macro("deprecate", {"name", "version", "alternative"}, {}, function(params, calling_token)
    local name        = params.positionnals.name:render()
    local version     = params.positionnals.version:render()
    local alternative = params.positionnals.alternative:render()

    if not plume.deprecate(name, version, alternative) then
        plume.error_macro_not_found(params.positionnals.name, name)
    end

end, nil, false, true)

--- Compatibility with 0.6.1, will be removed in a future version.

--- \set_local
-- DEPRECATED Affect a value to a variable locally.
-- @param key The name of the variable.
-- @param value The value of the variable.
-- @note Value is always stored as a string. To store lua object, use `#{var = ...}`
-- @alias `setl`
plume.register_macro("set_local", {"key", "value"}, {}, function(params, calling_token)
    set(params, calling_token, true)
    return ""
end, nil, false, true)

-- setl
-- DEPRECATED Alias for [set_local](#set_local)
-- @param key The name of the variable.
-- @param value The value of the variable.
-- @note Value is always stored as a string. To store lua object, use `#{var = ...}`
plume.register_macro("setl", {"key", "value"}, {}, function(params, calling_token)
    set(params, calling_token, true)
    return ""
end, nil, false, true)