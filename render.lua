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

function txe.parse_opt_args (macro, args, optargs)
    -- Capture "value" or "key=value" 
    -- in optionnals arguments when calling a macro.
    local key, eq, space
    local captured_args = {}
    for _, token in ipairs(optargs) do
        if key then
            if token.kind == "space" or token.kind == "newline" then
            elseif eq then
                if token.kind == "opt_assign" then
                    txe.error(token, "Expected parameter value, not '" .. token.value .. "'.")
                elseif key.kind ~= "block_text" then
                    txe.error(key, "Optional parameters names must be raw text.")
                end
                local name = key:render ()
                
                if not txe.is_identifier(name) then
                    txe.error(key, "'" .. name .. "' is an invalid name for an argument name.")
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
            txe.error(token, "Expected parameter name, not '" .. token.value .. "'.")
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

    -- If parameter alone, without key, try to
    -- find a name.
    local last_index = 1
    -- Not implemented : at the moment, cannot known
    -- argument order

    -- for _, arg_value in ipairs(t) do
    --     for i=last_index, #macro.defaut_optargs do
    --         local infos = macro.defaut_optargs[i]

    --         -- Check if this name isn't already used
    --         if not args[infos.name] then
    --             args[infos.name] = arg_value
    --             last_index = last_index + 1
    --             break
    --         end
    --     end
    -- end

    -- Put all remaining args in the field "$args"
    args["$args"] = {}
    for j=last_index, #captured_args do
        table.insert(args["$args"], captured_args[j])
    end

    -- set defaut value if not in args but provided by the macro
    for i, optarg in ipairs(macro.defaut_optargs) do
        if not args[optarg.name] then
            args[optarg.name] = optarg.value
        end
    end
end

function txe.renderToken (self)
    -- Main Plume - TextEngine function, who build the output.
    local pos = 1
    local result = {}

    -- Chain of info passed to adjacent macro
    -- Used to achive \if \else behavior
    local chain_sender, chain_message

    while pos <= #self do
        local token = self[pos]

        -- Break the chain if encounter non macro non space token
        if token.kind ~= "newline" and token.kind ~= "space" and token.kind ~= "macro" then
            chain_sender  = nil
            chain_message = nil
        end

        if token.kind == "block_text" then
            table.insert(result, token:render())

        elseif token.kind == "block" then
            table.insert(result, token:render())

        elseif token.kind == "opt_assign" then
            table.insert(result, token.value)

        elseif token.kind == "text" then
            table.insert(result, token.value)

        elseif token.kind == "escaped_text" then
            table.insert(result, token.value)
        
        elseif token.kind == "newline"  then
            table.insert(result, token.value)
        
        elseif token.kind == "space" then
            table.insert(result, token.value)
        
        elseif token.kind == "macro" then
            -- Capture required number of block after the macro.
            
            -- If more than txe.max_callstack_size macro are running, throw an error.
            -- Mainly to adress "\def foo \foo" kind of infinite loop.
            if #txe.traceback > txe.max_loop_size then
                txe.error(token, "To many intricate macro call (over the configurated limit of " .. txe.max_loop_size .. ").")
            end

            local stack = {}

            local function push_macro (token)
                -- Check if macro exist, then add it to the stack
                local name  = token.value:gsub("^"..txe.syntax.escape , "")
                local macro = txe.get_macro (name)
                if not macro then
                    txe.error(token, "Unknow macro '" .. name .. "'")
                end

                table.insert(stack, {token=token, macro=macro, args={}})
            end

            local function manage_optargs(top, token)
                if top.optargs then
                    txe.error(token, "To many optional blocks given for macro '" .. stack[1].token.value .. "'")
                end
                top.optargs = token
            end
 
            push_macro (token)
            -- Manage chained macro like \double \double x, that
            -- must be treated as \double{\double{x}}
            while #stack > 0 do
                
                -- Capture the right number of arguments for the macro
                local top = stack[#stack]
                while #top.args < #top.macro.args do
                    pos = pos+1
                    if not self[pos] then
                        -- End reached, but not enough arguments
                        txe.error(token, "End of block reached, not enough arguments for macro '" .. stack[1].token.value.."'. " .. #top.args.." instead of " .. #top.macro.args .. ".")
                    
                    elseif self[pos].kind == "macro" then
                        -- A new macro. Push it to the stack to catpures
                        -- it's arguments
                        push_macro(self[pos])
                        top = nil
                        break
                    
                    elseif self[pos].kind == "opt_block" then
                        -- An optional argument block
                        manage_optargs(top, self[pos])
                    
                    elseif self[pos].kind ~= "space" then
                        -- If it is not a space, add the current block
                        -- to the argument list
                        table.insert(top.args, self[pos])
                    end
                end

                --Check if there are an optional block after the arguments
                local finded_optional = false
                local oldpos          = pos
                while self[pos+1] do
                    pos = pos + 1
                    if self[pos].kind ~= "space" then
                        finded_optional = self[pos].kind == "opt_block"
                        break
                    end
                end

                if finded_optional then
                    manage_optargs(top, self[pos])
                else
                    pos = oldpos
                end

                -- top if nil only when capturing a new macro
                if top then
                    top = table.remove(stack)
                    if #stack > 0 then
                        local subtop = stack[#stack]
                        local arg_list = txe.tokenlist(top.args)

                        -- rebuild the captured macro hand it's argument
                        if top.optargs then
                            table.insert(arg_list, 1, top.optargs)
                        end
                        
                        table.insert(arg_list, 1, top.token)
                        table.insert(subtop.args, arg_list)
                    else
                        local args = {}
                        for k, v in ipairs(top.args) do
                            args[top.macro.args[k]] = v
                        end
                        for k, v in pairs(top.args) do
                            if type(k) ~= "number" then
                                args[k] = v
                            end
                        end

                        -- Parse optionnal args
                        txe.parse_opt_args(top.macro, args, top.optargs or {})

                        -- Update traceback, call the macro and add is result
                        table.insert(txe.traceback, token)

                        local call_result
                        call_result, chain_message = top.macro.macro(
                            args,
                            top.token,--send self token to throw error
                            chain_sender,
                            chain_message
                        )

                        chain_sender = top.token.value

                        table.insert(result, tostring(call_result or ""))
                        table.remove(txe.traceback)
                    end
                end
            end
        end
        pos = pos + 1
    end
    return table.concat(result)
end