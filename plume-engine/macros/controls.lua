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
return function (plume)
    local function extract_variables_names (token)
        local result = {}
        local pos = 1

        while pos <= #token do
            local child = token[pos]
            if child.kind == "lua_word" then
                table.insert(result, child.value)
            elseif (child.kind == "lua_code" and (child.value:match('=') or child.value == "in")) then
                break
            end
            pos = pos+1
        end

        return result
    end

    --- \for
    -- Implements a custom iteration mechanism that mimics Lua's for loop behavior.
    -- @param iterator Anything that follow the lua iterator syntax, such as `i=1, 10` or `foo in pairs(t)`.
    -- @param body A block that will be repeated.
    -- @note Each iteration has it's own scope. The maximal number of iteration is limited by `plume.config.max_loop_size`. See [config](config.md) to edit it.
    plume.register_macro("for", {"iterator", "body"}, {join=""}, function(params, calling_token)
        -- The macro uses coroutines to handle the iteration process, which allows for flexible
        -- iteration over various types of iterables without implementing a full Lua parser.
        local result = {}
        local scope = plume.get_scope (calling_token.context)
        local max_loop_size = scope:get("config", "max_loop_size")

        if params.positionals.iterator.kind ~= "code" then
           plume.error_expecting_an_eval_block (params.positionals.iterator)
        end
         
        local join = plume.render_if_token(params.keywords.join)

        -- Get iterator code and extract the names of the variables
        local iterator_token = params.positionals.iterator[2]
        local iterator_code  = iterator_token:source_lua ({}, false, false)
        local variables_list  = extract_variables_names (iterator_token)

        -- Construct a Lua coroutine to handle the iteration
        local coroutine_code = "return coroutine.create(function () for " .. iterator_code .. " do"
        coroutine_code = coroutine_code .. " coroutine.yield(" .. table.concat(variables_list, ",") .. ")"
        coroutine_code = coroutine_code .. " end end)"

        -- Load and create the coroutine
        local iterator_coroutine = plume.load_lua_chunk (coroutine_code)
        if not iterator_coroutine then
            plume.error_syntax_invalid_for_iterator (iterator_token)
        end

        local scope = plume.get_scope (calling_token.context)
        plume.setfenv (iterator_coroutine, scope:bridge_to("variables"))
        local co = iterator_coroutine ()
        
        -- Limiting loop iterations to avoid infinite loop
        local iteration_count  = 0

        -- Main iteration loop
        while true do
            -- Update and check loop limit
            iteration_count = iteration_count + 1
            if iteration_count > max_loop_size then
                plume.error_to_many_loop (calling_token, max_loop_size)
            end

            -- Iteration scope
            plume.push_scope (params.positionals.body.context)

            -- Resume the coroutine to get the next set of values
            local values_list = { coroutine.resume(co) }
            local sucess = values_list[1]
            table.remove(values_list, 1)
            local first_value = values_list[1]
                
            -- If it not the end of the loop and not the
            -- firt iteration, add the join char
            if first_value then
                if iteration_count > 1 then
                    table.insert(result, join)
                end
            -- And break the loop if there are no more values
            else
                -- exit iteration scope
                plume.pop_scope ()
                break
            end

            -- Check for Lua errors in the coroutine
            if not sucess or not co then
                plume.error(params.positionals.iterator, "(lua error)" .. first_value:gsub('.-:[0-9]+:', ''))
            end

            -- Verify that the number of variables matches the number of values
            if #values_list ~= #variables_list then
                plume.error(params.positionals.iterator,
                    "Wrong number of variables, "
                    .. #variables_list
                    .. " instead of "
                    .. #values_list .. "." )
            end

            -- Set local variables in the current scope
            local local_scope = plume.get_scope (calling_token.context)
            for i=1, #variables_list do
                local_scope:set_local ("variables", variables_list[i], values_list[i])
            end

            -- Render the body of the loop and add it to the result
            local body = params.positionals.body:copy ()
            body:set_context(plume.get_scope(), true)
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
    plume.register_macro("while", {"condition", "body"}, {}, function(params, calling_token)
        -- Have the same behavior of the lua while control structure.
        -- To prevent infinite loop, a hard limit is setted by plume.max_loop_size
        local scope = plume.get_scope (calling_token.context)
        local max_loop_size = scope:get("config", "max_loop_size")

        
        local result = {}
        local i = 0

        local condition_code
        if params.positionals.condition.kind == "code" then
            condition_code  = params.positionals.condition[2]:source_lua ()
        else
            plume.error_expecting_an_eval_block (params.positionals.condition)
        end

        while plume.call_lua_chunk (params.positionals.condition, condition_code) do
            -- Each iteration have it's own local scope
            plume.push_scope (params.positionals.body.context)
            
            local body = params.positionals.body:copy ()
            body:set_context(plume.get_scope(), true)
            table.insert(result, body:render())
            i = i + 1
            if i > max_loop_size then
                plume.error_to_many_loop (calling_token, max_loop_size)
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
    plume.register_macro("if", {"condition", "body"}, {}, function(params, calling_token)
        -- Have the same behavior of the lua if control structure.
        -- Send a message "true" or "false" for activate (or not)
        -- following "else" or "elseif"
        local condition_code

        if params.positionals.condition.kind == "code" then
            condition_code  = params.positionals.condition[2]:source_lua ()
        else
            plume.error_expecting_an_eval_block (params.positionals.condition)
        end

        local condition = plume.call_lua_chunk(params.positionals.condition, condition_code)
        if condition then
            return params.positionals.body:render()
        end
        return "", not condition
    end, nil, false, true)

    --- \else
    -- Implements a custom mechanism that mimics Lua's else behavior.
    -- @param body A block that will be rendered, only if the last condition isn't verified.
    -- @note Must follow an `\if` or an `\elseif` macro; otherwise, it will raise an error.
    plume.register_macro("else", {"body"}, {}, function(params, self_token, chain_sender, chain_message)
        -- Must receive a message from preceding if
        if chain_sender ~= "\\if" and chain_sender ~= "\\elseif" then
            plume.error(self_token, "'else' macro must be preceded by 'if' or 'elseif'.")
        end

        if chain_message then
            return params.positionals.body:render()
        end

        return ""
    end, nil, false, true)

    --- \elseif
    -- Implements a custom mechanism that mimics Lua's elseif behavior.
    -- @param condition Anything that follow syntax of a lua expression, to evaluate.
    -- @param body A block that will be rendered, only if the last condition isn't verified and the current condition is verified.
    -- @note Must follow an `\if` or an `\elseif` macro; otherwise, it will raise an error.
    plume.register_macro("elseif", {"condition", "body"}, {}, function(params, self_token, chain_sender, chain_message)
        -- Must receive a message from preceding if
        if chain_sender ~= "\\if" and chain_sender ~= "\\elseif" then
            plume.error(self_token, "'elseif' macro must be preceded by 'if' or 'elseif'.")
        end

        local condition_token

        if params.positionals.condition.kind == "code" then
            condition_code  = params.positionals.condition[2]:source_lua ()
        else
            plume.error_expecting_an_eval_block (params.positionals.condition)
        end

        local condition
        if chain_message then
            condition = plume.call_lua_chunk(params.positionals.condition, condition_code)
            if condition then
                return params.positionals.body:render()
            end
        else
            condition = true
        end
        return "", not condition
    end, nil, false, true)

    --- \do
    -- Implements a custom mechanism that mimics Lua's do behavior.
    -- @param body A block that will be rendered in a new scope.
    plume.register_macro("do", {"body"}, {}, function(params, self_token)
        
        plume.push_scope ()
            local result = params.positionals.body:render ()
        plume.pop_scope ()

        return result
    end, nil, false, true)
end