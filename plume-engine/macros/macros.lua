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

-- Define macro-related macros
return function (plume)

    --- Applies an annotation to the value based on the given key.
    -- @param token table The token associated with the annotation process.
    -- @param scope table The current scope containing potential annotation methods.
    -- @param k string The key used to determine which annotation to apply.
    -- @param v table The value to be annotated.
    -- @param annotations table A map of keys to their respective annotation types.
    -- @return any The resulting value after annotation is applied.
    local function apply_annotation (macro_token, calling_token, scope, k, v, annotations)
        local annotation = annotations[k] or scope:get("config", "default_annotation")

        -- If v is a boolean, then k is a flag
        if v==true or v==false then
            return v
        end

        local method = scope:get("annotations", annotation)
        
        -- Check if the method exists in the scope and if it's a function
        if method == nil then
            plume.error(macro_token,"Unknown annotation '" .. annotation .. "'.")
        elseif type(method) ~= "function" then
            plume.error(macro_token, "'"..annotation.."' is not a function, but a '"..type(method).."'. Cannot use it to annotate parameters.")
        end
        
        local method_wrapper = function () return method(v) end

        local result = { xpcall (method_wrapper, plume.error_handler) }
        local sucess = result[1]
        table.remove(result, 1)

        if not sucess then
            plume.error(calling_token, result[1], true)
        end

        return (unpack or table.unpack) (result)
    end

    --- Checks if a macro is already defined in the current scope and issues a warning if it is.
    -- @param token tokenlist
    -- @param name string The name of the macro to check.
    local function check_macro_availability(token, name)
        -- Retrieve the current scope based on the context provided by the token
        local scope = plume.get_scope(token.context)
        
        -- Attempt to get the macro by name from the current scope
        local macro = scope:get("macros", name)
        
        -- Get the configuration setting for showing macro overwrite warnings
        local show_macro_overwrite_warnings = scope:get("config", "show_macro_overwrite_warnings")
        
        -- If the macro is already defined and warnings are enabled, issue a warning
        if macro and show_macro_overwrite_warnings then
            plume.warning_macro_already_exists(token, macro)
        end
    end


    --- Defines a new macro or redefines an existing one.
    -- @param def_parameters table The arguments for the macro definition
    -- @param is_local boolean Whether the macro is local
    -- @param calling_token token The token where the macro is being defined
    local function new_macro (macro_parameters, is_local, macro_token)
        -- Get the provided macro name
        local name = macro_parameters.positionals.name:render()
        local variable_parameters_number = false

        local scope  = plume.get_scope(macro_token.context)

        -- Check if the name is a valid identifier
        if not plume.is_identifier(name) then
            plume.error_invalid_name (macro_parameters.positionals.name, name, "macro")
        end

        -- If define globaly, check if a macro with this name already exist
        if not is_local then
            check_macro_availability (macro_parameters.positionals.name, name)
        end

        local annotations = {}

        -- Check if parameters names are valid and register flags
        -- Also extract annotations
        local to_remove = {}
        local to_add    = {}
        for name, value in pairs(macro_parameters.others.keywords) do
            if name:match(':') then
                table.insert(to_remove, name)
                name, annotation = name:match('(.-):(.*)')
                annotations[name] = annotation
                to_add[name] = value
            end
            if not plume.is_identifier(name) then
                plume.error_invalid_name (macro_token, name, "parameter")
            end
        end

        for i, name in ipairs(to_remove) do
            macro_parameters.others.keywords[name] = nil
        end

        for name, value in pairs(to_add) do
            macro_parameters.others.keywords[name] = value
        end

        local parameters_names = {}
        for _, name in ipairs(macro_parameters.others.flags) do
            if name == "..." then
                variable_parameters_number = true
            else
                local flag = false
                local annotation = nil
                if name:sub(1, 1) == "?" then
                    name = name:sub(2, -1)
                    flag = true
                end
                if name:match(':') then
                    name, annotation = name:match('(.-):(.*)')
                    if flag then
                        plume.error(macro_token, "Cannot annotate flags.")
                    end
                end

                if not plume.is_identifier(name) then
                    plume.error(macro_token, "'" .. name .. "' is an invalid parameter name.")
                end
                if flag then
                    macro_parameters.others.keywords[name] = false
                else
                    table.insert(parameters_names, name)
                    annotations[name] = annotation
                end
            end
        end

        -- Capture current scope
        local closure = plume.get_scope ()
        
        plume.register_macro(name, parameters_names, macro_parameters.others.keywords, function(params, calling_token, chain_sender, chain_message)
            -- Insert closure
            plume.push_scope (closure)

            -- Copy all tokens. Then, give each of them
            -- a reference to current lua scope
            -- (affect only scripts and evals tokens)
            local last_scope = plume.get_scope ()
            for k, v in pairs(params.positionals) do
                if type(params.keywords[k]) == "table" then
                    params.positionals[k] = v:copy ()
                    params.positionals[k]:set_context (last_scope)
                end
            end
            for k, v in pairs(params.keywords) do
                if type(params.keywords[k]) == "table" then
                    params.keywords[k] = v:copy ()
                    params.keywords[k]:set_context (last_scope)
                end
            end

            --- @scope_variable __params When inside a macro with a variable paramter count, contain all excedents parameters, use `pairs` to iterate over them. Flags are both stocked as key=value (`__params.some_flag = true`) and table indice. (`__params[1] = "some_flag"`|
            local __params = {}
            for k, v in pairs(params.others.keywords) do
                if type(params.others.keywords[k]) == "table" then
                     __params[k] = v:copy ()
                     __params[k]:set_context (last_scope)
                end
            end
            for i, k in ipairs(params.others.flags) do
                __params[k] = true
                __params[i] = k
            end

            
            -- argument are variable local to the macro
            local scope = plume.push_scope ()

            -- add all params in the current scope
            for k, v in pairs(params.positionals) do
                v = apply_annotation (macro_token, calling_token, scope, k, v, annotations)
                scope:set_local("variables", k, v)
            end
            for k, v in pairs(params.keywords) do
                v = apply_annotation (macro_token, calling_token, scope, k, v, annotations)
                scope:set_local("variables", k, v)
            end
            for _, k in pairs(params.flags) do
                scope:set_local("variables", k, true)
            end

            scope:set_local("variables", "__params", __params)

            --- @scope_variable __message  Used to implement if-like behavior. If you give a value to `__message.send`, the next macro to be called (in the same block) will receive this value in `__message.content`, and the name for the last macro in `__message.sender` 
            
            scope:set_local("variables", "__message", {sender = chain_sender, content = chain_message})

            local body = macro_parameters.positionals.body:copy ()
            body:set_context (scope, true)
            local result = body:render()

            -- Capture message
            local message = scope:get("variables", "__message")
            -- exit macro scope
            plume.pop_scope ()

            -- exit closure
            plume.pop_scope ()

            return result, tostring(message.send)
        end, calling_token, is_local, false, variable_parameters_number)
    end

    --- \macro
    -- Define a new macro.
    -- @param name Name must be a valid lua identifier
    -- @param body Body of the macro, that will be render at each call.
    -- @other_options Macro arguments names. See [more about](advanced.md#macro-parameters)
    -- @note Doesn't work if the name is already taken by another macro.
    plume.register_macro("macro", {"name", "body"}, {}, function(def_parameters, calling_token)
        -- '$' in arg name, so they cannot be erased by user
        new_macro (def_parameters, false, calling_token)
        return ""
    end, nil, false, true, true)

    --- \local_macro
    -- Define a new macro locally.
    -- @param name Name must be a valid lua identifier
    -- @param body Body of the macro, that will be render at each call.
    -- @other_options Macro arguments names.
    -- @alias `\macrol`
    plume.register_macro("local_macro", {"name", "body"}, {}, function(def_parameters, calling_token)
        -- '$' in arg name, so they cannot be erased by user
        new_macro (def_parameters, true, calling_token)
        return ""
    end, nil, false, true, true)

    --- \lmacro
    -- Alias for [local_macro](#local_macro)
    -- @param name Name must be a valid lua identifier
    -- @param body Body of the macro, that will be render at each call.
    -- @other_options Macro arguments names.
    plume.register_macro("lmacro", {"name", "body"}, {}, function(macro_parameters, calling_token)
        -- '$' in arg name, so they cannot be erased by user
        new_macro (macro_parameters, true, calling_token)
        return ""
    end, nil, false, true, true)

    --- Create alias of a function
    local function alias (name1, name2, calling_token, is_local)
        -- Test names availability
        local scope =  plume.get_scope (calling_token.context)

        if not scope:get("macros", name1) then
            plume.error(calling_token, "The macro '" .. name2 .. "' doesn't exists, so \\alias failed.")
        end
        if not is_local then
            check_macro_availability (calling_token, name2)
        end

        local macro = scope.macros[name1]
        if is_local then
            scope:set_local("macros", name2, macro)
        else
            scope:set("macros", name2, macro) 
        end
    end

    --- \alias
    -- name2 will be a new way to call name1.
    -- @param name1 Name of an existing macro.
    -- @param name2 Any valid lua identifier.
    -- @flag local Is the new macro local to the current scope.
    plume.register_macro("alias", {"name1", "name2"}, {}, function(params, calling_token)
        local name1 = params.positionals.name1:render()
        local name2 = params.positionals.name2:render()
        alias (name1, name2, calling_token, false)
    end, nil, false, true)

    --- \local_alias
    -- Make an alias locally
    -- @param name1 Name of an existing macro.
    -- @param name2 Any valid lua identifier.
    -- @alias `\lalias`
    plume.register_macro("local_alias", {"name1", "name2"}, {}, function(params, calling_token)
        local name1 = params.positionals.name1:render()
        local name2 = params.positionals.name2:render()
        alias (name1, name2, calling_token, true)
    end, nil, false, true)

    --- \lalias
    -- Alias for [local_alias](#local_alias)
    -- @param name1 Name of an existing macro.
    -- @param name2 Any valid lua identifier.
    plume.register_macro("lalias", {"name1", "name2"}, {}, function(params, calling_token)
        local name1 = params.positionals.name1:render()
        local name2 = params.positionals.name2:render()
        alias (name1, name2, calling_token, true)
    end, nil, false, true)

    --- Set (or reset) default parameters of a given macro.
    -- @param token table The calling token
    -- @param name string The name of the macro.
    -- @param keywords table A table of keyword arguments to set as default.
    -- @param flags table A list of flags to set as default.
    -- @param is_local boolean Is the default value local or global
    local function default(token, name, keywords, flags, is_local)
        local scope = plume.get_scope(token.context)
        local macro = scope:get("macros", name)

        -- Warning if edit "eval"
        if name == "eval" and not is_local then
            if scope:get("config", "show_beginner_warnings") then
                plume.warning_using_global_default_on_eval (token)
            end
        end

        -- Check if this macro exists
        if not macro then
            plume.error_macro_not_found(token, name)
        end

        -- Register keyword params and flags.
        local other_keywords = {}
        
        for k, v in pairs(keywords) do
            local name = tostring(macro) .. "@" .. k

            if macro.default_opt_params[k] then
                if is_local then
                    scope:set_local("default", name, v)
                else
                    scope:set("default", name, v)
                end
            else
                other_keywords[k] = v
            end
        end
        
        local other_flags = {}
        for _, k in ipairs(flags) do
            local name  = tostring(macro) .. "@" .. k

            if macro.default_opt_params[k] then
                if is_local then
                    scope:set_local("default", name, true)
                else
                    scope:set("default", name, true)
                end
            else
                table.insert(other_flags, k)
            end
        end

        if #other_keywords>0 then
            local name = tostring(macro) .. "?keywords"
            if is_local then
                scope:set_local("default", name, other_keywords)
            else
                scope:set("default", name, other_keywords)
            end
        end

        if #other_flags>0 then
            local name = tostring(macro) .. "?flags"
            if is_local then
                scope:set_local("default", name, other_flags)
            else
                scope:set("default", name, other_flags)
            end
        end
    end


    --- \default
    -- set (or reset) default params of a given macro.
    -- @param name Name of an existing macro.
    -- @other_options Any parameters used by the given macro.
    plume.register_macro("default", {"name"}, {}, function(params, calling_token)
        local name = params.positionals.name:render()
        default (calling_token, name, params.others.keywords, params.others.flags, false)
    end, nil, false, true, true)

    --- \local_default
    -- set  localy (or reset) default params of a given macro.
    -- @param name Name of an existing macro.
    -- @other_options Any parameters used by the given macro.
    -- @alias `\ldefault`
    plume.register_macro("local_default", {"name"}, {}, function(params, calling_token)
        local name = params.positionals.name:render()
        default (calling_token, name, params.others.keywords, params.others.flags, true)

    end, nil, false, true, true)

    --- \ldefault
    -- alias for [local_default](#local_default).
    -- @param name Name of an existing macro.
    -- @other_options Any parameters used by the given macro.
    plume.register_macro("ldefault", {"name"}, {}, function(params, calling_token)
        local name = params.positionals.name:render()
        default (calling_token, name, params.others.keywords, params.others.flags, true)

    end, nil, false, true, true)
end