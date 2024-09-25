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

-- Define some useful macro like def, set, alias...

--- Test if the given name i available
-- @param name string the name to test
-- @param redef boolean Whether this is a redefinition
-- @param redef_forced boolean Whether to force redefinition of standard macros
local function test_macro_name_available (name, redef, redef_forced, calling_token)
    local std_macro = plume.std_macros[name]
    local macro     = plume.current_scope(calling_token.context).macros[name]
    -- Test if the name is taken by standard macro
    if std_macro then
        if not redef_forced then
            local msg = "The macro '" .. name .. "' is a standard macro and is certainly used by other macros, so you shouldn't replace it. If you really want to, use '\\redef_forced "..name.."'."
            return false, msg
        end

    -- Test if this macro already exists
    elseif macro then
        if not redef then
            local msg = "The macro '" .. name .. "' already exist"
            local first_definition = macro.token

            if first_definition then
                msg = msg
                    .. " (defined in file '"
                    .. first_definition.file
                    .. "', line "
                    .. first_definition.line .. ").\n"
            else
                msg = msg .. ". "
            end

            msg = msg .. "Use '\\redef "..name.."' to erase it."
            return false, msg
        end
    elseif redef and not redef_forced then
        local msg = "The macro '" .. name .. "' doesn't exist, so you can't erase it. Use '\\def "..name.."' instead."
        return false, msg
    end

    return true
end

--- Defines a new macro or redefines an existing one.
-- @param def_parameters table The arguments for the macro definition
-- @param redef boolean Whether this is a redefinition
-- @param redef_forced boolean Whether to force redefinition of standard macros
-- @param is_local boolean Whether the macro is local
-- @param calling_token token The token where the macro is being defined
local function def (def_parameters, redef, redef_forced, is_local, calling_token)
    -- Get the provided macro name
    local name = def_parameters.positionnals.name:render()
    local variable_parameters_number = false

    -- Check if the name is a valid identifier
    if not plume.is_identifier(name) then
        plume.error(def_parameters.positionnals.name, "'" .. name .. "' is an invalid name for a macro.")
    end

    if not is_local then
        local available, msg = test_macro_name_available (name, redef, redef_forced, calling_token)
        if not available then
            plume.error(def_parameters.positionnals.name, msg)
        end
    end

    -- Check if parameters names are valid and register flags
    for name, _ in pairs(def_parameters.others.keywords) do
        if not plume.is_identifier(name) then
            plume.error(calling_token, "'" .. name .. "' is an invalid parameter name.")
        end
    end

    local parameters_names = {}
    for _, name in ipairs(def_parameters.others.flags) do
        if name == "..." then
            variable_parameters_number = true
        else
            local flag = false
            if name:sub(1, 1) == "?" then
                name = name:sub(2, -1)
                flag = true
            end
            if not plume.is_identifier(name) then
                plume.error(calling_token, "'" .. name .. "' is an invalid parameter name.")
            end
            if flag then
                def_parameters.others.keywords[name] = false
            else
                table.insert(parameters_names, name)
            end
        end
    end

    -- Capture current scope
    local closure = plume.current_scope ()

    
    plume.register_macro(name, parameters_names, def_parameters.others.keywords, function(params)
        -- Insert closure
        plume.push_scope (closure)

        -- Copy all tokens. Then, give each of them
        -- a reference to current lua scope
        -- (affect only scripts and evals tokens)
        local last_scope = plume.current_scope ()
        for k, v in pairs(params.positionnals) do
            params.positionnals[k] = v:copy ()
            params.positionnals[k]:set_context (last_scope)
        end
        for k, v in pairs(params.keywords) do
            if type(params.keywords[k]) == "table" then
                params.keywords[k] = v:copy ()
                params.keywords[k]:set_context (last_scope)
            end
        end

        -- A table to store excedent params
        local __params = {}
        for k, v in pairs(params.others.keywords) do
            if type(params.others.keywords[k]) == "table" then
                 __params[k] = v:copy ()
                 __params[k]:set_context (last_scope)
            end
        end
        for _, k in ipairs(params.others.flags) do
            __params[k] = true
        end

        
        -- argument are variable local to the macro
        plume.push_scope ()

        -- add all params in the current scope
        for k, v in pairs(params.positionnals) do
            plume.current_scope():set_local("variables", k, v)
        end
        for k, v in pairs(params.keywords) do
            plume.current_scope():set_local("variables", k, v)
        end
        for _, k in pairs(params.flags) do
            plume.current_scope():set_local("variables", k, true)
        end

        plume.current_scope():set_local("variables", "__params", __params)

        local body = def_parameters.positionnals.body:copy ()
        body:set_context (plume.current_scope (), true)
        local result = body:render()

        -- exit macro scope
        plume.pop_scope ()

        -- exit closure
        plume.pop_scope ()

        return result
    end, calling_token, false, false, variable_parameters_number)
end

