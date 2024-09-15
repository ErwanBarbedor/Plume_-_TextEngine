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

--- Parses optional arguments when calling a macro.
-- @param macro table The macro being called
-- @param args table The arguments table to be filled
-- @param opt_args table The optional arguments to parse
function plume.parse_opt_args (macro, args, opt_args)
    local key, eq, space
    local captured_args = {}
    for _, token in ipairs(opt_args) do
        if key then
            if token.kind == "space" or token.kind == "newline" then
            elseif eq then
                if token.kind == "opt_assign" then
                    plume.error(token, "Expected parameter value, not '" .. token.value .. "'.")
                elseif key.kind ~= "block_text" then
                    plume.error(key, "Optional parameters names must be raw text.")
                end
                local name = key:render ()
                
                if not plume.is_identifier(name) then
                    plume.error(key, "'" .. name .. "' is an invalid name for an argument name.")
                end

                captured_args[name] = token
                eq = false
                key = nil
            elseif token.kind == "opt_assign" then
                eq = true
            else
                table.insert(captured_args, key)
                key = token
            end
        elseif token.kind == "opt_assign" then
            plume.error(token, "Expected parameter name, not '" .. token.value .. "'.")
        elseif token.kind ~= "space" and token.kind ~= "newline"then
            key = token
        end
    end
    if key then
        table.insert(captured_args, key)
    end

    -- Add all named arguments to the table args
    for k, v in pairs(captured_args) do
        if type(k) ~= "number" then
            args[k] = v
        end
    end

    -- Put all remaining args in the field "__args"
    args.__args = {}
    for j=1, #captured_args do
        table.insert(args.__args, captured_args[j])
    end

    -- set defaut value if not in args but provided by the macro
    -- or provided by the user
    for name, value in pairs(macro.user_opt_args) do
        if tonumber(name) then
            if not args.__args[name] then
                args.__args[name] = value
            end
        else
            if not args[name] then
                args[name] = value
            end
        end
    end
    for name, value in pairs(macro.default_opt_args) do
        if tonumber(name) then
            if not args.__args[name] then
                args.__args[name] = value
            end
        else
            if not args[name] then
                args[name] = value
            end
        end
    end

    -- Add __args elements as a key, to simply check for
    -- the presence of a specific word in optional arguments.
    -- Use of :source to avoid calling :render in a hidden way.
    for _, token in ipairs(args.__args) do
        args.__args[token:source()] = true
    end
end

