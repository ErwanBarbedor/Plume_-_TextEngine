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

-- Define for, while, if, elseif, else control structures

txe.register_macro("for", {"iterator", "body"}, {}, function(args)
    -- Have the same behavior of the lua for control structure.
    -- Error management implementation isn't done yet

    local result = {}
    local iterator_source = args.iterator:source ()
    local var, var1, var2, first, last

    -- I'm not going to write a full lua parser to read the iterator.
    -- Some are relatively simple to handle using load, such as
    -- "for k, v in pairs(t)". But when writing "for=from, to, step"
    -- each element is an expression in its own. So it's difficult
    -- to parse, and lua doesn't provide a simple
    -- mechanism for emulating this syntax.
    -- So, in very simple cases, the iterator will be parsed for performance, (WIP)
    -- otherwise we'll switch to using coroutines.

    local mode = 1

    -- Check i=1, 10 syntax
    -- var, first, last = iterator_source:match('%s*(.-)%s*=%s*([0-9]-)%s*,%s*([0-9]-)$')

    -- If fail, capture anything after "="
    if not var then
        mode = mode + 1
    
        var, iterator = iterator_source:match('%s*([a-zA-Z_][a-zA-Z0-9_]*)%s*=%s*(.-)$')
    end

    -- If fail again, capture anythin after 'in'
    if not var then
        mode = mode + 1
        var, iterator = iterator_source:match('%s*(.-)%s*in%s*(.-)$')
    end
    
    if not var then
        txe.error(args.iterator, "Non valid syntax for iterator.")
    end

    if mode == 1 then
        for i=first, last do
            -- For some reasons, i is treated as a float...
            i = math.floor(i)
            
            -- Add counter to the local scope, to 
            -- be used by user
            txe.scope_set_local(var, i)
            
            table.insert(result, args.body:render())
        end
    elseif mode == 2 then
        local coroutine_code = "for " .. iterator_source .. " do"
        coroutine_code = coroutine_code .. " coroutine.yield(" .. var .. ")"
        coroutine_code = coroutine_code .. " end"

        local iterator_coroutine = txe.load_lua_chunck (coroutine_code, _, _, txe.current_scope ())
        local co = coroutine.create(iterator_coroutine)
        while true do
            local sucess, value = coroutine.resume(co)
            -- print(co, sucess, value)
            if not value then
                break
            end
            if not sucess or not co then
                txe.error(args.iterator, "(iterator error)" .. value)
            end

            txe.scope_set_local (var, value)
            table.insert(result, args.body:render())
        end
    
    elseif mode == 3 then
        -- Save all variables name in a table
        local variables_list = {}
        for name in var:gmatch('[^%s,]+') do
            table.insert(variables_list, name)
        end

        -- Create the iterator
        local iter, state, key = txe.eval_lua_expression (args.iterator, iterator)

        -- Check if iter is callable.
        if type(iter) ~= "function" or type(iter) == "table" and getmetatable(iter).__call then
            txe.error(args.iterator, "iterator cannot be '" .. type(iter) .. "'")
        end

        -- Get first iteration
        local values_list = { iter(state, key) }

        -- If the iterator return nothing
        if #values_list == 0 then
            return ""
        end

        -- If not enough (or too much) variables was provided
        if #values_list ~= #variables_list then
            txe.error(args.iterator, "Wrong number of variables, " .. #variables_list .. " instead of " .. #values_list .. "." )
        end

        -- Run util the iterator return nothing
        while values_list[1] do
            -- Add all returned variables to the local scope
            for i=1, #variables_list do
                txe.scope_set_local (variables_list[i], values_list[i])
            end

            table.insert(result, args.body:render())

            -- Call the iterator one more time
            values_list = { iter(state, values_list[1]),  }
        end
    end

    return table.concat(result, "")
end)

txe.register_macro("while", {"condition", "body"}, {}, function(args)
    -- Have the same behavior of the lua while control structure.
    -- To prevent infinite loop, a hard limit is setted by txe.max_loop_size

    local result = {}
    local i = 0
    while txe.eval_lua_expression (args.condition) do
        table.insert(result, args.body:render())
        i = i + 1
        if i > txe.max_loop_size then
            txe.error(args.condition, "To many loop repetition (over the configurated limit of " .. txe.max_loop_size .. ").")
        end
    end

    return table.concat(result, "")
end)

txe.register_macro("if", {"condition", "body"}, {}, function(args)
    -- Have the same behavior of the lua if control structure.
    -- Send a message "true" or "false" for activate (or not)
    -- following "else" or "elseif"

    local condition = txe.eval_lua_expression(args.condition)
    if condition then
        return args.body:render()
    end
    return "", not condition
end)

txe.register_macro("else", {"body"}, {}, function(args, self_token, chain_sender, chain_message)
    -- Have the same behavior of the lua else control structure.

    -- Must receive a message from preceding if
    if chain_sender ~= "\\if" and chain_sender ~= "\\elseif" then
        txe.error(self_token, "'else' macro must be preceded by 'if' or 'elseif'.")
    end

    if chain_message then
        return args.body:render()
    end

    return ""
end)

txe.register_macro("elseif", {"condition", "body"}, {}, function(args, self_token, chain_sender, chain_message)
    -- Have the same behavior of the lua elseif control structure.
    
    -- Must receive a message from preceding if
    if chain_sender ~= "\\if" and chain_sender ~= "\\elseif" then
        txe.error(self_token, "'elseif' macro must be preceded by 'if' or 'elseif'.")
    end

    local condition
    if chain_message then
        condition = txe.eval_lua_expression(args.condition)
        if condition then
            return args.body:render()
        end
    else
        condition = true
    end
    return "", not condition
end)