--- \def
-- Define a new macro.
-- @param name Name must be a valid lua identifier
-- @param body Body of the macro, that will be render at each call.
-- @other_options Macro arguments names. See [more about](advanced.md#macro-parameters)
-- @note Doesn't work if the name is already taken by another macro.
plume.register_macro("def", {"name", "body"}, {}, function(def_parameters, calling_token)
    -- '$' in arg name, so they cannot be erased by user
    def (def_parameters, false, false, false, calling_token)
    return ""
end, nil, false, true, true)

--- \redef
-- Redefine a macro.
-- @param name Name must be a valid lua identifier
-- @param body Body of the macro, that will be render at each call.
-- @other_options Macro arguments names.
-- @note Doesn't work if the name is available.
plume.register_macro("redef", {"name", "body"}, {}, function(def_parameters, calling_token)
    def (def_parameters, true, false, false, calling_token)
    return ""
end, nil, false, true, true)

--- \redef_forced
-- Redefined a predefined macro.
-- @param name Name must be a valid lua identifier
-- @param body Body of the macro, that will be render at each call.
-- @other_options Macro arguments names.
-- @note Doesn't work if the name is available or isn't a predefined macro.
plume.register_macro("redef_forced", {"name", "body"}, {["*"]=true}, function(def_parameters, calling_token)
    def (def_parameters, true, true, false, calling_token)
    return ""
end, nil, false, true, true)

--- \def_local
-- Define a new macro locally.
-- @param name Name must be a valid lua identifier
-- @param body Body of the macro, that will be render at each call.
-- @other_options Macro arguments names.
-- @note Contrary to `\def`, can erase another macro without error.
-- @alias `\defl`
plume.register_macro("def_local", {"name", "body"}, {}, function(def_parameters, calling_token)
    -- '$' in arg name, so they cannot be erased by user
    def (def_parameters, false, false, true, calling_token)
    return ""
end, nil, true, true)

--- \defl
-- Alias for [def_local](#def_local)
-- @param name Name must be a valid lua identifier
-- @param body Body of the macro, that will be render at each call.
-- @other_options Macro arguments names.
plume.register_macro("defl", {"name", "body"}, {}, function(def_parameters, calling_token)
    -- '$' in arg name, so they cannot be erased by user
    def (def_parameters, false, false, true, calling_token)
    return ""
end, nil, true, true)

--- Create alias of a function
local function alias (name1, name2, calling_token, is_local)
    -- Test if name2 is available
    local available, msg = test_macro_name_available (name2, false, false, calling_token)
    if not available then
        -- Remove the last sentence of the error message
        -- (the reference to redef)
        msg = msg:gsub("%.[^%.]-%.$", ".")
        plume.error(params.name2, msg)
    end

    local scope =  plume.current_scope (calling_token.context)

    if is_local then
        plume.current_scope (calling_token.context):set_local("macros", name2, scope.macros[name1])
    else
        plume.current_scope (calling_token.context):set("macros", name2, scope.macros[name1]) 
    end
end

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

--- \set_local
-- Affect a value to a variable locally.
-- @param key The name of the variable.
-- @param value The value of the variable.
-- @note Value is always stored as a string. To store lua object, use `#{var = ...}`
-- @alias `setl`
plume.register_macro("set_local", {"key", "value"}, {}, function(params, calling_token)
    set(params, calling_token, true)
    return ""
end, nil, false, true)

-- setl
-- Alias for [set_local](#set_local)
-- @param key The name of the variable.
-- @param value The value of the variable.
-- @note Value is always stored as a string. To store lua object, use `#{var = ...}`
plume.register_macro("setl", {"key", "value"}, {}, function(params, calling_token)
    set(params, calling_token, true)
    return ""
end, nil, false, true)


--- \alias
-- name2 will be a new way to call name1.
-- @param name1 Name of an existing macro.
-- @param name2 Any valid lua identifier.
-- @flag local Is the new macro local to the current scope.
-- @alias `\aliasl` is equivalent as `\alias[local]`
plume.register_macro("alias", {"name1", "name2"}, {}, function(params, calling_token)
    local name1 = params.positionnals.name1:render()
    local name2 = params.positionnals.name2:render()
    alias (name1, name2, calling_token, false)
end, nil, false, true)

--- \alias_local
-- Make an alias locally
-- @param name1 Name of an existing macro.
-- @param name2 Any valid lua identifier.
-- @alias `\aliasl`
plume.register_macro("alias_local", {"name1", "name2"}, {}, function(params, calling_token)
    local name1 = params.positionnals.name1:render()
    local name2 = params.positionnals.name2:render()
    alias (name1, name2, calling_token, true)
end, nil, false, true)

--- \aliasl
-- Alias for [alias_local](#alias_local)
-- @param name1 Name of an existing macro.
-- @param name2 Any valid lua identifier.
plume.register_macro("aliasl", {"name1", "name2"}, {}, function(params, calling_token)
    local name1 = params.positionnals.name1:render()
    local name2 = params.positionnals.name2:render()
    alias (name1, name2, calling_token, true)
end, nil, false, true)

--- \default
-- set (or reset) default params of a given macro.
-- @param name Name of an existing macro.
-- @other_options Any parameters used by the given macro.
plume.register_macro("default", {"name"}, {}, function(params, calling_token)
    -- Get the provided macro name
    local name = params.positionnals.name:render()

    local scope = plume.current_scope(calling_token.context)

    -- Check if this macro exists
    if not scope.macros[name] then
        plume.error_macro_not_found(params.positionnals.name, name)
    end

    -- Add all arguments (except name) in user_opt_params
    for k, v in pairs(params.others.keywords) do
        scope.macros[name].user_opt_params[k] = v
    end
    for _, k in ipairs(params.others.flags) do
        scope.macros[name].user_opt_params[k] = true
    end

end, nil, false, true, true)

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
            print("Warning : macro '" .. name .. "' (used in file '" .. calling_token.file .. "', line ".. calling_token.line .. ") is deprecated, and will be removed in version " .. version .. ". Use '" .. alternative .. "' instead.")
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
    local name        = params.name:render()
    local version     = params.version:render()
    local alternative = params.alternative:render()

    if not plume.deprecate(name, version, alternative) then
        plume.error_macro_not_found(params.name, name)
    end

end, nil, false, true)