--- Main Plume - TextEngine function, that builds the output.
-- @param self tokenlist The token list to render
-- @return string The rendered output
function plume.renderToken (self)
    local pos = 1
    local result = {}

    -- Chain of information passed to adjacent macros
    -- Used to achieve \if \else behavior
    local chain_sender, chain_message

    -- Used to skip space at line beginning
    local last_is_newline = false

    while pos <= #self do
        local token = self[pos]

        -- Break the chain if encounter non macro non space token
        if token.kind ~= "newline" and token.kind ~= "space" and token.kind ~= "macro" and token.kind ~= "comment" then
            chain_sender  = nil
            chain_message = nil
        end

        if token.kind ~= "space" then
            last_is_newline = false
        end

        if token.kind == "block_text" then
            table.insert(result, token:render())

        elseif token.kind == "block" then
            table.insert(result, token:render())

        elseif token.kind == "opt_block" then
            table.insert(result,
                plume.syntax.opt_block_begin
                .. token:render() 
                .. plume.syntax.opt_block_end)

        elseif token.kind == "opt_assign" then
            table.insert(result, token.value)

        elseif token.kind == "text" then
            table.insert(result, token.value)

        elseif token.kind == "escaped_text" then
            table.insert(result, token.value)
        
        elseif token.kind == "newline" then
            if not plume.running_api.config.ignore_spaces then
                if token.__type == "token" then
                    table.insert(result, token.value)
                else
                    table.insert(result, token:render())
                end
            else
                last_is_newline = true
            end
        
        elseif token.kind == "space" then
            if plume.running_api.config.ignore_spaces then
                if last_is_newline then
                    last_is_newline = false
                else
                    table.insert(result, " ")
                end
            else
                table.insert(result, token.value)
            end

        elseif token.kind == "macro" then
            -- Capture required number of block after the macro.
            
            -- If more than plume.max_callstack_size macro are running, throw an error.
            -- Mainly to adress "\def foo \foo" kind of infinite loop.
            local up_limit = plume.running_api.config.max_callstack_size
            
            if #plume.traceback > up_limit then
                plume.error(token, "To many intricate macro call (over the configurated limit of " .. up_limit .. ").")
            end

            local name = token.value:gsub("^"..plume.syntax.escape , "")

            if name == plume.syntax.eval then
                name = "eval"
            end

            if not plume.is_identifier(name) then
                plume.error(token, "'" .. name .. "' is an invalid name for a macro.")
            end

            local macro = (self.context or plume.current_scope()).macros[name]
            if not macro then
                plume.error_macro_not_found(token, name)
            end

            local args = {}
            local opt_args

            while #args < #macro.args do
                pos = pos+1
                if not self[pos] then
                    -- End reached, but not enough arguments
                    plume.error(token, "End of block reached, not enough arguments for macro '" .. token.value.."'. " .. #args.." instead of " .. #macro.args .. ".")
                
                elseif self[pos].kind == "macro" then
                    -- Raise an error. (except for '#') 
                    -- Macro as parameter must be enclosed in braces
                    if self[pos].value == plume.syntax.eval then
                        if not self[pos+1] then
                            plume.error(token, "End of block reached, not enough arguments for macro '#'.0 instead of 1.")
                        end
                        local eval = plume.tokenlist ()
                        table.insert(eval, self[pos])
                        table.insert(eval, self[pos+1])
                        table.insert(args, eval)
                        pos = pos + 1
                    else
                        plume.error(self[pos], "Macro call cannot be a parameter (here, parameter #"..(#args+1).." of the macro '\\" .. name .."', line" .. token.line .. ") without being surrounded by braces.")
                    end
                
                elseif self[pos].kind == "opt_block" then
                    -- Register an opt arg, or raise an error if too many.
                    if opt_args then
                        plume.error(self[pos], "To many optional blocks given for macro '\\" .. name .. "'")
                    else
                        opt_args = self[pos]
                    end
                    
                elseif self[pos].kind ~= "space" and self[pos].kind ~= "newline" then
                    -- If it is not a space, add the current block
                    -- to the argument list
                    table.insert(args, self[pos])
                end
            end

            -- Try to capture optional block,
            -- Even after parameters.
            if not opt_args then
                local test_pos = pos
                while self[test_pos+1] do
                    test_pos = test_pos+1
                    if self[test_pos].kind == "opt_block" then
                        opt_args = self[test_pos]
                        pos = test_pos
                        break
                    elseif self[test_pos].kind ~= "space" and self[test_pos].kind ~= "newline" then
                        break
                    end
                end
            end

            local macro_args = {}
            for k, v in ipairs(args) do
                macro_args[macro.args[k]] = v
            end
            for k, v in pairs(args) do
                if type(k) ~= "number" then
                    macro_args[k] = v
                end
            end

            -- Parse optionnal args
            plume.parse_opt_args(macro, macro_args, opt_args or {})

            -- Update traceback, call the macro and add is result
            table.insert(plume.traceback, token)
                local success, macro_call_result = pcall(function ()
                    return { macro.macro (
                        macro_args,
                        token, -- send self token to throw error, if any
                        chain_sender,
                        chain_message
                    ) }
                end)

                local call_result
                if success then
                    call_result, chain_message = macro_call_result[1], macro_call_result[2]
                else
                    plume.error(token, "Unexpected lua error running the macro : " .. macro_call_result)
                end

                chain_sender = token.value

                table.insert(result, tostring(call_result or ""))
            table.remove(plume.traceback)

        end
        pos = pos + 1
    end
    return table.concat(result)
end

--- If the tokenlist starts with `#`, `eval` or `script`
-- evaluate this macro and return the result as a lua object,
-- without conversion to string.
-- Otherwise, render the tokenlist.
-- @param self tokenlist The token list to render
-- @return lua_objet Result of evaluation
function plume.renderTokenLua (self)
    local is_lua
    if #self == 2 and self[1].kind == "macro" then
        is_lua = is_lua or self[1].value == "#"
        is_lua = is_lua or self[1].value == "eval"
        is_lua = is_lua or self[1].value == "script"
    end

    if is_lua then
        local result = plume.eval_lua_expression(self[2])
        if type(result) == "table" and result.__type == "tokenlist" then
            result = result:render ()
        end
        return result
    else
        local result = self:render ()
        return tonumber(result) or result
    end
end