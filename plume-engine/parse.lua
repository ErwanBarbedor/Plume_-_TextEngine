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

--- Converts a flat list of tokens into a nested structure.
-- Handles blocks, optional blocks, and text grouping
-- @param tokenlist table The list of tokens to parse
-- @return tokenlist The parsed nested structure
function plume.parse (tokenlist)
    local stack = {plume.tokenlist("block")}

    for _, token in ipairs(tokenlist) do
        local top = stack[#stack]

        if token.kind == "block_begin" then
            eval_var = 0
            table.insert(stack, plume.tokenlist("block"))
            stack[#stack].opening_token = token
        
        elseif token.kind == "block_end" then
            eval_var = 0
            local block = table.remove(stack)
            local top = stack[#stack]

            -- Check if match the oppening brace
            if not top then
                plume.syntax_error_brace_close_nothing (token)
            elseif block.kind ~= "block" then
                plume.syntax_error_unpaired_braces (token, block.opening_token.value)
            end
            
            block.closing_token = token

            local parent = stack[#stack]
            table.insert(parent, block)
        
        elseif token.kind == "opt_block_begin" then
            table.insert(stack, plume.tokenlist("opt_block"))
            stack[#stack].opening_token = token
        
        elseif token.kind == "opt_block_end" then
            local last = table.remove(stack)
            local top = stack[#stack]

            -- Check if match the oppening brace
            if not top then
                plume.syntax_error_brace_close_nothing (token)
            elseif last.kind ~= "opt_block" then
                plume.syntax_error_unpaired_braces (token, last.opening_token.value)
            end

            last.closing_token = token
            local parent = stack[#stack]
            
            -- Check if last token is an eval without optionnal block
            local previous = parent[#parent]
            if previous and previous.kind == "code" and #previous == 2 then
                parent = previous
            end

            table.insert(parent, last)
        
        elseif token.kind == "text" 
            or token.kind == "escaped_text" 
            or token.kind == "opt_assign" and top.kind ~= "opt_block" then

            local last = stack[#stack]
            if #last == 0 or last[#last].kind ~= "block_text" then
                table.insert(last, plume.tokenlist("block_text"))
            end
            table.insert(last[#last], token)
        
        elseif token.kind == "eval" then
            table.insert(stack, plume.tokenlist("code"))
            table.insert(stack[#stack], token)
            
        else
            table.insert(stack[#stack], token)
        end

        -- If last block is code, close it after capture two tokens.
        local last = stack[#stack]
        if last.kind == "code" and #last == 2 then
            local code   = table.remove(stack)
            local parent =  stack[#stack]

            table.insert(parent, code)
        end
    end
    if #stack > 1 then
        plume.syntax_error_brace_unclosed (stack[#stack].opening_token)
    end
    return stack[1] 
end