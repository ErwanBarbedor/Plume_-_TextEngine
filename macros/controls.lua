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

--- \for
-- Implements a custom iteration mechanism that mimics Lua's for loop behavior.
-- @param iterator Anything that follow the lua iterator syntax, such as `i=1, 10` or `foo in pairs(t)`.
-- @param body A block that will be repeated.
-- @note Each iteration has it's own scope. The maximal number of iteration is limited by `plume.config.max_loop_size`. See [config](config.md) to edit it.
plume.register_macro("for", {"iterator", "body"}, {}, function(args, calling_token)
    -- The macro uses coroutines to handle the iteration process, which allows for flexible
    -- iteration over various types of iterables without implementing a full Lua parser.
    local result = {}
    local iterator_source = args.iterator:source ()
    local var, var1, var2, first, last

    local mode = 1

    -- Try to parse the iterator syntax
    -- First, attempt to match the "var = iterator" syntax
    if not var then
        var, iterator = iterator_source:match('%s*([a-zA-Z_][a-zA-Z0-9_]*)%s*=%s*(.-)$')
    end

    --- If the first attempt fails, try to match the "var in iterator" syntax
    if not var then
        var, iterator = iterator_source:match('%s*(.-[^,])%s+in%s*(.-)$')
    end
    
    -- If both attempts fail, raise an error
    if not var then
        plume.error(args.iterator, "Non valid syntax for iterator.")
    end

    -- Extract all variable names from the iterator
    local variables_list = {}
    for name in var:gmatch('[^%s,]+') do
        table.insert(variables_list, name)
    end

    -- Construct a Lua coroutine to handle the iteration
    local coroutine_code = "return coroutine.create(function () for " .. iterator_source .. " do"
    coroutine_code = coroutine_code .. " coroutine.yield(" .. var .. ")"
    coroutine_code = coroutine_code .. " end end)"

    -- Load and create the coroutine
    -- plume.push_scope ()
    local iterator_coroutine = plume.load_lua_chunk (coroutine_code)
    plume.setfenv (iterator_coroutine, plume.current_scope (calling_token.context).variables)
    local co = iterator_coroutine ()
    -- plume.pop_scope ()
    
    -- Limiting loop iterations to avoid infinite loop
    local up_limit = plume.running_api.config.max_loop_size
    local iteration_count  = 0

    
    -- Main iteration loop
    while true do
        -- Update and check loop limit
        iteration_count = iteration_count + 1
        if iteration_count > up_limit then
            plume.error(args.condition, "To many loop repetition (over the configurated limit of " .. up_limit .. ").")
        end

        -- Iteration scope
        plume.push_scope (args.body.context)

        -- Resume the coroutine to get the next set of values
        local values_list = { coroutine.resume(co) }
        local sucess = values_list[1]
        table.remove(values_list, 1)
        local first_value = values_list[1]
            
        -- Break the loop if there are no more values
        if not first_value then
            -- exit iteration scope
            plume.pop_scope ()
            break
        end

        -- Check for Lua errors in the coroutine
        if not sucess or not co then
            plume.error(args.iterator, "(lua error)" .. first_value:gsub('.-:[0-9]+:', ''))
        end

        -- Verify that the number of variables matches the number of values
        if #values_list ~= #variables_list then
            plume.error(args.iterator,
                "Wrong number of variables, "
                .. #variables_list
                .. " instead of "
                .. #values_list .. "." )
        end

        -- Set local variables in the current scope
        for i=1, #variables_list do
            (calling_token.context or plume.current_scope ()):set_local ("variables", variables_list[i], values_list[i])
        end

        -- print("::", plume.current_scope ())
        -- Render the body of the loop and add it to the result
        local body = args.body:copy ()
        body:set_context(plume.current_scope(), true)
        table.insert(result, body:render())

        -- exit iteration scope
        plume.pop_scope ()
    end

    return table.concat(result, "")
end, nil, false, true)

--- \while
-- Implements a custom iteration mechanism that mimics Lua's while loop behavior.
-- @param condition Anything that follow syntax of a lua expression, to evaluate.
-- @param body A block that will be rendered while the condition is verified.
-- @note Each iteration has it's own scope. The maximal number of iteration is limited by `plume.config.max_loop_size`. See [config](config.md) to edit it.
plume.register_macro("while", {"condition", "body"}, {}, function(args)
    -- Have the same behavior of the lua while control structure.
    -- To prevent infinite loop, a hard limit is setted by plume.max_loop_size

    local result = {}
    local i = 0
    local up_limit = plume.running_api.config.max_loop_size
    while plume.call_lua_chunk (args.condition) do
        -- Each iteration have it's own local scope
        plume.push_scope (args.body.context)
        
        local body = args.body:copy ()
        body:set_context(plume.current_scope(), true)
        table.insert(result, body:render())
        i = i + 1
        if i > up_limit then
            plume.error(args.condition, "To many loop repetition (over the configurated limit of " .. up_limit .. ").")
        end

        -- exit local scope
        plume.pop_scope ()
    end

    return table.concat(result, "")
end, nil, false, true)

--- \if
-- Implements a custom mechanism that mimics Lua's if behavior.
-- @param condition Anything that follow syntax of a lua expression, to evaluate.
-- @param body A block that will be rendered, only if the condition is verified.
plume.register_macro("if", {"condition", "body"}, {}, function(args)
    -- Have the same behavior of the lua if control structure.
    -- Send a message "true" or "false" for activate (or not)
    -- following "else" or "elseif"

    local condition = plume.call_lua_chunk(args.condition)
    if condition then
        return args.body:render()
    end
    return "", not condition
end, nil, false, true)

--- \else
-- Implements a custom mechanism that mimics Lua's else behavior.
-- @param body A block that will be rendered, only if the last condition isn't verified.
-- @note Must follow an `\if` or an `\elseif` macro; otherwise, it will raise an error.
plume.register_macro("else", {"body"}, {}, function(args, self_token, chain_sender, chain_message)
    -- Have the same behavior of the lua else control structure.

    -- Must receive a message from preceding if
    if chain_sender ~= "\\if" and chain_sender ~= "\\elseif" then
        plume.error(self_token, "'else' macro must be preceded by 'if' or 'elseif'.")
    end

    if chain_message then
        return args.body:render()
    end

    return ""
end, nil, false, true)

--- \elseif
-- Implements a custom mechanism that mimics Lua's elseif behavior.
-- @param condition Anything that follow syntax of a lua expression, to evaluate.
-- @param body A block that will be rendered, only if the last condition isn't verified and the current condition is verified.
-- @note Must follow an `\if` or an `\elseif` macro; otherwise, it will raise an error.
plume.register_macro("elseif", {"condition", "body"}, {}, function(args, self_token, chain_sender, chain_message)
    -- Have the same behavior of the lua elseif control structure.
    
    -- Must receive a message from preceding if
    if chain_sender ~= "\\if" and chain_sender ~= "\\elseif" then
        plume.error(self_token, "'elseif' macro must be preceded by 'if' or 'elseif'.")
    end

    local condition
    if chain_message then
        condition = plume.call_lua_chunk(args.condition)
        if condition then
            return args.body:render()
        end
    else
        condition = true
    end
    return "", not condition
end, nil, false, true)

--- \do
-- Implements a custom mechanism that mimics Lua's do behavior.
-- @param body A block that will be rendered in a new scope.
plume.register_macro("do", {"body"}, {}, function(args, self_token)
    
    plume.push_scope ()
        local result = args.body:render ()
    plume.pop_scope ()

    return result
end, nil, false, true)