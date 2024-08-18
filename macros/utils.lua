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
local function test_macro_name_available (name, redef, redef_forced)
    -- Test if the name is taken by standard macro
    if plume.std_macros[name] then
        if not redef_forced then
            local msg = "The macro '" .. name .. "' is a standard macro and is certainly used by other macros, so you shouldn't replace it. If you really want to, use '\\redef_forced "..name.."'."
            return false, msg
        end

    -- Test if this macro already exists
    elseif plume.macros[name] then
        if not redef then
            local msg = "The macro '" .. name .. "' already exist"
            local first_definition = plume.macros[name].token

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
-- @param calling_token token The token where the macro is being defined
local function def (def_args, redef, redef_forced, calling_token)
    -- Get the provided macro name
    local name = def_args["$name"]:render()

    -- Check if the name is a valid identifier
    if not plume.is_identifier(name) then
        plume.error(def_args["$name"], "'" .. name .. "' is an invalid name for a macro.")
    end

    local available, msg = test_macro_name_available (name, redef, redef_forced)
    if not available then
        plume.error(def_args["$name"], msg)
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
    
    plume.register_macro(name, def_args.__args, opt_args, function(args)
        -- Copy all tokens. Then, hive each of them
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
            plume.scope_set_local(k, v)
        end

        local result = def_args["$body"]:render()

        --exit macro scope
        plume.pop_scope ()

        return result
    end, calling_token)
end

plume.register_macro("def", {"$name", "$body"}, {}, function(def_args, calling_token)
    -- '$' in arg name, so they cannot be erased by user
    def (def_args, false, false, calling_token)
    return ""
end)

plume.register_macro("redef", {"$name", "$body"}, {}, function(def_args, calling_token)
    def (def_args, true, false, calling_token)
    return ""
end)

plume.register_macro("redef_forced", {"$name", "$body"}, {}, function(def_args, calling_token)
    def (def_args, true, true, calling_token)
    return ""
end)

local function set(args, calling_token, is_local)
    -- A macro to set variable to a value
    local key = args.key:render()
    if not plume.is_identifier(key) then
        plume.error(args.key, "'" .. key .. "' is an invalid name for a variable.")
    end

    local value = args.value:renderLua ()

    value = tonumber(value) or value

    if is_local then
        plume.scope_set_local (key, value)
    else
        (calling_token.context or plume.current_scope())[key] = value 
    end
end

plume.register_macro("set", {"key", "value"}, {}, function(args, calling_token)
    set(args, calling_token,args.__args["local"])
    return ""
end)

plume.register_macro("setl", {"key", "value"}, {}, function(args, calling_token)
    set(args, true)
    return ""
end)


plume.register_macro("alias", {"name1", "name2"}, {}, function(args)
    -- Copie macro "name1" to name2
    local name1 = args.name1:render()
    local name2 = args.name2:render()

    -- Test if name2 is available
    local available, msg = test_macro_name_available (name2)
    if not available then
        -- Remove the last sentence of the error message
        -- (the reference to redef)
        msg = msg:gsub("%.[^%.]-%.$", ".")
        plume.error(args.name2, msg)
    end

    plume.macros[name2] = plume.macros[name1]
    return ""
end)


plume.register_macro("default", {"$name"}, {}, function(args)
    -- Get the provided macro name
    local name = args["$name"]:render()

    -- Check if this macro exists
    if not plume.macros[name] then
        plume.error_macro_not_found(args["name"], name)
    end

    -- Add all arguments (except name) in user_opt_args
    for k, v in pairs(args) do
        if k:sub(1, 1) ~= "$" and k ~= "__args" then
            plume.macros[name].user_opt_args[k] = v
        end
    end
    for k, v in ipairs(args.__args) do
        plume.macros[name].user_opt_args[k] = v
    end

end)

plume.register_macro("raw", {"body"}, {}, function(args)
    -- Return content without execute it
    return args['body']:source ()
end)

plume.register_macro("config", {"name", "value"}, {}, function(args, calling_token)
    -- Edit configuration
    -- Warning : value will be converted

    local name   = args.name:render ()
    local value  = args.value:renderLua ()
    local config = plume.running_api.config

    if config[name] == nil then
        plume.error (calling_token, "Unknow configuration entry '" .. name .. "'.")
    end

    config[name] = value
end)