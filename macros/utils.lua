--[[This file is part of TextEngine.

TextEngine is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

TextEngine is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with TextEngine. If not, see <https://www.gnu.org/licenses/>.
]]

-- Define some useful macro like def, set, alias.

local function def (def_args, redef)
    -- Main way to define new macro from TextEngine

    local name = def_args.name:render()
    -- Test if name is a valid identifier
    if not txe.is_identifier(name) then
        txe.error(def_args.name, "'" .. name .. "' is an invalid name for a macro.")
    end

    -- Test if this macro already exists
    if txe.macros[name] and not redef then
        txe.error(def_args.name, "The macro '" .. name .. "' already exist. Use '\\redef' to erease it.")
    end

    -- Remaining args are the macro args names
    for k, v in ipairs(def_args['...']) do
        def_args['...'][k] = v:render()
    end
    
    txe.register_macro(name, def_args['...'], {}, function(args)
        -- argument are variable local to the macro
        txe.push_env ()

        --add all args in the lua_env table
        for k, v in pairs(args) do
            if v.render then-- '...' field it is'nt a tokenlist
                txe.lua_env_set_local(k, v)
            end
        end

        local result = def_args.body:render()

        --exit macro scope
        txe.pop_env ()

        return result
    end)
end

txe.register_macro("def", {"name", "body"}, {}, function(def_args)
    def (def_args)
    return ""
end)

txe.register_macro("redef", {"name", "body"}, {}, function(def_args)
    def (def_args, true)
    return ""
end)

txe.register_macro("set", {"key", "value"}, {["local"]=false}, function(args)
    -- A macro to set variable to a value

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

    txe.lua_env[key] = value
    return ""
end)

txe.register_macro("alias", {"name1", "name2"}, {}, function(args)
    -- Copie macro "name1" to name2
    local name1 = args.name1:render()
    local name2 = args.name2:render()

    txe.macros[name2] = txe.macros[name1]
    return "", not condition
end)


