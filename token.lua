function txe.token (kind, value, line, pos, file, code)
    -- Token represente a small chunck of code :
    -- a macro, a newline, a word...
    -- Each token track his position in the source code
    return setmetatable({
        kind  = kind,
        value = value,
        line  = line,
        pos   = pos,
        file  = file,
        code  = code,
        source = function (self)
            return self.value
        end
    }, {})
end

function txe.tokenlist (x)
    local kind = "block"
    local t = {}

    if type(x) == "table" then
        t = x
    else
        kind = x
    end

    local tokenlist = setmetatable({
        kind=kind,
        source = function (self)
            -- "detokenize" the tokens, to retrieve the
            -- original code.
            local result = {}
            for _, token in ipairs(self) do
                if token.kind == "block" then
                    table.insert(result, txe.syntax.block_begin)
                end
                table.insert(result, token:source())
                if token.kind == "block" then
                    table.insert(result, txe.syntax.block_end)
                end
            end

            return table.concat(result, "")
        end,
        render = function (self)
            -- Main TextEngine function, who build the output.
            local pos = 1
            local result = {}
            while pos <= #self do
                local token = self[pos]

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
                    -- Manage chained macro like \double \double x, that
                    -- must be treated as \double{\double{x}}

                    -- If more than txe.max_callstack_size macro are running, throw an error.
                    -- Mainly to adress "\def foo \foo" kind of infinite loop.
                    if #txe.traceback > txe.max_loop_size then
                        txe.error(token, "To many intricate macro call (over the configurated limit of " .. txe.max_loop_size .. ").")
                    end

                    local stack = {}

                    local function push_macro (token)
                        -- Check if macro exist, then add it to the stack
                        local name    = token.value:gsub("^"..txe.syntax.escape , "")
                        local macro = txe.get_macro (name)
                        if not macro then
                            txe.error(token, "Unknow macro '" .. name .. "'")
                        end

                        table.insert(stack, {token=token, macro=macro, args={}})
                    end
                    
                    push_macro (token)
                    while #stack > 0 do
                        
                        local top = stack[#stack]
                        while #top.args < #top.macro.args do
                            pos = pos+1
                            if not self[pos] then
                                txe.error(token, "End of block reached, not enough arguments for macro '" .. stack[1].token.value.."'. " .. #top.args.." instead of " .. #top.macro.args .. ".")
                            elseif self[pos].kind == "macro" then
                                push_macro(self[pos])
                                top = nil
                                break
                            elseif self[pos].kind == "opt_block" and #stack == 1 then
                                if top.optargs then
                                    txe.error(self[pos], "To many optional blocks given for macro '" .. stack[1].token.value .. "'")
                                end
                                top.optargs = self[pos]
                            elseif self[pos].kind ~= "space" then
                                table.insert(top.args, self[pos])
                            end
                        end
                        if top then
                            top = table.remove(stack)
                            if #stack > 0 then
                                local subtop = stack[#stack]
                                table.insert(top.args, 1, top.token)
                                table.insert(subtop.args, txe.tokenlist(top.args))
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
                                table.insert(result, tostring(top.macro.macro(args) or ""))
                                table.remove(txe.traceback)
                            end
                        end
                    end
                end
                pos = pos + 1
            end
            return table.concat(result)
        end
    }, {})

    for k, v in ipairs(t) do
        tokenlist[k] = v
    end
    
    return tokenlist
end

function txe.parse_opt_args (macro, args, optargs)
    -- Check for value or key=value in optargs, and add it to args
    local key, eq
    local t = {}
    for _, token in ipairs(optargs) do
        if key then
            if token.kind == "space" then
                table.insert(t, key)
                key = nil
            elseif eq then
                if token.kind == "opt_assign" then
                    txe.error(token, "Expected parameter value, not '" .. token.value .. "'.")
                elseif key.kind ~= "block_text" then
                    txe.error(key, "Optional parameters names must be raw text.")
                end
                key = key:render ()
                -- check if "key" is a valid identifier
                -- to do...
                t[key] = token
                eq = false
                key = nil
            elseif token.kind == "opt_assign" then
                eq = true
            end
        elseif token.kind == "opt_assign" then
            txe.error(token, "Expected parameter name, not '" .. token.value .. "'.")
        elseif token.kind ~= "space" then
            key = token
        end
    end
    if key then
        table.insert(t, key)
    end

    -- print "---------"
    for k, v in pairs(t) do
        if type(k) ~= "number" then
            args[k] = v
        end
    end

    -- If parameter alone, without key, try to
    -- find a name.
    local i = 1
    for _, name in ipairs(macro.defaut_optargs) do
        --to do...
    end

    -- Put all remaining tokens in the field "..."
    args['...'] = {}
    for j=i, #t do
        table.insert(args['...'], t[j])
    end

    -- set defaut value if provided by the macros
    -- to do...
end