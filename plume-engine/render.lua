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

--- Parses optional arguments when calling a macro, then add default value if any
-- @param macro table The macro being called
-- @param params table The arguments table to be filled
-- @param opt_params table The optional arguments to parse
-- @param context table Scope to search default parameters for
function plume.make_opt_params (macro, params, opt_params, context)
    local key, eq
    local flags = {}
    local scope = plume.get_scope (context)

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

        -- trim name
        name = name:gsub('^%s+', ''):gsub('%s+$', '')

        -- empty flag don't raise an error
        if #name == 0 then
            return
        end

        -- Handle the sugar syntax "?flag", except for the macro "macro"
        if name:sub(1, 1) == "?" and macro.name ~= "macro" then
            name = name:sub(2, -1)

            -- If value of "$flag" is false or nil, abort
            if not scope:get("variables", name) then
                return
            end
            -- Otherwise, continue as if the user had supplied
            -- the word “flag” as an optional parameter. 
        end

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
        local token = opt_params[i]
        
        -- Anything that is not ${...}, "=", a block, a comment or a space (in fact, macros)
        -- will lead to an error
        if token.kind ~= "opt_assign" and token.kind ~= "comment"
            and token.kind ~= "block" and token.kind ~= "block_text"
            and token.kind  ~= "space" and token.kind  ~= "newline" and token.kind  ~= "code" then
            plume.syntax_error_cannot_use_inside_optionnal_block (token)
        end

        if key then
            if token.kind == "space" or token.kind == "newline" or token.kind == "comment" then
            elseif eq then
                if token.kind == "opt_assign" then
                    plume.syntax_error_expected_parameter_value(token)
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
            plume.syntax_error_expected_parameter_name(token)
        elseif token.kind ~= "space" and token.kind ~= "newline" and token.kind ~= "comment" then
            key = token
        end
    end
    if key then
        capture_flag(key)
    end

    
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

    -- if it is an eval token, parameter is saved inside
    if macro_token.kind == "code" then
        table.insert(params, macro_token[2])
        opt_params = macro_token[3]
    end

    -- Iterate over token list child until getting enough parameters
    while #params < nargs do
        pos = pos + 1

        -- End reached, but not enough arguments
        if not tokenlist[pos] then
            plume.error_end_block_reached(macro_token, #params, nargs)
        
        -- Macro as a parameter must be enclosed in braces, to avoid
        -- nested parameters capture
        elseif tokenlist[pos].kind == "macro" then
            plume.error_macro_call_without_braces (macro_token, tokenlist[pos], #params + 1)
       
        -- Lua block is the only exception, because it's parameter is already
        -- captured in the parser.
        elseif tokenlist[pos].kind == "code" then
            table.insert(params, tokenlist[pos])
        
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

    -- Try to capture the optional block after the last parameters
    -- Useful for macros without required parameters, but with optional ones
    if not opt_params then
        local test_pos = pos
        while tokenlist[test_pos+1] do
            test_pos = test_pos+1
            if tokenlist[test_pos].kind == "opt_block" then
                opt_params = tokenlist[test_pos]
                pos = test_pos
                break

            -- stop searching if hint anything that isn't a space
            elseif tokenlist[test_pos].kind ~= "space" and tokenlist[test_pos].kind ~= "newline" then
                break
            end
        end
    end

    return pos, params, opt_params
end

function plume.call_macro (macro, calling_token, parameters, chain_sender, chain_message)
        
    local traceback_token = calling_token
    if calling_token.kind == "code" then
        traceback_token = calling_token[1]
    end

    -- Update traceback
    table.insert(plume.traceback, traceback_token)
        -- call the macro
        local success, macro_call_result = pcall(function ()
            return { macro.macro (
                parameters,
                calling_token, -- send self token to throw error, if any
                chain_sender,
                chain_message
            ) }
        end)

        local call_result
        if success then
            call_result, chain_message = macro_call_result[1], macro_call_result[2]
        else
            plume.error(calling_token, "Unexpected lua error running the macro : " .. macro_call_result)
        end

        -- code is a tokenlist, not a token
        if calling_token.kind ~= "code" then
            chain_sender = calling_token.value
        end
    -- end of call
    table.remove(plume.traceback)

    return call_result, chain_sender, chain_message
end

--- @api_method Get tokenlist rendered.
-- @name render
-- @return output The string rendered tokenlist.
function plume.render_token (self)
    local pos = 0
    local result = {}

    -- dirty fix
    if self.kind == "code" then
        local container = plume.tokenlist ("block")
        table.insert(container, self)
        return container:render()
    end

    -- Chain of information passed to adjacent macros
    -- Used to achieve \if \else behavior
    local chain_sender, chain_message

    -- Used to skip space at line beginning
    -- local last_is_newline = false

    local scope = plume.get_scope (self.context)

    -- Iterate over token childs
    while pos < #self do
        pos = pos + 1
        local token = self[pos]

        -- Get current configuration
        -- update after each child because any token can change it
        local config_filter_newlines    = scope:get("config", "filter_newlines")
        local config_filter_spaces      = scope:get("config", "filter_spaces")
        local config_max_callstack_size = scope:get("config", "max_callstack_size")

        -- Break the chain if encounter non macro non space token
        if token.kind ~= "newline" and token.kind ~= "space" and token.kind ~= "macro" and token.kind ~= "comment" then
            chain_sender  = nil
            chain_message = nil
        end

        if token.kind ~= "space" and token.kind ~= "newline" then
            -- print(token.kind)
            plume.last_is_newline = false
        end

        -- Call recursively render method on block
        if token.kind == "block_text" or token.kind == "block" then
            table.insert(result, token:render())

        -- No special render for text
        elseif token.kind == "text" or token.kind == "escaped_text" then
            table.insert(result, token.value)

        -- If optionnal blocks or assign are encoutered here, there
        -- are outside of a macro call, so treat it as normal text
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
                if not plume.last_is_newline then
                    table.insert(result, config_filter_newlines)
                    plume.last_is_newline = true
                end
            elseif token.__type == "token" then
                table.insert(result, token.value)
            else
                table.insert(result, token:render())
            end
        elseif token.kind == "space" then
            if config_filter_spaces then
                if plume.last_is_newline then
                    plume.last_is_newline = false
                else
                    table.insert(result, config_filter_spaces)
                end
            else
                table.insert(result, token.value)
            end

        -- Capture required number of parameters after the macro, then call it
        elseif token.kind == "macro" or token.kind == "code" then
            -- If more than config_max_callstack_size macro are running, throw an error.
            -- Mainly to adress "\macro foo \foo" kind of infinite loop.
            local up_limit = config_max_callstack_size
            
            if #plume.traceback > up_limit then
                plume.error(token, "To many intricate macro call (over the configurated limit of " .. up_limit .. ").")
            end

            -- Remove the "\" in front of macro to get the name
            local name

            -- "$" is a syntax sugar for "eval"
            if token.kind == "code" then
                name = "eval"
            else
                name = token.value:gsub("^"..plume.syntax.escape , "")
            end

            -- Check if the given name is a valid identifier
            if not plume.is_identifier(name) then
                plume.error_invalid_macro_name (token, name, "macro")
            end
            

            -- Check if macro exist
            local macro = scope:get("macros", name)
            if not macro then
                plume.error_macro_not_found(token, name)
            end

            -- Capture parameters
            local params, opt_params
            pos, params, opt_params = plume.capture_macro_args (self, token, pos, #macro.params)

            -- Rearange parameters for the call
            local macro_params = {
                positionnals={}, -- positionnal parameters
                keywords={},     -- optionnal parameters
                flags={},        -- syntax suger for some optionnal parameters
                others={         -- "others" is used if a macro accepts a variable number of parameters.
                    keywords={},
                    flags={}
                }
            }


            -- All captured parameters are postionnals
            for k, v in ipairs(params) do
                macro_params.positionnals[macro.params[k]] = v
            end

            -- Parse and add optionnals one. Add default values if any
            plume.make_opt_params(macro, macro_params, opt_params or {}, token.context)

            -- call macro
            local macro_call_result
            macro_call_result, chain_sender, chain_message = plume.call_macro (
                macro,
                token,
                macro_params,
                chain_sender,
                chain_message
            )

            -- Add result to the output
            table.insert(result, tostring(macro_call_result or ""))
        end
        
    end
    return table.concat(result)
end

--- @api_method Get tokenlist rendered. If the tokenlist first child is an eval block, evaluate it and return the result as a lua object. Otherwise, render the tokenlist.
-- @name render_lua
-- @return lua_objet Result of evaluation
function plume.render_token_lua (self)
    if self.kind == "code" then
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