txe.macros = {}
function txe.register_macro (name, args, defaut_optargs, macro)
    -- args: table contain the name of macro arguments
    -- defaut_optargs: table contain key and defaut value for optionnals args
    -- macro: the function to call
    txe.macros[name] = {
        args           = args,
        defaut_optargs = defaut_optargs,
        macro          = macro
    }
end
function txe.get_macro(name)
    return txe.macros[name]
end

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

txe.register_macro("#", {"expr"}, {}, function(args)
    --Eval lua chunck and return the result
    --Todo : check for syntax error
    return txe.call_lua_chunck(args.expr)
end)

local function lua_package (path)
    local paths = {}
    table.insert(paths, "./" .. path .. ".lua")
    table.insert(paths, "./" .. path .. "/init.lua")

    return paths
end

local function find_file (paths)
    return nil, "Cannot find or open file. Tried :\n\t" .. table.concat(paths, "\n\t")
end

txe.register_macro("require", {"path"}, {}, function(args)
    -- Execute a lua file in the current context

    -- Todo: check if file exist, check for errors...
    local path = args.path:render ()
    local f = txe.call_lua_chunck (args.path, " function ()" .. io.open(path .. ".lua"):read("*a") .. " end")

    return f()
end)

txe.register_macro("include", {"path"}, {}, function(args)
    -- Execute the given txe file and return the output

    -- Todo: check if file exist, check for errors...
    local path = args.path:render () .. ".txe"
    
    return txe.renderFile(path)
end)


txe.register_macro("set", {"key", "value"}, {["local"]=false}, function(args)
    -- A macro to set variable to a value

    --to do : check if sket
    local key = args.key:render()
    
    local value
    --If value is a lua chunck, call it there to avoid conversion to string
    if #args.value > 0 and args.value[1].kind == "macro" and args.value[1].value == "#" then
        value = txe.call_lua_chunck(args.value[2])
    else
        value = args.value:render ()
    end

    -- Convert to number if possible
    value = tonumber(value) or value

    txe.lua_env[key] = value
    return ""
end)

-- Controle structures
txe.register_macro("for", {"iterator", "body"}, {}, function(args)
    local result = {}
    local iterator = args.iterator:render ()
    local var, var1, var2, first, last

    var, first, last = iterator:match('%s*(.-)%s*=%s*([0-9]-)%s*,%s*([0-9]-)$')
    if not var then
        var, iterator = iterator:match('%s*(.-)%s*in%s*(.-)$')
    end

    if var and first and last then
        for i=first, last do
            i = math.floor(i)-- For some reasons, i is treated as a float...
            txe.lua_env_set_local(var, i)
            table.insert(result, args.body:render())
        end
    elseif iterator and var then
        local variables_list = {}
        for name in var:gmatch('[^%s,]') do
            table.insert(variables_list, name)
        end

        local iter, state, key = txe.call_lua_chunck (args.iterator, iterator)
        local values_list = { iter(state, key) }

        if #values_list ~= #variables_list then
            txe.error(args.iterator, "Wrong number of variables, " .. #variables_list .. " instead of " .. #values_list .. "." )
        end

        while values_list[1] do
            for i=1, #variables_list do
                txe.lua_env_set_local (variables_list[i], values_list[i])
            end
            table.insert(result, args.body:render())
            values_list = { iter(state, values_list[1]),  }
        end
    else
        txe.error(args.iterator, "Non valid syntax for iterator.")
    end

    return table.concat(result, "")
end)

txe.register_macro("while", {"condition", "body"}, {}, function(args)
    local result = {}
    local i = 0
    while txe.call_lua_chunck (args.condition) do
        table.insert(result, args.body:render())
        i = i + 1
        if i > txe.max_loop_size then
            txe.error(args.condition, "To many loop repetition (over the configurated limit of " .. txe.max_loop_size .. ").")
        end
    end

    return table.concat(result, "")
end)

txe.register_macro("if", {"condition", "body"}, {}, function(args)
    local condition = txe.call_lua_chunck(args.condition)
    if condition then
        return args.body:render()
    end
    return ""
end)