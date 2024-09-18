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
-- @param def_args table The arguments for the macro definition
-- @param redef boolean Whether this is a redefinition
-- @param redef_forced boolean Whether to force redefinition of standard macros
-- @param is_local boolean Whether the macro is local
-- @param calling_token token The token where the macro is being defined
local function def (def_args, redef, redef_forced, is_local, calling_token)

    -- Get the provided macro name
    local name = def_args["$name"]:render()

    -- Check if the name is a valid identifier
    if not plume.is_identifier(name) then
        plume.error(def_args["$name"], "'" .. name .. "' is an invalid name for a macro.")
    end

    if not is_local then
        local available, msg = test_macro_name_available (name, redef, redef_forced, calling_token)
        if not available then
            plume.error(def_args["$name"], msg)
        end
    end

    -- All args (except $name, $body and __args) are optional args
    -- with defaut values
    local opt_args = {}
    for k, v in pairs(def_args) do
        if k:sub(1, 1) ~= "$" then
            opt_args[k] = v
        end
    end

    -- Remaining args are the macro args names
    for k, v in ipairs(def_args.__args) do
        def_args.__args[k] = v:render()
    end

    -- Capture current scope
    local closure = plume.current_scope ()
    
    plume.register_macro(name, def_args.__args, opt_args, function(args)
        -- Insert closure
        plume.push_scope (closure)

        -- Copy all tokens. Then, give each of them
        -- a reference to current lua scope
        -- (affect only scripts and evals tokens)
        local last_scope = plume.current_scope ()
        for k, v in pairs(args) do
            if k ~= "__args" then
                args[k] = v:copy ()
                args[k]:set_context (last_scope)
            end
        end
        for k, v in ipairs(args.__args) do
            args.__args[k] = v:copy ()
            args.__args[k]:set_context (last_scope)
        end
        -- argument are variable local to the macro
        plume.push_scope ()

        -- add all args in the current scope
        for k, v in pairs(args) do
            plume.current_scope():set_local("variables", k, v)
        end

        local body = def_args["$body"]:copy ()
        body:set_context (plume.current_scope (), true)
        local result = body:render()

        -- exit macro scope
        plume.pop_scope ()

        -- exit closure
        plume.pop_scope ()

        return result
    end, calling_token)
end

--- \def
-- Define a new macro.
-- @param name Name must be a valid lua identifier
-- @param body Body of the macro, that will be render at each call.
-- @other_options Macro arguments names.
-- @note Doesn't work if the name is already taken by another macro.
plume.register_macro("def", {"$name", "$body"}, {}, function(def_args, calling_token)
    -- '$' in arg name, so they cannot be erased by user
    def (def_args, false, false, false, calling_token)
    return ""
end, nil, false, true)

--- \redef
-- Redefine a macro.
-- @param name Name must be a valid lua identifier
-- @param body Body of the macro, that will be render at each call.
-- @other_options Macro arguments names.
-- @note Doesn't work if the name is available.
plume.register_macro("redef", {"$name", "$body"}, {}, function(def_args, calling_token)
    def (def_args, true, false, false, calling_token)
    return ""
end, nil, false, true)

--- \redef_forced
-- Redefined a predefined macro.
-- @param name Name must be a valid lua identifier
-- @param body Body of the macro, that will be render at each call.
-- @other_options Macro arguments names.
-- @note Doesn't work if the name is available or isn't a predefined macro.
plume.register_macro("redef_forced", {"$name", "$body"}, {}, function(def_args, calling_token)
    def (def_args, true, true, false, calling_token)
    return ""
end, nil, false, true)

--- \ldef
-- Define a new macro locally.
-- @param name Name must be a valid lua identifier
-- @param body Body of the macro, that will be render at each call.
-- @other_options Macro arguments names.
-- @note Contrary to `\def`, can erase another macro without error.
plume.register_macro("ldef", {"$name", "$body"}, {}, function(def_args, calling_token)
    -- '$' in arg name, so they cannot be erased by user
    def (def_args, false, false, true, calling_token)
    return ""
end, nil, true, true)

local function set(args, calling_token, is_local)
    -- A macro to set variable to a value
    local key = args.key:render()
    if not plume.is_identifier(key) then
        plume.error(args.key, "'" .. key .. "' is an invalid name for a variable.")
    end

    local value = args.value:renderLua ()

    value = tonumber(value) or value
    
    if is_local then
        plume.current_scope (calling_token.context):set_local("variables", key, value)
    else
        plume.current_scope (calling_token.context):set("variables", key, value) 
    end
