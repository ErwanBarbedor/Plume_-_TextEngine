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
-- @param context table Scope to search default parameters for
function plume.parse_opt_params (macro, params, opt_params, context)
    local key, eq, space
    local flags = {}

    local function capture_keyword(key, value)
        local name = key:render ()
        
        if macro.default_opt_params[name] == nil then
            if macro.variable_parameters_number then
                params.others.keywords[name] = value
            else
                plume.error_unknown_parameter (key, macro.name, name, macro.default_opt_params)
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
            plume.error_unknown_parameter (key, macro.name, name, macro.default_opt_params)
        else
            flags[name] = true
            table.insert(params.flags, name)
        end
    end

    local i=0
    while i < #opt_params do
        i = i + 1
        token = opt_params[i]
        -- See ${...} as {${...}}
        if token.kind == "macro" and token.value == plume.syntax.eval then
            local eval = plume.tokenlist("block")
            table.insert(eval, token)

            i = i + 1
            if not opt_params[i] then
                plume.error(token, "End of block reached, not enough arguments for macro '$'.0 instead of 1.")
            end
            table.insert(eval, opt_params[i])

            if opt_params[i+1] and opt_params[i+1].kind == "opt_block" then
                i = i + 1
                table.insert(eval, opt_params[i])
            end
            token = eval
        -- Anything that is not ${...}, "=", a block, a comment or a space (in fact, macros)
        -- will lead to an error
        elseif token.kind ~= "opt_assign" and token.kind ~= "comment"
            and token.kind ~= "block" and token.kind ~= "block_text"
            and token.kind  ~= "space" and token.kind  ~= "newline" then
            plume.error(token, "Cannot use '" .. token.kind .. "' in optionnal parameters declaration. Please place braces around, or use raw text.")
        end

        if key then
            if token.kind == "space" or token.kind == "newline" or token.kind == "comment" then
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
        elseif token.kind ~= "space" and token.kind ~= "newline" and token.kind ~= "comment" then
            key = token
        end
    end
    if key then
        capture_flag(key)
    end

    local scope = plume.get_scope (context)
    for k, _ in pairs(macro.default_opt_params) do
        if not params.keywords[k] then
            local keyword_name = tostring(macro) .. "@" .. k
            local v = scope:get("default", keyword_name)
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

--- Captures macro arguments from a token list, ensuring correct syntax and handling optional blocks.
-- @param tokenlist table The list of tokens to parse.
-- @param macro_token table The macro token used as reference for error messages.
-- @param pos number The current position in the token list.
-- @param nargs number The number of arguments to capture.
-- @return number The new position in the token list after processing.
-- @return table The list of captured macro arguments.
-- @return table|nil The optional parameter, if any.
function plume.capture_macro_args(tokenlist, macro_token, pos, nargs)
    local params = {}
    local opt_params

    -- Iterate over token list child until getting enough parameters
    while #params < nargs do
        pos = pos + 1

        -- End reached, but not enough arguments
        if not tokenlist[pos] then
            plume.error_end_block_reached(macro_token, #params, nargs)
        
        elseif tokenlist[pos].kind == "macro" then
            -- Macro as a parameter must be enclosed in braces
            if tokenlist[pos].value ~= plume.syntax.eval then
                plume.error_macro_call_without_braces (macro_token, tokenlist[pos], #params + 1)
                
            -- Lua block is the only exception. Capture its parameter here.
            else
                if not tokenlist[pos + 1] then
                    plume.error_end_block_reached(macro_token, 0, 1)
                end
                local eval = plume.tokenlist()
                table.insert(eval, tokenlist[pos])
                table.insert(eval, tokenlist[pos + 1])

                if tokenlist[pos + 2] and tokenlist[pos + 2].kind == "opt_block" then
                    table.insert(eval, tokenlist[pos + 2])
                    pos = pos + 1
                end

                table.insert(params, eval)
                pos = pos + 1
            end
        
        -- Register an optional argument, or raise an error if too many.
        elseif tokenlist[pos].kind == "opt_block" then
            
            if opt_params then
                plume.error(tokenlist[pos], "Too many optional blocks given for macro '" .. macro_token.value .. "'")
            else
                opt_params = tokenlist[pos]
            end
            
        -- If it is not a space or newline, add the current block
        -- to the argument list
        elseif tokenlist[pos].kind ~= "space" and tokenlist[pos].kind ~= "newline" then
            table.insert(params, tokenlist[pos])
        end
    end

    return pos, params, opt_params
end


--- @api_method Get tokenlist rendered.
-- @name render
-- @return output The string rendered tokenlist.
function plume.render_token (self)
    local pos = 1
    local result = {}

    -- Chain of information passed to adjacent macros
    -- Used to achieve \if \else behavior
    local chain_sender, chain_message

    -- Used to skip space at line beginning
    local last_is_newline = false

    local scope = plume.get_scope (self.context)

    -- Iterate over token childs
    while pos <= #self do
        local token = self[pos]

        -- Get current configuration
        local config_filter_newlines    = scope:get("config", "filter_newlines")
        local config_filter_spaces      = scope:get("config", "filter_spaces")
        local config_max_callstack_size = scope:get("config", "max_callstack_size")

        -- Break the chain if encounter non macro non space token
        if token.kind ~= "newline" and token.kind ~= "space" and token.kind ~= "macro" and token.kind ~= "comment" then
            chain_sender  = nil
            chain_message = nil
        end

        if token.kind ~= "space" and token.kind ~= "newline" then
            last_is_newline = false
        end

        -- Call recursively render method on block
        if token.kind == "block_text" or token.kind == "block" then
            table.insert(result, token:render())

        -- No special render for text
        elseif token.kind == "text" or token.kind == "escaped_text" then
            table.insert(result, token.value)

        -- If optionnal blocks or assign are encoutered here, there
        -- are outside of a macro call, so treat it as raw text
        elseif token.kind == "opt_block" then
            table.insert(result,
                plume.syntax.opt_block_begin
                .. token:render() 
                .. plume.syntax.opt_block_end
            )
        elseif token.kind == "opt_assign" then
            table.insert(result, token.value)

        -- For space and newline, apply filter if exist.
        elseif token.kind == "newline" then
            if config_filter_newlines then
                if not last_is_newline then
                    table.insert(result, config_filter_newlines)
                    last_is_newline = true
                end
            elseif token.__type == "token" then
                table.insert(result, token.value)
            else
                table.insert(result, token:render())
            end
        elseif token.kind == "space" then
            if config_filter_spaces then
                if last_is_newline then
                    last_is_newline = false
                else
                    table.insert(result, config_filter_spaces)
                end
            else
                table.insert(result, token.value)
            end

        elseif token.kind == "macro" then
            -- Capture required number of block after the macro.
            
            -- If more than plume.max_callstack_size macro are running, throw an error.
            -- Mainly to adress "\macro foo \foo" kind of infinite loop.
            local up_limit = config_max_callstack_size
            
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

            local macro = scope:get("macros", name)
            if not macro then
                plume.error_macro_not_found(token, name)
            end

            local params, opt_params
            pos, params, opt_params = plume.capture_macro_args (self,  token, pos, #macro.params)

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
            plume.parse_opt_params(macro, macro_params, opt_params or {}, token.context)

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
-- @name render_lua
-- @return lua_objet Result of evaluation
function plume.render_token_lua (self)
    if self:is_eval_block () then
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