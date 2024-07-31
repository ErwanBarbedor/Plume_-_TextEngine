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

-- Define some useful macro like def, set, alias.

local function def (def_args, redef, redef_forced, calling_token)
    -- Main way to define new macro from Plume - TextEngine

    -- Get the provided macro name
    local name = def_args["$name"]:render()

    -- Test if name is a valid identifier
    if not txe.is_identifier(name) then
        txe.error(def_args["$name"], "'" .. name .. "' is an invalid name for a macro.")
    end

    -- Test if the name is taken by standard macro
    if txe.std_macros[name] then
        if not redef_forced then
            local msg = "The macro '" .. name .. "' is a standard macro and is certainly used by other macros, so you shouldn't replace it. If you really want to, use '\\redef_forced "..name.."'."
            txe.error(def_args["$name"], msg)
        end
    -- Test if this macro already exists
    elseif txe.macros[name] then
        if not redef then
            local msg = "The macro '" .. name .. "' already exist"
            local first_definition = txe.macros[name].token

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
            txe.error(def_args["$name"], msg)
        end
    elseif redef then
        local msg = "The macro '" .. name .. "' doesn't exist, so you can't erase it. Use '\\def "..name.."' instead."
        txe.error(def_args["$name"], msg)
    end

    -- All args (except $name, $body and __args) are optional args
    -- with defaut values
    local opt_args = {}
    for k, v in pairs(def_args) do
        if k:sub(1, 1) ~= "$" then
            table.insert(opt_args, {name=k, value=v})
        end
    end

    -- Remaining args are the macro args names
    for k, v in ipairs(def_args.__args) do
        def_args.__args[k] = v:render()
    end
    
    txe.register_macro(name, def_args.__args, opt_args, function(args)
        
        -- Give each arg a reference to current lua scope
        -- (affect only scripts and evals tokens)
        txe.freeze_scope (args)

        -- argument are variable local to the macro
        txe.push_scope ()

        -- add all args in the current scope
        for k, v in pairs(args) do
            txe.scope_set_local(k, v)
        end

        local result = def_args["$body"]:render()

        --exit macro scope
        txe.pop_scope ()

        return result
    end, calling_token)
end

txe.register_macro("def", {"$name", "$body"}, {}, function(def_args, calling_token)
    -- '$' in arg name, so they cannot be erased by user
    def (def_args, false, false, calling_token)
    return ""
end)

txe.register_macro("redef", {"$name", "$body"}, {}, function(def_args, calling_token)
    def (def_args, true, false, calling_token)
    return ""
end)

txe.register_macro("redef_forced", {"$name", "$body"}, {}, function(def_args, calling_token)
    def (def_args, true, true, calling_token)
    return ""
end)

txe.register_macro("set", {"key", "value"}, {global=false}, function(args, calling_token)
    -- A macro to set variable to a value
    local global = args.__args.global

    local key = args.key:render()
    if not txe.is_identifier(key) then
        txe.error(args.key, "'" .. key .. "' is an invalid name for a variable.")
    end

    local value
    --If value is a lua chunck, call it there to avoid conversion to string
    if #args.value > 0 and args.value[1].kind == "macro" and args.value[1].value == "#" then
        value = txe.eval_lua_expression(args.value[2])
    elseif #args.value > 0 and args.value[1].kind == "macro" and args.value[1].value == "script" then
        value = txe.eval_lua_expression(args.value[2])
    else
        value = args.value:render ()
    end

    value = tonumber(value) or value

    if global then
        txe.current_scope ()[key] = value
    else
        txe.scope_set_local (key, value, calling_token.frozen_scope)
    end

    return ""
end)

txe.register_macro("alias", {"name1", "name2"}, {}, function(args)
    -- Copie macro "name1" to name2
    local name1 = args.name1:render()
    local name2 = args.name2:render()

    txe.macros[name2] = txe.macros[name1]
    return "", not condition
end)