end

--- \set
-- Deprecated and will be removed in 1.0. You should use '#' instead.
plume.register_macro("set", {"key", "value"}, {}, function(args, calling_token)
    set(args, calling_token, args.__args["local"])
    return ""
end, nil, false, true)

--- \setl
-- Deprecated and will be removed in 1.0. You should use '#' instead.
plume.register_macro("setl", {"key", "value"}, {}, function(args, calling_token)
    set(args, calling_token, true)
    return ""
end, nil, false, true)


--- Create alias of a function
local function alias (name1, name2, calling_token, is_local)
    -- Test if name2 is available
    local available, msg = test_macro_name_available (name2, false, false, calling_token)
    if not available then
        -- Remove the last sentence of the error message
        -- (the reference to redef)
        msg = msg:gsub("%.[^%.]-%.$", ".")
        plume.error(args.name2, msg)
    end

    local scope =  plume.current_scope (calling_token.context)

    if is_local then
        plume.current_scope (calling_token.context):set_local("macros", name2, scope.macros[name1])
    else
        plume.current_scope (calling_token.context):set("macros", name2, scope.macros[name1]) 
    end
end

--- \alias
-- name2 will be a new way to call name1.
-- @param name1 Name of an existing macro.
-- @param name2 Any valid lua identifier.
-- @option_nkw local={} Is the new macro local to the current scope.
-- @alias `\aliasl` is equivalent as `\alias[local]`
plume.register_macro("alias", {"name1", "name2"}, {}, function(args, calling_token)
    local name1 = args.name1:render()
    local name2 = args.name2:render()
    alias (name1, name2, calling_token, args.__args["local"])
end, nil, false, true)

--- \aliasl
-- Make an alias locally
-- @param name1 Name of an existing macro.
-- @param name2 Any valid lua identifier.
-- @alias `\aliasl` is equivalent as `\alias[local]`
plume.register_macro("aliasl", {"name1", "name2"}, {}, function(args, calling_token)
    local name1 = args.name1:render()
    local name2 = args.name2:render()
    alias (name1, name2, calling_token, true)
end, nil, false, true)

--- \default
-- set (or reset) default args of a given macro.
-- @param name Name of an existing macro.
-- @other_options Any parameters used by the given macro.
plume.register_macro("default", {"$name"}, {}, function(args, calling_token)
    -- Get the provided macro name
    local name = args["$name"]:render()

    local scope = plume.current_scope(calling_token.context)

    -- Check if this macro exists
    if not scope.macros[name] then
        plume.error_macro_not_found(args["name"], name)
    end

    -- Add all arguments (except name) in user_opt_args
    for k, v in pairs(args) do
        if k:sub(1, 1) ~= "$" and k ~= "__args" then
            scope.macros[name].user_opt_args[k] = v
        end
    end
    for k, v in ipairs(args.__args) do
        scope.macros[name].user_opt_args[k] = v
    end

end, nil, false, true)

--- \raw
-- Return the given body without render it.
-- @param body
plume.register_macro("raw", {"body"}, {}, function(args)
    return args['body']:source ()
end, nil, false, true)

--- \config
-- Edit plume configuration.
-- @param key Name of the paramter.
-- @param value New value to save.
-- @note Will raise an error if the key doesn't exist. See [config](config.md) to get all available parameters.
plume.register_macro("config", {"name", "value"}, {}, function(args, calling_token)
    local name   = args.name:render ()
    local value  = args.value:renderLua ()
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

    macro.macro = function (args, calling_token)
        if plume.running_api.config.show_deprecation_warnings then
            print("Warning : macro '" .. name .. "' (used in file '" .. calling_token.file .. "', line ".. calling_token.line .. ") is deprecated, and will be removed in version " .. version .. ". Use '" .. alternative .. "' instead.")
        end

        return macro_f (args, calling_token)
    end

    return true
end

--- \deprecate
-- Mark a macro as "deprecated". An error message will be printed each time you call it, except if you set `plume.config.show_deprecation_warnings` to `false`.
-- @param name Name of an existing macro.
-- @param version Version where the macro will be deleted.
-- @param alternative Give an alternative to replace this macro.
plume.register_macro("deprecate", {"name", "version", "alternative"}, {}, function(args, calling_token)
    local name        = args.name:render()
    local version     = args.version:render()
    local alternative = args.alternative:render()

    if not plume.deprecate(name, version, alternative) then
        plume.error_macro_not_found(args.name, name)
    end

end, nil, false, true)
