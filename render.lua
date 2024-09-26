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
-- @param params table The arguments table to be filled
-- @param opt_params table The optional arguments to parse
function plume.parse_opt_params (macro, params, opt_params)

    local key, eq, space
    local flags = {}

    local function capture_keyword(key, value)
        local name = key:render ()
        
        if macro.default_opt_params[name] == nil then
            if macro.variable_parameters_number then
                params.others.keywords[name] = value
            else 
                plume.error(key, "Unknow keyword parameters named '" .. name .. "' for macro '" .. macro.name .. "'.")
            end
        else
            params.keywords[name] = value
        end
    end

    local function capture_flag (key)
        local name = key:render ()
        if macro.variable_parameters_number then
            table.insert(params.others.flags, name)
        elseif macro.default_opt_params[name] == nil then
            plume.error(key, "Unknow flag named '" .. name .. "' for macro '" .. macro.name .. "'.")
        else
            flags[name] = true
            table.insert(params.flags, name)
        end
    end

    for _, token in ipairs(opt_params) do
        if token.kind ~= "opt_assign"
            and token.kind ~= "block" and token.kind ~= "block_text"
            and token.kind  ~= "space" and token.kind  ~= "newline" then
            plume.error(token, "Cannot use '" .. token.kind .. "' in optionnal parameters declaration. Please place braces around, or use raw text.")
        end

        if key then
            if token.kind == "space" or token.kind == "newline" then
            elseif eq then
                if token.kind == "opt_assign" then
                    plume.error(token, "Expected parameter value, not '" .. token.value .. "'.")
                end
                
                capture_keyword (key, token)
                
                eq = false
                key = nil
            elseif token.kind == "opt_assign" then
                eq = true
            else
                capture_flag(key)
                key = token
            end
        elseif token.kind == "opt_assign" then
            plume.error(token, "Expected parameter name, not '" .. token.value .. "'.")
        elseif token.kind ~= "space" and token.kind ~= "newline"then
            key = token
        end
    end
    if key then
        capture_flag(key)
    end

    local scope = plume.current_scope ()
    for k, _ in pairs(macro.default_opt_params) do
        if not params.keywords[k] then
            local v = scope.default[tostring(macro) .. "@" .. k]
            params.keywords[k] = v
        end
    end

    for k, v in pairs(scope.default[tostring(macro) .. "?keywords"] or {}) do
        if not params.others.keywords[k] then
            params.others.keywords[k] = v
        end
    end

    for _, k in pairs(scope.default[tostring(macro) .. "?flags"] or {}) do
        if not params.keywords[k] then
            table.insert(params.others.flags, k)
        end
    end
end

--- @api_method Get tokenlist rendered.
-- @name render
-- @return output The string rendered tokenlist.
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

        if token.kind ~= "space" and token.kind ~= "newline" then
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
            -- To be removed in 1.0 --
            if plume.running_api.config.ignore_spaces then
                last_is_newline = true
            --------------------------
            else
                if plume.running_api.config.filter_newlines then
                    if not last_is_newline then
                        table.insert(result, plume.running_api.config.filter_newlines)
                        last_is_newline = true
                    end
                elseif token.__type == "token" then
                    table.insert(result, token.value)
                else
                    table.insert(result, token:render())
                end
            end
        
        elseif token.kind == "space" then
            -- To be removed in 1.0 --
            if plume.running_api.config.ignore_spaces then
                if last_is_newline then
                    last_is_newline = false
                else
                    table.insert(result, " ")
                end
            --------------------------
            else
                if plume.running_api.config.filter_spaces then
                    if last_is_newline then
                        last_is_newline = false
                    else
                        table.insert(result, plume.running_api.config.filter_spaces)
                    end
                else
                    table.insert(result, token.value)
                end
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

            local macro = plume.current_scope(self.context).macros[name]
            if not macro then
                plume.error_macro_not_found(token, name)
            end

            local params = {}
            local opt_params

            while #params < #macro.params do
                pos = pos+1
                if not self[pos] then
                    -- End reached, but not enough arguments
                    plume.error(token, "End of block reached, not enough arguments for macro '" .. token.value.."'. " .. #params.." instead of " .. #macro.params .. ".")
                
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
                        table.insert(params, eval)
                        pos = pos + 1
                    else
                        plume.error(self[pos], "Macro call cannot be a parameter (here, parameter #"..(#params+1).." of the macro '\\" .. name .."', line" .. token.line .. ") without being surrounded by braces.")
                    end
                
                elseif self[pos].kind == "opt_block" then
                    -- Register an opt arg, or raise an error if too many.
                    if opt_params then
                        plume.error(self[pos], "To many optional blocks given for macro '\\" .. name .. "'")
                    else
                        opt_params = self[pos]
                    end
                    
                elseif self[pos].kind ~= "space" and self[pos].kind ~= "newline" then
                    -- If it is not a space, add the current block
                    -- to the argument list
                    table.insert(params, self[pos])
                end
            end

            -- Try to capture optional block,
            -- Even after parameters.
            if not opt_params then
                local test_pos = pos
                while self[test_pos+1] do
                    test_pos = test_pos+1
                    if self[test_pos].kind == "opt_block" then
                        opt_params = self[test_pos]
                        pos = test_pos
                        break
                    elseif self[test_pos].kind ~= "space" and self[test_pos].kind ~= "newline" then
                        break
                    end
                end
            end

            local macro_params = {
                positionnals={},
                keywords={},
                flags={},
                others={
                    keywords={},
                    flags={}
                }
            }
            for k, v in ipairs(params) do
                macro_params.positionnals[macro.params[k]] = v
            end
            -- for k, v in pairs(params) do
            --     if type(k) ~= "number" then
            --         macro_params[k] = v
            --     end
            -- end

            -- Parse optionnal params
            plume.parse_opt_params(macro, macro_params, opt_params or {})

            -- Update traceback, call the macro and add is result
            table.insert(plume.traceback, token)
                local success, macro_call_result = pcall(function ()
                    return { macro.macro (
                        macro_params,
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

--- @api_method Get tokenlist rendered. If the tokenlist first child is an eval block, evaluate it and return the result as a lua object. Otherwise, render the tokenlist.
-- @name renderLua
-- @return lua_objet Result of evaluation
function plume.renderTokenLua (self)
    local is_lua
    if #self == 2 and self[1].kind == "macro" then
        is_lua = is_lua or self[1].value == "#"
        is_lua = is_lua or self[1].value == "eval"
        --          To be removed in 1.0          --
        is_lua = is_lua or self[1].value == "script"
        --------------------------------------------
    end

    if is_lua then
        local result = plume.call_lua_chunk(self[2])
        if type(result) == "table" and result.__type == "tokenlist" then
            result = result:render ()
        end
        return result
    else
        local result = self:render ()
        return tonumber(result) or result
    end
end

-- <DEV>
function plume.print_params(params)
    print('-------')
    for k, v in pairs(params) do
        print(k)

        if k == "others" then
            for kk, vv in pairs(v) do
                print('\t' .. kk)
                for kkk, vvv in pairs(vv) do
                print('\t\t' .. kkk, vvv:render())
            end
            end
        else
            for kk, vv in pairs(v) do
                print('\t' .. kk, vv:render())
            end
        end
    end
    print('-------')
end
-- </DEV>