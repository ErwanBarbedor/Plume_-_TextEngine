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

-- Define for, while, if, elseif, else control structures

txe.register_macro("for", {"iterator", "body"}, {}, function(args)
    -- Have the same behavior of the lua for control structure.
    -- Limitation : limit for "i=1,10" must be constants

    local result = {}
    local iterator = args.iterator:source ()
    local var, var1, var2, first, last

    -- Iterator may be in the form of "i=1, 10"
    -- Or "i in ...."
    var, first, last = iterator:match('%s*(.-)%s*=%s*([0-9]-)%s*,%s*([0-9]-)$')
    if not var then
        var, iterator = iterator:match('%s*(.-)%s*in%s*(.-)$')
    end

    -- If it is the form 'i=1, 10'
    if var and first and last then
        for i=first, last do
            -- For some reasons, i is treated as a float...
            i = math.floor(i)
            
            -- Add counter to the local scope, to 
            -- be used by user
            txe.lua_env_set_local(var, i)
            
            table.insert(result, args.body:render())
        end

    -- If it is the form "i in ..."
    elseif iterator and var then
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
                txe.lua_env_set_local (variables_list[i], values_list[i])
            end

            table.insert(result, args.body:render())

            -- Call the iterator one more time
            values_list = { iter(state, values_list[1]),  }
        end
    
    -- If it was nor "i=1, 10" nor "i in ..."
    else
        txe.error(args.iterator, "Non valid syntax for iterator.")
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