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

return function ()
    --- Affect a value to a variable
    local function set(params, calling_token, is_local)
        -- A macro to set variable to a value
        local key = params.positionals.key:render()
        if not plume.is_identifier(key) then
            plume.error(params.positionals.key, "'" .. key .. "' is an invalid name for a variable.")
        end

        local value = params.positionals.value:render ()
        local scope = plume.get_scope(calling_token.context)

        if is_local then
            scope:set_local("variables", key, value)
        else
            scope:set("variables", key, value) 
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
        return params.positionals['body']:source ()
    end, nil, false, true)

    --- \config
    -- Edit plume configuration.
    -- @param key Name of the parameter.
    -- @param value New value to save.
    -- @note Will raise an error if the key doesn't exist. See [config](config.md) to get all available parameters.
    plume.register_macro("config", {"name", "value"}, {}, function(params, calling_token)
        local name   = params.positionals.name:render ()
        local value  = params.positionals.value:render_lua ()
        local scope = plume.get_scope()

        if scope.config[name] == nil then
            plume.error (calling_token, "Unknow configuration entry '" .. name .. "'.")
        end

        scope:set("config", name, value)
    end, nil, false, true)

    --- \lconfig
    -- Edit plume configuration in local scope.
    -- @param key Name of the parameter.
    -- @param value New value to save.
    -- @note Will raise an error if the key doesn't exist. See [config](config.md) to get all available parameters.
    plume.register_macro("lconfig", {"name", "value"}, {}, function(params, calling_token)
        local name   = params.positionals.name:render ()
        local value  = params.positionals.value:render_lua ()
        local scope = plume.get_scope(calling_token.context)

        if scope.config[name] == nil then
            plume.error (calling_token, "Unknow configuration entry '" .. name .. "'.")
        end
        
        scope:set_local("config", name, value)
    end, nil, false, true)

    function plume.deprecate (name, version, alternative, calling_token)
        local scope = plume.get_scope ()
        local macro = scope:get("macros", name)

        if not macro then
            return nil
        end

        local macro_f = macro.macro

        macro.macro = function (params, calling_token)
            local scope = plume.get_scope (calling_token.context)
            local show_deprecation_warnings = scope:get("config", "show_deprecation_warnings")
            if show_deprecation_warnings then
                plume.warning_deprecated_macro (calling_token, name, version, alternative)
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
        local name        = params.positionals.name:render()
        local version     = params.positionals.version:render()
        local alternative = params.positionals.alternative:render()

        if not plume.deprecate(name, version, alternative) then
            plume.error_macro_not_found(params.positionals.name, name)
        end

    end, nil, false, true)
end